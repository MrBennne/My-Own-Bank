from src.pb_client import PocketBaseClient


class PocketBaseDeduplicator:
    def __init__(self, config):
        self.client = PocketBaseClient(config)

    def filter_new(self, transactions):
        """Return only transactions not already in PocketBase."""
        existing = self._fetch_existing()
        return [
            tx for tx in transactions
            if (tx['date'], tx['name'], round(tx['amount'], 2)) not in existing
        ]

    def _fetch_existing(self):
        existing = set()
        page = 1
        while True:
            r = self.client.get('/api/collections/transactions/records', params={
                'perPage': 500,
                'page': page,
                'fields': 'date,name,amount',
            })
            data = r.json()
            for rec in data.get('items', []):
                existing.add((rec['date'], rec['name'], round(rec['amount'], 2)))
            if page >= data.get('totalPages', 1):
                break
            page += 1
        return existing
