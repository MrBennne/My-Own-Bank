import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/category_service.dart';
import '../theme/app_theme.dart';

/// Result returned by [CategoryBottomSheet].
class CategorySelection {
  final String category;
  final String subcategory;
  final String? type; // 'Income' | 'Expense' | 'Transfer'

  const CategorySelection({
    required this.category,
    this.subcategory = '',
    this.type,
  });
}

class CategoryBottomSheet extends StatefulWidget {
  final String currentCategory;
  final String currentSubcategory;

  const CategoryBottomSheet({
    super.key,
    required this.currentCategory,
    this.currentSubcategory = '',
  });

  @override
  State<CategoryBottomSheet> createState() => _CategoryBottomSheetState();
}

class _CategoryBottomSheetState extends State<CategoryBottomSheet> {
  String _search = '';
  String? _typeFilter; // null = all
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CategoryGroup> get _groups {
    final groups = CategoryService.instance.groupedCategories(
      filterType: _typeFilter,
    );
    if (_search.isEmpty) return groups;
    final q = _search.toLowerCase();
    // Filter: keep groups that have matching categories
    return groups
        .map((g) {
          final filtered = g.categories
              .where((c) => c.name.toLowerCase().contains(q))
              .toList();
          if (filtered.isEmpty) return null;
          return CategoryGroup(groupName: g.groupName, categories: filtered);
        })
        .whereType<CategoryGroup>()
        .toList();
  }

  void _select(Category cat) {
    String category = cat.name;
    String subcategory = '';
    String? type;

    if (cat.isSubcategory) {
      category = cat.parentName ?? cat.name;
      subcategory = cat.name;
    }

    switch (cat.type) {
      case 'income':
        type = 'Income';
      case 'transfer':
        type = 'Transfer';
      default:
        type = 'Expense';
    }

    Navigator.pop(
      context,
      CategorySelection(
        category: category,
        subcategory: subcategory,
        type: type,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Select Category',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(
                    context,
                    const CategorySelection(category: 'Uncategorized'),
                  ),
                  child: const Text(
                    'Uncategorized',
                    style: TextStyle(
                      color: AppTheme.onSurfaceMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Type filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _typeFilter == null,
                  onTap: () => setState(() => _typeFilter = null),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'Expense',
                  selected: _typeFilter == 'expense',
                  color: AppTheme.expense,
                  onTap: () => setState(() => _typeFilter = 'expense'),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'Income',
                  selected: _typeFilter == 'income',
                  color: AppTheme.income,
                  onTap: () => setState(() => _typeFilter = 'income'),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'Transfer',
                  selected: _typeFilter == 'transfer',
                  color: AppTheme.savings,
                  onTap: () => setState(() => _typeFilter = 'transfer'),
                ),
              ],
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search categories...',
                prefixIcon: Icon(Icons.search_rounded, size: 18),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          // List
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: groups.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No categories found',
                      style: TextStyle(color: AppTheme.onSurfaceMuted),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: groups.length,
                    itemBuilder: (ctx, i) {
                      final group = groups[i];
                      return _GroupSection(
                        group: group,
                        currentCategory: widget.currentCategory,
                        onSelect: _select,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? c.withAlpha(30) : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? c.withAlpha(100) : AppTheme.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? c : AppTheme.onSurfaceMuted,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _GroupSection extends StatelessWidget {
  final CategoryGroup group;
  final String currentCategory;
  final ValueChanged<Category> onSelect;

  const _GroupSection({
    required this.group,
    required this.currentCategory,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            group.groupName.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.onSurfaceMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),
        // Category rows
        ...group.categories.map((cat) {
          final isCurrent = cat.name == currentCategory;
          final color = CategoryColors.forCategory(cat.name);
          return ListTile(
            dense: true,
            onTap: () => onSelect(cat),
            leading: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  cat.name.isNotEmpty ? cat.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            title: Text(
              cat.name,
              style: TextStyle(
                color: isCurrent ? AppTheme.primary : AppTheme.onSurface,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
            trailing: isCurrent
                ? const Icon(Icons.check_rounded,
                    color: AppTheme.primary, size: 18)
                : null,
            tileColor: isCurrent ? AppTheme.primary.withAlpha(13) : null,
          );
        }),
      ],
    );
  }
}
