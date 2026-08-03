import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:sales_tracking_v2/features/home/presentation/widgets/home_month_picker.dart';

import '../../data/models/home_models.dart';

/// Accent colors adapted for both Light and Dark themes.
abstract final class _RouteAccent {
  static const Color teal = Color(0xFF0D9488);
  static const Color cyan = Color(0xFF0891B2);
  static const Color deep = Color(0xFF0F766E);
  static const Color live = Color(0xFF10B981);
  static const Color visits = Color(0xFF8B5CF6);
  static const Color fresh = Color(0xFFF59E0B);
  static const Color follow = Color(0xFFEC4899);
}

class HomeTrackingDashboardHero extends StatelessWidget {
  const HomeTrackingDashboardHero({
    super.key,
    required this.performance,
    required this.displayName,
    this.showLiveBadge = true,
    this.displayRangeStart,
    this.displayRangeEnd,
  });

  final HomePerformanceData performance;
  final String displayName;
  final bool showLiveBadge;
  final DateTime? displayRangeStart;
  final DateTime? displayRangeEnd;

  static String _formatKmValue(double v) {
    if (v >= 100) return v.toStringAsFixed(0);
    if (v >= 10) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }

  static DateTime? _calendarDateFromIso(String iso) {
    final s = iso.trim();
    if (s.isEmpty) return null;
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
    if (match != null) {
      final y = int.tryParse(match.group(1)!);
      final m = int.tryParse(match.group(2)!);
      final d = int.tryParse(match.group(3)!);
      if (y != null && m != null && d != null) {
        return DateTime(y, m, d);
      }
    }
    return DateTime.tryParse(s)?.toLocal();
  }

  static String _periodLabelFromLocal(DateTime start, DateTime end) {
    final a = DateTime(start.year, start.month, start.day);
    final b = DateTime(end.year, end.month, end.day);
    if (a.year == b.year && a.month == b.month) {
      return '${DateFormat('d').format(a)} – ${DateFormat('d MMM yyyy').format(b)}';
    }
    return '${DateFormat('d MMM').format(a)} – ${DateFormat('d MMM yyyy').format(b)}';
  }

  static String _periodLabel(String fromIso, String toIso) {
    final a = _calendarDateFromIso(fromIso);
    final b = _calendarDateFromIso(toIso);
    if (a == null || b == null) return 'This month';
    return _periodLabelFromLocal(a, b);
  }

  String _resolvePeriodLabel() {
    final start = displayRangeStart;
    final end = displayRangeEnd;
    if (start != null && end != null) {
      return _periodLabelFromLocal(start, end);
    }
    return _periodLabel(performance.rangeFromIso, performance.rangeToIso);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final t = performance.totals;
    final km = t.distanceKm;
    final animKey =
        '${performance.rangeFromIso}|${performance.rangeToIso}|${km.toStringAsFixed(4)}';

    final border = scheme.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.4);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Main Well Container (Circle + Description + Top Right Month Picker)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: scheme.surfaceContainerLow,
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Animated KM Circle (Filled Color Upgrade)
                        TweenAnimationBuilder<double>(
                          key: ValueKey(animKey),
                          tween: Tween(begin: 0, end: km),
                          duration: const Duration(milliseconds: 1600),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) {
                            return Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                // Gradient Fill for premium modern look
                                // gradient: RadialGradient(
                                //   colors: [
                                //     _RouteAccent.teal.withValues(alpha: isDark ? 0.25 : 0.18),
                                //     _RouteAccent.teal.withValues(alpha: isDark ? 0.10 : 0.06),
                                //   ],
                                //   stops: const [0.5, 1.0],
                                // ),
                                border: Border.all(
                                  color: _RouteAccent.deep.withValues(alpha: 0.50),
                                  width: 5,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6.0,
                                      ),
                                      child: Text(
                                        _formatKmValue(value),
                                        style: GoogleFonts.inter(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.5,
                                          color: scheme.onSurface,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    "KM",
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: _RouteAccent.teal,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        const SizedBox(width: 16),

                        // Live Badge Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Total Distance",
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Text(
                                  "GPS sessions & synced visits recorded for this period.",
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    height: 1.3,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // HomeMonthPicker Positioned at Top Right inside Container
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: HomeMonthPicker(),
                  ),
                ],
              ),
            ),

            // Grid View with Stats
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.3,
                children: [
                  _DashboardTile(
                    title: "Visits",
                    value: "${t.visits}",
                    icon: Icons.location_on_rounded,
                    color: _RouteAccent.visits,
                  ),
                  _DashboardTile(
                    title: "New",
                    value: "${t.newVisits}",
                    icon: Icons.flag_rounded,
                    color: _RouteAccent.fresh,
                  ),
                  _DashboardTile(
                    title: "Follow Up",
                    value: "${t.followupVisits}",
                    icon: Icons.reply_rounded,
                    color: _RouteAccent.follow,
                  ),
                  _DashboardTile(
                    title: "Field Hours",
                    value: "${t.productiveHours.toStringAsFixed(1)}h",
                    icon: Icons.timer_rounded,
                    color: _RouteAccent.teal,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  const _DashboardTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}