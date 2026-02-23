from notion_client import Client


class NotionUploader:
    def __init__(self, config):
        self.client = Client(auth=config['notion']['token'])
        self.db_id = config['notion']['database_id']

    def upload(self, transactions):
        """Upload transactions to Notion. Returns list of created page IDs."""
        page_ids = []
        for tx in transactions:
            page_id = self._create_page(tx)
            page_ids.append(page_id)
        return page_ids

    def _create_page(self, tx):
        resp = self.client.pages.create(
            parent={'database_id': self.db_id},
            properties={
                'n': {'title': [{'text': {'content': tx['name']}}]},
                'Date': {'date': {'start': tx['date']}},
                'Amount': {'number': tx['amount']},
                'Account': {'select': {'name': tx.get('account', 'Lønkonto')}},
                'Currency': {'select': {'name': tx.get('currency', 'DKK')}},
                'Category': {'select': {'name': tx.get('category', 'Uncategorized')}},
            },
        )
        return resp['id']
