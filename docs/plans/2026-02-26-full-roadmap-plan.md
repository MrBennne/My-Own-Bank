# MyBank Full Roadmap - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform MyBank from an expense logger into a full personal finance app with budgeting, goals, intelligence, and Danish market optimization - 16 features across 5 phases.

**Architecture:** Flutter mobile app backed by PocketBase REST API. All new features use PocketBase collections. Local caching via shared_preferences. Singleton ChangeNotifier services. IndexedStack navigation with BottomNavigationBar.

**Tech Stack:** Flutter 3.41 / Dart 3.11, PocketBase, fl_chart 0.69, http 1.2.1, shared_preferences 2.3.3

**Key file references:**
- API: `mobile/lib/services/api_service.dart`
- Models: `mobile/lib/models/transaction.dart`, `mobile/lib/models/category.dart`
- Dashboard: `mobile/lib/screens/dashboard_screen.dart` + `mobile/lib/services/dashboard_service.dart`
- Transactions: `mobile/lib/screens/transactions_screen.dart`
- Navigation: `mobile/lib/screens/main_shell.dart` (IndexedStack, 5 tabs)
- Settings: `mobile/lib/screens/settings_screen.dart`
- Theme: `mobile/lib/theme/app_theme.dart`
- Category picker: `mobile/lib/widgets/category_bottom_sheet.dart`

---

# Phase 1: Quick Fixes

## Task 1: Fix Transaction Count KPI

**Files:**
- Modify: `mobile/lib/services/dashboard_service.dart:74-86` (KpiData class)
- Modify: `mobile/lib/screens/dashboard_screen.dart:225` (KPI strip)

**Step 1:** Add `final int transactionCount` field to KpiData class at line 74.

**Step 2:** In aggregate() at line 233, pass `transactionCount: transactions.length` to KpiData constructor.

**Step 3:** In dashboard_screen.dart at line 225, replace the hardcoded dash with `'${kpi.transactionCount}'`.

**Step 4:** Build: `cd mobile && flutter build apk --debug 2>&1 | tail -5`

**Step 5:** Commit: `git commit -m "fix: wire up transaction count KPI on dashboard"`

---

## Task 2: Infinite Scroll on Transactions

**Files:**
- Modify: `mobile/lib/screens/transactions_screen.dart:44,68,393-430`

**Step 1:** Add `final _scrollController = ScrollController();` to state fields at line 44.

**Step 2:** In initState at line 68, add `_scrollController.addListener(_onScroll);`

**Step 3:** Add dispose override to clean up both controllers.

**Step 4:** Add scroll handler that triggers _fetchTransactions() when within 200px of bottom, guarded by _loadingMore and _page checks.

**Step 5:** Attach controller to ListView.builder at line 393.

**Step 6:** Replace Load more button (lines 396-420) with a loading spinner when i == _transactions.length.

**Step 7:** Commit: `git commit -m "feat: replace Load more button with infinite scroll"`

---

## Task 3: Persist Filter/Sort State

**Files:**
- Modify: `mobile/lib/services/settings_service.dart`
- Modify: `mobile/lib/screens/transactions_screen.dart`

**Step 1:** In settings_service.dart, add filter persistence keys (tx_search_query, tx_selected_category, tx_selected_type, tx_sort_field, tx_sort_asc) with getter/setter pairs following existing pattern.

**Step 2:** Add saveTransactionFilters() method that saves all filter state at once.

**Step 3:** In transactions_screen.dart initState, restore filters from SettingsService.

**Step 4:** After each filter/sort change handler, call saveTransactionFilters().

**Step 5:** Commit: `git commit -m "feat: persist transaction filter and sort state across navigation"`

---

## Task 4: Category Dropdown by Frequency

**Files:**
- Modify: `mobile/lib/screens/transactions_screen.dart:259-280`

**Step 1:** Add `Map<String, int> _categoryFrequency = {};` to state.

**Step 2:** After fetching transactions (reset=true), build frequency map from results.

**Step 3:** Sort category dropdown items by frequency descending, keeping "All" first. Show count in label.

**Step 4:** Commit: `git commit -m "feat: sort category dropdown by usage frequency"`

---

## Task 5: Dashboard Local Caching

**Files:**
- Create: `mobile/lib/services/dashboard_cache_service.dart`
- Modify: `mobile/lib/services/dashboard_service.dart` (add toJson/fromJson)
- Modify: `mobile/lib/screens/dashboard_screen.dart:36-62`

