import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../widgets/session_route_map_preview.dart';

/// Full-screen session route with pan/zoom and road-synced replay.
class TrackingSessionMapFullScreen extends StatelessWidget {
  const TrackingSessionMapFullScreen({
    super.key,
    required this.sessionId,
    this.checkInAt,
    this.checkOutAt,
    this.totalDistanceKm,
    this.sessionStatus,
    this.userName,
  });

  final String sessionId;
  final String? checkInAt;
  final String? checkOutAt;
  final double? totalDistanceKm;
  final String? sessionStatus;
  final String? userName;

  String _fmtLocal(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '—';
    return DateFormat('d MMM, h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final closed = (sessionStatus ?? '').toLowerCase() != 'open';

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              userName?.trim().isNotEmpty == true ? userName!.trim() : 'Session route',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            Text(
              '${_fmtLocal(checkInAt)} → ${closed ? _fmtLocal(checkOutAt) : 'Active'}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
        surfaceTintColor: Colors.transparent,
        actions: [
          if (totalDistanceKm != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${totalDistanceKm!.toStringAsFixed(2)} km',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SessionRouteMapPreview(
              sessionId: sessionId,
              height: constraints.maxHeight,
              interactive: true,
              checkInAt: checkInAt,
              checkOutAt: checkOutAt,
              totalDistanceKm: totalDistanceKm,
              sessionStatus: sessionStatus,
            );
          },
        ),
      ),
    );
  }
}
