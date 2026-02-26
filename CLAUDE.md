# Banking Project

Personal banking transaction pipeline with PocketBase backend, Flutter mobile app, and Flask web GUI.

## Architecture

```
banking/
  main.py              — Pipeline orchestrator (--once or continuous polling)
  config.yaml          — All credentials and settings (DO NOT commit changes)
  src/                 — Python pipeline modules
    pb_client.py       — PocketBase REST client (auth, get, post, patch, delete)
    categorizer.py     — Keyword-based categorization from PocketBase categories
    parser.py          — Semicolon-delimited CSV parser (DD-MM-YYYY, Danish bank format)
    pb_deduplicator.py — Dedup by (date, name, amount) tuples
    pb_uploader.py     — Upload transactions to PocketBase
    pb_learner.py      — Scan for recategorized transactions, skip force-manual keywords
    drive_watcher.py   — Google Drive polling, CSV/Sheets download
    notifier.py        — Gmail SMTP alerts for uncategorized transactions
  gui/                 — Flask web GUI (port 5000)
    app.py             — Routes: /upload, /transactions, /categories, /review
    templates/         — Jinja2 templates
  mobile/              — Flutter mobile app
    lib/
      models/          — Transaction, Category (fromJson/toJson)
      services/        — ApiService, AuthService, CategoryService, DashboardService, etc.
      screens/         — Dashboard, Transactions, Import, Settings, Login, ReviewRules
      widgets/         — Charts, CategoryBottomSheet, PeriodSelector, KPI cards
      theme/           — Dark theme (AppTheme)
```

## Key Conventions

- **PocketBase is the single source of truth** for categories. Never use categories.json (deleted).
- Categories have typed keyword rules (income/expense/transfer). "Uncategorized" category with keywords forces manual review.
- `originally_uncategorized` flag on transactions controls the Review tab.
- Flutter uses `CategoryService` singleton for all category operations.
- Python uses `PocketBaseClient` from `src/pb_client.py` for all API calls.

## PocketBase

- Collections: `transactions`, `categories`, `users`
- Auth: `/api/collections/users/auth-with-password`
- Categories have fields: name, type (income/expense/transfer), keywords (array), color

## Run Commands

```bash
# Pipeline (one-shot)
python main.py --once

# Flask GUI
python gui/app.py

# Flutter build
cd mobile && flutter build apk --release

# Flutter run (debug)
cd mobile && flutter run
```

## Sensitive Files

- `config.yaml` — Contains all credentials (PocketBase, Gmail, Google Drive). Never log or expose.
- `.env.pocketbase` — PocketBase env config
- `config/service_account.json` — Google service account key

## Code Style

- Python: No type hints in existing code, simple logging with `log.info/error/warning`
- Dart/Flutter: Material Design, dark theme, ChangeNotifier pattern for state
- No tests exist yet — test directory needs to be created
