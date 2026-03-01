import 'package:flutter/material.dart';
import '../services/category_service.dart';
import '../theme/app_theme.dart';
import 'category_settings_screen.dart';
import 'rules_editor_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: CategoryService.instance,
        builder: (context, _) {
          final catCount = CategoryService.instance.categories.length;
          final ruleCount = CategoryService.instance.categories
              .fold(0, (sum, c) => sum + c.keywords.length);

          return ListView(
            children: [
              // ── Categories ──────────────────────────────────────────────
              _SectionHeader(label: 'Categories'),
              ListTile(
                leading: _IconBox(
                  color: AppTheme.primary,
                  icon: Icons.label_outline_rounded,
                ),
                title: const Text('Categories'),
                subtitle: Text(
                  '$catCount categories',
                  style: const TextStyle(color: AppTheme.onSurfaceMuted),
                ),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.onSurfaceMuted),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CategorySettingsScreen()),
                ),
              ),

              // ── Rules ───────────────────────────────────────────────────
              const Divider(),
              _SectionHeader(label: 'Categorization'),
              ListTile(
                leading: _IconBox(
                  color: AppTheme.savings,
                  icon: Icons.rule_rounded,
                ),
                title: const Text('Keyword Rules'),
                subtitle: Text(
                  '$ruleCount keywords across all categories',
                  style: const TextStyle(
                      color: AppTheme.onSurfaceMuted, fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.onSurfaceMuted),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RulesEditorScreen()),
                ),
              ),

              // ── App ─────────────────────────────────────────────────────
              const Divider(),
              _SectionHeader(label: 'App'),
              ListTile(
                leading: _IconBox(
                  color: AppTheme.onSurfaceMuted,
                  icon: Icons.info_outline_rounded,
                ),
                title: const Text('Version'),
                subtitle: const Text('1.1.0',
                    style: TextStyle(color: AppTheme.onSurfaceMuted)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.color, required this.icon});
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.onSurfaceMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
