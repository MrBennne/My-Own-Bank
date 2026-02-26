---
name: pocketbase-query
description: Query PocketBase collections (transactions, categories, users)
user-invocable: true
---

# PocketBase Query Tool

Interactive tool to query and debug PocketBase collections.

## Usage

```
/pocketbase-query
```

Then specify one of:

- `list-categories` — Show all categories with keywords and types
- `count-transactions` — Count total transactions
- `count-uncategorized` — Count uncategorized transactions only
- `find-category NAME` — Search for a category by name
- `transactions-by-date START END` — Find transactions in date range (YYYY-MM-DD)
- `list-all-transactions` — List all transactions (slow, use carefully)
- `collection-schema COLLECTION` — Show collection field schema

## Examples

```
/pocketbase-query list-categories
# Shows all categories with keywords and types

/pocketbase-query count-uncategorized
# Displays how many transactions are uncategorized

/pocketbase-query find-category Groceries
# Find "Groceries" category details

/pocketbase-query transactions-by-date 2026-02-01 2026-02-27
# Transactions in February 2026
```

## Collections Available

- **transactions**: date, name, amount, currency, category, type, account, originally_uncategorized
- **categories**: name, type (income/expense/transfer), group, parent, keywords, color, sort_order
- **users**: email, verified, created (system fields)

## Authentication

Uses superuser credentials from `.env.pocketbase` or `config.yaml`

## When to use

- Debugging categorization issues
- Checking category keywords
- Verifying transaction counts
- Finding specific transactions during development
- Validating API changes
