# MyBank Mobile App — Feature List

## Current Features

### Dashboard

* Hero summary card — net savings, savings rate %, income/expense totals
* KPI strip — savings rate, avg monthly expense, transaction count
* Category chart — 3 view modes: pie, horizontal bars, ranked list
* Monthly bar chart — income vs expenses over last 12 months with tooltips
* Top 5 expenses — ranked by amount with category chips
* Period selector — 7 presets (This Month, Last Month, Last 3/6 Months, This/Last Year, All Time) + custom month-range picker
* Pull-to-refresh
* Transfers excluded from KPI calculations

### Transactions

* Searchable list — real-time search by merchant name
* Filters — category dropdown, type (All/Income/Expense)
* Multi-column sorting — date, amount, name, category (asc/desc)
* Inline category editing — tap category chip to reassign via bottom sheet
* Create new category directly from category selector bottom sheet
* Pagination — 50 per page with "load more"
* Total item count in app bar

### Review Rules

* Pending reviews — shows transactions imported as uncategorized but now assigned a category
* Recategorize before dismissing
* Bulk dismiss all with confirmation
* Swipe-to-dismiss

### Import

* CSV parser — semicolon-delimited bank exports (DD-MM-YYYY format)
* Account selector — dropdown + "New account" dialog
* Skip categorization checkbox — import everything as Uncategorized
* Typed keyword matching — income/expense/transfer rules from PocketBase categories
* Deduplication — checks existing (date, name, amount) tuples in PocketBase
* Transfer detection — auto-links matching amounts (+/- 1 day) across accounts
* UTF-8/Latin-1 fallback encoding support
* Result summary — parsed, uploaded, skipped, categorized, transfers, errors

### Settings

* Category management — add/rename/delete custom categories, color picker (24 presets)
* Type badges — shows Income/Expense/Transfer per category
* Keyword rules editor — view/edit categorization keywords, organized by type
* Force-manual keywords — "Uncategorized" category keywords force manual review (e.g. MobilePay)
* Reset autocategorizer — clears server-side learned rules (Flask API)
* Version display

### Auth

* PocketBase login with secure token storage (FlutterSecureStorage)
* Auto-token validation on app start
* 401 auto-retry with token refresh

### Data Architecture

* PocketBase backend for transactions (date, name, amount, currency, category, type, account, originally\_uncategorized)
* PocketBase categories collection as single source of truth for categorization rules
* SettingsService singleton with ChangeNotifier for reactive UI updates
* Deterministic hash-based category colors with custom override support

---

## Planned Features

### Tier 1 — Core UX

1. **Transaction detail screen** — full view with edit fields, history, linked transfers
2. **Category drill-down** — tap a category on dashboard to see all transactions in it
3. **Dark/light theme toggle** — light theme option with toggle in settings
4. **Undo actions** — undo snackbar after category change or dismiss
5. **Auto-learn from corrections** — recategorization creates Review item, not auto-rule

### Tier 2 — Dashboard Enhancements

6. **Income vs expense trend line** — line chart overlay on monthly bars showing net savings trend
7. **Year-over-year + month-over-month comparison** — compare periods to same period last year
8. **Account breakdown** — per-account income/expense summary card

### Tier 3 — Data Management

9. **Bulk recategorize** — select multiple transactions and assign category at once
10. **Notes/tags on transactions** — add personal notes or tags for extra context
11. **Suggested category** — on uncategorized, show "did you mean X?" based on similar merchants
12. **Drag-and-drop import** — especially useful on tablet/desktop

### Tier 4 — Advanced Features

13. **Budget targets** — set monthly spending limits per category, show progress bars on dashboard
14. **Recurring transaction detection** — auto-identify subscriptions and recurring bills, flag when amount changes
15. **Split transactions** — split one transaction across multiple categories
16. **Savings goal tracker** — set a target and track progress visually

### Tier 5 — Security

17. **Biometric auth** — fingerprint/face unlock instead of password, optional toggle
