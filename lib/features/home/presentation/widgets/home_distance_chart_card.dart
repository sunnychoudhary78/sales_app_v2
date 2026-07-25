import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../data/models/home_models.dart';
import 'home_dashboard_chrome.dart';

abstract final class _KmTrackAccent {
  static const Color teal = Color(0xFF0D9488);
  static const Color cyan = Color(0xFF0891B2);
  static const Color deep = Color(0xFF0F766E);
  static const Color roll = Color(0xFF059669);
  static const Color trackBg = Color(0xFFF1F5F9);
}

class HomeDistanceChartCard extends StatefulWidget {
  const HomeDistanceChartCard({super.key, required this.byDay});

  final List<DailyChartPoint> byDay;

  @override
  State<HomeDistanceChartCard> createState() => _HomeDistanceChartCardState();
}

class _HomeDistanceChartCardState extends State<HomeDistanceChartCard> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final data = _trim(widget.byDay, 31);

    if (data.isEmpty) {
      return _emptyCard(context, 'No travel in this range yet.');
    }

    // Calculations for KPIs & Axes
    final totalKm = data.fold<double>(0, (sum, item) => sum + item.distanceKm);
    final avgKm = totalKm / data.length;

    double maxY = 0;
    int peakIdx = 0;
    for (var i = 0; i < data.length; i++) {
      if (data[i].distanceKm > maxY) {
        maxY = data[i].distanceKm;
        peakIdx = i;
      }
    }

    final top = maxY <= 0 ? 10.0 : (maxY * 1.15).ceilToDouble();
    final selectedPoint = _touchedIndex != null && _touchedIndex! < data.length
        ? data[_touchedIndex!]
        : data[peakIdx];

    final n = data.length;
    final barW = n > 22 ? 6.0 : (n > 16 ? 8.0 : (n > 10 ? 10.0 : 12.0));
    final labelEvery = n > 24 ? 5 : (n > 18 ? 3 : (n > 12 ? 2 : 1));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: HomeDashboardChrome.panelDecoration(scheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          HomeDashboardChrome.sectionHeader(
            context,
            eyebrow: 'Tracking',
            title: 'Daily distance',
            subtitle: 'Kilometres logged per day',
            icon: Icons.near_me_rounded,
          ),
          const SizedBox(height: 8),        

          // 2. Chart Container
          Container(
            padding: const EdgeInsets.fromLTRB(10, 16, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: scheme.surfaceContainerLow.withValues(alpha: 0.6),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.25),
              ),
            ),
            child: SizedBox(
              height: 190,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  minY: 0,
                  maxY: top,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: top / 3 > 0 ? top / 3 : 1,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: scheme.outline.withValues(alpha: 0.08),
                      strokeWidth: 1,
                      dashArray: [4, 4], // Dashed lines look modern
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        reservedSize: 32,
                        showTitles: true,
                        interval: top / 3 > 0 ? top / 3 : 1,
                        getTitlesWidget: (value, meta) {
                          if (value < 0 || value > top) return const SizedBox.shrink();
                          return Text(
                            value.toInt().toString(),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface.withValues(alpha: 0.4),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (i, meta) {
                          final idx = i.toInt();
                          if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                          if (idx % labelEvery != 0 && idx != data.length - 1) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _shortDate(data[idx].date),
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: _touchedIndex == idx ? FontWeight.w800 : FontWeight.w500,
                                color: _touchedIndex == idx
                                    ? _KmTrackAccent.teal
                                    : scheme.onSurface.withValues(alpha: 0.45),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Touch Interaction Setup
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchCallback: (FlTouchEvent event, response) {
                      if (event is FlTapUpEvent || event is FlPanUpdateEvent) {
                        final index = response?.spot?.touchedBarGroupIndex;
                        if (index != null && index != _touchedIndex) {
                          setState(() => _touchedIndex = index);
                        }
                      }
                    },
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.transparent, // Disable standard floating box
                      tooltipPadding: EdgeInsets.zero,
                      getTooltipItem: (_, __, ___, ____) => null,
                    ),
                  ),
                  barGroups: List.generate(data.length, (i) {
                    final isPeak = peakIdx == i && data[i].distanceKm > 0;
                    final isSelected = _touchedIndex == i;

                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: data[i].distanceKm,
                          width: isSelected ? barW + 2 : barW,
                          borderRadius: BorderRadius.circular(6),
                          // Modern Track Pill Background
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: top,
                            color: scheme.onSurface.withValues(alpha: 0.04),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: isSelected
                                ? [_KmTrackAccent.deep, _KmTrackAccent.cyan]
                                : isPeak
                                    ? [_KmTrackAccent.roll, _KmTrackAccent.teal]
                                    : [
                                        _KmTrackAccent.teal.withValues(alpha: 0.4),
                                        _KmTrackAccent.teal,
                                      ],
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 3. Selected Point Interactive Detail Strip
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _KmTrackAccent.teal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _KmTrackAccent.teal.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: _KmTrackAccent.teal,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _longDate(selectedPoint.date),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      '${selectedPoint.distanceKm.toStringAsFixed(2)} km',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _KmTrackAccent.teal,
                      ),
                    ),
                    Text(
                      '  •  ${selectedPoint.visits} visits',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widget for KPI Badges
  Widget _buildKpiChip(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    bool isHighlight = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isHighlight
              ? _KmTrackAccent.teal.withValues(alpha: 0.12)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isHighlight
                ? _KmTrackAccent.teal.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 12,
                  color: isHighlight ? _KmTrackAccent.teal : scheme.outline,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isHighlight ? _KmTrackAccent.deep : scheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
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
      padding: const EdgeInsets.all(18),
      decoration: HomeDashboardChrome.panelDecoration(scheme),
      child: Row(
        children: [
          Icon(Icons.near_me_rounded, color: _KmTrackAccent.teal, size: 24),
          const SizedBox(width: 12),
          Text(
            msg,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
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
      return ymd;
    }
  }

  static String _longDate(String ymd) {
    try {
      final d = DateFormat('yyyy-MM-dd').parse(ymd);
      return DateFormat('EEE, d MMM').format(d);
    } catch (_) {
      return ymd;
    }
  }
}