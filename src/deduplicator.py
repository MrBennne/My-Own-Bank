from notion_client import Client


class Deduplicator:
    def __init__(self, config):
        self.client = Client(auth=config['notion']['token'])
        self.db_id = config['notion']['database_id']

    def _fetch_existing(self):
        """Fetch all (date, name, amount) keys from Notion into a set."""
        existing = set()
        cursor = None

        while True:
            kwargs = {'database_id': self.db_id, 'page_size': 100}
            if cursor:
                kwargs['start_cursor'] = cursor

            resp = self.client.databases.query(**kwargs)

            for page in resp['results']:
                props = page['properties']
                try:
                    date = props['Date']['date']['start']
                    name_arr = props['n']['title']
                    name = name_arr[0]['plain_text'] if name_arr else ''
                    amount = props['Amount']['number']
                    if date and name and amount is not None:
                        existing.add((date, name, round(amount, 2)))
                except (KeyError, TypeError, IndexError):
                    continue

            if not resp.get('has_more'):
                break
            cursor = resp['next_cursor']

        return existing

    def filter_new(self, transactions):
        """Return only transactions not already present in Notion.

        Duplicate check uses only export-file columns: date, name, amount.
        """
        existing = self._fetch_existing()
        new = []
        for tx in transactions:
            key = (tx['date'], tx['name'], round(tx['amount'], 2))
            if key not in existing:
                new.append(tx)
        return new
