import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../data/tracking_repository.dart';
import 'tracking_polyline_utils.dart';

/// Route + visit pins for a session (parity with legacy Sales App map preview).
///
/// Uses OpenStreetMap tiles via [flutter_map] — same approach as the classic
/// Sales App route screen — so no Google Maps API key is required on device.
class SessionRouteMapPreview extends ConsumerStatefulWidget {
  const SessionRouteMapPreview({
    super.key,
    required this.sessionId,
    this.height = 220,
    this.interactive = false,
  });

  final String sessionId;
  final double height;

  /// When true, map accepts pan/zoom (e.g. fullscreen). Inline preview stays lite.
  final bool interactive;

  @override
  ConsumerState<SessionRouteMapPreview> createState() =>
      _SessionRouteMapPreviewState();
}

class _SessionRouteMapPreviewState extends ConsumerState<SessionRouteMapPreview> {
  Future<({Map<String, dynamic> track, List<Map<String, dynamic>> visits})>?
      _future;
  final MapController _mapController = MapController();

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

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static MapOptions _mapOptionsFor(
    List<LatLng> flat,
    bool interactive,
  ) {
    if (flat.isEmpty) {
      return MapOptions(
        initialCenter: const LatLng(20.5937, 78.9629),
        initialZoom: 4.5,
        interactionOptions: InteractionOptions(
          flags: interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
      );
    }
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final p in flat) {
      minLat = minLat < p.latitude ? minLat : p.latitude;
      maxLat = maxLat > p.latitude ? maxLat : p.latitude;
      minLng = minLng < p.longitude ? minLng : p.longitude;
      maxLng = maxLng > p.longitude ? maxLng : p.longitude;
    }
    final c = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    final latSpan = (maxLat - minLat).abs().clamp(0.001, 10.0);
    final zoom = (14 - latSpan * 2).clamp(4.5, 17.0);
    return MapOptions(
      initialCenter: c,
      initialZoom: zoom,
      interactionOptions: InteractionOptions(
        flags: interactive
            ? InteractiveFlag.all & ~InteractiveFlag.rotate
            : InteractiveFlag.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
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
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.primary,
                  ),
                ),
              );
            }
            if (snap.hasError) {
              return ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Could not load map data',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              );
            }
            final bundle = snap.data!;
            final track = bundle.track;
            final visits = bundle.visits;

            final pointsRaw = (track['points'] is List) ? track['points'] as List : const [];
            final routeRaw = (track['route'] is List) ? track['route'] as List : const [];
            final routeSegmentsRaw =
                (track['route_segments'] is List) ? track['route_segments'] as List : const [];

            final mapsForTrack = pointsRaw.whereType<Map>().toList();

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

            final flatForBounds = flattenGpsSegments(drawableSegments);
            final mapOptions = _mapOptionsFor(flatForBounds, widget.interactive);

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

            final markers = <Marker>[];
            if (routeStart != null) {
              markers.add(
                Marker(
                  point: routeStart!,
                  width: 36,
                  height: 36,
                  alignment: Alignment.topCenter,
                  child: Icon(Icons.flag_rounded, color: Colors.green.shade700, size: 32),
                ),
              );
              markers.add(
                Marker(
                  point: routeEnd ?? routeStart!,
                  width: 40,
                  height: 40,
                  alignment: Alignment.topCenter,
                  child: Icon(
                    Icons.flag_rounded,
                    color: Colors.red.shade700,
                    size: 32,
                  ),
                ),
              );
            }

            for (final v in visits) {
              final lat = _toDouble(v['latitude']);
              final lon = _toDouble(v['longitude']);
              if (lat == null || lon == null) continue;
              markers.add(
                Marker(
                  point: LatLng(lat, lon),
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.person_pin_circle_rounded,
                    color: Colors.blue.shade600,
                    size: 22,
                  ),
                ),
              );
            }

            final pointCount = flatForBounds.length;
            final hasTrail = drawableSegments.isNotEmpty;

            return Stack(
              fit: StackFit.expand,
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: mapOptions,
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.sales_tracking_v2',
                    ),
                    if (drawableSegments.length > 1)
                      PolylineLayer(
                        polylines: [
                          for (int si = 0; si < drawableSegments.length; si++)
                            Polyline(
                              points: drawableSegments[si],
                              color: trackingSegmentColor(si).withValues(alpha: 0.95),
                              strokeWidth:
                                  trackingSegmentStrokeWidth(si, drawableSegments.length),
                            ),
                        ],
                      )
                    else if (drawableSegments.length == 1)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: drawableSegments.first,
                            color: scheme.primary,
                            strokeWidth: 5,
                          ),
                        ],
                      ),
                    if (markers.isNotEmpty) MarkerLayer(markers: markers),
                  ],
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Text(
                        !hasTrail ? 'No GPS trail' : '$pointCount points',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
