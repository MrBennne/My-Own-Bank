import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/category_service.dart';
import '../theme/app_theme.dart';

Color _typeColor(String type) {
  switch (type) {
    case 'income':
      return AppTheme.income;
    case 'transfer':
      return AppTheme.savings;
    default:
      return AppTheme.expense;
  }
}

String _typeLabel(String type) {
  switch (type) {
    case 'income':
      return 'Income';
    case 'transfer':
      return 'Transfer';
    default:
      return 'Expense';
  }
}

const List<Color> _presetColors = [
  Color(0xFF0d6efd),
  Color(0xFF6366f1),
  Color(0xFF8b5cf6),
  Color(0xFFec4899),
  Color(0xFFf43f5e),
  Color(0xFFef4444),
  Color(0xFFf97316),
  Color(0xFFf59e0b),
  Color(0xFFfbbf24),
  Color(0xFFa3e635),
  Color(0xFF22c55e),
  Color(0xFF10b981),
  Color(0xFF14b8a6),
  Color(0xFF06b6d4),
  Color(0xFF0ea5e9),
  Color(0xFF3b82f6),
  Color(0xFF6c757d),
  Color(0xFF475569),
  Color(0xFF1e293b),
  Color(0xFFffffff),
  Color(0xFFff6b6b),
  Color(0xFF4ecdc4),
  Color(0xFFa8edea),
  Color(0xFFff9ff3),
];

class CategorySettingsScreen extends StatefulWidget {
  const CategorySettingsScreen({super.key});

  @override
  State<CategorySettingsScreen> createState() => _CategorySettingsScreenState();
}

