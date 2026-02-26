import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/dashboard_service.dart';
import '../theme/app_theme.dart';

export '../theme/app_theme.dart' show CategoryColors;

class CategoryPieChart extends StatefulWidget {
  final List<CategoryAmount> categories;

  const CategoryPieChart({super.key, required this.categories});

  @override
  State<CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<CategoryPieChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final cats = widget.categories;
    final total = cats.fold(0.0, (sum, c) => sum + c.amount);
    final formatter = NumberFormat('#,##0', 'da_DK');

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
          children: [
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 50,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            response?.touchedSection == null) {
                          _touchedIndex = -1;
                          return;
                        }
                        _touchedIndex = response!
                            .touchedSection!.touchedSectionIndex;
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
                      radius: isTouched ? 64 : 54,
                      showTitle: isTouched,
                      title: isTouched
                          ? '${pct.toStringAsFixed(1)}%'
                          : '',
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Legend
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: List.generate(cats.length, (i) {
                final cat = cats[i];
                final color = CategoryColors.forCategory(cat.category);
                final pct = total > 0 ? cat.amount / total * 100 : 0.0;
                return _LegendItem(
                  color: color,
                  label: cat.category,
                  amount: '${formatter.format(cat.amount)} DKK',
                  pct: pct,
                  isHighlighted: i == _touchedIndex,
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String amount;
  final double pct;
  final bool isHighlighted;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.amount,
    required this.pct,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isHighlighted ? color.withAlpha(26) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isHighlighted ? color.withAlpha(77) : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.onSurface),
          ),
          const SizedBox(width: 4),
          Text(
            '${pct.toStringAsFixed(1)}%',
            style: TextStyle(fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }
}
