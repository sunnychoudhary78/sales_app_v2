import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../providers/home_dashboard_provider.dart';

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

  static bool isCurrentMonthSelected(DateTime? selected) {
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
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) {
        ref.read(homeSelectedMonthProvider.notifier).setMonth(value);
        ref.invalidate(homeDashboardProvider);
      },
      itemBuilder: (ctx) => [
        PopupMenuItem<DateTime>(
          value: currentMonthAnchor,
          child: Text(
            'This month (to date)',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: isCurrentMonthSelected(selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ),
        const PopupMenuDivider(),
        ...months.map((m) {
          final isCurrent = m.year == now.year && m.month == now.month;
          final isSelected = isCurrent
              ? isCurrentMonthSelected(selected)
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
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          );
        }),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_rounded,
              size: 14,
              color: scheme.primary,
            ),
            const SizedBox(width: 5),
            Text(
              labelForMonth(selected),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}