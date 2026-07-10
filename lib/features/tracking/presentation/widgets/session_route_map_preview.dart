import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../data/tracking_repository.dart';
import 'route_replay_controls.dart';
import 'tracking_map_pins.dart';
import 'tracking_polyline_utils.dart';
import 'tracking_route_decorations.dart';
import 'tracking_route_replay.dart';

/// Session route map with road polyline and replay (admin panel parity).
class SessionRouteMapPreview extends ConsumerStatefulWidget {
  const SessionRouteMapPreview({
    super.key,
    required this.sessionId,
    this.height = 220,
    this.interactive = false,
    this.checkInAt,
    this.checkOutAt,
    this.totalDistanceKm,
    this.sessionStatus,
  });

  final String sessionId;
  final double height;
  final bool interactive;
  final String? checkInAt;
  final String? checkOutAt;
  final double? totalDistanceKm;
  final String? sessionStatus;

  @override
  ConsumerState<SessionRouteMapPreview> createState() =>
      _SessionRouteMapPreviewState();
}

class _SessionRouteMapPreviewState extends ConsumerState<SessionRouteMapPreview> {
  Future<({Map<String, dynamic> track, List<Map<String, dynamic>> visits})>?
      _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(trackingRepositoryProvider).fetchSessionMapBundle(widget.sessionId);
  }

  @override
  void didUpdateWidget(SessionRouteMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId != widget.sessionId) {
      _future =
          ref.read(trackingRepositoryProvider).fetchSessionMapBundle(widget.sessionId);
    }
  }

  DateTime? _parseSessionTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.interactive ? 0 : 18),
      child: SizedBox(
        height: widget.height,
        child: FutureBuilder<
            ({Map<String, dynamic> track, List<Map<String, dynamic>> visits})>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: scheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Loading route…',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (snap.hasError) {
              return ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map_outlined, size: 40, color: scheme.error),
                        const SizedBox(height: 10),
                        Text(
                          'Could not load map data',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: scheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            final bundle = snap.data!;
            return _SessionRouteMapContent(
              key: ValueKey(widget.sessionId),
              track: bundle.track,
              visits: bundle.visits,
              interactive: widget.interactive,
              checkInAt: _parseSessionTime(widget.checkInAt),
              checkOutAt: _parseSessionTime(widget.checkOutAt),
              totalDistanceKm: widget.totalDistanceKm,
              sessionStatus: widget.sessionStatus,
            );
          },
        ),
      ),
    );
  }
}

class _SessionRouteMapContent extends StatefulWidget {
  const _SessionRouteMapContent({
    super.key,
    required this.track,
    required this.visits,
    required this.interactive,
    required this.checkInAt,
    required this.checkOutAt,
    this.totalDistanceKm,
    this.sessionStatus,
  });

  final Map<String, dynamic> track;
  final List<Map<String, dynamic>> visits;
  final bool interactive;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final double? totalDistanceKm;
  final String? sessionStatus;

  @override
  State<_SessionRouteMapContent> createState() => _SessionRouteMapContentState();
}

