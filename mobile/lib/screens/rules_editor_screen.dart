import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/category_service.dart';
import '../theme/app_theme.dart';

class RulesEditorScreen extends StatefulWidget {
  const RulesEditorScreen({super.key});

  @override
  State<RulesEditorScreen> createState() => _RulesEditorScreenState();
}

class _RulesEditorScreenState extends State<RulesEditorScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await CategoryService.instance.refresh();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _editKeywords(Category cat) async {
    final controller = TextEditingController(text: cat.keywords.join('\n'));

    final saved = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceVariant,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(cat.name),
            Text('${cat.group} \u2022 ${cat.type}',
                style: const TextStyle(
                    color: AppTheme.onSurfaceMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.normal)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Keywords (one per line)',
                  style:
                      TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                maxLines: 10,
                minLines: 4,
                decoration: const InputDecoration(
                  hintText: 'REMA 1000\nNETTO\n...',
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
            onPressed: () {
              final kws = controller.text
                  .split('\n')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
              Navigator.pop(ctx, kws);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (saved != null) {
      try {
        await CategoryService.instance.updateCategory(
          cat.id,
          keywords: saved,
        );
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Keywords saved')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error: $e'), backgroundColor: AppTheme.expense),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorization Rules'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildList(),
    );
  }

  Widget _buildList() {
    return ListenableBuilder(
      listenable: CategoryService.instance,
      builder: (context, _) {
        final groups = CategoryService.instance.groupedCategories();
        return ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: groups.map((g) {
            return _GroupSection(
              group: g,
              onTap: _editKeywords,
            );
          }).toList(),
        );
      },
    );
  }
}

class _GroupSection extends StatelessWidget {
  final CategoryGroup group;
  final ValueChanged<Category> onTap;

  const _GroupSection({
    required this.group,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final totalKw =
        group.categories.fold(0, (sum, c) => sum + c.keywords.length);
    return ExpansionTile(
      initiallyExpanded: true,
      title: Text(group.groupName,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      trailing: Text('$totalKw keywords',
          style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
      children: group.categories.map((cat) {
        final kwCount = cat.keywords.length;
        return ListTile(
          dense: true,
          onTap: () => onTap(cat),
          title: Text(cat.name),
          subtitle: Text(
            '$kwCount keyword${kwCount == 1 ? '' : 's'}',
            style:
                const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right_rounded,
              color: AppTheme.onSurfaceMuted, size: 18),
        );
      }).toList(),
    );
  }
}
