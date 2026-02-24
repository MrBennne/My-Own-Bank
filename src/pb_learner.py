import json
import os

from src.pb_client import PocketBaseClient

PENDING_RULES = 'data/pending_rules.json'
APPROVED_RULES = 'data/approved_rules.json'


class PocketBaseLearner:
    def __init__(self, config):
        self.client = PocketBaseClient(config)
        os.makedirs('data', exist_ok=True)

    def _load_json(self, path):
        if os.path.exists(path):
            with open(path, encoding='utf-8') as f:
                return json.load(f)
        return []

    def _save_json(self, path, data):
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)

    def scan_for_recategorized(self):
        """Query PocketBase for originally-uncategorized records that now have a real category.
        Single query replaces the old per-page Notion polling loop.
        """
        pending = self._load_json(PENDING_RULES)
        approved = self._load_json(APPROVED_RULES)
        seen = {(e['name'], e['category']) for e in pending}
        seen |= {(e['name'], e['category']) for e in approved}

        new_pending = []
        page = 1
        while True:
            r = self.client.get('/api/collections/transactions/records', params={
                'perPage': 200,
                'page': page,
                'filter': 'originally_uncategorized=true && category!="Uncategorized"',
                'fields': 'id,name,category,amount',
            })
            data = r.json()
            for rec in data.get('items', []):
                name = rec['name']
                category = rec['category']
                amount = rec.get('amount', 0) or 0
                tx_type = 'income' if amount >= 0 else 'expense'

                if (name, category) not in seen:
                    seen.add((name, category))
                    new_pending.append({
                        'record_id': rec['id'],
                        'page_id': rec['id'],  # kept for review template compatibility
                        'name': name,
                        'category': category,
                        'transaction_type': tx_type,
                        'keyword': name[:40].strip(),
                        'approved': False,
                    })

            if page >= data.get('totalPages', 1):
                break
            page += 1

        if new_pending:
            pending.extend(new_pending)
            self._save_json(PENDING_RULES, pending)
