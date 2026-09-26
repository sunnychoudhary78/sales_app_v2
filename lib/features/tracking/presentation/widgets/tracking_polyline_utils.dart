import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Meters between two coordinates (WGS84).
double haversineMeters(LatLng a, LatLng b) {
  const R = 6371000.0;
  double toRad(double v) => v * math.pi / 180.0;
  final dLat = toRad(b.latitude - a.latitude);
  final dLon = toRad(b.longitude - a.longitude);
  final lat1 = toRad(a.latitude);
  final lat2 = toRad(b.latitude);
  final h = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
      (math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2));
  final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  return R * c;
}

class TrackSegment {
  const TrackSegment({
    required this.points,
    this.type = 'trace',
    this.provider,
    this.startTime,
    this.endTime,
    this.seq,
  });

  final List<LatLng> points;
  final String type;
  final String? provider;
  final DateTime? startTime;
  final DateTime? endTime;
  final int? seq;

  bool get isConnector => type.toLowerCase() == 'connector';
}

DateTime? parseSegmentTime(dynamic raw) {
  if (raw == null) return null;
  try {
    return DateTime.parse(raw.toString()).toUtc();
  } catch (_) {
    return null;
  }
}

({LatLng? start, LatLng? end}) gpsTrackEndpoints(List<Map<String, dynamic>> pointMaps) {
  final pts = <({LatLng ll, DateTime t})>[];
  for (final p in pointMaps) {
    final lat = _toDoubleLoose(p['latitude']);
    final lon = _toDoubleLoose(p['longitude']);
    if (lat == null || lon == null) continue;
    final t = _parseRecordedAt(p['recorded_at']);
    pts.add((ll: LatLng(lat, lon), t: t ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)));
  }
  if (pts.isEmpty) return (start: null, end: null);
  pts.sort((a, b) => a.t.compareTo(b.t));
  return (start: pts.first.ll, end: pts.last.ll);
}

List<LatLng> offsetPolylineMeters(List<LatLng> path, [double meters = 7]) {
  if (path.length < 2 || meters == 0) return path;
  double toRad(double v) => v * math.pi / 180.0;
  double toDeg(double v) => v * 180.0 / math.pi;
  double bearingRad(LatLng a, LatLng b) {
    final lat1 = toRad(a.latitude);
    final lat2 = toRad(b.latitude);
    final dLon = toRad(b.longitude - a.longitude);
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return math.atan2(y, x);
  }

  LatLng dest(LatLng origin, double brng, double distM) {
    final angular = distM / 6371000.0;
    final lat1 = toRad(origin.latitude);
    final lon1 = toRad(origin.longitude);
    final lat2 = math.asin(
      math.sin(lat1) * math.cos(angular) +
          math.cos(lat1) * math.sin(angular) * math.cos(brng),
    );
    final lon2 = lon1 +
        math.atan2(
          math.sin(brng) * math.sin(angular) * math.cos(lat1),
          math.cos(angular) - math.sin(lat1) * math.sin(lat2),
        );
    var lng = toDeg(lon2);
    lng = ((lng + 540) % 360) - 180;
    return LatLng(toDeg(lat2), lng);
  }

  return [
    for (var i = 0; i < path.length; i++)
      dest(
        path[i],
        bearingRad(
          i == 0 ? path[i] : path[i - 1],
          i == path.length - 1 ? path[i] : path[i + 1],
        ) +
            math.pi / 2,
        meters,
      ),
  ];
}

List<TrackSegment> resolveTypedTrackPolylines({
  required List<dynamic> pointMapsRaw,
  required List<TrackSegment> routeSegments,
  required List<LatLng> routeLinePoints,
}) {
  final road = routeSegments.where((s) => s.points.length >= 2).toList();
  if (road.isNotEmpty) {
    road.sort((a, b) => (a.seq ?? 0).compareTo(b.seq ?? 0));
    return road;
  }
  if (routeLinePoints.length >= 2) {
    return [TrackSegment(points: List<LatLng>.from(routeLinePoints))];
  }
  final lists = resolveTrackPolylines(
    pointMapsRaw: pointMapsRaw,
    routeSegmentLines: const [],
    routeLinePoints: const [],
  );
  return [
    for (final pts in lists)
      if (pts.length >= 2) TrackSegment(points: pts, type: 'gps'),
  ];
}

