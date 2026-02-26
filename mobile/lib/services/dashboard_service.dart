import '../models/transaction.dart';
import 'category_service.dart';

enum TimePeriod {
  allTime,
  thisYear,
  lastYear,
  last6Months,
  last3Months,
  lastMonth,
  thisMonth,
}

extension TimePeriodLabel on TimePeriod {
  String get label {
    switch (this) {
      case TimePeriod.allTime:
        return 'All Time';
      case TimePeriod.thisYear:
        return 'This Year';
      case TimePeriod.lastYear:
        return 'Last Year';
      case TimePeriod.last6Months:
        return 'Last 6M';
      case TimePeriod.last3Months:
        return 'Last 3M';
      case TimePeriod.lastMonth:
        return 'Last Month';
      case TimePeriod.thisMonth:
        return 'This Month';
    }
  }

  /// Returns a PocketBase filter string for the date field, or null for allTime.
  String? get dateFilter {
    final now = DateTime.now();
    DateTime? from;
    DateTime? to;

    switch (this) {
      case TimePeriod.allTime:
        return null;
      case TimePeriod.thisMonth:
        from = DateTime(now.year, now.month, 1);
        to = DateTime(now.year, now.month + 1, 1)
            .subtract(const Duration(days: 1));
      case TimePeriod.lastMonth:
        final first = DateTime(now.year, now.month - 1, 1);
        from = first;
        to = DateTime(now.year, now.month, 1).subtract(const Duration(days: 1));
      case TimePeriod.last3Months:
        from = DateTime(now.year, now.month - 2, 1);
        to = now;
      case TimePeriod.last6Months:
        from = DateTime(now.year, now.month - 5, 1);
        to = now;
      case TimePeriod.thisYear:
        from = DateTime(now.year, 1, 1);
        to = DateTime(now.year, 12, 31);
      case TimePeriod.lastYear:
        from = DateTime(now.year - 1, 1, 1);
        to = DateTime(now.year - 1, 12, 31);
    }

    final fromStr = _fmt(from);
    final toStr = _fmt(to ?? now); // ignore: dead_null_aware_expression
    return 'date>="$fromStr"&&date<="$toStr"';
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class KpiData {
  final double totalIncome;
  final double totalExpenses;
  final double netSavings;
  final double savingsRate;
  final int transactionCount;

  const KpiData({
    required this.totalIncome,
    required this.totalExpenses,
    required this.netSavings,
    required this.savingsRate,
    required this.transactionCount,
  });

  Map<String, dynamic> toJson() => {
    'totalIncome': totalIncome,
    'totalExpenses': totalExpenses,
    'netSavings': netSavings,
    'savingsRate': savingsRate,
    'transactionCount': transactionCount,
  };

  factory KpiData.fromJson(Map<String, dynamic> json) => KpiData(
    totalIncome: (json['totalIncome'] as num).toDouble(),
    totalExpenses: (json['totalExpenses'] as num).toDouble(),
    netSavings: (json['netSavings'] as num).toDouble(),
    savingsRate: (json['savingsRate'] as num).toDouble(),
    transactionCount: (json['transactionCount'] as num).toInt(),
  );
}

class CategoryAmount {
  final String category;
  final double amount;

  const CategoryAmount({required this.category, required this.amount});

  Map<String, dynamic> toJson() => {'category': category, 'amount': amount};

  factory CategoryAmount.fromJson(Map<String, dynamic> json) => CategoryAmount(
    category: json['category'] as String,
    amount: (json['amount'] as num).toDouble(),
  );
}

class MonthlyBar {
  final String label; // e.g. "Jan 24"
  final double income;
  final double expenses;
  double get net => income - expenses;

  const MonthlyBar({
    required this.label,
    required this.income,
    required this.expenses,
  });

  Map<String, dynamic> toJson() => {'label': label, 'income': income, 'expenses': expenses};

  factory MonthlyBar.fromJson(Map<String, dynamic> json) => MonthlyBar(
    label: json['label'] as String,
    income: (json['income'] as num).toDouble(),
    expenses: (json['expenses'] as num).toDouble(),
  );
}

class DashboardData {
  final KpiData kpi;
  final List<CategoryAmount> topCategories;
  final List<MonthlyBar> monthlyBars;

  const DashboardData({
    required this.kpi,
    required this.topCategories,
    required this.monthlyBars,
  });

  Map<String, dynamic> toJson() => {
    'kpi': kpi.toJson(),
    'topCategories': topCategories.map((c) => c.toJson()).toList(),
    'monthlyBars': monthlyBars.map((b) => b.toJson()).toList(),
  };

  factory DashboardData.fromJson(Map<String, dynamic> json) => DashboardData(
    kpi: KpiData.fromJson(json['kpi'] as Map<String, dynamic>),
    topCategories: (json['topCategories'] as List)
        .map((e) => CategoryAmount.fromJson(e as Map<String, dynamic>))
        .toList(),
    monthlyBars: (json['monthlyBars'] as List)
        .map((e) => MonthlyBar.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

// ---------------------------------------------------------------------------
// DateFilter — wraps either a preset TimePeriod or a custom month range.
// ---------------------------------------------------------------------------

class DateFilter {
  final TimePeriod? preset;
  final DateTime? customFrom; // first day of the start month
  final DateTime? customTo;   // first day of the end month

  const DateFilter.fromPreset(TimePeriod p)
      : preset = p,
        customFrom = null,
        customTo = null;

  const DateFilter.custom(DateTime from, DateTime to)
      : preset = null,
        customFrom = from,
        customTo = to;

  bool get isCustom => preset == null;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String get label {
    if (preset != null) return preset!.label;
    final f = customFrom!;
    final t = customTo!;
    final fs = '${_months[f.month - 1]} ${f.year.toString().substring(2)}';
    final ts = '${_months[t.month - 1]} ${t.year.toString().substring(2)}';
    return fs == ts ? fs : '$fs – $ts';
  }

  String? get dateFilter {
    if (preset != null) return preset!.dateFilter;
    final f = customFrom!;
    final t = customTo!;
    // End on the last day of the customTo month.
    final lastDay =
        DateTime(t.year, t.month + 1, 1).subtract(const Duration(days: 1));
    return 'date>="${_fmt(f)}"&&date<="${_fmt(lastDay)}"';
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class DashboardService {
  DashboardData aggregate(List<Transaction> transactions) {
    double totalIncome = 0;
    double totalExpenses = 0;

    // Category map (expenses only for pie chart)
    final categoryMap = <String, double>{};

    // Monthly map
    final monthlyMap = <String, MonthlyBar>{};

    for (final t in transactions) {
      // Exclude transfers from KPI calculations — they cancel out between accounts.
      if (t.isTransfer ||
          CategoryService.instance.isTransferCategory(t.category)) {
        continue;
      }

      final absAmount = t.amount.abs();

      if (t.isIncome) {
        totalIncome += absAmount;
      } else {
        totalExpenses += absAmount;
        categoryMap[t.category] =
            (categoryMap[t.category] ?? 0) + absAmount;
      }

      // Monthly grouping
      final key = _monthKey(t.date);
      if (key.isNotEmpty) {
        final existing = monthlyMap[key];
        if (existing == null) {
          monthlyMap[key] = MonthlyBar(
            label: key,
            income: t.isIncome ? absAmount : 0,
            expenses: t.isIncome ? 0 : absAmount,
          );
        } else {
          monthlyMap[key] = MonthlyBar(
            label: key,
            income: existing.income + (t.isIncome ? absAmount : 0),
            expenses: existing.expenses + (t.isIncome ? 0 : absAmount),
          );
        }
      }
    }

    final netSavings = totalIncome - totalExpenses;
    final savingsRate =
        totalIncome > 0 ? (netSavings / totalIncome * 100) : 0.0;

    // Top 10 categories sorted by amount desc
    final topCategories = categoryMap.entries
        .map((e) => CategoryAmount(category: e.key, amount: e.value))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final top10 = topCategories.take(10).toList();

    // Monthly bars sorted chronologically
    final sortedMonths = monthlyMap.values.toList()
      ..sort((a, b) => a.label.compareTo(b.label));

    return DashboardData(
      kpi: KpiData(
        totalIncome: totalIncome,
        totalExpenses: totalExpenses,
        netSavings: netSavings,
        savingsRate: savingsRate,
        transactionCount: transactions.length,
      ),
      topCategories: top10,
      monthlyBars: sortedMonths,
    );
  }

  /// Parses "YYYY-MM-DD" into "MMM YY" for bar chart label.
  String _monthKey(String date) {
    if (date.length < 7) return '';
    try {
      final parts = date.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      final shortYear = year.toString().substring(2);
      return '${months[month - 1]} $shortYear';
    } catch (_) {
      return '';
    }
  }
}
