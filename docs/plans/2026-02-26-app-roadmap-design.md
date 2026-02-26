# MyBank App Roadmap - Design Document

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform MyBank from an expense logger into a full personal finance app with budgeting, goals, intelligence, and Danish market optimization.

**Architecture:** Flutter mobile app backed by PocketBase. All new features use PocketBase collections as single source of truth. Local caching for dashboard performance. No external API dependencies except optional OCR for receipts.

**Tech Stack:** Flutter 3.41 / Dart 3.11, PocketBase REST API, fl_chart for visualizations, shared_preferences for local cache.

---

## Research Basis

This roadmap was informed by competitive analysis of 11 finance apps (YNAB, Monarch Money, Copilot, Spiir, Lunch Money, PocketGuard, Goodbudget, Wallet by BudgetBakers, Spendee, Rocket Money, Lunar) and review analysis from App Store, Google Play, Trustpilot, and Reddit. Danish market specifics sourced from Spiir (400k+ Nordic users, licensed AISP) and Lunar (750k+ users).

### Key Competitive Insights
- Budget tracking is table-stakes - every top-rated app has it
- Recurring detection separates "expense loggers" from "finance apps"
- Users hate: sync failures (our manual import avoids this), categorization that does not learn (our Review workflow addresses this), price increases (our app is free/self-hosted)
- Danish market: MobilePay handling matters (our force-manual approach works), semicolon CSV already supported, multi-currency less critical for single-user

### Features Explicitly Excluded
- Logout button (single user, not needed)
- Dark/light theme toggle (dark only by design)
- Multi-currency support (DKK only)
- Privacy-first messaging (single user)
- API access for power users (not needed)
- Gamification (not the app style)
- Predictive spending alerts (manual import makes real-time predictions irrelevant)
- Export CSV/PDF (can query PocketBase directly)
- MobilePay special handling (current force-manual approach preferred)

---

## Phase 1: Quick Fixes (Foundation Polish)

Small code fixes that improve UX immediately.

### 1. Fix Transaction Count KPI
- **Current:** Shows dash placeholder in KPI strip
- **Fix:** Wire up actual transaction count from aggregated data
- **Effort:** ~15 minutes

### 2. Infinite Scroll on Transactions
- **Current:** Manual "Load more" button
- **Fix:** NotificationListener to auto-fetch next page near bottom
- **Effort:** ~1 hour

### 3. Persist Filter/Sort State
- **Current:** Filters reset when navigating away from transactions screen
- **Fix:** Save search query, selected category, sort field/direction in SettingsService; restore in initState()
- **Effort:** ~1 hour

### 4. Category Dropdown by Frequency
- **Current:** Alphabetical sorting in category filter dropdown
- **Fix:** Sort by transaction count (most-used first), show "Suggested" section at top based on recent usage
- **Effort:** ~1 hour

### 5. Dashboard Local Caching
- **Current:** Fetches ALL transactions (500/page, loops) on every dashboard load
- **Fix:** Cache aggregated data in shared_preferences with timestamp. Only re-fetch if stale (>5 min) or after pull-to-refresh. Store: monthly totals, category sums, KPI values.
- **Effort:** ~2 hours

---

## Phase 2: Core Financial Planning

The features that transform this from "expense logger" to "finance app."

### 6. Budget Tracking
- Per-category monthly spending limits
- Progress bars on dashboard (green to yellow to red as approaching/exceeding limit)
- New "Budgets" section on dashboard or dedicated screen
- Budget vs. actual summary card
- Rollover option (carry unspent/overspent to next month)

**New PocketBase collection: `budgets`**
- categoryId (relation to categories)
- monthlyLimit (number)
- month (number, 1-12)
- year (number)
- rollover (boolean)

### 7. Recurring Transaction Detection
- Algorithm: Group transactions by merchant name similarity + amount similarity + regular interval
- Auto-flag detected recurring patterns
- Dashboard card: "Fixed costs: X DKK/month" vs "Variable: Y DKK/month"
- Alert when recurring amount changes (e.g., subscription price increase)
- Alert when expected recurring is missing (e.g., salary did not arrive)

**New PocketBase collection: `recurring_patterns`**
- merchantPattern (text - regex or substring)
- frequency (text - "monthly", "weekly", "yearly", "biweekly")
- avgAmount (number)
- categoryId (relation to categories)
- lastSeen (date)
- nextExpected (date)
- isActive (boolean)

### 8. Transaction Detail Screen
- Tap transaction to open full-screen detail view
- All fields visible: date, merchant, amount, currency, category, type, account
- Edit fields: category (via bottom sheet), notes, tags
- Show linked transfer (if type=Transfer)
- Show recurring pattern (if detected)
- Show receipt/attachment (if attached, Phase 5)
- History: show if category was changed (originally_uncategorized context)

