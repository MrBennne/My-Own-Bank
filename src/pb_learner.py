import json
import os

from src.pb_client import PocketBaseClient

PENDING_RULES = 'data/pending_rules.json'
APPROVED_RULES = 'data/approved_rules.json'


class PocketBaseLearner:
    def __init__(self, config):
        self.client = PocketBaseClient(config)
        self.categories_file = config.get('categories_file', 'categories.json')
        os.makedirs('data', exist_ok=True)

    def _load_json(self, path):
        if os.path.exists(path):
            with open(path, encoding='utf-8') as f:
                return json.load(f)
        return []

    def _save_json(self, path, data):
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)

    def _load_force_manual_keywords(self):
        """Load keywords from 'Uncategorized' categories - these merchants should never generate rules."""
        try:
            with open(self.categories_file, encoding='utf-8') as f:
                raw = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            return set()

        keywords = set()
        for section in ('income', 'expense', 'transfer'):
            for kw in raw.get(section, {}).get('Uncategorized', []):
                keywords.add(kw.lower())
        # Also check flat format
        if 'Uncategorized' in raw and isinstance(raw['Uncategorized'], list):
            for kw in raw['Uncategorized']:
                keywords.add(kw.lower())
        return keywords

    def scan_for_recategorized(self):
        """Query PocketBase for originally-uncategorized records that now have a real category.
        Single query replaces the old per-page Notion polling loop.
        """
        pending = self._load_json(PENDING_RULES)
        approved = self._load_json(APPROVED_RULES)
        seen = {(e['name'], e['category']) for e in pending}
        seen |= {(e['name'], e['category']) for e in approved}
        force_manual = self._load_force_manual_keywords()

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

                # Skip merchants matching force-manual keywords
                name_lower = name.lower()
                is_force_manual = any(kw in name_lower for kw in force_manual)
                if not is_force_manual and (name, category) not in seen:
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
