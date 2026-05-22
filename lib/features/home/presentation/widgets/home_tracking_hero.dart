import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../data/models/home_models.dart';

/// Brand-style accents for the distance hero (stable across theme seeds).
abstract final class _RouteAccent {
  static const Color teal = Color(0xFF0D9488);
  static const Color cyan = Color(0xFF0891B2);
  static const Color deep = Color(0xFF0F766E);
  static const Color live = Color(0xFF059669);
  static const Color visits = Color(0xFF7C3AED);
  static const Color fresh = Color(0xFFD97706);
  static const Color follow = Color(0xFFDB2777);
}

/// Flagship home block: month context + animated total km (real [totals.distance_km] from API).
class HomeTrackingDashboardHero extends StatelessWidget {
  const HomeTrackingDashboardHero({
    super.key,
    required this.performance,
    required this.displayName,
  });

  final HomePerformanceData performance;
  final String displayName;

  static String _formatKmValue(double v) {
    if (v >= 100) return v.toStringAsFixed(0);
    if (v >= 10) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }

  static String _periodLabel(String fromIso, String toIso) {
    final a = DateTime.tryParse(fromIso)?.toLocal();
    final b = DateTime.tryParse(toIso)?.toLocal();
    if (a == null || b == null) return 'This month';
    if (a.year == b.year && a.month == b.month) {
      return '${DateFormat('d').format(a)} – ${DateFormat('d MMM yyyy').format(b)}';
    }
    return '${DateFormat('d MMM').format(a)} – ${DateFormat('d MMM yyyy').format(b)}';
  }

  static String _firstName(String full) {
    final t = full.trim();
    if (t.isEmpty) return '';
    return t.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = performance.totals;
    final km = t.distanceKm;
    final animKey = '${performance.rangeFromIso}|${performance.rangeToIso}|${km.toStringAsFixed(4)}';

    final border = scheme.outlineVariant.withValues(alpha: 0.38);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: _RouteAccent.teal.withValues(alpha: 0.14),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top band: context (editorial / standard product header)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow.withValues(alpha: 0.65),
                  border: Border(bottom: BorderSide(color: border)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DISTANCE',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.35,
                              color: _RouteAccent.deep,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            displayName.trim().isEmpty
                                ? 'Your overview'
                                : 'Hi, ${_firstName(displayName)}',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.35,
                              height: 1.2,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _periodLabel(performance.rangeFromIso, performance.rangeToIso),
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: _RouteAccent.live.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _RouteAccent.live.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded, size: 16, color: _RouteAccent.live),
                          const SizedBox(width: 5),
                          Text(
                            'Live',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _RouteAccent.live,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Metric well — inset “instrument” panel + count-up (unchanged animation)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _RouteAccent.teal.withValues(alpha: 0.07),
                        _RouteAccent.cyan.withValues(alpha: 0.05),
                        scheme.surfaceContainerLow.withValues(alpha: 0.92),
                      ],
                    ),
                    border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.42)),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(19),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                _RouteAccent.teal,
                                _RouteAccent.cyan,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 22, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total this period',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _RouteAccent.deep.withValues(alpha: 0.85),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TweenAnimationBuilder<double>(
                              key: ValueKey<String>(animKey),
                              tween: Tween(begin: 0, end: km),
                              duration: const Duration(milliseconds: 1600),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, _) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: ShaderMask(
                                          blendMode: BlendMode.srcIn,
                                          shaderCallback: (bounds) {
                                            return LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                _RouteAccent.deep,
                                                _RouteAccent.teal,
                                                _RouteAccent.cyan,
                                              ],
                                            ).createShader(
                                              Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                                            );
                                          },
                                          child: Text(
                                            _formatKmValue(value),
                                            style: GoogleFonts.inter(
                                              fontSize: 52,
                                              fontWeight: FontWeight.w900,
                                              height: 1.0,
                                              letterSpacing: -2.2,
                                              color: Colors.white,
                                              fontFeatures: const [
                                                FontFeature.tabularFigures(),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        'km',
                                        style: GoogleFonts.inter(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: _RouteAccent.deep.withValues(alpha: 0.55),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'GPS sessions and synced visits in the date range above.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // KPI strip — equal cells, standard dashboard footer
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _RouteAccent.teal.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _RouteAccent.teal.withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    children: [
                      _StatCell(
                        icon: Icons.place_rounded,
                        value: '${t.visits}',
                        label: 'Visits',
                        scheme: scheme,
                        iconColor: _RouteAccent.visits,
                        showLeftDivider: false,
                      ),
                      _StatCell(
                        icon: Icons.flag_rounded,
                        value: '${t.newVisits}',
                        label: 'New',
                        scheme: scheme,
                        iconColor: _RouteAccent.fresh,
                        showLeftDivider: true,
                      ),
                      _StatCell(
                        icon: Icons.reply_rounded,
                        value: '${t.followupVisits}',
                        label: 'F/U',
                        scheme: scheme,
                        iconColor: _RouteAccent.follow,
                        showLeftDivider: true,
                      ),
                      _StatCell(
                        icon: Icons.timer_outlined,
                        value: '${t.productiveHours.toStringAsFixed(1)}h',
                        label: 'Field',
                        scheme: scheme,
                        iconColor: _RouteAccent.teal,
                        showLeftDivider: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.icon,
    required this.value,
    required this.label,
    required this.scheme,
    required this.iconColor,
    required this.showLeftDivider,
  });

  final IconData icon;
  final String value;
  final String label;
  final ColorScheme scheme;
  final Color iconColor;
  final bool showLeftDivider;

  @override
  Widget build(BuildContext context) {
    final border = Color.lerp(_RouteAccent.teal, scheme.outlineVariant, 0.65)!
        .withValues(alpha: 0.45);
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: showLeftDivider
              ? Border(left: BorderSide(color: border))
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(height: 6),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.35,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