Color trackingSegmentColor(int index) {
  return HSLColor.fromAHSL(1, (210 + index * 48) % 360, 0.78, 0.48).toColor();
}

double trackingSegmentStrokeWidth(int index, int totalSegments) {
  if (totalSegments <= 1) return 5;
  return math.max(3.5, 8 - (index * 1.25));
}

List<Map<String, dynamic>> typedPointMapsFromRaw(List<dynamic> pointMapsRaw) {
  final typed = <Map<String, dynamic>>[];
  for (final p in pointMapsRaw) {
    if (p is Map<String, dynamic>) {
      typed.add(p);
    } else if (p is Map) {
      typed.add(Map<String, dynamic>.from(p));
    }
  }
  return typed;
}

/// Track polylines for the map. Priority:
/// 1. backend [routeSegmentLines] — road-snapped chronological passes.
/// 2. [routeLinePoints] — merged backend road line.
/// 3. split GPS segments as a fallback when the backend has no road geometry.
List<List<LatLng>> resolveTrackPolylines({
  required List<dynamic> pointMapsRaw,
  required List<List<LatLng>> routeSegmentLines,
  required List<LatLng> routeLinePoints,
}) {
  final roadSegments = routeSegmentLines
      .where((seg) => seg.length >= 2)
      .map((seg) => List<LatLng>.from(seg))
      .toList();
  if (roadSegments.isNotEmpty) {
    return roadSegments;
  }

  if (routeLinePoints.length >= 2) {
    return [List<LatLng>.from(routeLinePoints)];
  }

  final typed = typedPointMapsFromRaw(pointMapsRaw);
  final gpsSegments = buildGpsTrackSegments(typed);
  if (gpsSegments.isNotEmpty) {
    return gpsSegments;
  }

  final continuousGps = buildGpsTrackContinuousPoints(typed);
  if (continuousGps.length >= 2) {
    return [List<LatLng>.from(continuousGps)];
  }

  return const [];
}

/// First / last vertex of the drawable track (for start/end markers).
void trackEndpoints(
  List<List<LatLng>> drawableSegments, {
  required void Function(LatLng start, LatLng end) onFound,
}) {
  if (drawableSegments.isEmpty) return;
  final firstSeg = drawableSegments.first;
  final lastSeg = drawableSegments.last;
  if (firstSeg.isEmpty || lastSeg.isEmpty) return;
  onFound(firstSeg.first, lastSeg.last);
}

class _GpsPt {
  _GpsPt(this.ll, this.t);
  final LatLng ll;
  final DateTime t;
}

DateTime? _parseRecordedAt(
  dynamic raw, {
  DateTime? Function(dynamic raw)? parseRecordedAt,
}) {
  if (parseRecordedAt != null) return parseRecordedAt(raw);
  if (raw == null) return null;
  final s = raw.toString();
  if (s.isEmpty) return null;
  try {
    return DateTime.parse(s).toUtc();
  } catch (_) {
    return null;
  }
}

