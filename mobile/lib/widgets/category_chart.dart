import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/dashboard_service.dart';
import '../theme/app_theme.dart';

enum ChartType { pie, bars, list }

extension _ChartTypeLabel on ChartType {
  IconData get icon {
    switch (this) {
      case ChartType.pie:
        return Icons.pie_chart_rounded;
      case ChartType.bars:
        return Icons.bar_chart_rounded;
      case ChartType.list:
        return Icons.format_list_numbered_rounded;
    }
  }
}

class CategoryChart extends StatefulWidget {
  final List<CategoryAmount> categories;

  const CategoryChart({super.key, required this.categories});

  @override
  State<CategoryChart> createState() => _CategoryChartState();
}

class _CategoryChartState extends State<CategoryChart> {
  ChartType _type = ChartType.bars;
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final cats = widget.categories;
    final total = cats.fold(0.0, (sum, c) => sum + c.amount);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header + type selector
            Row(
              children: [
                const Text(
                  'Expenses by Category',
                  style: TextStyle(
                    color: AppTheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _ChartTypeSelector(
                  selected: _type,
                  onChanged: (t) => setState(() {
                    _type = t;
                    _touchedIndex = -1;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Chart body
            if (_type == ChartType.pie)
              _buildPie(cats, total)
            else if (_type == ChartType.bars)
              _buildBars(cats, total)
            else
              _buildList(cats, total),
          ],
        ),
      ),
    );
  }

  // ── Pie chart ──────────────────────────────────────────────────────────────

  Widget _buildPie(List<CategoryAmount> cats, double total) {
    final fmt = NumberFormat('#,##0', 'da_DK');
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 45,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        response?.touchedSection == null) {
                      _touchedIndex = -1;
                      return;
                    }
                    _touchedIndex =
                        response!.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              sections: List.generate(cats.length, (i) {
                final cat = cats[i];
                final isTouched = i == _touchedIndex;
                final pct = total > 0 ? cat.amount / total * 100 : 0.0;
                final color = CategoryColors.forCategory(cat.category);
                return PieChartSectionData(
                  value: cat.amount,
                  color: color,
                  radius: isTouched ? 62 : 52,
                  showTitle: isTouched,
                  title: '${pct.toStringAsFixed(1)}%',
                  titleStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: List.generate(cats.length, (i) {
            final cat = cats[i];
            final color = CategoryColors.forCategory(cat.category);
            final pct = total > 0 ? cat.amount / total * 100 : 0.0;
            final isHl = i == _touchedIndex;
            return GestureDetector(
              onTap: () => setState(() => _touchedIndex = isHl ? -1 : i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isHl ? color.withAlpha(26) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isHl ? color.withAlpha(80) : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: color, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 5),
                    Text(cat.category,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.onSurface)),
                    const SizedBox(width: 4),
                    Text('${pct.toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 11, color: color)),
                  ],
                ),
              ),
            );
          }),
        ),
        if (_touchedIndex >= 0 && _touchedIndex < cats.length) ...[
          const SizedBox(height: 10),
          Text(
            '${cats[_touchedIndex].category}: ${fmt.format(cats[_touchedIndex].amount)} DKK',
            style: TextStyle(
              color: CategoryColors.forCategory(cats[_touchedIndex].category),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  // ── Horizontal bars ───────────────────────────────────────────────────────

  Widget _buildBars(List<CategoryAmount> cats, double total) {
    final fmt = NumberFormat('#,##0', 'da_DK');
    return Column(
      children: cats.asMap().entries.map((e) {
        final i = e.key;
        final cat = e.value;
        final pct = total > 0 ? cat.amount / total : 0.0;
        final color = CategoryColors.forCategory(cat.category);
        final isHl = i == _touchedIndex;

        return GestureDetector(
          onTap: () => setState(() => _touchedIndex = isHl ? -1 : i),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        cat.category,
                        style: TextStyle(
                          color: isHl ? color : AppTheme.onSurface,
                          fontSize: 13,
                          fontWeight:
                              isHl ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    Text(
                      '${fmt.format(cat.amount)} DKK',
                      style: TextStyle(
                        color: AppTheme.onSurface,
                        fontSize: 12,
                        fontWeight: isHl ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(pct * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                LayoutBuilder(builder: (ctx, box) {
                  return Stack(children: [
                    Container(
                      height: 6,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.divider,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 6,
                      width: box.maxWidth * pct,
                      decoration: BoxDecoration(
                        color: isHl ? color : color.withAlpha(180),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ]);
                }),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Sorted list ───────────────────────────────────────────────────────────

  Widget _buildList(List<CategoryAmount> cats, double total) {
    final fmt = NumberFormat('#,##0', 'da_DK');
    return Column(
      children: cats.asMap().entries.map((e) {
        final i = e.key;
        final cat = e.value;
        final pct = total > 0 ? cat.amount / total * 100 : 0.0;
        final color = CategoryColors.forCategory(cat.category);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withAlpha(26),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  cat.category,
                  style:
                      const TextStyle(color: AppTheme.onSurface, fontSize: 13),
                ),
              ),
              Text(
                '${fmt.format(cat.amount)} DKK',
                style: const TextStyle(
                  color: AppTheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 42,
                child: Text(
                  '${pct.toStringAsFixed(1)}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Chart type selector ───────────────────────────────────────────────────────

class _ChartTypeSelector extends StatelessWidget {
  final ChartType selected;
  final ValueChanged<ChartType> onChanged;

  const _ChartTypeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ChartType.values.map((t) {
          final isSelected = t == selected;
          return GestureDetector(
            onTap: () => onChanged(t),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(
                t.icon,
                size: 15,
                color: isSelected ? Colors.white : AppTheme.onSurfaceMuted,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
