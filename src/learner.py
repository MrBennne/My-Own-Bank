import json
import os
from notion_client import Client

UPLOADED_LOG = 'data/uploaded_uncategorized.json'
PENDING_RULES = 'data/pending_rules.json'
APPROVED_RULES = 'data/approved_rules.json'


class Learner:
    def __init__(self, config):
        self.client = Client(auth=config['notion']['token'])
        self.db_id = config['notion']['database_id']
        os.makedirs('data', exist_ok=True)

    def _load_json(self, path):
        if os.path.exists(path):
            with open(path, encoding='utf-8') as f:
                return json.load(f)
        return []

    def _save_json(self, path, data):
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)

    def record_uploaded_uncategorized(self, page_id_name_pairs):
        """Log (page_id, merchant_name) for every transaction uploaded as Uncategorized."""
        log = self._load_json(UPLOADED_LOG)
        existing_ids = {e['page_id'] for e in log}
        for page_id, name in page_id_name_pairs:
            if page_id not in existing_ids:
                log.append({'page_id': page_id, 'name': name})
        self._save_json(UPLOADED_LOG, log)

    def scan_for_recategorized(self):
        """Check Notion for entries that were Uncategorized but now have a real category.
        Adds them to pending_rules.json for GUI review.
        """
        log = self._load_json(UPLOADED_LOG)
        if not log:
            return

        pending = self._load_json(PENDING_RULES)
        approved = self._load_json(APPROVED_RULES)

        # Build sets of already-seen (name, category) pairs to avoid duplicates
        seen = {(e['name'], e['category']) for e in pending}
        seen |= {(e['name'], e['category']) for e in approved}

        new_pending = []
        still_uncategorized = []

        for entry in log:
            page_id = entry['page_id']
            try:
                page = self.client.pages.retrieve(page_id=page_id)
                props = page['properties']
                sel = props.get('Category', {}).get('select')
                category = sel['name'] if sel else None
            except Exception:
                still_uncategorized.append(entry)
                continue

            if category and category != 'Uncategorized':
                # Determine income vs expense from stored amount
                amount = props.get('Amount', {}).get('number') or 0
                tx_type = 'income' if amount >= 0 else 'expense'

                key = (entry['name'], category, tx_type)
                if key not in seen:
                    seen.add(key)
                    suggested_keyword = entry['name'][:40].strip()
                    new_pending.append({
                        'page_id': page_id,
                        'name': entry['name'],
                        'category': category,
                        'transaction_type': tx_type,
                        'keyword': suggested_keyword,
                        'approved': False,
                    })
                # even if duplicate, remove from log (already handled)
            else:
                still_uncategorized.append(entry)

        if new_pending:
            pending.extend(new_pending)
            self._save_json(PENDING_RULES, pending)

        # Keep only still-uncategorized entries in the log
        self._save_json(UPLOADED_LOG, still_uncategorized)
