import json


class Categorizer:
    def __init__(self, rules_file='categories.json'):
        self.rules_file = rules_file
        self._load()

    def _load(self):
        with open(self.rules_file, encoding='utf-8') as f:
            raw = json.load(f)

        # Support both the old flat format {"Category": [...keywords]}
        # and the new typed format {"income": {...}, "expense": {...}, "transfer": {...}}
        if 'income' in raw or 'expense' in raw or 'transfer' in raw:
            self._typed = True
            self.income_rules = raw.get('income', {})
            self.expense_rules = raw.get('expense', {})
            self.transfer_rules = raw.get('transfer', {})
            # Flat union for backward compat
            self.rules = {}
            for section in (self.transfer_rules, self.income_rules, self.expense_rules):
                self.rules.update(section)
        else:
            self._typed = False
            self.rules = raw
            self.income_rules = {}
            self.expense_rules = {}
            self.transfer_rules = {}

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

        if not self._typed:
            # Legacy flat matching
            for category, keywords in self.rules.items():
                for keyword in keywords:
                    if keyword.lower() in name_lower:
                        return category
            return None

        # Typed matching: transfers first, then type-specific
        for category, keywords in self.transfer_rules.items():
            for keyword in keywords:
                if keyword.lower() in name_lower:
                    return category

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

        # Return Uncategorized only if no other category matched
        if uncategorized_match:
            return 'Uncategorized'
        return None
