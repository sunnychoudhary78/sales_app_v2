import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/home_dashboard_provider.dart';

/// Header action: pick one of the last 12 calendar months for home metrics.
class HomeMonthPicker extends ConsumerWidget {
  const HomeMonthPicker({super.key});

  static List<DateTime> last12CalendarMonths() {
    final now = DateTime.now();
    return List.generate(12, (i) {
      final d = DateTime(now.year, now.month - i, 1);
      return DateTime(d.year, d.month, 1);
    });
  }

  static String labelForMonth(DateTime? selected) {
    if (selected == null || HomeDashboardNotifier.isCurrentMonthMtd(selected)) {
      return 'This month';
    }
    return DateFormat('MMM yyyy').format(selected);
  }

  static bool _isCurrentMonthSelected(DateTime? selected) {
    return selected == null || HomeDashboardNotifier.isCurrentMonthMtd(selected);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(homeSelectedMonthProvider);
    final scheme = Theme.of(context).colorScheme;
    final months = last12CalendarMonths();
    final now = DateTime.now();
    final currentMonthAnchor = DateTime(now.year, now.month, 1);

    return PopupMenuButton<DateTime>(
      tooltip: 'Select month',
      onSelected: (value) {
        ref.read(homeSelectedMonthProvider.notifier).setMonth(value);
        ref.invalidate(homeDashboardProvider);
      },
      itemBuilder: (ctx) => [
        PopupMenuItem<DateTime>(
          value: currentMonthAnchor,
          child: Text(
            'This month (to date)',
            style: TextStyle(
              fontWeight: _isCurrentMonthSelected(selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ),
        const PopupMenuDivider(),
        ...months.map((m) {
          final isCurrent = m.year == now.year && m.month == now.month;
          final isSelected = isCurrent
              ? _isCurrentMonthSelected(selected)
              : selected != null &&
                  selected.year == m.year &&
                  selected.month == m.month;
          final label = isCurrent
              ? '${DateFormat('MMMM yyyy').format(m)} (to date)'
              : DateFormat('MMMM yyyy').format(m);
          return PopupMenuItem<DateTime>(
            value: m,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          );
        }),
      ],
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_month_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                labelForMonth(selected),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.arrow_drop_down_rounded, size: 20, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
