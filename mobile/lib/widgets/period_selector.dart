import 'package:flutter/material.dart';
import '../services/dashboard_service.dart';
import '../theme/app_theme.dart';

class PeriodSelector extends StatelessWidget {
  final DateFilter selected;
  final ValueChanged<DateFilter> onChanged;

  const PeriodSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  // ── Month range picker bottom sheet ──────────────────────────────────────

  Future<void> _openCustomPicker(BuildContext context) async {
    final now = DateTime.now();
    // Build list of (year, month) going back 5 years, newest first.
    final options = <DateTime>[];
    for (int y = now.year; y >= now.year - 5; y--) {
      final maxM = y == now.year ? now.month : 12;
      for (int m = maxM; m >= 1; m--) {
        options.add(DateTime(y, m));
      }
    }

    // Default selection: current month for both from/to (or restore custom).
    DateTime fromVal =
        selected.isCustom ? selected.customFrom! : DateTime(now.year, now.month);
    DateTime toVal =
        selected.isCustom ? selected.customTo! : DateTime(now.year, now.month);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceVariant,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Custom Range',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 20),

                // From row
                _MonthRowPicker(
                  label: 'From',
                  value: fromVal,
                  options: options,
                  onChanged: (d) {
                    setLocal(() {
                      fromVal = d;
                      // Clamp: to must be >= from.
                      if (toVal.isBefore(fromVal)) toVal = fromVal;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // To row
                _MonthRowPicker(
                  label: 'To',
                  value: toVal,
                  options:
                      options.where((d) => !d.isBefore(fromVal)).toList(),
                  onChanged: (d) => setLocal(() => toVal = d),
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onChanged(DateFilter.custom(fromVal, toVal));
                    },
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          // Preset chips
          ...TimePeriod.values.map((period) {
            final isSelected =
                !selected.isCustom && selected.preset == period;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(period.label),
                selected: isSelected,
                onSelected: (_) =>
                    onChanged(DateFilter.fromPreset(period)),
                selectedColor: AppTheme.primary,
                backgroundColor: AppTheme.surfaceVariant,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.onSurface,
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                side: BorderSide(
                  color: isSelected ? AppTheme.primary : AppTheme.divider,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            );
          }),

          // Custom range chip
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(
                selected.isCustom ? selected.label : 'Custom…',
              ),
              selected: selected.isCustom,
              onSelected: (_) => _openCustomPicker(context),
              selectedColor: AppTheme.savings,
              backgroundColor: AppTheme.surfaceVariant,
              avatar: const Icon(Icons.date_range_rounded, size: 14),
              labelStyle: TextStyle(
                color: selected.isCustom ? Colors.white : AppTheme.onSurface,
                fontSize: 12,
                fontWeight: selected.isCustom
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
              side: BorderSide(
                color: selected.isCustom
                    ? AppTheme.savings
                    : AppTheme.divider,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Month / year dropdown row
// ---------------------------------------------------------------------------

class _MonthRowPicker extends StatelessWidget {
  const _MonthRowPicker({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final DateTime value;
  final List<DateTime> options;
  final ValueChanged<DateTime> onChanged;

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.onSurfaceMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.divider),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Month dropdown
              DropdownButtonHideUnderline(
                child: DropdownButton<DateTime>(
                  value: options.contains(value)
                      ? value
                      : options.firstOrNull,
                  dropdownColor: AppTheme.surfaceVariant,
                  style: const TextStyle(
                      color: AppTheme.onSurface, fontSize: 15),
                  items: options
                      .where((d) => d.year == value.year)
                      .map((d) => DropdownMenuItem(
                            value: d,
                            child: Text(_monthNames[d.month - 1]),
                          ))
                      .toList(),
                  onChanged: (d) {
                    if (d != null) onChanged(d);
                  },
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '/',
                style: TextStyle(color: AppTheme.onSurfaceMuted),
              ),
              const SizedBox(width: 8),
              // Year dropdown
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: value.year,
                  dropdownColor: AppTheme.surfaceVariant,
                  style: const TextStyle(
                      color: AppTheme.onSurface, fontSize: 15),
                  items: (options
                          .map((d) => d.year)
                          .toSet()
                          .toList()
                        ..sort((a, b) => b.compareTo(a)))
                      .map((y) => DropdownMenuItem(
                            value: y,
                            child: Text('$y'),
                          ))
                      .toList(),
                  onChanged: (y) {
                    if (y == null) return;
                    // Keep same month if available in new year, else clamp.
                    final sameMonth = DateTime(y, value.month);
                    final available = options
                        .where((d) => d.year == y)
                        .toList();
                    if (available.contains(sameMonth)) {
                      onChanged(sameMonth);
                    } else {
                      onChanged(available.first);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
