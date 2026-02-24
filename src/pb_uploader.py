from src.pb_client import PocketBaseClient


class PocketBaseUploader:
    def __init__(self, config):
        self.client = PocketBaseClient(config)

    def upload(self, transactions):
        """Upload transactions to PocketBase. Returns list of created record IDs."""
        ids = []
        for tx in transactions:
            r = self.client.post('/api/collections/transactions/records', json={
                'date': tx['date'],
                'name': tx['name'],
                'amount': tx['amount'],
                'currency': tx.get('currency', 'DKK'),
                'account': tx.get('account', 'Lønkonto'),
                'category': tx.get('category', 'Uncategorized'),
                'type': tx.get('type', 'Expense'),
                'originally_uncategorized': tx.get('category', 'Uncategorized') == 'Uncategorized',
            })
            r.raise_for_status()
            ids.append(r.json()['id'])
        return ids
