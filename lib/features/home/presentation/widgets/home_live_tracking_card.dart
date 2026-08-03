import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../data/models/home_models.dart';

abstract final class _LiveCardAccent {
  static const Color teal = Color(0xFF0D9488);
  static const Color cyan = Color(0xFF0891B2);
  static const Color amber = Color(0xFFF59E0B);
  static const Color liveGreen = Color(0xFF10B981);
}

class HomeLiveTrackingCard extends StatefulWidget {
  const HomeLiveTrackingCard({super.key, required this.live});

  final TrackingLiveSummary live;

  @override
  State<HomeLiveTrackingCard> createState() => _HomeLiveTrackingCardState();
}

class _HomeLiveTrackingCardState extends State<HomeLiveTrackingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLive = widget.live.isLive && widget.live.sessionId != null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isLive
              ? _LiveCardAccent.liveGreen.withValues(alpha: 0.3)
              : scheme.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: isLive
                ? _LiveCardAccent.liveGreen.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Background Decorative Watermark Icon
            Positioned(
              right: -24,
              bottom: -24,
              child: Icon(
                isLive ? Icons.navigation_rounded : Icons.map_rounded,
                size: 160,
                color: (isLive ? _LiveCardAccent.liveGreen : _LiveCardAccent.teal)
                    .withValues(alpha: 0.04),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: isLive
                  ? _buildLiveState(context, scheme)
                  : _buildIdleState(context, scheme),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ACTIVE / LIVE STATE
  // ---------------------------------------------------------------------------
  Widget _buildLiveState(BuildContext context, ColorScheme scheme) {
    final hb = widget.live.lastHeartbeatAt;
    final hbStr = hb != null ? DateFormat('h:mm a').format(hb.toLocal()) : '—';
    final startTimeStr = widget.live.checkInAt != null
        ? DateFormat('EEE, MMM d · h:mm a').format(widget.live.checkInAt!.toLocal())
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row: Pulsing Indicator + Main Title
        Row(
          children: [
            _buildLiveBadge(),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Session in Progress',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (startTimeStr != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Started $startTimeStr',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Key Metrics Row
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                scheme: scheme,
                icon: Icons.straighten_rounded,
                iconColor: _LiveCardAccent.cyan,
                label: 'DISTANCE',
                value: '${widget.live.totalDistanceKm.toStringAsFixed(2)} km',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                scheme: scheme,
                icon: Icons.favorite_rounded,
                iconColor: _LiveCardAccent.liveGreen,
                label: 'LAST PULSE',
                value: hbStr,
              ),
            ),
          ],
        ),

        // Location Warning Banner
        if (widget.live.locationOffReason != null &&
            widget.live.locationOffReason!.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.errorContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.error.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: scheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.live.locationOffReason!,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // IDLE / STANDBY STATE
  // ---------------------------------------------------------------------------
  Widget _buildIdleState(BuildContext context, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Standby Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _LiveCardAccent.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _LiveCardAccent.amber.withValues(alpha: 0.3),
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
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: _LiveCardAccent.amber,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.sensors_off_rounded,
              size: 20,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Tracking Idle',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Check in to start recording your live route and distance.',
          style: GoogleFonts.inter(
            fontSize: 13,
            height: 1.4,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Month-to-date totals auto-update from saved visits.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // HELPER WIDGETS
  // ---------------------------------------------------------------------------

  /// Pulsing LIVE Pill
  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _LiveCardAccent.liveGreen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _pulseAnimation,
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'LIVE',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  /// Metric Card Tile
  Widget _buildMetricTile({
    required ColorScheme scheme,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}