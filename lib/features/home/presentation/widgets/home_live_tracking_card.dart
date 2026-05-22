import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../data/models/home_models.dart';

/// Matches distance hero accents for a cohesive dashboard.
abstract final class _LiveCardAccent {
  static const Color teal = Color(0xFF0D9488);
  static const Color cyan = Color(0xFF0891B2);
  static const Color deep = Color(0xFF0F766E);
  static const Color amber = Color(0xFFF59E0B);
  static const Color slate = Color(0xFF64748B);
}

class HomeLiveTrackingCard extends StatelessWidget {
  const HomeLiveTrackingCard({super.key, required this.live});

  final TrackingLiveSummary live;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (!live.isLive || live.sessionId == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _LiveCardAccent.teal.withValues(alpha: 0.1),
                _LiveCardAccent.cyan.withValues(alpha: 0.06),
                scheme.surface,
              ],
            ),
            border: Border.all(color: _LiveCardAccent.teal.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: _LiveCardAccent.teal.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -12,
                top: -8,
                child: Icon(
                  Icons.my_location_rounded,
                  size: 96,
                  color: _LiveCardAccent.teal.withValues(alpha: 0.07),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _LiveCardAccent.teal,
                            _LiveCardAccent.cyan,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _LiveCardAccent.teal.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2.5),
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(15.5),
                          ),
                          child: Icon(
                            Icons.route_rounded,
                            size: 28,
                            color: _LiveCardAccent.deep,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _LiveCardAccent.amber.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: _LiveCardAccent.amber.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _LiveCardAccent.amber,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'STANDBY',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.9,
                                        color: _LiveCardAccent.deep,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Tracking idle',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.touch_app_rounded,
                                  size: 18,
                                  color: _LiveCardAccent.teal,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Open Daily tracking and check in to record live route distance and session km.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    height: 1.45,
                                    fontWeight: FontWeight.w500,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: _LiveCardAccent.slate.withValues(alpha: 0.85),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'No active GPS session · your month-to-date totals still update from saved visits.',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    height: 1.35,
                                    fontWeight: FontWeight.w600,
                                    color: _LiveCardAccent.slate.withValues(alpha: 0.9),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final hb = live.lastHeartbeatAt;
    final hbStr = hb != null ? DateFormat('MMM d, h:mm a').format(hb.toLocal()) : '—';

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.52),
                  border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF059669).withValues(alpha: 0.14),
                    scheme.primaryContainer.withValues(alpha: 0.28),
                    scheme.surface.withValues(alpha: 0.15),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF059669).withValues(alpha: 0.45),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'LIVE',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.9,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${live.totalDistanceKm.toStringAsFixed(2)} km',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Session in progress',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                if (live.checkInAt != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Since ${DateFormat('EEE, MMM d · h:mm a').format(live.checkInAt!.toLocal())}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.favorite_border_rounded, size: 18, color: scheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Last pulse $hbStr',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (live.locationOffReason != null && live.locationOffReason!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Location: ${live.locationOffReason}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: scheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
