import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/dashboard_service.dart';
import '../theme/app_theme.dart';

class MonthlyBarChart extends StatefulWidget {
  final List<MonthlyBar> bars;

  const MonthlyBarChart({super.key, required this.bars});

  @override
  State<MonthlyBarChart> createState() => _MonthlyBarChartState();
}

class _MonthlyBarChartState extends State<MonthlyBarChart> {
  int _touchedGroupIndex = -1;

  @override
  Widget build(BuildContext context) {
    final bars = widget.bars;
    if (bars.isEmpty) return const SizedBox.shrink();

    // Only show last 12 months to keep chart readable
    final visible = bars.length > 12 ? bars.sublist(bars.length - 12) : bars;

    final maxY = visible
        .map((b) => b.income > b.expenses ? b.income : b.expenses)
        .reduce((a, b) => a > b ? a : b);

    final formatter = NumberFormat('#,##0', 'da_DK');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: Column(
          children: [
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendDot(AppTheme.income, 'Income'),
                const SizedBox(width: 16),
                _legendDot(AppTheme.expense, 'Expenses'),
                const SizedBox(width: 16),
                _legendLine(AppTheme.savings, 'Net'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  maxY: maxY * 1.2,
                  minY: 0,
                  groupsSpace: 8,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => AppTheme.surfaceVariant,
                      tooltipPadding: const EdgeInsets.all(8),
                      tooltipMargin: 8,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final bar = visible[group.x];
                        final isIncome = rodIndex == 0;
                        final value = isIncome ? bar.income : bar.expenses;
                        return BarTooltipItem(
                          '${isIncome ? "Income" : "Expense"}\n'
                          '${formatter.format(value)} DKK',
                          TextStyle(
                            color:
                                isIncome ? AppTheme.income : AppTheme.expense,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                    touchCallback: (event, response) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            response == null ||
                            response.spot == null) {
                          _touchedGroupIndex = -1;
                          return;
                        }
                        _touchedGroupIndex =
                            response.spot!.touchedBarGroupIndex;
                      });
                    },
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= visible.length) {
                            return const SizedBox.shrink();
                          }
                          // Show every label if <= 6 bars, else every other
                          if (visible.length > 6 && i % 2 != 0) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              visible[i].label,
                              style: const TextStyle(
                                color: AppTheme.onSurfaceMuted,
                                fontSize: 9,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 52,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox.shrink();
                          return Text(
                            _shortNumber(value),
                            style: const TextStyle(
                              color: AppTheme.onSurfaceMuted,
                              fontSize: 9,
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AppTheme.divider,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(visible.length, (i) {
                    final bar = visible[i];
                    final isTouched = i == _touchedGroupIndex;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: bar.income,
                          color: isTouched
                              ? AppTheme.income
                              : AppTheme.income.withAlpha(179),
                          width: 8,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3),
                          ),
                        ),
                        BarChartRodData(
                          toY: bar.expenses,
                          color: isTouched
                              ? AppTheme.expense
                              : AppTheme.expense.withAlpha(179),
                          width: 8,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3),
                          ),
                        ),
                      ],
                      showingTooltipIndicators: isTouched ? [0, 1] : [],
                    );
                  }),
                ),
              ),
            ),
            // Net savings line overlay as a simple separate line chart
            const SizedBox(height: 8),
            _NetLineChart(bars: visible, maxY: maxY),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
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
        const SizedBox(width: 4),
        Text(label,
            style:
                const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 11)),
      ],
    );
  }

  Widget _legendLine(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 2,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(label,
            style:
                const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 11)),
      ],
    );
  }

  String _shortNumber(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
    return value.toStringAsFixed(0);
  }
}

/// A compact line chart showing net savings per month.
class _NetLineChart extends StatelessWidget {
  final List<MonthlyBar> bars;
  final double maxY;

  const _NetLineChart({required this.bars, required this.maxY});

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) return const SizedBox.shrink();

    final nets = bars.map((b) => b.net).toList();
    final minNet = nets.reduce((a, b) => a < b ? a : b);
    final maxNet = nets.reduce((a, b) => a > b ? a : b);
    final absMax = (minNet.abs() > maxNet ? minNet.abs() : maxNet) * 1.3;
    if (absMax == 0) return const SizedBox.shrink();

    final spots = List.generate(
      bars.length,
      (i) => FlSpot(i.toDouble(), bars[i].net),
    );

    return SizedBox(
      height: 56,
      child: LineChart(
        LineChartData(
          minY: -absMax,
          maxY: absMax,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppTheme.savings,
              barWidth: 2,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                  radius: 3,
                  color: spot.y >= 0 ? AppTheme.savings : AppTheme.expense,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.savings.withAlpha(26),
                cutOffY: 0,
                applyCutOffY: true,
              ),
              aboveBarData: BarAreaData(
                show: true,
                color: AppTheme.expense.withAlpha(26),
                cutOffY: 0,
                applyCutOffY: true,
              ),
            ),
          ],
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppTheme.surfaceVariant,
              getTooltipItems: (spots) => spots.map((s) {
                final formatter = NumberFormat('#,##0', 'da_DK');
                return LineTooltipItem(
                  'Net: ${formatter.format(s.y)} DKK',
                  TextStyle(
                    color: s.y >= 0 ? AppTheme.savings : AppTheme.expense,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: 0,
                color: AppTheme.divider,
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
