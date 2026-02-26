import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/dashboard_service.dart';
import '../theme/app_theme.dart';

class HeroSummaryCard extends StatelessWidget {
  final KpiData kpi;
  final String periodLabel;

  const HeroSummaryCard({
    super.key,
    required this.kpi,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'da_DK');
    final isPositive = kpi.netSavings >= 0;
    final netColor = isPositive ? AppTheme.income : AppTheme.expense;
    final netSign = isPositive ? '+' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: netColor.withAlpha(60)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period label
            Text(
              periodLabel,
              style: const TextStyle(
                color: AppTheme.onSurfaceMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 6),

            // Net savings (hero number)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$netSign${fmt.format(kpi.netSavings.abs())}',
                  style: TextStyle(
                    color: netColor,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    'DKK',
                    style: TextStyle(
                      color: netColor.withAlpha(180),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: netColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: netColor.withAlpha(60)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive
                            ? Icons.savings_rounded
                            : Icons.trending_down_rounded,
                        color: netColor,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${kpi.savingsRate.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: netColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1, color: AppTheme.divider),
            const SizedBox(height: 14),

            // Income / Expense row
            Row(
              children: [
                _StatChip(
                  icon: Icons.trending_up_rounded,
                  label: 'Income',
                  value: '${fmt.format(kpi.totalIncome)} DKK',
                  color: AppTheme.income,
                ),
                const SizedBox(width: 12),
                _StatChip(
                  icon: Icons.trending_down_rounded,
                  label: 'Expenses',
                  value: '${fmt.format(kpi.totalExpenses)} DKK',
                  color: AppTheme.expense,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(13),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 13),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: color.withAlpha(180),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: AppTheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
