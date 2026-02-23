import io
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseDownload
from google.oauth2 import service_account

SCOPES = ['https://www.googleapis.com/auth/drive']


class DriveWatcher:
    def __init__(self, config):
        sa_file = config['google_drive']['service_account_file']
        creds = service_account.Credentials.from_service_account_file(sa_file, scopes=SCOPES)
        self.service = build('drive', 'v3', credentials=creds)
        self.folder_id = config['google_drive']['folder_id']
        self.processed_name = config['google_drive'].get('processed_folder_name', 'processed')
        self._processed_folder_id = None

    def _get_or_create_processed_folder(self):
        if self._processed_folder_id:
            return self._processed_folder_id

        query = (
            f"'{self.folder_id}' in parents and "
            f"name='{self.processed_name}' and "
            f"mimeType='application/vnd.google-apps.folder' and trashed=false"
        )
        results = self.service.files().list(q=query, fields='files(id)').execute()
        files = results.get('files', [])

        if files:
            self._processed_folder_id = files[0]['id']
        else:
            metadata = {
                'name': self.processed_name,
                'mimeType': 'application/vnd.google-apps.folder',
                'parents': [self.folder_id],
            }
            folder = self.service.files().create(body=metadata, fields='id').execute()
            self._processed_folder_id = folder['id']

        return self._processed_folder_id

    def get_new_files(self):
        """Return list of (filename, file_id, content_string) for all CSVs in the folder."""
        query = (
            f"'{self.folder_id}' in parents and "
            f"(name contains '.csv' or name contains '.CSV') and "
            f"trashed=false"
        )
        results = self.service.files().list(q=query, fields='files(id, name)').execute()
        files = results.get('files', [])

        output = []
        for f in files:
            fid, fname = f['id'], f['name']
            request = self.service.files().get_media(fileId=fid)
            buf = io.BytesIO()
            downloader = MediaIoBaseDownload(buf, request)
            done = False
            while not done:
                _, done = downloader.next_chunk()
            # utf-8-sig handles optional BOM
            content = buf.getvalue().decode('utf-8-sig')
            output.append((fname, fid, content))

        return output

    def mark_processed(self, file_id):
        """Move a file into the processed/ subfolder."""
        processed_id = self._get_or_create_processed_folder()
        file_meta = self.service.files().get(fileId=file_id, fields='parents').execute()
        prev_parents = ','.join(file_meta.get('parents', []))
        self.service.files().update(
            fileId=file_id,
            addParents=processed_id,
            removeParents=prev_parents,
            fields='id, parents',
        ).execute()
