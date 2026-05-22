import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../data/models/home_models.dart';
import 'home_dashboard_chrome.dart';

/// Field-tracking palette (aligned with distance hero — reads as route / km).
abstract final class _KmTrackAccent {
  static const Color teal = Color(0xFF0D9488);
  static const Color cyan = Color(0xFF0891B2);
  static const Color deep = Color(0xFF0F766E);
  static const Color roll = Color(0xFF059669);
  static const Color ink = Color(0xFF134E4A);
}

/// Bar chart of daily distance (km) — up to 31 days.
class HomeDistanceChartCard extends StatelessWidget {
  const HomeDistanceChartCard({super.key, required this.byDay});

  final List<DailyChartPoint> byDay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final data = HomeDistanceChartCard._trim(byDay, 31);
    if (data.isEmpty) {
      return HomeDistanceChartCard._emptyCard(
        context,
        'No travel in this range yet.',
      );
    }

    final maxY = data.map((e) => e.distanceKm).reduce((a, b) => a > b ? a : b);
    final top = maxY <= 0 ? 5.0 : (maxY * 1.14).clamp(1.0, double.infinity);

    var peakIdx = 0;
    for (var i = 1; i < data.length; i++) {
      if (data[i].distanceKm > data[peakIdx].distanceKm) peakIdx = i;
    }
    final peakKm = data[peakIdx].distanceKm;

    final n = data.length;
    final barW = n > 22 ? 6.0 : (n > 16 ? 8.0 : (n > 10 ? 10.0 : 12.0));
    final barsSpace = n > 22 ? 2.5 : (n > 16 ? 3.5 : 4.5);
    final labelEvery = n > 24 ? 5 : (n > 18 ? 3 : (n > 12 ? 2 : 1));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: HomeDashboardChrome.panelDecoration(scheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeDashboardChrome.sectionHeader(
            context,
            eyebrow: 'Tracking',
            title: 'Daily distance',
            subtitle: 'Kilometres logged per day · tap a bar for detail',
            icon: Icons.near_me_rounded,
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: scheme.surfaceContainerLow.withValues(alpha: 0.72),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.32),
              ),
              boxShadow: [
                BoxShadow(
                  color: _KmTrackAccent.teal.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SizedBox(
              height: 224,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  minY: 0,
                  maxY: top,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: top / 4,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: scheme.outline.withValues(alpha: 0.11),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(
                        color: _KmTrackAccent.teal.withValues(alpha: 0.22),
                        width: 1,
                      ),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      axisNameWidget: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.straighten_rounded,
                            size: 11,
                            color: _KmTrackAccent.teal.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'km',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.9,
                              color: _KmTrackAccent.teal.withValues(alpha: 0.78),
                            ),
                          ),
                        ],
                      ),
                      axisNameSize: 16,
                      sideTitles: SideTitles(
                        reservedSize: 36,
                        showTitles: true,
                        interval: top / 4,
                        getTitlesWidget: (value, meta) {
                          if (value < 0 || value > top * 1.01) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              value == 0
                                  ? '0'
                                  : value.toStringAsFixed(
                                      value >= 10 ? 0 : 1,
                                    ),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (i, meta) {
                          final idx = i.toInt();
                          if (idx < 0 || idx >= data.length) {
                            return const SizedBox.shrink();
                          }
                          final show = idx % labelEvery == 0 ||
                              idx == data.length - 1;
                          if (!show) return const SizedBox.shrink();
                          final short = _shortDate(data[idx].date);
                          return Padding(
                            padding: const EdgeInsets.only(top: 7),
                            child: Text(
                              short,
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface.withValues(alpha: 0.48),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(data.length, (i) {
                    final isPeak = peakKm > 0 &&
                        i == peakIdx &&
                        data[i].distanceKm > 0;
                    final cap = Radius.circular(barW >= 10 ? 6 : 5);
                    return BarChartGroupData(
                      x: i,
                      barsSpace: barsSpace,
                      barRods: [
                        BarChartRodData(
                          toY: data[i].distanceKm,
                          width: barW,
                          borderRadius: BorderRadius.vertical(top: cap),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.18),
                            width: 0.75,
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: isPeak
                                ? [
                                    _KmTrackAccent.deep.withValues(alpha: 0.55),
                                    _KmTrackAccent.roll,
                                    _KmTrackAccent.cyan,
                                  ]
                                : [
                                    _KmTrackAccent.deep.withValues(alpha: 0.42),
                                    _KmTrackAccent.teal,
                                    _KmTrackAccent.cyan,
                                  ],
                            stops: const [0.0, 0.52, 1.0],
                          ),
                        ),
                      ],
                    );
                  }),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBorderRadius: BorderRadius.circular(12),
                      tooltipPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      maxContentWidth: 200,
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipColor: (_) =>
                          _KmTrackAccent.ink.withValues(alpha: 0.94),
                      tooltipBorder: BorderSide(
                        color: _KmTrackAccent.cyan.withValues(alpha: 0.4),
                        width: 1,
                      ),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final idx = group.x.toInt();
                        if (idx < 0 || idx >= data.length) return null;
                        final d = data[idx];
                        return BarTooltipItem(
                          '${_longDate(d.date)}\n'
                          '${d.distanceKm.toStringAsFixed(2)} km\n'
                          '${d.visits} visits',
                          GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static List<DailyChartPoint> _trim(List<DailyChartPoint> all, int max) {
    if (all.length <= max) return List<DailyChartPoint>.from(all);
    return all.sublist(all.length - max);
  }

  static Widget _emptyCard(BuildContext context, String msg) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: HomeDashboardChrome.panelDecoration(scheme),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _KmTrackAccent.teal.withValues(alpha: 0.2),
                  _KmTrackAccent.cyan.withValues(alpha: 0.1),
                ],
              ),
              border: Border.all(
                color: _KmTrackAccent.teal.withValues(alpha: 0.26),
              ),
            ),
            child: Icon(
              Icons.near_me_rounded,
              color: _KmTrackAccent.teal,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily distance',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.35,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  msg,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
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

  static String _shortDate(String ymd) {
    try {
      final d = DateFormat('yyyy-MM-dd').parse(ymd);
      return DateFormat('d MMM').format(d);
    } catch (_) {
      return ymd.length > 5 ? ymd.substring(5) : ymd;
    }
  }

  static String _longDate(String ymd) {
    try {
      final d = DateFormat('yyyy-MM-dd').parse(ymd);
      return DateFormat('EEE d MMM').format(d);
    } catch (_) {
      return ymd;
    }
  }
}
