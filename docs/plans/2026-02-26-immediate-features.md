# Immediate Features Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement two features: (A) create new category directly from the category selector bottom sheet, and (B) force-manual "Uncategorized" keyword rules so merchants like MobilePay always require manual categorization.

**Architecture:** Feature A adds a creation dialog to the existing `CategoryBottomSheet` widget, reusing the existing `CategoryService.createCategory()` method. Feature B adds "Uncategorized" as a real category with keywords in both `categories.json` (Python pipeline) and PocketBase (Flutter app), then modifies the Python learner to skip force-manual merchants when generating pending rules.

**Tech Stack:** Flutter/Dart (mobile app), Python (pipeline), PocketBase (backend)

---

## Task 1: Add "+ New Category" to CategoryBottomSheet

**Files:**
- Modify: `mobile/lib/widgets/category_bottom_sheet.dart`

**Step 1: Add the creation dialog method to `_CategoryBottomSheetState`**

Add a `_showCreateDialog()` method after the `_select()` method (after line 90). This is a simplified version of the Add dialog from `category_settings_screen.dart` — only name, type, and color (no keywords or group needed from the selector context).

```dart
Future<void> _showCreateDialog() async {
  final nameController = TextEditingController();
  String selectedType = 'expense';
  String? selectedColor;
  final formKey = GlobalKey<FormState>();

  final created = await showDialog<Category>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setLocal) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceVariant,
          title: const Text('New Category'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    autofocus: true,
                    validator: (v) =>
                        (v?.trim() ?? '').isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    dropdownColor: AppTheme.surfaceVariant,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(value: 'expense', child: Text('Expense')),
                      DropdownMenuItem(value: 'income', child: Text('Income')),
                      DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
                    ],
                    onChanged: (v) {
                      if (v != null) setLocal(() => selectedType = v);
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text('Colour (optional)',
                      style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 13)),
                  const SizedBox(height: 10),
                  _ColorPickerInline(
                    selected: selectedColor,
                    onSelect: (hex) => setLocal(() => selectedColor = hex),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  final cat = await CategoryService.instance.createCategory(
                    nameController.text.trim(),
                    selectedType,
                    color: selectedColor,
                  );
                  if (ctx.mounted) Navigator.pop(ctx, cat);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      });
    },
  );

  if (created != null && mounted) {
    _select(created);
  }
}
```

**Step 2: Add the _ColorPickerInline widget**

Add this private widget after the `_GroupSection` class (at the end of the file). This is a compact inline color picker reusing the same preset colors from `category_settings_screen.dart`.

```dart
const List<Color> _presetColors = [
  Color(0xFF0d6efd), Color(0xFF6366f1), Color(0xFF8b5cf6), Color(0xFFec4899),
  Color(0xFFf43f5e), Color(0xFFef4444), Color(0xFFf97316), Color(0xFFf59e0b),
  Color(0xFFfbbf24), Color(0xFFa3e635), Color(0xFF22c55e), Color(0xFF10b981),
  Color(0xFF14b8a6), Color(0xFF06b6d4), Color(0xFF0ea5e9), Color(0xFF3b82f6),
  Color(0xFF6c757d), Color(0xFF475569), Color(0xFF1e293b), Color(0xFFffffff),
  Color(0xFFff6b6b), Color(0xFF4ecdc4), Color(0xFFa8edea), Color(0xFFff9ff3),
];

class _ColorPickerInline extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelect;

  const _ColorPickerInline({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _presetColors.map((color) {
        final hex = '#${color.toARGB32().toRadixString(16).substring(2)}';
        final isSelected = selected == hex;
        return GestureDetector(
          onTap: () => onSelect(hex),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: Colors.white, width: 2)
                  : Border.all(color: Colors.transparent, width: 2),
            ),
          ),
        );
      }).toList(),
    );
  }
}
```

**Step 3: Add "+ New Category" tile to the ListView**

In the `build()` method, insert a "+ New Category" tile before the category groups. Replace the `ListView.builder` section (lines 200-211) with a builder that inserts the creation tile at index 0:

Replace the existing ListView.builder (lines 200-211):
```dart
ListView.builder(
    shrinkWrap: true,
    padding: const EdgeInsets.only(bottom: 16),
    itemCount: groups.length + 1,
    itemBuilder: (ctx, i) {
      if (i == 0) {
        return ListTile(
          dense: true,
          onTap: _showCreateDialog,
          leading: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.add_rounded,
                  color: AppTheme.primary, size: 16),
            ),
          ),
          title: const Text(
            'New Category',
            style: TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        );
      }
      final group = groups[i - 1];
      return _GroupSection(
        group: group,
        currentCategory: widget.currentCategory,
        onSelect: _select,
      );
    },
  ),
```

**Step 4: Verify manually**

