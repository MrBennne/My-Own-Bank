import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/category_bottom_sheet.dart';

class ReviewRulesScreen extends StatefulWidget {
  const ReviewRulesScreen({super.key});

  @override
  State<ReviewRulesScreen> createState() => _ReviewRulesScreenState();
}

class _ReviewRulesScreenState extends State<ReviewRulesScreen> {
  final _api = ApiService();

  List<Transaction> _pending = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _pending = await _api.fetchPendingReviews();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _dismiss(Transaction tx) async {
    try {
      await _api.markReviewed(tx.id);
      if (mounted) {
        setState(() => _pending.removeWhere((t) => t.id == tx.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dismissed'),
            duration: Duration(seconds: 1),
            backgroundColor: AppTheme.onSurfaceMuted,
          ),
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

  Future<void> _recategorize(Transaction tx) async {
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
      try {
        await _api.updateTransactionCategory(
          tx.id,
          result.category,
          subcategory: result.subcategory,
          type: result.type,
        );
        await _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed: $e'), backgroundColor: AppTheme.expense),
          );
        }
      }
    }
  }

  Future<void> _dismissAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceVariant,
        title: const Text('Dismiss all?'),
        content: Text('Mark all ${_pending.length} pending items as reviewed. '
            'They will no longer appear here.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Dismiss all')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    for (final tx in List.of(_pending)) {
      try {
        await _api.markReviewed(tx.id);
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _pending.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All dismissed'),
          backgroundColor: AppTheme.income,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_pending.isEmpty
            ? 'Review Rules'
            : 'Review Rules (${_pending.length})'),
        actions: [
          if (_pending.isNotEmpty)
            TextButton(
              onPressed: _dismissAll,
              child: const Text('Dismiss all',
                  style: TextStyle(color: AppTheme.onSurfaceMuted)),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_pending.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded,
                size: 64, color: AppTheme.income.withAlpha(180)),
            const SizedBox(height: 16),
            const Text('All caught up!',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface)),
            const SizedBox(height: 8),
            const Text(
              'No transactions waiting for review.',
              style: TextStyle(color: AppTheme.onSurfaceMuted),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildInfoBanner(),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: _pending.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (ctx, i) => _ReviewTile(
              transaction: _pending[i],
              onDismiss: () => _dismiss(_pending[i]),
              onRecategorize: () => _recategorize(_pending[i]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primary.withAlpha(60)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppTheme.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'These transactions were uncategorized when imported but have '
              'since been manually assigned a category. '
              'Dismiss to clear, or change the category.',
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.onSurface.withAlpha(200),
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onDismiss;
  final VoidCallback onRecategorize;

  const _ReviewTile({
    required this.transaction,
    required this.onDismiss,
    required this.onRecategorize,
  });

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final catColor = CategoryColors.forCategory(tx.category);
    final amountColor = tx.isTransfer
        ? AppTheme.savings
        : tx.isIncome
            ? AppTheme.income
            : AppTheme.expense;
    final fmt = NumberFormat('#,##0.00', 'da_DK');

    String dateStr = tx.date;
    try {
      if (dateStr.length >= 10) {
        dateStr = DateFormat('dd MMM yyyy')
            .format(DateTime.parse(dateStr.substring(0, 10)));
      }
    } catch (_) {}

    final displayCat = tx.subcategory.isNotEmpty ? tx.subcategory : tx.category;

    return Dismissible(
      key: ValueKey(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppTheme.expense.withAlpha(40),
        child: const Icon(Icons.check_rounded, color: AppTheme.expense),
      ),
      onDismissed: (_) => onDismiss(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: catColor.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: catColor.withAlpha(80)),
              ),
              child: Icon(Icons.label_rounded, color: catColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: AppTheme.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(dateStr,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.onSurfaceMuted)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onRecategorize,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: catColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: catColor.withAlpha(80)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(displayCat,
                              style: TextStyle(
                                  color: catColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(width: 4),
                          Icon(Icons.edit_rounded, size: 10, color: catColor),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${tx.isIncome ? '+' : '-'}${fmt.format(tx.amount.abs())}',
                  style: TextStyle(
                      color: amountColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onDismiss,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.income.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.income.withAlpha(60)),
                    ),
                    child: const Text('Done',
                        style: TextStyle(
                            color: AppTheme.income,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
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
