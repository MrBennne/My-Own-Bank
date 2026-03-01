---
name: warn-deprecated-categories-json
enabled: true
event: file
action: warn
pattern: categories\.json
---

**Deprecated: categories.json reference detected!**

`categories.json` has been removed. PocketBase is the single source of truth for categories.

**Use instead:**
- Python: `PocketBaseClient` to fetch from `/api/collections/categories/records`
- Flutter: `CategoryService.instance` which fetches from PocketBase
- GUI: `pb_fetch_categories(pb)` helper in `gui/app.py`