Run: `cd mobile && flutter run`
- Open any transaction → tap category chip → bottom sheet opens
- Verify "+ New Category" tile appears at top of list
- Tap it → creation dialog appears
- Create a category → dialog closes → new category is auto-selected
- Verify the transaction's category was updated

**Step 5: Commit**

```bash
git add mobile/lib/widgets/category_bottom_sheet.dart
git commit -m "feat(mobile): add 'New Category' option to category selector bottom sheet"
```

---

## Task 2: Add "Uncategorized" keywords to categories.json

**Files:**
- Modify: `categories.json`

**Step 1: Add Uncategorized keyword section to expense rules**

Add `"Uncategorized"` entry to the `expense` section. This tells the Python categorizer to match these merchants to "Uncategorized" explicitly, which sets `originally_uncategorized=true` in the uploader.

Add after the `"Udlån"` entry (before the closing `}` of the expense section, after line 52):

```json
"Uncategorized": [
  "MobilePay"
]
```

Note: Only add the generic "MobilePay" keyword here — NOT specific recipients like "MobilePay: MobilePay Madeline" which are already mapped to specific categories like "Udlån". The categorizer checks keywords in order, and specific matches (e.g., "MobilePay: MobilePay Madeline" → Udlån) will match before the generic "MobilePay" → Uncategorized because they appear in a category checked first.

**IMPORTANT:** Actually, looking at the categorizer code, `_match()` iterates through categories and returns the FIRST match. Since `expense_rules` is a dict and iteration order is insertion order, "Udlån" with "MobilePay: MobilePay Madeline" would be checked BEFORE "Uncategorized" with "MobilePay". However, "MobilePay" as a substring would match "MobilePay: MobilePay Madeline" too. So we need "Uncategorized" to be LAST in the expense dict (after Udlån), and the more specific entries like `"MobilePay: MobilePay Madeline"` in Udlån will match first.

Wait — the categorizer does substring matching (`keyword.lower() in name_lower`). If the transaction name is "MobilePay: MobilePay Madeline", the keyword "MobilePay: MobilePay Madeline" (in Udlån) matches. But if we add "MobilePay" to Uncategorized, it would ALSO match. The question is which category is checked first.

Since Python dicts preserve insertion order, and we add "Uncategorized" at the END, all other categories' keywords are checked first. So "MobilePay: MobilePay Madeline" → Udlån will match before "MobilePay" → Uncategorized. For a generic "MobilePay" payment (no specific recipient), no other keyword matches, so it falls through to "Uncategorized". This is the correct behavior.

**Step 2: Verify with a quick test**

```bash
python -c "
from src.categorizer import Categorizer
c = Categorizer()
# Specific MobilePay recipient → still matches Udlån
cat, uncat = c.categorize([{'name': 'MobilePay: MobilePay Madeline', 'type': 'Expense'}])
assert len(cat) == 1 and cat[0]['category'] == 'Udlån', f'Expected Udlån, got {cat}'

# Generic MobilePay → matches Uncategorized
cat, uncat = c.categorize([{'name': 'MobilePay betalingsservice', 'type': 'Expense'}])
assert len(cat) == 1 and cat[0]['category'] == 'Uncategorized', f'Expected Uncategorized, got {cat}'
print('All assertions passed!')
"
```

**Step 3: Commit**

```bash
git add categories.json
git commit -m "feat: add force-manual Uncategorized keywords for generic MobilePay"
```

---

## Task 3: Modify Python learner to skip force-manual merchants

**Files:**
- Modify: `src/pb_learner.py`

**Step 1: Add a method to load force-manual keywords**

Add a `_load_force_manual_keywords()` method to `PocketBaseLearner`. This loads categories.json and extracts all keywords from the "Uncategorized" category across all type sections.

Add after `_save_json()` method (after line 23):

```python
def _load_force_manual_keywords(self):
    """Load keywords from 'Uncategorized' categories — these merchants should never generate rules."""
    try:
        with open(self.categories_file, encoding='utf-8') as f:
            raw = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return set()

    keywords = set()
    for section in ('income', 'expense', 'transfer'):
        for kw in raw.get(section, {}).get('Uncategorized', []):
            keywords.add(kw.lower())
    # Also check flat format
    if 'Uncategorized' in raw and isinstance(raw['Uncategorized'], list):
        for kw in raw['Uncategorized']:
            keywords.add(kw.lower())
    return keywords
```

**Step 2: Update `__init__` to accept categories_file path**

Modify the `__init__` to store the categories file path:

```python
def __init__(self, config):
    self.client = PocketBaseClient(config)
    self.categories_file = config.get('categories_file', 'categories.json')
    os.makedirs('data', exist_ok=True)
```

**Step 3: Add skip logic to `scan_for_recategorized()`**

In `scan_for_recategorized()`, load force-manual keywords at the start, and skip matching merchants. Add after the `seen` set construction (after line 32):