class _SessionRouteMapContentState extends State<_SessionRouteMapContent>
    with SingleTickerProviderStateMixin, RouteReplayTickerMixin {
  final MapController _mapController = MapController();
  List<LatLng> _displayPath = const [];
  String _displayPathKey = '';
  bool _boundsFitted = false;
  LatLng? _prevReplayPos;

  static const Color _routeBlue = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    initReplayTicker();
  }

  @override
  void dispose() {
    disposeReplayTicker();
    super.dispose();
  }

  void _syncReplayTimeline() {
    attachReplayTimeline(
      buildRouteTimeline(
        _pointMaps(),
        sessionStart: widget.checkInAt,
        sessionEnd: widget.checkOutAt,
        roadPath: _displayPath,
      ),
    );
    _prevReplayPos = null;
    _boundsFitted = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitRouteBounds(_displayPath);
    });
  }

  List<Map<String, dynamic>> _pointMaps() {
    final pointsRaw =
        (widget.track['points'] is List) ? widget.track['points'] as List : const [];
    return pointsRaw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  void _fitRouteBounds(List<LatLng> points) {
    if (points.length < 2 || _boundsFitted) return;
    try {
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(48),
          maxZoom: 16,
        ),
      );
      _boundsFitted = true;
    } catch (_) {}
  }

  bool get _showReplayOnMap =>
      canReplayRoute && (replayPlaying || replayElapsedMs > 0);

  String _formatDuration() {
    final timeline = replayTimeline;
    if (timeline != null && timeline.durationMs > 0) {
      return formatReplayClock(timeline.durationMs);
    }
    if (widget.checkInAt != null && widget.checkOutAt != null) {
      final ms = widget.checkOutAt!
          .difference(widget.checkInAt!)
          .inMilliseconds
          .clamp(0, 1 << 31);
      return formatReplayClock(ms);
    }
    return '—';
  }

  double? _distanceKm() {
    final fromWidget = widget.totalDistanceKm;
    if (fromWidget != null && fromWidget > 0) return fromWidget;
    final fromApi = _toDouble(widget.track['route_distance_km']);
    if (fromApi != null && fromApi > 0) return fromApi;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mapsForTrack = _pointMaps();

    final routeRaw = (widget.track['route'] is List) ? widget.track['route'] as List : const [];
    final routeSegmentsRaw = (widget.track['route_segments'] is List)
        ? widget.track['route_segments'] as List
        : const [];

    final routeLinePoints = routeRaw.map((p) {
      if (p is! Map) return null;
      final lat = _toDouble(p['latitude']);
      final lon = _toDouble(p['longitude']);
      if (lat == null || lon == null) return null;
      return LatLng(lat, lon);
    }).whereType<LatLng>().toList();

    final routeSegmentLines = <List<LatLng>>[];
    for (final seg in routeSegmentsRaw) {
      if (seg is! Map) continue;
      final pts = seg['points'];
      if (pts is! List) continue;
      final path = pts.map((p) {
        if (p is! Map) return null;
        final lat = _toDouble(p['latitude']);
        final lon = _toDouble(p['longitude']);
        if (lat == null || lon == null) return null;
        return LatLng(lat, lon);
      }).whereType<LatLng>().toList();
      if (path.length >= 2) routeSegmentLines.add(path);
    }

    final drawableSegments = resolveTrackPolylines(
      pointMapsRaw: mapsForTrack,
      routeSegmentLines: routeSegmentLines,
      routeLinePoints: routeLinePoints,
    );

    final displayPath = mergeDisplayPath(drawableSegments);
    final pathKey = displayPath.isEmpty
        ? ''
        : '${displayPath.length}:${displayPath.first.latitude},${displayPath.first.longitude}:${displayPath.last.latitude},${displayPath.last.longitude}';
    if (pathKey != _displayPathKey) {
      _displayPathKey = pathKey;
      _displayPath = displayPath;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncReplayTimeline();
      });
    }

    final replayPos = replayPosition;

    final arrowMarkers = buildRouteDirectionArrowMarkers(
      displayPath,
      color: _routeBlue,
    );

    final flatForBounds =
        displayPath.isNotEmpty ? displayPath : flattenGpsSegments(drawableSegments);

    LatLng? routeStart;
    LatLng? routeEnd;
    trackEndpoints(drawableSegments, onFound: (s, e) {
      routeStart = s;
      routeEnd = e;
    });

    final rawPoints = mapsForTrack
        .map((p) {
          final lat = _toDouble(p['latitude']);
          final lon = _toDouble(p['longitude']);
          if (lat == null || lon == null) return null;
          return LatLng(lat, lon);
        })
        .whereType<LatLng>()
        .toList();
    if (routeStart == null && rawPoints.isNotEmpty) {
      routeStart = rawPoints.first;
      routeEnd = rawPoints.last;
    }

    final markers = <Marker>[...arrowMarkers];
    if (routeStart != null) {
      markers.add(
        Marker(
          point: routeStart!,
          width: 40,
          height: 44,
          alignment: Alignment.bottomCenter,
          child: const TrackingStartPin(),
        ),
      );
      final isOpen = (widget.sessionStatus ?? '').toLowerCase() == 'open';
      if (!_showReplayOnMap) {
        markers.add(
          Marker(
            point: routeEnd ?? routeStart!,
            width: 40,
            height: 44,
            alignment: Alignment.bottomCenter,
            child: isOpen
                ? Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _routeBlue,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.directions_run_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  )
                : const TrackingEndPin(),
          ),
        );
      }
    }

    for (final v in widget.visits) {
      final lat = _toDouble(v['latitude']);
      final lon = _toDouble(v['longitude']);
      if (lat == null || lon == null) continue;
      markers.add(
        Marker(
          point: LatLng(lat, lon),
          width: 28,
          height: 28,
          alignment: Alignment.center,
          child: const TrackingVisitPin(),
        ),
      );
    }

    if (_showReplayOnMap && replayPos != null) {
      double? replayBearing;
      if (_prevReplayPos != null) {
        final jumpM = haversineMeters(_prevReplayPos!, replayPos);
        if (jumpM >= 3) {
          replayBearing = bearingBetween(_prevReplayPos!, replayPos);
        }
      }
      markers.add(
        Marker(
          point: replayPos,
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: TrackingReplayLivePin(bearingDegrees: replayBearing),
        ),
      );
    }

    if (replayPos != null && _showReplayOnMap) {
      _prevReplayPos = replayPos;
    } else if (replayElapsedMs == 0) {
      _prevReplayPos = null;
    }

    final polylines = <Polyline>[];
    if (displayPath.length >= 2) {
      polylines.add(
        Polyline(
          points: displayPath,
          color: _routeBlue.withValues(alpha: 0.88),
          strokeWidth: 5,
        ),
      );
    }

    final hasTrail = displayPath.length >= 2;
    final distKm = _distanceKm();
    final visitCount = widget.visits.length;
    final gpsCount = mapsForTrack.length;
    final routeQuality = widget.track['route_quality'];
    int? accuracyTierUsed;
    if (routeQuality is Map) {
      final tier = routeQuality['accuracy_tier_used'];
      if (tier is num) accuracyTierUsed = tier.round();
    }

    final mapStack = Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: flatForBounds.isNotEmpty
                ? flatForBounds.first
                : const LatLng(20.5937, 78.9629),
            initialZoom: flatForBounds.isEmpty ? 4.5 : 13,
            interactionOptions: InteractionOptions(
              flags: widget.interactive
                  ? InteractiveFlag.all & ~InteractiveFlag.rotate
                  : InteractiveFlag.none,
            ),
            onMapReady: () {
              if (flatForBounds.length >= 2) _fitRouteBounds(flatForBounds);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.sales_tracking_v2',
            ),
            if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
            if (markers.isNotEmpty) MarkerLayer(markers: markers),
          ],
        ),
        Positioned(
          left: 12,
          top: 12,
          right: widget.interactive ? 12 : null,
          child: _MapStatsChip(
            hasTrail: hasTrail,
            distanceKm: distKm,
            durationLabel: _formatDuration(),
            gpsCount: gpsCount,
            visitCount: visitCount,
            isReplayActive: _showReplayOnMap,
            accuracyTierUsed: accuracyTierUsed,
          ),
        ),
        if (widget.interactive && canReplayRoute)
          Positioned(
            right: 12,
            top: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_circle_outline_rounded,
                        size: 16, color: scheme.onPrimaryContainer),
                    const SizedBox(width: 4),
                    Text(
                      'Replay ready',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );

    if (!widget.interactive) {
      return mapStack;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: mapStack),
        RouteReplayControls(
          canReplay: canReplayRoute,
          playing: replayPlaying,
          elapsedMs: replayElapsedMs,
          durationMs: replayDurationMs,
          speed: replaySpeed,
          onToggle: toggleReplay,
          onReset: () {
            _prevReplayPos = null;
            resetReplay();
          },
          onElapsedChanged: (ms) {
            if (ms == 0) _prevReplayPos = null;
            setReplayElapsed(ms);
          },
          onSpeedChanged: setReplaySpeed,
        ),
      ],
    );
  }
}