**Step 1:** Create dashboard_cache_service.dart with load/save/invalidate using shared_preferences. Cache key includes filter string. Stale after 5 minutes.

**Step 2:** Add toJson/fromJson to KpiData, CategoryAmount, MonthlyBar, DashboardData.

**Step 3:** In dashboard_screen.dart _load(), try cache first (unless forceRefresh). On miss, fetch from API and save to cache.

**Step 4:** Update refresh button and pull-to-refresh to use _load(forceRefresh: true).

**Step 5:** Commit: `git commit -m "feat: add local caching for dashboard data with 5-minute staleness"`

---

# Phase 2: Core Financial Planning

## Task 6: Budget Tracking

**Files:**
- Create: `mobile/lib/models/budget.dart`
- Create: `mobile/lib/services/budget_service.dart`
- Create: `mobile/lib/screens/budget_screen.dart`
- Create: `mobile/lib/widgets/budget_progress_card.dart`
- Modify: `mobile/lib/services/api_service.dart` (budget CRUD)
- Modify: `mobile/lib/screens/dashboard_screen.dart` (budget widget)
- Modify: `mobile/lib/screens/settings_screen.dart` (navigation)

**PocketBase prerequisite:** Create budgets collection - categoryId (relation->categories), monthlyLimit (number), month (number), year (number), rollover (bool).

**Step 1:** Create Budget model with fromJson/toJson. Handle expand.categoryId.name for category name.

**Step 2:** Add to ApiService: fetchBudgets(month, year), createBudget, updateBudget, deleteBudget.

**Step 3:** Create BudgetService (ChangeNotifier singleton) with BudgetProgress class (budget + spent + percentage + isOver). Compute spent from transactions grouped by category.

**Step 4:** Create BudgetProgressCard widget - top 5 categories with LinearProgressIndicator (green/yellow/red by percentage).

**Step 5:** Create BudgetScreen - list budgets for current month, FAB to add new (category picker + amount input), swipe to delete, month navigation.

**Step 6:** Add BudgetProgressCard to dashboard ListView after TopExpenses.

**Step 7:** Add Budget Limits tile in settings_screen.dart.

**Step 8:** Commit: `git commit -m "feat: add budget tracking with per-category limits and dashboard progress"`

---

## Task 7: Recurring Transaction Detection

**Files:**
- Create: `mobile/lib/models/recurring_pattern.dart`
- Create: `mobile/lib/services/recurring_service.dart`
- Create: `mobile/lib/widgets/recurring_summary_card.dart`
- Modify: `mobile/lib/services/api_service.dart`
- Modify: `mobile/lib/screens/dashboard_screen.dart`

**PocketBase prerequisite:** Create recurring_patterns collection - merchantPattern (text), frequency (text), avgAmount (number), categoryId (relation->categories), lastSeen (date), nextExpected (date), isActive (bool).

**Step 1:** Create RecurringPattern model with fromJson.

**Step 2:** Create RecurringService with detection algorithm: group by merchant, check amount similarity (10%) and interval regularity, classify frequency (~7d=weekly, ~14d=biweekly, ~30d=monthly, ~365d=yearly).

**Step 3:** Create RecurringSummaryCard - Fixed vs Variable cost split, top recurring items with frequency badges.

**Step 4:** Integrate into dashboard.

**Step 5:** Commit: `git commit -m "feat: add recurring transaction detection and fixed vs variable cost summary"`

---

## Task 8: Transaction Detail Screen

**Files:**
- Create: `mobile/lib/screens/transaction_detail_screen.dart`
- Modify: `mobile/lib/screens/transactions_screen.dart:514` (change onTap)
- Modify: `mobile/lib/models/transaction.dart` (add notes, tags)
- Modify: `mobile/lib/services/api_service.dart`

**PocketBase prerequisite:** Add notes (text) and tags (JSON) fields to transactions collection.

**Step 1:** Add notes (String) and tags (List String) to Transaction model. Update fromJson and copyWith.

**Step 2:** Create TransactionDetailScreen - amount hero, info rows (Date, Category tappable, Type, Account), notes TextField, tags Chips, originally_uncategorized banner.

**Step 3:** Change _TransactionTile onTap to Navigator.push(TransactionDetailScreen). Return modified transaction.

**Step 4:** Add updateTransactionFields() to ApiService for notes/tags PATCH.

**Step 5:** Commit: `git commit -m "feat: add transaction detail screen with notes and tags"`

---

# Phase 3: Power Features

## Task 9: Savings Goals