```python
force_manual = self._load_force_manual_keywords()
```

Then modify the inner loop check (around line 50). Replace:
```python
if (name, category) not in seen:
```
With:
```python
# Skip merchants matching force-manual keywords
name_lower = name.lower()
is_force_manual = any(kw in name_lower for kw in force_manual)
if not is_force_manual and (name, category) not in seen:
```

**Step 4: Verify the fix**

```bash
python -c "
import json
# Simulate: MobilePay transaction recategorized to 'Mad & Drikke'
# The learner should skip it because 'mobilepay' is a force-manual keyword
from src.pb_learner import PocketBaseLearner
learner = PocketBaseLearner({'pocketbase': {'url': 'http://locserv.tail18bcbb.ts.net:8091', 'email': 'banking@mybank.local', 'password': 'Banking#Q-CsEdIGYdvDxx0X'}, 'categories_file': 'categories.json'})
kw = learner._load_force_manual_keywords()
assert 'mobilepay' in kw, f'Expected mobilepay in keywords, got {kw}'
print(f'Force-manual keywords: {kw}')
print('Learner correctly loads force-manual keywords!')
"
```

**Step 5: Commit**

```bash
git add src/pb_learner.py
git commit -m "feat: skip force-manual merchants in rule learner"
```

---

## Task 4: Ensure Flutter CategoryService handles "Uncategorized" keyword match

**Files:**
- Verify: `mobile/lib/services/csv_pipeline_service.dart:169`
- Verify: `mobile/lib/services/category_service.dart:170-221`

**Step 1: Verify CsvPipelineService already works**

Check line 169 of `csv_pipeline_service.dart`:
```dart
'originally_uncategorized': tx['category'] == 'Uncategorized',
```

This already handles the case where `categorize()` returns category='Uncategorized' — it sets `originally_uncategorized=true`. No code change needed.

**Step 2: Verify CategoryService.categorize() works**

The `categorize()` method in `category_service.dart` iterates through PocketBase categories and matches keywords. If an "Uncategorized" category exists in PocketBase with keywords, it will match and return `(category: 'Uncategorized', ...)`.

For this to work, the user must create an "Uncategorized" category in PocketBase via Settings > Categories with:
- Name: `Uncategorized`
- Type: `expense`
- Keywords: `MobilePay` (and any other generic payment processors)

**This is a manual setup step.** Document it in the commit message.

**Step 3: Commit (docs only)**

No code changes needed for this task. Add a note to the FEATURES.md if desired.

```bash
git add mobile/FEATURES.md
git commit -m "docs: document force-manual categorization setup for Flutter app"
```

---

## Task 5: Final integration test

**Step 1: Test Python pipeline path**

```bash
python -c "
from src.categorizer import Categorizer
c = Categorizer()

# Test 1: Generic MobilePay → Uncategorized
cat, uncat = c.categorize([
    {'name': 'MobilePay betalingsservice', 'type': 'Expense'},
    {'name': 'MobilePay: MobilePay Madeline', 'type': 'Expense'},
    {'name': 'REMA 1000 Kolding', 'type': 'Expense'},
])
print('Categorized:', [(t['name'][:30], t['category']) for t in cat])
print('Uncategorized:', [(t['name'][:30], t['category']) for t in uncat])

# Expect:
# - MobilePay betalingsservice → Uncategorized (in categorized list, force-manual)
# - MobilePay: MobilePay Madeline → Udlån (specific match wins)
# - REMA 1000 Kolding → Mad & Drikke
"
```

**Step 2: Test Flutter app manually**

1. Open app → Settings → Categories → Add "Uncategorized" category with keyword "MobilePay"
2. Import a CSV with generic MobilePay transactions
3. Verify they appear as "Uncategorized" in Transactions tab
4. Verify they appear in Review tab after manual categorization
5. Test the new "+ New Category" button in the category selector

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat: implement force-manual categorization and category creation from selector

- Add 'New Category' option to category bottom sheet selector
- Add 'Uncategorized' keyword rules for generic MobilePay
- Skip force-manual merchants in Python rule learner
- Clean up FEATURES.md: remove rejected features, add roadmap tiers"
```

---

## Summary of all changes

| File | Change |
|------|--------|
| `mobile/lib/widgets/category_bottom_sheet.dart` | Add `_showCreateDialog()`, `_ColorPickerInline`, and "+ New Category" tile |
| `categories.json` | Add `"Uncategorized": ["MobilePay"]` to expense section |
| `src/pb_learner.py` | Add `_load_force_manual_keywords()`, skip force-manual merchants in `scan_for_recategorized()` |
| `mobile/FEATURES.md` | Clean up: remove (no) items, add roadmap tiers |
| `docs/plans/2026-02-26-features-roadmap-design.md` | Design document |
