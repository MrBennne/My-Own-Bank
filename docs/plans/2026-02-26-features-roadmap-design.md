# Feature Roadmap & Immediate Implementation Design

**Date:** 2026-02-26
**Branch:** pocketbase-migration

## Immediate Features (Implement Now)

### Feature A: Create Category from Bottom Sheet Selector

**Goal:** Let users create a new category directly from the category selection bottom sheet, without leaving the transaction context.

**Where:** `CategoryBottomSheet` widget — shown when tapping a category chip on any transaction.

**Behavior:**
1. Add a "+ New Category" tile at the top of the category list
2. Tapping opens an inline dialog:
   - Category name (required text field)
   - Type selector: Income / Expense / Transfer
   - Color picker (reuse existing 24-preset picker)
3. On save: create category in PocketBase via `CategoryService.createCategory()`
4. After creation: auto-select the new category for the current transaction
5. Bottom sheet closes with the new category applied

**Files:**
- `mobile/lib/widgets/category_bottom_sheet.dart` — add "+ New Category" option + creation dialog
- `mobile/lib/services/category_service.dart` — already has `createCategory()`, just wire it

---

### Feature B: Force-Manual Uncategorized Keywords

**Goal:** Allow merchants like "MobilePay" to be marked as always requiring manual categorization, even though keywords exist for them elsewhere.

**Approach:** Add keywords to an "Uncategorized" category in the categorization rules. When `categorize()` matches a keyword to "Uncategorized", the transaction gets `originally_uncategorized = true` and appears in the Review tab.

**Behavior:**
1. Add `"Uncategorized": ["MobilePay"]` to categories.json (expense section, and optionally income)
2. Python categorizer matches "MobilePay" -> returns "Uncategorized"
3. Uploader sees category == "Uncategorized" -> sets `originally_uncategorized = true`
4. Transaction appears in Review tab for manual categorization
5. Learner skips merchants that matched "Uncategorized" keywords (avoids nagging)

**Files:**
- `categories.json` — add Uncategorized keywords
- `src/categorizer.py` — verify "Uncategorized" is handled as valid matched category
- `src/pb_learner.py` — skip force-manual merchants when generating pending rules
- `mobile/lib/services/category_service.dart` — ensure categorize() handles "Uncategorized" match
- Flutter settings screens — ensure "Uncategorized" category is visible/editable in keyword rules

---

## Full Feature Roadmap (Prioritized)

### Tier 1 — Core UX (High value, moderate effort)
1. **Transaction detail screen** (#23) — full view with edit fields, history, linked transfers
2. **Category drill-down** (#8) — tap a category on dashboard to see all its transactions
3. **Dark/light theme toggle** (#20) — currently dark-only, add light theme + toggle
4. **Undo actions** (#24) — undo snackbar after category change or dismiss
5. **Auto-learn from corrections through Review** (#16) — recategorization creates Review item, not auto-rule

### Tier 2 — Dashboard Enhancements (High value, moderate effort)
6. **Income vs expense trend line** (#6) — line chart overlay on monthly bars
7. **Year-over-year + month-over-month comparison** (#7) — compare periods to same period last year
8. **Account breakdown** (#9) — per-account income/expense summary card

### Tier 3 — Data Management (Moderate value, moderate effort)
9. **Bulk recategorize** (#13) — select multiple transactions, assign category at once
10. **Notes/tags on transactions** (#15) — add personal notes or tags for context
11. **Suggested category** (#17) — "did you mean X?" based on similar merchants
12. **Drag-and-drop import** (#11) — useful on tablet/desktop

### Tier 4 — Advanced Features (High effort, new subsystems)
13. **Budget targets** (#1) — monthly spending limits per category, progress bars
14. **Recurring transaction detection** (#3) — identify subscriptions, flag amount changes
15. **Split transactions** (#14) — split one transaction across multiple categories
16. **Savings goal tracker** (#27) — set target and track progress

### Tier 5 — Security
17. **Biometric auth** (#21) — fingerprint/face unlock, optional toggle
