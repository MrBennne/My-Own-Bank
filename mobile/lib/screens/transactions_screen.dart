import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';
import '../services/category_service.dart';
import '../theme/app_theme.dart';
import '../widgets/category_bottom_sheet.dart';

class _CategoryChip extends StatelessWidget {
  final String category;
  final String subcategory;
  const _CategoryChip({required this.category, this.subcategory = ''});

  @override
  Widget build(BuildContext context) {
    final color = CategoryColors.forCategory(category);
    final label = subcategory.isNotEmpty ? subcategory : category;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _api = ApiService();
  final _searchController = TextEditingController();

  List<Transaction> _transactions = [];
  List<String> _categories = [''];
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  // Filters & sort
  String _searchQuery = '';
  String _selectedCategory = '';
  String _selectedType = 'All';
  String _sortField = 'date';
  bool _sortAsc = false;

  int _page = 1;
  int _totalPages = 1;
  int _totalItems = 0;

  static const _perPage = 50;
  static const _typeOptions = ['All', 'Income', 'Expense', 'Transfer'];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _fetchTransactions(reset: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadCategories() {
    final names = CategoryService.instance.allCategoryNames;
    setState(() => _categories = ['', ...names]);
  }

  String get _sortParam {
    final prefix = _sortAsc ? '' : '-';
    return '$prefix$_sortField';
  }

  Future<void> _fetchTransactions({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
        _transactions = [];
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final result = await _api.fetchTransactions(
        page: reset ? 1 : _page,
        perPage: _perPage,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        category:
            _selectedCategory.isNotEmpty ? _selectedCategory : null,
        type: _selectedType != 'All' ? _selectedType : null,
        sort: _sortParam,
      );

      if (mounted) {
        setState(() {
          if (reset) {
            _transactions = result.items;
          } else {
            _transactions.addAll(result.items);
          }
          _totalPages = result.totalPages;
          _totalItems = result.totalItems;
          _page = result.page + 1;
          _loading = false;
          _loadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _onSearchChanged(String v) {
    _searchQuery = v;
    _fetchTransactions(reset: true);
  }

  Future<void> _openCategorySheet(Transaction tx) async {
    final result = await showModalBottomSheet<CategorySelection>(
      context: context,
      backgroundColor: AppTheme.surfaceVariant,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => CategoryBottomSheet(
        currentCategory: tx.category,
        currentSubcategory: tx.subcategory,
      ),
    );

    if (result != null && mounted) {
      if (result.category != tx.category ||
          result.subcategory != tx.subcategory) {
        try {
          await _api.updateTransactionCategory(
            tx.id,
            result.category,
            subcategory: result.subcategory,
            type: result.type,
          );
          if (mounted) {
            setState(() {
              final idx =
                  _transactions.indexWhere((t) => t.id == tx.id);
              if (idx != -1) {
                _transactions[idx] = tx.copyWith(
                  category: result.category,
                  subcategory: result.subcategory,
                  type: result.type,
                );
              }
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Category updated to "${result.subcategory.isNotEmpty ? result.subcategory : result.category}"'),
                backgroundColor: AppTheme.income,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to update: $e'),
                backgroundColor: AppTheme.expense,
              ),
            );
          }
        }
      }
    }
  }

  void _toggleSort(String field) {
    setState(() {
      if (_sortField == field) {
        _sortAsc = !_sortAsc;
      } else {
        _sortField = field;
        _sortAsc = false;
      }
    });
    _fetchTransactions(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _totalItems > 0
              ? 'Transactions ($_totalItems)'
              : 'Transactions',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : () => _fetchTransactions(reset: true),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          _buildSortBar(),
          const Divider(height: 1),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search by merchant...',
              prefixIcon: Icon(Icons.search_rounded, size: 20),
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _DropdownFilter(
                  value: _selectedCategory.isEmpty
                      ? 'All'
                      : _selectedCategory,
                  hint: 'All Categories',
                  items: [
                    const DropdownMenuItem(
                        value: 'All', child: Text('All')),
                    ..._categories
                        .where((c) => c.isNotEmpty)
                        .map(
                          (c) => DropdownMenuItem(
                              value: c, child: Text(c)),
                        ),
                  ],
                  onChanged: (v) {
                    setState(() =>
                        _selectedCategory = v == 'All' ? '' : v ?? '');
                    _fetchTransactions(reset: true);
                  },
                ),
              ),
              const SizedBox(width: 8),
              _DropdownFilter(
                value: _selectedType,
                hint: 'Type',
                items: _typeOptions
                    .map(
                      (t) =>
                          DropdownMenuItem(value: t, child: Text(t)),
                    )
                    .toList(),
                onChanged: (v) {
                  setState(() => _selectedType = v ?? 'All');
                  _fetchTransactions(reset: true);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSortBar() {
    const fields = [
      ('date', 'Date'),
      ('amount', 'Amount'),
      ('name', 'Merchant'),
      ('category', 'Category'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: fields.map((f) {
          final isActive = _sortField == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              selected: isActive,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(f.$2),
                  if (isActive) ...[
                    const SizedBox(width: 4),
                    Icon(
                      _sortAsc
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 14,
                      color: AppTheme.primary,
                    ),
                  ],
                ],
              ),
              onSelected: (_) => _toggleSort(f.$1),
              selectedColor: AppTheme.primary.withAlpha(51),
              checkmarkColor: AppTheme.primary,
              labelStyle: TextStyle(
                color:
                    isActive ? AppTheme.primary : AppTheme.onSurface,
                fontSize: 12,
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildList() {
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
              const Icon(Icons.wifi_off_rounded,
                  size: 48, color: AppTheme.onSurfaceMuted),
              const SizedBox(height: 16),
              Text(_error!,
                  style: const TextStyle(color: AppTheme.expense),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _fetchTransactions(reset: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_transactions.isEmpty) {
      return const Center(
        child: Text(
          'No transactions found',
          style: TextStyle(color: AppTheme.onSurfaceMuted),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount:
          _transactions.length + (_page <= _totalPages ? 1 : 0),
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (ctx, i) {
        if (i == _transactions.length) {
          return _loadingMore
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child:
                      Center(child: CircularProgressIndicator()),
                )
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: OutlinedButton(
                    onPressed: () => _fetchTransactions(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(
                          color: AppTheme.primary),
                    ),
                    child: Text(
                      'Load more (${_totalItems - _transactions.length} remaining)',
                    ),
                  ),
                );
        }

        final tx = _transactions[i];
        return _TransactionTile(
          transaction: tx,
          onCategoryTap: () => _openCategorySheet(tx),
        );
      },
    );
  }
}

class _DropdownFilter extends StatelessWidget {
  final String? value;
  final String hint;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  const _DropdownFilter({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint,
              style: const TextStyle(
                  color: AppTheme.onSurfaceMuted, fontSize: 13)),
          items: items,
          onChanged: onChanged,
          dropdownColor: AppTheme.surfaceVariant,
          style: const TextStyle(
              color: AppTheme.onSurface, fontSize: 13),
          isDense: true,
          isExpanded: false,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppTheme.onSurfaceMuted, size: 18),
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onCategoryTap;

  const _TransactionTile({
    required this.transaction,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final Color amountColor;
    final String sign;
    if (tx.isTransfer) {
      amountColor = AppTheme.savings;
      sign = tx.amount >= 0 ? '+' : '-';
    } else if (tx.isIncome) {
      amountColor = AppTheme.income;
      sign = '+';
    } else {
      amountColor = AppTheme.expense;
      sign = '-';
    }
    final absAmount = tx.amount.abs();

    final formatter = NumberFormat('#,##0.00', 'da_DK');
    final amountStr = '${formatter.format(absAmount)} ${tx.currency}';

    String dateStr = tx.date;
    try {
      if (dateStr.length >= 10) {
        final d = DateTime.parse(dateStr.substring(0, 10));
        dateStr = DateFormat('dd MMM').format(d);
      }
    } catch (_) {}

    return InkWell(
      onTap: onCategoryTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: amountColor.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  sign,
                  style: TextStyle(
                    color: amountColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.name,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateStr,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amountStr,
                  style: TextStyle(
                    color: amountColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onCategoryTap,
                  child: _CategoryChip(
                    category: tx.category,
                    subcategory: tx.subcategory,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