**Files:**
- Create: `mobile/lib/models/savings_goal.dart`
- Create: `mobile/lib/services/savings_service.dart`
- Create: `mobile/lib/screens/savings_goals_screen.dart`
- Create: `mobile/lib/widgets/savings_goals_card.dart`
- Modify: `mobile/lib/services/api_service.dart`
- Modify: `mobile/lib/screens/dashboard_screen.dart`
- Modify: `mobile/lib/screens/settings_screen.dart`

**PocketBase prerequisite:** Create savings_goals collection - name (text), targetAmount (number), deadline (date), isActive (bool), createdAt (date).

**Step 1:** Create SavingsGoal model. Compute progress from current net savings vs target.

**Step 2:** Add goals CRUD to ApiService.

**Step 3:** Create SavingsGoalsScreen - list with progress bars, FAB to create, swipe to archive.

**Step 4:** Create SavingsGoalsCard - dashboard widget with top 1-2 goals, progress bars, forecast.

**Step 5:** Add to dashboard and settings navigation.

**Step 6:** Commit: `git commit -m "feat: add savings goals with progress tracking and dashboard widget"`

---

## Task 10: Advanced Filtering

**Files:**
- Create: `mobile/lib/widgets/filter_panel.dart`
- Modify: `mobile/lib/screens/transactions_screen.dart`

**Step 1:** Create TransactionFilter class with toPocketBaseFilter(). Support: search, multi-category, type, minAmount, maxAmount, dateFrom, dateTo.

**Step 2:** Create FilterPanel widget - expandable with multi-category checkboxes, RangeSlider for amount, DateRangePicker for dates.

**Step 3:** Show active filters as removable Chips above transaction list.

**Step 4:** Replace current filters with FilterPanel.

**Step 5:** Commit: `git commit -m "feat: add advanced filtering with amount range, date range, and multi-category"`

---

## Task 11: Bulk Recategorize

**Files:**
- Modify: `mobile/lib/screens/transactions_screen.dart`
- Modify: `mobile/lib/services/api_service.dart`

**Step 1:** Add selection mode: bool _selectionMode, Set String _selectedIds.

**Step 2:** Long-press toggles selection mode. Show checkboxes. App bar: "X selected" + Recategorize + Cancel.

**Step 3:** Add bulkUpdateCategory to ApiService.

**Step 4:** Recategorize button opens CategoryBottomSheet, applies to all selected.

**Step 5:** Commit: `git commit -m "feat: add bulk recategorize with multi-select in transactions"`

---

## Task 12: Split Transactions

**Files:**
- Create: `mobile/lib/widgets/split_transaction_dialog.dart`
- Modify: `mobile/lib/models/transaction.dart`
- Modify: `mobile/lib/screens/transaction_detail_screen.dart`
- Modify: `mobile/lib/services/dashboard_service.dart`

**PocketBase prerequisite:** Add splitParts (JSON) field to transactions collection.

**Step 1:** Add SplitPart class and splitParts list to Transaction model.

**Step 2:** Create SplitTransactionDialog - rows with category picker + amount, validation (must sum to original).

**Step 3:** Add Split button to TransactionDetailScreen (expenses only).

**Step 4:** In DashboardService.aggregate(), count split parts under their respective categories.

**Step 5:** Commit: `git commit -m "feat: add split transactions across multiple categories"`

---

# Phase 4: Intelligence Layer

## Task 13: Auto-Insights Engine

**Files:**
- Create: `mobile/lib/services/insights_service.dart`
- Create: `mobile/lib/widgets/insights_card.dart`
- Modify: `mobile/lib/screens/dashboard_screen.dart`

**Step 1:** Create InsightsService.generate(current, previous) returning insights. Types: trend (>20% category change), anomaly (>2x daily average), record (best/worst month), pattern (weekday vs weekend).

**Step 2:** Create InsightsCard - horizontal scrollable cards with icon + title + detail.

**Step 3:** In dashboard _load(), fetch previous period, generate insights, add InsightsCard to ListView.

**Step 4:** Commit: `git commit -m "feat: add auto-insights engine with trend, anomaly, and pattern detection"`

---

## Task 14: Cash Flow Forecast

**Files:**
- Create: `mobile/lib/services/forecast_service.dart`
- Create: `mobile/lib/widgets/forecast_chart.dart`
- Modify: `mobile/lib/screens/dashboard_screen.dart`

**Step 1:** Create ForecastService - uses recurring patterns to project 30-90 days. Returns list of date+balance points.

**Step 2:** Create ForecastChart - fl_chart LineChart, date x-axis, balance y-axis, red zone below threshold.