**Transaction model additions:**
- notes (text)
- tags (JSON array of strings)

---

## Phase 3: Power Features

Advanced transaction management capabilities.

### 9. Savings Goals
- Create goal: name, target amount, deadline
- Visual progress bar + percentage
- Forecast: "At current savings rate, you will reach this in X months"
- Dashboard widget showing active goals
- Mark as achieved/archived

**New PocketBase collection: `savings_goals`**
- name (text)
- targetAmount (number)
- deadline (date)
- isActive (boolean)
- createdAt (date)

### 10. Advanced Filtering
- Amount range slider (min-max)
- Date range picker (from-to)
- Multi-category select (checkboxes, not single dropdown)
- Combine filters with AND logic
- Filter chips showing active filters with remove button

### 11. Bulk Recategorize
- Long-press or checkbox mode on transaction list
- Selection count in app bar
- "Recategorize Selected" button opens category bottom sheet
- Batch API call to update all selected transactions

### 12. Split Transactions
- In transaction detail: "Split" button
- Split editor: add rows with category + amount
- Amounts must sum to original transaction amount
- Original transaction gets splitParts field
- Dashboard/analytics count each split part under its category

**Transaction model addition:**
- splitParts (JSON array: [{category: string, amount: number}])

---

## Phase 4: Intelligence Layer

Smart features that surface insights automatically.

### 13. Auto-Insights Engine
- Dashboard insight cards (horizontal scroll or stacked)
- Types of insights:
  - Trend: "Groceries up 30% vs last month"
  - Anomaly: "Highest spending day was Mar 15 (4,200 DKK)"
  - Record: "Lowest monthly expense in 6 months!"
  - Pattern: "You spend 40% more on weekends"
- Computed from cached dashboard data
- Refreshed on pull-to-refresh

### 14. Cash Flow Forecast
- Uses detected recurring patterns (Phase 2, Feature 7) for known income/expenses
- Projects daily balance forward 30/60/90 days
- Line chart visualization
- Highlights danger zones (balance dips below threshold) or comfort zones (comfortable through next payday)
- Manual adjustments: add one-off expected expenses/income

### 15. Danish Merchant Database
- Pre-built keyword rules for ~50 common Danish merchants
- Categories:
  - Groceries: Netto, Fotex, COOP, Bilka, Rema 1000, Lidl, Aldi, SuperBrugsen, Meny, Irma
  - Transport: DSB, Rejsekort, Q8, OK, Circle K, Shell
  - Dining: 7-Eleven, McDonalds, Sunset Boulevard
  - Subscriptions: Netflix, Spotify, Apple, Google, HBO, Viaplay, DR Licens
  - Utilities: Orsted, SEAS-NVE, HOFOR, Norlys
  - Insurance: Tryg, Topdanmark, Alm Brand, Gjensidige, If
  - Telecom: TDC, Telia, 3, Telenor
  - Home: IKEA, Jysk, Bauhaus, Silvan, Harald Nyborg
  - Fashion: H&M, Zara, Zalando, Matas
  - Health: Apotek, Matas, Fitness World
- Shipped as default rules in categories collection
- User can override/customize

**New PocketBase collection: `merchant_rules`**
- merchantName (text - display name)
- keywords (JSON array - matching patterns)
- defaultCategory (text)
- type (text - "expense", "income", "transfer")
- isDefault (boolean - shipped vs user-created)

---

## Phase 5: Attachments

### 16. Receipt Scanning
- In transaction detail: "Attach Receipt" button
- Camera capture or file picker (image/PDF)
- Upload to PocketBase file storage
- Optional OCR: extract amount + merchant text (on-device ML or simple regex on receipt text)
- Receipt thumbnail shown in transaction detail and transaction list (small icon indicator)

**New PocketBase collection: `receipts`**
- transactionId (relation to transactions)
- file (file field - image or PDF)
- ocrText (text - extracted text, optional)
- createdAt (date)

**Transaction model addition:**
- receiptId (relation to receipts, optional)

---

## Summary

| Phase | Features | Effort Estimate |
|-------|----------|-----------------|
| 1: Quick Fixes | KPI fix, infinite scroll, persist filters, category sort, caching | ~6 hours |
| 2: Core Planning | Budgets, recurring detection, transaction detail | ~30 hours |
| 3: Power Features | Savings goals, advanced filtering, bulk recategorize, split transactions | ~25 hours |
| 4: Intelligence | Auto-insights, cash flow forecast, Danish merchant DB | ~20 hours |
| 5: Attachments | Receipt scanning with OCR | ~15 hours |
| **Total** | **16 features** | **~96 hours** |
