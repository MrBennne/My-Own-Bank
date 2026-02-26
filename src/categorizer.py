from src.pb_client import PocketBaseClient


class Categorizer:
    def __init__(self, config):
        self.client = PocketBaseClient(config)
        self._load()

    def _load(self):
        """Fetch categories from PocketBase and build keyword rule dicts."""
        all_cats = []
        page = 1
        while True:
            r = self.client.get('/api/collections/categories/records', params={
                'perPage': 500,
                'page': page,
                'fields': 'name,type,keywords',
            })
            data = r.json()
            all_cats.extend(data.get('items', []))
            if page >= data.get('totalPages', 1):
                break
            page += 1

        self.income_rules = {}
        self.expense_rules = {}
        self.transfer_rules = {}

        for cat in all_cats:
            name = cat.get('name', '')
            cat_type = cat.get('type', 'expense')
            keywords = cat.get('keywords', [])
            if not name or not keywords:
                continue
            if cat_type == 'income':
                self.income_rules[name] = keywords
            elif cat_type == 'transfer':
                self.transfer_rules[name] = keywords
            else:
                self.expense_rules[name] = keywords

    def reload(self):
        self._load()

    def categorize(self, transactions):
        """Split transactions into (categorized, uncategorized) lists."""
        self.reload()
        categorized = []
        uncategorized = []

        for tx in transactions:
            category = self._match(tx['name'], tx.get('type', 'Expense'))
            if category:
                categorized.append({**tx, 'category': category})
            else:
                uncategorized.append({**tx, 'category': 'Uncategorized'})

        return categorized, uncategorized

    def _match(self, name, tx_type='Expense'):
        name_lower = name.lower()

        # Transfers first
        for category, keywords in self.transfer_rules.items():
            for keyword in keywords:
                if keyword.lower() in name_lower:
                    return category

        # Type-specific, with Uncategorized deferred to last
        type_rules = self.income_rules if tx_type == 'Income' else self.expense_rules
        uncategorized_match = False
        for category, keywords in type_rules.items():
            if category == 'Uncategorized':
                if any(keyword.lower() in name_lower for keyword in keywords):
                    uncategorized_match = True
                continue
            for keyword in keywords:
                if keyword.lower() in name_lower:
                    return category

        if uncategorized_match:
            return 'Uncategorized'
        return None
