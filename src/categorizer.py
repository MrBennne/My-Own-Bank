import json


class Categorizer:
    def __init__(self, rules_file='categories.json'):
        self.rules_file = rules_file
        self._load()

    def _load(self):
        with open(self.rules_file, encoding='utf-8') as f:
            self.rules = json.load(f)

    def reload(self):
        self._load()

    def categorize(self, transactions):
        """Split transactions into (categorized, uncategorized) lists."""
        self.reload()
        categorized = []
        uncategorized = []

        for tx in transactions:
            category = self._match(tx['name'])
            if category:
                categorized.append({**tx, 'category': category})
            else:
                uncategorized.append({**tx, 'category': 'Uncategorized'})

        return categorized, uncategorized

    def _match(self, name):
        name_lower = name.lower()
        for category, keywords in self.rules.items():
            for keyword in keywords:
                if keyword.lower() in name_lower:
                    return category
        return None
