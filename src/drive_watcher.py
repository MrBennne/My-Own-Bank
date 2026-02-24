import io
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseDownload, MediaFileUpload
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
        results = self.service.files().list(
            q=query,
            fields='files(id)',
            includeItemsFromAllDrives=True,
            supportsAllDrives=True,
        ).execute()
        files = results.get('files', [])

        if files:
            self._processed_folder_id = files[0]['id']
        else:
            metadata = {
                'name': self.processed_name,
                'mimeType': 'application/vnd.google-apps.folder',
                'parents': [self.folder_id],
            }
            folder = self.service.files().create(body=metadata, fields='id', supportsAllDrives=True).execute()
            self._processed_folder_id = folder['id']

        return self._processed_folder_id

    SHEETS_MIME = 'application/vnd.google-apps.spreadsheet'

    def get_new_files(self):
        """Return list of (filename, file_id, content_string) for all CSVs/Sheets in the folder."""
        query = (
            f"'{self.folder_id}' in parents and trashed=false and ("
            f"name contains '.csv' or name contains '.CSV' or "
            f"mimeType='{self.SHEETS_MIME}'"
            f")"
        )
        results = self.service.files().list(
            q=query,
            fields='files(id, name, mimeType)',
            includeItemsFromAllDrives=True,
            supportsAllDrives=True,
        ).execute()
        files = results.get('files', [])

        output = []
        for f in files:
            fid, fname, mime = f['id'], f['name'], f['mimeType']
            buf = io.BytesIO()
            if mime == self.SHEETS_MIME:
                # Export Google Sheets as CSV
                request = self.service.files().export_media(fileId=fid, mimeType='text/csv')
                fname = fname if fname.lower().endswith('.csv') else fname + '.csv'
            else:
                request = self.service.files().get_media(fileId=fid)
            downloader = MediaIoBaseDownload(buf, request)
            done = False
            while not done:
                _, done = downloader.next_chunk()
            content = buf.getvalue().decode('utf-8-sig')
            output.append((fname, fid, content))

        return output

    def upload_log(self, log_path):
        """Overwrite pipeline.log in the Drive folder.

        The file must already exist in the folder (created manually by the Drive owner)
        because service accounts cannot create new files (no storage quota).
        """
        query = (
            f"'{self.folder_id}' in parents and name='pipeline.log' and trashed=false"
        )
        results = self.service.files().list(
            q=query,
            fields='files(id)',
            includeItemsFromAllDrives=True,
            supportsAllDrives=True,
        ).execute()
        existing = results.get('files', [])

        if not existing:
            raise FileNotFoundError(
                "pipeline.log not found in Drive folder. "
                "Please create an empty 'pipeline.log' text file there manually."
            )

        media = MediaFileUpload(log_path, mimetype='text/plain', resumable=False)
        self.service.files().update(
            fileId=existing[0]['id'],
            media_body=media,
            supportsAllDrives=True,
        ).execute()

    def mark_processed(self, file_id):
        """Move a file into the processed/ subfolder."""
        processed_id = self._get_or_create_processed_folder()
        file_meta = self.service.files().get(fileId=file_id, fields='parents', supportsAllDrives=True).execute()
        prev_parents = ','.join(file_meta.get('parents', []))
        self.service.files().update(
            fileId=file_id,
            addParents=processed_id,
            removeParents=prev_parents,
            fields='id, parents',
            supportsAllDrives=True,
        ).execute()