class _CategorySettingsScreenState extends State<CategorySettingsScreen> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await CategoryService.instance.refresh();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<CategoryGroup> get _groups =>
      CategoryService.instance.groupedCategories();

  Future<void> _showEditDialog(Category cat) async {
    final nameController = TextEditingController(text: cat.name);
    final keywordsController =
        TextEditingController(text: cat.keywords.join('\n'));
    String selectedType = cat.type;
    String selectedGroup = cat.group.isNotEmpty ? cat.group : kGroupOrder.first;
    String? selectedColor = cat.color;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocal) {
          return AlertDialog(
            backgroundColor: AppTheme.surfaceVariant,
            title: const Text('Edit Category'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    dropdownColor: AppTheme.surfaceVariant,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(value: 'income', child: Text('Income')),
                      DropdownMenuItem(
                          value: 'expense', child: Text('Expense')),
                      DropdownMenuItem(
                          value: 'transfer', child: Text('Transfer')),
                    ],
                    onChanged: (v) {
                      if (v != null) setLocal(() => selectedType = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedGroup,
                    dropdownColor: AppTheme.surfaceVariant,
                    decoration: const InputDecoration(labelText: 'Group'),
                    items: kGroupOrder
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setLocal(() => selectedGroup = v);
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text('Colour',
                      style: TextStyle(
                          color: AppTheme.onSurfaceMuted, fontSize: 13)),
                  const SizedBox(height: 10),
                  _ColorPickerGrid(
                    selected: selectedColor != null && selectedColor!.isNotEmpty
                        ? _parseHex(selectedColor!)
                        : null,
                    onSelect: (c) => setLocal(() => selectedColor =
                        '#${c.toARGB32().toRadixString(16).substring(2)}'),
                  ),
                  if (selectedColor != null && selectedColor!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => setLocal(() => selectedColor = ''),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Reset colour'),
                      style: TextButton.styleFrom(
                          foregroundColor: AppTheme.onSurfaceMuted),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text('Keywords (one per line)',
                      style: TextStyle(
                          color: AppTheme.onSurfaceMuted, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: keywordsController,
                    maxLines: 6,
                    minLines: 3,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'REMA 1000\nNETTO\n...',
                      hintStyle: TextStyle(
                          color: AppTheme.onSurfaceMuted, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  final kws = keywordsController.text
                      .split('\n')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .toList();
                  try {
                    await CategoryService.instance.updateCategory(
                      cat.id,
                      name: name,
                      type: selectedType,
                      group: selectedGroup,
                      color: selectedColor ?? '',
                      keywords: kws,
                    );
                    if (mounted) setState(() {});
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _showAddDialog() async {
    final nameController = TextEditingController();
    final keywordsController = TextEditingController();
    String selectedType = 'expense';
    String selectedGroup = kGroupOrder.first;
    String? selectedColor;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocal) {
          return AlertDialog(
            backgroundColor: AppTheme.surfaceVariant,
            title: const Text('Add Category'),
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
                      validator: (v) {
                        if ((v?.trim() ?? '').isEmpty) {
                          return 'Name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      dropdownColor: AppTheme.surfaceVariant,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: const [
                        DropdownMenuItem(
                            value: 'income', child: Text('Income')),
                        DropdownMenuItem(
                            value: 'expense', child: Text('Expense')),
                        DropdownMenuItem(
                            value: 'transfer', child: Text('Transfer')),
                      ],
                      onChanged: (v) {
                        if (v != null) setLocal(() => selectedType = v);
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedGroup,
                      dropdownColor: AppTheme.surfaceVariant,
                      decoration: const InputDecoration(labelText: 'Group'),
                      items: kGroupOrder
                          .map(
                              (g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setLocal(() => selectedGroup = v);
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text('Colour (optional)',
                        style: TextStyle(
                            color: AppTheme.onSurfaceMuted, fontSize: 13)),
                    const SizedBox(height: 10),
                    _ColorPickerGrid(
                      selected: selectedColor != null
                          ? _parseHex(selectedColor!)
                          : null,
                      onSelect: (c) => setLocal(() => selectedColor =
                          '#${c.toARGB32().toRadixString(16).substring(2)}'),
                    ),
                    const SizedBox(height: 20),
                    const Text('Keywords (one per line, optional)',
                        style: TextStyle(
                            color: AppTheme.onSurfaceMuted, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: keywordsController,
                      maxLines: 6,
                      minLines: 3,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'REMA 1000\nNETTO\n...',
                        hintStyle: TextStyle(
                            color: AppTheme.onSurfaceMuted, fontSize: 13),
                      ),
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
                  final name = nameController.text.trim();
                  final kws = keywordsController.text
                      .split('\n')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .toList();
                  try {
                    await CategoryService.instance.createCategory(
                      name,
                      selectedType,
                      group: selectedGroup,
                      color: selectedColor,
                      keywords: kws,
                    );
                    if (mounted) setState(() {});
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _confirmDelete(Category cat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceVariant,
        title: const Text('Delete category'),
        content: Text('Delete "${cat.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.expense),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await CategoryService.instance.deleteCategory(cat.id);
        if (mounted) setState(() {});
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        tooltip: 'Add category',
        child: const Icon(Icons.add_rounded),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 48, color: AppTheme.onSurfaceMuted),
              const SizedBox(height: 12),
              Text('Could not load categories',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(
                      color: AppTheme.onSurfaceMuted, fontSize: 12),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final groups = _groups;
    if (groups.isEmpty) {
      return const Center(
        child: Text('No categories yet.\nTap + to add one.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.onSurfaceMuted)),
      );
    }

    return ListenableBuilder(
      listenable: CategoryService.instance,
      builder: (context, _) {
        final items = _groups;
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final group = items[index];
            return _GroupSection(
              group: group,
              onEdit: _showEditDialog,
              onDelete: _confirmDelete,
            );
          },
        );
      },
    );
  }
}

class _GroupSection extends StatelessWidget {
  final CategoryGroup group;
  final ValueChanged<Category> onEdit;
  final ValueChanged<Category> onDelete;

  const _GroupSection({
    required this.group,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
          child: Row(
            children: [
              Text(
                group.groupName.toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.onSurfaceMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Text(
                '${group.categories.length}',
                style: const TextStyle(
                    color: AppTheme.onSurfaceMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        // Category tiles
        ...group.categories.map((cat) {
          final color = CategoryService.instance.colorFor(cat.name);
          final kwCount = cat.keywords.length;
          return Dismissible(
            key: ValueKey(cat.id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) async {
              onDelete(cat);
              return false;
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              color: AppTheme.expense.withAlpha(180),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Colors.white, size: 24),
            ),
            child: ListTile(
              onTap: () => onEdit(cat),
              leading: CircleAvatar(
                backgroundColor: color,
                radius: 16,
                child: Text(
                  cat.name.isNotEmpty ? cat.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
              ),
              title: Text(cat.name),
              subtitle: Row(
                children: [
                  _TypeBadge(type: cat.type),
                  if (kwCount > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '$kwCount keyword${kwCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: AppTheme.onSurfaceMuted, fontSize: 12),
                    ),
                  ],
                ],
              ),
              trailing: const Icon(Icons.edit_outlined,
                  size: 18, color: AppTheme.onSurfaceMuted),
            ),
          );
        }),
        const Divider(height: 1),
      ],
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(type);
    final label = _typeLabel(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class _ColorPickerGrid extends StatelessWidget {
  const _ColorPickerGrid({required this.selected, required this.onSelect});
  final Color? selected;
  final ValueChanged<Color> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _presetColors.map((color) {
        final isSelected =
            selected != null && selected!.toARGB32() == color.toARGB32();
        return GestureDetector(
          onTap: () => onSelect(color),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: Colors.white, width: 2.5)
                  : Border.all(color: Colors.transparent, width: 2.5),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                          color: color.withAlpha(120),
                          blurRadius: 6,
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

Color? _parseHex(String hex) {
  hex = hex.replaceFirst('#', '');
  if (hex.length == 6) return Color(int.parse('FF$hex', radix: 16));
  if (hex.length == 8) return Color(int.parse(hex, radix: 16));
  return null;
}