**Step 3:** Add collapsible section to dashboard.

**Step 4:** Commit: `git commit -m "feat: add cash flow forecast chart based on recurring patterns"`

---

## Task 15: Danish Merchant Database

**Files:**
- Create: `mobile/lib/data/danish_merchants.dart`
- Modify: `mobile/lib/services/category_service.dart`
- Modify: `mobile/lib/screens/settings_screen.dart`

**Step 1:** Create danish_merchants.dart with ~50 rules: Netto, Fotex, COOP, Bilka, Rema 1000, Lidl, Aldi (Groceries); DSB, Rejsekort, Q8, Circle K, Shell (Transport); Netflix, Spotify, Apple, Google, Viaplay (Subscriptions); 7-Eleven, McDonalds (Dining); TDC, Telia, 3 (Telecom); Tryg, Topdanmark, Alm Brand (Insurance); Orsted, Norlys (Utilities); IKEA, Jysk, Bauhaus (Home); H&M, Zalando, Matas (Fashion/Health); Fitness World (Health).

**Step 2:** Add importDanishMerchantRules() to CategoryService - merges keywords into existing categories.

**Step 3:** Add Import Danish Merchant Rules tile in settings.

**Step 4:** Commit: `git commit -m "feat: add Danish merchant database with 50+ keyword rules"`

---

# Phase 5: Attachments

## Task 16: Receipt Scanning

**Files:**
- Create: `mobile/lib/models/receipt.dart`
- Create: `mobile/lib/widgets/receipt_attach_button.dart`
- Modify: `mobile/lib/screens/transaction_detail_screen.dart`
- Modify: `mobile/lib/services/api_service.dart`
- Modify: `mobile/pubspec.yaml` (add image_picker)

**PocketBase prerequisite:** Create receipts collection - transactionId (relation->transactions), file (file), ocrText (text), createdAt (date). Add receiptId (relation->receipts) to transactions.

**Step 1:** Add image_picker: ^1.1.2 to pubspec.yaml, run flutter pub get.

**Step 2:** Create Receipt model.

**Step 3:** Add to ApiService: uploadReceipt (multipart POST), fetchReceipt, deleteReceipt.

**Step 4:** Create ReceiptAttachButton - bottom sheet with Take Photo / Choose from Gallery.

**Step 5:** Add receipt section to TransactionDetailScreen (thumbnail or attach button).

**Step 6:** Add receipt icon indicator to _TransactionTile.

**Step 7:** Commit: `git commit -m "feat: add receipt scanning with camera capture and PocketBase file storage"`

---

# PocketBase Setup Checklist

**Phase 2:**
- [ ] budgets - categoryId (relation->categories), monthlyLimit (number), month (number), year (number), rollover (bool)
- [ ] recurring_patterns - merchantPattern (text), frequency (text), avgAmount (number), categoryId (relation->categories), lastSeen (date), nextExpected (date), isActive (bool)
- [ ] Add notes (text) and tags (JSON) to transactions

**Phase 3:**
- [ ] savings_goals - name (text), targetAmount (number), deadline (date), isActive (bool), createdAt (date)
- [ ] Add splitParts (JSON) to transactions

**Phase 5:**
- [ ] receipts - transactionId (relation->transactions), file (file), ocrText (text), createdAt (date)
- [ ] Add receiptId (relation->receipts) to transactions

---

# Summary

| Task | Feature | Phase | Effort |
|------|---------|-------|--------|
| 1 | Fix Transaction Count KPI | 1 | 15 min |
| 2 | Infinite Scroll | 1 | 1 hr |
| 3 | Persist Filter State | 1 | 1 hr |
| 4 | Category Dropdown by Frequency | 1 | 1 hr |
| 5 | Dashboard Caching | 1 | 2 hr |
| 6 | Budget Tracking | 2 | 10 hr |
| 7 | Recurring Detection | 2 | 10 hr |
| 8 | Transaction Detail Screen | 2 | 10 hr |
| 9 | Savings Goals | 3 | 8 hr |
| 10 | Advanced Filtering | 3 | 6 hr |
| 11 | Bulk Recategorize | 3 | 4 hr |
| 12 | Split Transactions | 3 | 7 hr |
| 13 | Auto-Insights Engine | 4 | 8 hr |
| 14 | Cash Flow Forecast | 4 | 6 hr |
| 15 | Danish Merchant Database | 4 | 6 hr |
| 16 | Receipt Scanning | 5 | 15 hr |
| **Total** | | | **~96 hr** |
