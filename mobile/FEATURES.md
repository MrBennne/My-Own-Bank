# MyBank Mobile App — Feature List

## Current Features

### Dashboard
- Hero summary card — net savings, savings rate %, income/expense totals
- KPI strip — savings rate, avg monthly expense, transaction count
- Category chart — 3 view modes: pie, horizontal bars, ranked list
- Monthly bar chart — income vs expenses over last 12 months with tooltips
- Top 5 expenses — ranked by amount with category chips
- Period selector — 7 presets (This Month, Last Month, Last 3/6 Months, This/Last Year, All Time) + custom month-range picker
- Pull-to-refresh
- Transfers excluded from KPI calculations

### Transactions
- Searchable list — real-time search by merchant name
- Filters — category dropdown, type (All/Income/Expense)
- Multi-column sorting — date, amount, name, category (asc/desc)
- Inline category editing — tap category chip to reassign via bottom sheet
- Pagination — 50 per page with "load more"
- Total item count in app bar

### Review Rules
- Pending reviews — shows transactions imported as uncategorized but now assigned a category
- Recategorize before dismissing
- Bulk dismiss all with confirmation
- Swipe-to-dismiss

### Import
- CSV parser — semicolon-delimited bank exports (DD-MM-YYYY format)
- Account selector — dropdown + "New account" dialog
- Skip categorization checkbox — import everything as Uncategorized
- Typed keyword matching — income/expense/transfer rules from categories.json
- Deduplication — checks existing (date, name, amount) tuples in PocketBase
- Transfer detection — auto-links matching amounts (+/- 1 day) across accounts
- UTF-8/Latin-1 fallback encoding support
- Result summary — parsed, uploaded, skipped, categorized, transfers, errors

### Settings
- Category management — add/rename/delete custom categories, color picker (24 presets)
- Type badges — shows Income/Expense/Transfer per category
- Keyword rules editor — view/edit categorization keywords, organized by type
- Reset autocategorizer — clears server-side learned rules (Flask API)
- Version display

### Auth
- PocketBase login with secure token storage (FlutterSecureStorage)
- Auto-token validation on app start
- 401 auto-retry with token refresh

### Data Architecture
- PocketBase backend for transactions (date, name, amount, currency, category, type, account, originally_uncategorized)
- Local categories.json asset with SharedPreferences overrides for rules
- SettingsService singleton with ChangeNotifier for reactive UI updates
- Deterministic hash-based category colors with custom override support

---

## Suggested Features

### High Value
1. **Budget targets** — set monthly spending limits per category, show progress bars on dashboard
2. **Push notifications** — alert when approaching budget limit or large transaction detected
3. **Recurring transaction detection** — auto-identify subscriptions and recurring bills, flag when amount changes
4. **Multi-currency support** — conversion rates, display in DKK or original currency
5. **Export** — export filtered transactions as CSV/PDF for tax or records

### Dashboard Enhancements
6. **Income vs expense trend line** — line chart overlay on monthly bars showing net savings trend
7. **Year-over-year comparison** — compare this month/quarter to same period last year
8. **Category drill-down** — tap a category to see all transactions in it
9. **Account breakdown** — per-account income/expense summary card
10. **Spending velocity** — "you've spent X% of last month's total with Y days remaining"

### Import & Data
11. **Drag-and-drop import** — especially useful on tablet/desktop
12. **Bank API integration** — auto-fetch transactions (if bank supports PSD2/Open Banking)
13. **Bulk recategorize** — select multiple transactions and assign category at once
14. **Split transactions** — split one transaction across multiple categories
15. **Notes/tags on transactions** — add personal notes or tags for extra context

### Categorization Intelligence
16. **Auto-learn from corrections** — when you recategorize, auto-add the merchant keyword to rules
17. **Suggested category** — on uncategorized, show "did you mean X?" based on similar merchants
18. **Fuzzy matching** — handle typos and slight name variations in merchant matching
19. **Category merge/alias** — map multiple category names to one

### UX & Quality of Life
20. **Dark/light theme toggle**
21. **Biometric auth** — fingerprint/face unlock instead of password
22. **Onboarding flow** — first-launch tutorial explaining import process
23. **Transaction detail screen** — full view with edit fields, history, linked transfers
24. **Undo actions** — undo snackbar after category change or dismiss
25. **Offline mode** — cache transactions locally, sync when back online

### Reporting
26. **Monthly report generation** — auto-summary email/PDF at month end
27. **Savings goal tracker** — set a target and track progress visually
28. **Net worth tracking** — track account balances over time
29. **Tax category grouping** — group deductible expenses for tax reporting