double? _toDoubleLoose(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

/// Sorts by time, drops near-duplicate fixes, returns null if fewer than 2 points.
List<_GpsPt>? _sortedCollapsedGpsPoints(
  List<Map<String, dynamic>> pointMaps, {
  DateTime? Function(dynamic raw)? parseRecordedAt,
}) {
  final raw = <_GpsPt>[];
  for (final p in pointMaps) {
    final lat = _toDoubleLoose(p['latitude']);
    final lon = _toDoubleLoose(p['longitude']);
    if (lat == null || lon == null) continue;
    final t = _parseRecordedAt(p['recorded_at'], parseRecordedAt: parseRecordedAt);
    if (t == null) continue;
    raw.add(_GpsPt(LatLng(lat, lon), t));
  }
  if (raw.isEmpty) return null;
  raw.sort((a, b) => a.t.compareTo(b.t));

  final collapsed = <_GpsPt>[];
  for (final p in raw) {
    if (collapsed.isEmpty) {
      collapsed.add(p);
      continue;
    }
    final last = collapsed.last;
    final d = haversineMeters(last.ll, p.ll);
    if (d < 1.2 && p.t.difference(last.t).inSeconds < 40) continue;
    collapsed.add(p);
  }
  if (collapsed.length < 2) return null;
  return collapsed;
}

/// One continuous path in time order (check-in → checkout) for a single blue polyline.
List<LatLng> buildGpsTrackContinuousPoints(
  List<Map<String, dynamic>> pointMaps, {
  DateTime? Function(dynamic raw)? parseRecordedAt,
}) {
  final collapsed = _sortedCollapsedGpsPoints(pointMaps, parseRecordedAt: parseRecordedAt);
  if (collapsed == null) return const [];

  final out = <LatLng>[collapsed.first.ll];
  for (int i = 1; i < collapsed.length; i++) {
    final d = haversineMeters(out.last, collapsed[i].ll);
    if (d >= 0.4) out.add(collapsed[i].ll);
  }
  return out.length >= 2 ? out : const [];
}

/// Builds ordered GPS polylines split when the path revisits the same area
/// (out-and-back on one road) or after a long stop, so multiple passes are visible.
///
/// [pointMaps] must be maps with `latitude`, `longitude`, and `recorded_at`.
List<List<LatLng>> buildGpsTrackSegments(
  List<Map<String, dynamic>> pointMaps, {
  DateTime? Function(dynamic raw)? parseRecordedAt,
}) {
  final collapsed = _sortedCollapsedGpsPoints(pointMaps, parseRecordedAt: parseRecordedAt);
  if (collapsed == null) return const [];

  const timeSplit = Duration(minutes: 5);
  const revisitM = 95.0;
  const minLookback = 14;
  const maxLookback = 55;
  const minPathAlongTrackM = 220.0;

  double pathLenBetween(int fromIdx, int toIdx) {
    double s = 0;
    for (int k = fromIdx + 1; k <= toIdx; k++) {
      s += haversineMeters(collapsed[k - 1].ll, collapsed[k].ll);
    }
    return s;
  }

  bool shouldStartNewSegmentAt(int i) {
    if (i <= 0) return false;
    final dt = collapsed[i].t.difference(collapsed[i - 1].t);
    if (dt >= timeSplit) return true;

    final jump = haversineMeters(collapsed[i - 1].ll, collapsed[i].ll);
    if (dt < const Duration(minutes: 2) && jump > 2800) return true;

    if (i < minLookback + 3) return false;

    final startJ = math.max(0, i - maxLookback);
    for (int j = i - minLookback; j >= startJ; j--) {
      if (haversineMeters(collapsed[i].ll, collapsed[j].ll) > revisitM) continue;
      if (pathLenBetween(j, i) >= minPathAlongTrackM) return true;
    }
    return false;
  }

  final segments = <List<LatLng>>[];
  var current = <LatLng>[collapsed.first.ll];

  for (int i = 1; i < collapsed.length; i++) {
    if (shouldStartNewSegmentAt(i)) {
      if (current.length >= 2) {
        segments.add(List<LatLng>.from(current));
      }
      current = <LatLng>[collapsed[i - 1].ll, collapsed[i].ll];
    } else {
      final d = haversineMeters(current.last, collapsed[i].ll);
      if (d >= 0.4) current.add(collapsed[i].ll);
    }
  }
  if (current.length >= 2) segments.add(current);
  return segments;
}

/// Flattens segments in order (each segment end may equal next start; dedupe lightly).
List<LatLng> flattenGpsSegments(List<List<LatLng>> segments) {
  if (segments.isEmpty) return const [];
  final out = <LatLng>[];
  for (final seg in segments) {
    for (final p in seg) {
      if (out.isEmpty || haversineMeters(out.last, p) >= 0.4) out.add(p);
    }
  }
  return out;
}
