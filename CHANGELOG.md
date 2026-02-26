# Changelog

All notable changes to MyBank are documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [1.1.0] - 2026-02-26

### Phase 1: Quick Fixes

#### Fixed
- **Transaction Count KPI** — Dashboard KPI strip now shows the actual transaction count instead of a dash placeholder.
- **Category Dropdown Sync** — The category filter dropdown now listens for changes in PocketBase and stays in sync if categories are added/removed or refreshed.

#### Added
- **Infinite Scroll** — Transactions list auto-loads the next page when scrolling near the bottom, replacing the manual "Load more" button. A spinner appears at the bottom while loading.
- **Persist Filter/Sort State** — Search query, selected category, transaction type, sort field, and sort direction are saved to SharedPreferences. Filters survive tab navigation and app restarts.
- **Category Dropdown by Frequency** — The category filter dropdown sorts categories by usage count (most-used first) and shows the count in parentheses, e.g. "Groceries (42)". Frequency is pre-loaded from all transactions in the past 3 months for an accurate view of top spending categories.
- **Dashboard Local Caching** — Aggregated dashboard data (KPIs, category totals, monthly bars) is cached in SharedPreferences with a 5-minute staleness window. The dashboard loads instantly from cache on repeat visits. Pull-to-refresh and the refresh button force a fresh API fetch.

---

## [1.0.0] - 2026-02-26

Initial release: PocketBase migration.

### Added
- Flutter mobile app with dark theme
- Dashboard with KPI cards, category pie chart, monthly bar chart, top expenses
- Transaction list with search, category filter, type filter, sort controls
- CSV import pipeline (semicolon-delimited Danish bank format)
- Category management with keyword-based auto-categorization
- Review workflow for uncategorized transactions (originally_uncategorized flag)
- Rule learning from recategorized transactions
- Period selector with presets and custom month range
- PocketBase REST API backend (transactions, categories, users collections)
- Flask web GUI for upload, transaction management, and category editing
