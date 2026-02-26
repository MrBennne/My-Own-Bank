import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';
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
  final _api = ApiService();
  Map<String, int> _recentlyUsedFrequency = {};

  @override
  void initState() {
    super.initState();
    _loadRecentlyUsedCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentlyUsedCategories() async {
    try {
      final now = DateTime.now();
      final threeMonthsAgo = now.subtract(const Duration(days: 90));
      final dateFilter = 'created >= "${threeMonthsAgo.toIso8601String()}"';

      final result = await _api.fetchTransactions(
        perPage: 500,
        dateFilter: dateFilter,
      );

      final frequency = <String, int>{};
      for (final tx in result.items) {
        final category = tx.category ?? 'Uncategorized';
        if (category.isNotEmpty) {
          frequency[category] = (frequency[category] ?? 0) + 1;
        }
      }

      // Sort by frequency descending, take top 8
      final sorted = frequency.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      if (mounted) {
        setState(() {
          _recentlyUsedFrequency = Map.fromEntries(sorted.take(8));
        });
      }
    } catch (e) {
      print('Failed to load recently used categories: $e');
    }
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

  Future<void> _showCreateDialog() async {
    final nameController = TextEditingController();
    String selectedType = 'expense';
    String? selectedColor;
    bool isCreating = false;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
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
                      decoration:
                          const InputDecoration(labelText: 'Name'),
                      autofocus: true,
                      validator: (v) {
                        final name = v?.trim() ?? '';
                        if (name.isEmpty) return 'Name is required';
                        if (CategoryService.instance.findByName(name) != null) {
                          return 'Category already exists';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      dropdownColor: AppTheme.surfaceVariant,
                      decoration:
                          const InputDecoration(labelText: 'Type'),
                      items: const [
                        DropdownMenuItem(
                            value: 'expense', child: Text('Expense')),
                        DropdownMenuItem(
                            value: 'income', child: Text('Income')),
                        DropdownMenuItem(
                            value: 'transfer',
                            child: Text('Transfer')),
                      ],
                      onChanged: (v) {
                        if (v != null) setLocal(() => selectedType = v);
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text('Colour (optional)',
                        style: TextStyle(
                            color: AppTheme.onSurfaceMuted,
                            fontSize: 13)),
                    const SizedBox(height: 10),
                    _ColorPickerInline(
                      selected: selectedColor,
                      onSelect: (hex) =>
                          setLocal(() => selectedColor = hex),
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
                onPressed: isCreating
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setLocal(() => isCreating = true);
                        final name = nameController.text.trim();
                        try {
                          final created =
                              await CategoryService.instance.createCategory(
                            name,
                            selectedType,
                            color: selectedColor,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) _select(created);
                        } catch (e) {
                          setLocal(() => isCreating = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                child: isCreating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create'),
              ),
            ],
          );
        });
      },
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
                    itemCount: groups.length + (_recentlyUsedFrequency.isNotEmpty ? 2 : 1),
                    itemBuilder: (ctx, i) {
                      // Recently used section (if available)
                      if (_recentlyUsedFrequency.isNotEmpty && i == 0) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              child: Text(
                                'FREQUENTLY USED',
                                style: const TextStyle(
                                  color: AppTheme.onSurfaceMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _recentlyUsedFrequency.entries.map((entry) {
                                final color = CategoryColors.forCategory(entry.key);
                                return GestureDetector(
                                  onTap: () {
                                    final cat = CategoryService.instance.findByName(entry.key);
                                    if (cat != null) {
                                      _select(cat);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: color.withAlpha(20),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: color.withAlpha(60),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: color.withAlpha(30),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Center(
                                            child: Text(
                                              entry.key.isNotEmpty ? entry.key[0].toUpperCase() : '?',
                                              style: TextStyle(
                                                color: color,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${entry.key} (${entry.value})',
                                          style: TextStyle(
                                            color: AppTheme.onSurface,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      }

                      // New category button + regular groups
                      final actualIndex = _recentlyUsedFrequency.isNotEmpty ? i - 1 : i;
                      if (actualIndex == 0) {
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
                              child: Icon(
                                Icons.add_rounded,
                                size: 16,
                                color: AppTheme.primary,
                              ),
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
                      final group = groups[actualIndex - 1];
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

// ── Compact color picker for the creation dialog ────────────────────────────

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

  const _ColorPickerInline({
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _presetColors.map((color) {
        final hex =
            '#${color.toARGB32().toRadixString(16).substring(2)}';
        final isSelected = selected != null &&
            selected!.toLowerCase() == hex.toLowerCase();
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
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                          color: color.withAlpha(120),
                          blurRadius: 4,
                          spreadRadius: 1)
                    ]
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}
