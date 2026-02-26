import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';
import '../services/dashboard_cache_service.dart';
import '../services/dashboard_service.dart';
import '../theme/app_theme.dart';
import '../widgets/hero_summary_card.dart';
import '../widgets/category_chart.dart';
import '../widgets/monthly_bar_chart.dart';
import '../widgets/period_selector.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiService();
  final _dashboardService = DashboardService();

  DateFilter _filter =
      const DateFilter.fromPreset(TimePeriod.thisMonth);
  bool _loading = false;
  String? _error;
  List<Transaction> _transactions = [];
  DashboardData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final filterKey = DashboardCacheService.sanitiseKey(
          _filter.dateFilter ?? 'all');
      final cache = DashboardCacheService.instance;

      // Try cache first (unless force refresh)
      if (!forceRefresh) {
        final cached = cache.load(filterKey);
        if (cached != null) {
          if (mounted) {
            setState(() {
              _data = cached;
              _loading = false;
            });
          }
          return;
        }
      }

      // Cache miss or force refresh -- fetch from API
      final transactions = await _api.fetchAllTransactions(
        dateFilter: _filter.dateFilter,
      );
      final data = _dashboardService.aggregate(transactions);

      // Save to cache
      unawaited(cache.save(filterKey, data));

      if (mounted) {
        setState(() {
          _transactions = transactions;
          _data = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  void _onFilterChanged(DateFilter f) {
    setState(() => _filter = f);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loading ? null : () => _load(forceRefresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          PeriodSelector(
            selected: _filter,
            onChanged: _onFilterChanged,
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading…',
                style: TextStyle(color: AppTheme.onSurfaceMuted)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 48, color: AppTheme.onSurfaceMuted),
              const SizedBox(height: 16),
              Text('Could not load data',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(_error!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.expense),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
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

    if (_data == null || _data!.kpi.transactionCount == 0) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bar_chart_rounded,
                size: 48, color: AppTheme.onSurfaceMuted),
            const SizedBox(height: 16),
            Text('No transactions for this period',
                style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );
    }

    final data = _data!;

    return RefreshIndicator(
      onRefresh: () => _load(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SizedBox(height: 12),

          // ── Hero card ───────────────────────────────────────────────────
          HeroSummaryCard(
            kpi: data.kpi,
            periodLabel: _filter.label,
          ),
          const SizedBox(height: 12),

          // ── KPI strip ───────────────────────────────────────────────────
          _KpiStrip(kpi: data.kpi, months: data.monthlyBars.length),
          const SizedBox(height: 16),

          // ── Category chart ──────────────────────────────────────────────
          if (data.topCategories.isNotEmpty) ...[
            CategoryChart(categories: data.topCategories),
            const SizedBox(height: 16),
          ],

          // ── Monthly trend ───────────────────────────────────────────────
          if (data.monthlyBars.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text('Monthly Income vs Expenses',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            MonthlyBarChart(bars: data.monthlyBars),
            const SizedBox(height: 16),
          ],

          // ── Top expenses ────────────────────────────────────────────────
          _TopExpenses(transactions: _transactions),
        ],
      ),
    );
  }
}

// ── KPI horizontal scroll strip ──────────────────────────────────────────────

class _KpiStrip extends StatelessWidget {
  final KpiData kpi;
  final int months;

  const _KpiStrip({required this.kpi, required this.months});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'da_DK');
    final avgMonthly =
        months > 0 ? kpi.totalExpenses / months : kpi.totalExpenses;

    final cards = [
      _KpiMini(
        label: 'Savings Rate',
        value: '${kpi.savingsRate.toStringAsFixed(1)}%',
        icon: Icons.percent_rounded,
        color: AppTheme.amber,
      ),
      _KpiMini(
        label: 'Avg / Month',
        value: '${fmt.format(avgMonthly)} DKK',
        icon: Icons.calendar_month_rounded,
        color: AppTheme.savings,
      ),
      _KpiMini(
        label: 'Transactions',
        value: '${kpi.transactionCount}',
        icon: Icons.receipt_long_rounded,
        color: AppTheme.onSurfaceMuted,
      ),
    ];

    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => cards[i],
      ),
    );
  }
}

class _KpiMini extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiMini({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 145,
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.onSurfaceMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top 5 Expenses ────────────────────────────────────────────────────────────

class _TopExpenses extends StatelessWidget {
  final List<Transaction> transactions;

  const _TopExpenses({required this.transactions});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'da_DK');

    final expenses = transactions
        .where((t) => !t.isIncome)
        .toList()
      ..sort((a, b) => a.amount.compareTo(b.amount)); // most negative first

    final top5 = expenses.take(5).toList();
    if (top5.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Expenses',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Column(
              children: top5.asMap().entries.map((e) {
                final i = e.key;
                final tx = e.value;
                final color =
                    CategoryColors.forCategory(tx.category);
                final isLast = i == top5.length - 1;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color.withAlpha(26),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tx.name,
                                  style: const TextStyle(
                                    color: AppTheme.onSurface,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  tx.category,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${fmt.format(tx.amount.abs())} DKK',
                            style: const TextStyle(
                              color: AppTheme.expense,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      const Divider(height: 1, indent: 56, color: AppTheme.divider),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
