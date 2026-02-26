class Transaction {
  final String id;
  final String date;
  final String name;
  final double amount;
  final String currency;
  final String category;
  final String subcategory;
  final String type;
  final bool originallyUncategorized;
  final String account;

  const Transaction({
    required this.id,
    required this.date,
    required this.name,
    required this.amount,
    required this.currency,
    required this.category,
    required this.type,
    required this.originallyUncategorized,
    this.subcategory = '',
    this.account = 'Lønkonto',
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String? ?? '',
      date: json['date'] as String? ?? '',
      name: json['name'] as String? ?? '',
      amount: _parseDouble(json['amount']),
      currency: json['currency'] as String? ?? 'DKK',
      category: json['category'] as String? ?? 'Uncategorized',
      subcategory: json['subcategory'] as String? ?? '',
      type: json['type'] as String? ?? 'Expense',
      originallyUncategorized:
          json['originally_uncategorized'] as bool? ?? false,
      account: json['account'] as String? ?? 'Lønkonto',
    );
  }

  Transaction copyWith({
    String? category,
    String? subcategory,
    String? type,
  }) {
    return Transaction(
      id: id,
      date: date,
      name: name,
      amount: amount,
      currency: currency,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      type: type ?? this.type,
      originallyUncategorized: originallyUncategorized,
      account: account,
    );
  }

  bool get isIncome => type == 'Income';
  bool get isTransfer => type == 'Transfer';

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}

class PaginatedTransactions {
  final List<Transaction> items;
  final int totalItems;
  final int totalPages;
  final int page;

  const PaginatedTransactions({
    required this.items,
    required this.totalItems,
    required this.totalPages,
    required this.page,
  });

  factory PaginatedTransactions.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return PaginatedTransactions(
      items: rawItems
          .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalItems: json['totalItems'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 1,
      page: json['page'] as int? ?? 1,
    );
  }
}