class _MapStatsChip extends StatelessWidget {
  const _MapStatsChip({
    required this.hasTrail,
    required this.distanceKm,
    required this.durationLabel,
    required this.gpsCount,
    required this.visitCount,
    required this.isReplayActive,
    this.accuracyTierUsed,
  });

  final bool hasTrail;
  final double? distanceKm;
  final String durationLabel;
  final int gpsCount;
  final int visitCount;
  final bool isReplayActive;
  final int? accuracyTierUsed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              !hasTrail
                  ? 'No GPS trail'
                  : isReplayActive
                      ? 'Replaying route'
                      : 'Session route',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
            if (hasTrail) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 10,
                runSpacing: 2,
                children: [
                  if (distanceKm != null)
                    _StatLine(
                      icon: Icons.straighten_rounded,
                      text: '${distanceKm!.toStringAsFixed(2)} km',
                    ),
                  _StatLine(icon: Icons.schedule_rounded, text: durationLabel),
                  _StatLine(icon: Icons.gps_fixed_rounded, text: '$gpsCount pts'),
                  if (visitCount > 0)
                    _StatLine(
                      icon: Icons.storefront_rounded,
                      text: '$visitCount visits',
                    ),
                  if (accuracyTierUsed != null)
                    _StatLine(
                      icon: Icons.gps_not_fixed_rounded,
                      text: 'Route GPS ≤ ${accuracyTierUsed}m',
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: scheme.primary),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
