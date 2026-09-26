import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';

import 'tracking_polyline_utils.dart';

const List<int> replaySpeeds = [1, 4, 16, 32, 64];

const int _stopMinMs = 180000;
const int gpsTimeGapMs = 5 * 60 * 1000;
const double _stopPathM = 35;
const double _stopGpsM = 50;
const double _pathMNoiseM = 15;

class ConnectorWindow {
  ConnectorWindow({
    required this.startMs,
    required this.endMs,
    required this.path,
    required this.cumulativeM,
  });

  final int startMs;
  final int endMs;
  final List<LatLng> path;
  final List<double> cumulativeM;
}

class RouteTimeline {
  RouteTimeline({
    required this.points,
    required this.durationMs,
    required this.startMs,
    required this.endMs,
    this.roadPath = const [],
    this.cumulativeRoadM = const [],
    this.connectorWindows = const [],
  });

  final List<RouteTimelinePoint> points;
  final int durationMs;
  final int startMs;
  final int endMs;
  final List<LatLng> roadPath;
  final List<double> cumulativeRoadM;
  final List<ConnectorWindow> connectorWindows;

  bool get canReplay => points.length >= 2 && durationMs > 0;
  bool get hasRoadPath => roadPath.length >= 2 && cumulativeRoadM.length >= 2;
}

class RouteTimelinePoint {
  RouteTimelinePoint({
    required this.latLng,
    required this.tMs,
    this.pathM,
  });

  final LatLng latLng;
  final int tMs;
  final double? pathM;
}

List<LatLng> normalizeRoadPath(List<LatLng> raw) {
  if (raw.length < 2) return const [];
  final out = <LatLng>[];
  for (final p in raw) {
    if (out.isEmpty) {
      out.add(p);
      continue;
    }
    if (haversineMeters(out.last, p) >= 0.3) out.add(p);
  }
  return out.length >= 2 ? out : const [];
}

List<double> buildCumulativeMeters(List<LatLng> path) {
  final cum = <double>[0];
  for (var i = 1; i < path.length; i++) {
    cum.add(cum.last + haversineMeters(path[i - 1], path[i]));
  }
  return cum;
}

LatLng _projectOnSegment(LatLng target, LatLng start, LatLng end) {
  final ax = start.longitude;
  final ay = start.latitude;
  final bx = end.longitude;
  final by = end.latitude;
  final px = target.longitude;
  final py = target.latitude;
  final abx = bx - ax;
  final aby = by - ay;
  final ab2 = abx * abx + aby * aby;
  if (ab2 <= 0) return start;
  final t = ((px - ax) * abx + (py - ay) * aby) / ab2;
  final ratio = t.clamp(0.0, 1.0);
  return LatLng(ay + aby * ratio, ax + abx * ratio);
}

double distanceAlongRoad(List<LatLng> path, List<double> cumulative, LatLng target) {
  var bestM = 0.0;
  var bestOffset = double.infinity;
  for (var i = 1; i < path.length; i++) {
    final proj = _projectOnSegment(target, path[i - 1], path[i]);
    final off = haversineMeters(target, proj);
    if (off < bestOffset) {
      bestOffset = off;
      bestM = cumulative[i - 1] + haversineMeters(path[i - 1], proj);
    }
  }
  return bestM;
}

List<RouteTimelinePoint> assignMonotonicPathM(
  List<RouteTimelinePoint> gpsPoints,
  List<LatLng> roadPath,
) {
  final path = normalizeRoadPath(roadPath);
  if (path.length < 2) return gpsPoints;

  final cumulative = buildCumulativeMeters(path);
  final total = cumulative.last;
  var lastM = 0.0;

  return gpsPoints.map((p) {
    var m = distanceAlongRoad(path, cumulative, p.latLng);
    m = math.min(math.max(m, 0), total);
    if (m < lastM && lastM - m <= _pathMNoiseM) {
      m = lastM;
    }
    lastM = m;
    return RouteTimelinePoint(latLng: p.latLng, tMs: p.tMs, pathM: m);
  }).toList();
}

LatLng? positionAtDistanceAlongRoad(
  List<LatLng> path,
  List<double> cumulative,
  double distanceM,
) {
  if (path.length < 2) return null;
  final total = cumulative.last;
  final d = distanceM.clamp(0, total);
  if (d <= 0) return path.first;
  if (d >= total) return path.last;
  for (var i = 1; i < path.length; i++) {
    if (cumulative[i] < d) continue;
    final segLen = cumulative[i] - cumulative[i - 1];
    final ratio = segLen > 0 ? (d - cumulative[i - 1]) / segLen : 0.0;
    final a = path[i - 1];
    final b = path[i];
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * ratio,
      a.longitude + (b.longitude - a.longitude) * ratio,
    );
  }
  return path.last;
}

List<ConnectorWindow> buildConnectorWindows(
  List<({LatLng ll, int tMs})> gpsPoints,
  List<TrackSegment> segments,
) {
  if (gpsPoints.length < 2 || segments.isEmpty) return const [];
  final windows = <ConnectorWindow>[];
  for (var i = 0; i < segments.length; i++) {
    final seg = segments[i];
    if (!seg.isConnector || seg.points.length < 2) continue;
    final explicitStart = seg.startTime?.millisecondsSinceEpoch;
    final explicitEnd = seg.endTime?.millisecondsSinceEpoch;
    if (explicitStart != null && explicitEnd != null && explicitEnd > explicitStart) {
      windows.add(ConnectorWindow(
        startMs: explicitStart,
        endMs: explicitEnd,
        path: seg.points,
        cumulativeM: buildCumulativeMeters(seg.points),
      ));
      continue;
    }
    final prevEnd = i > 0 && segments[i - 1].points.isNotEmpty
        ? segments[i - 1].points.last
        : seg.points.first;
    final nextStart = i < segments.length - 1 && segments[i + 1].points.isNotEmpty
        ? segments[i + 1].points.first
        : seg.points.last;
    var startIdx = 0;
    var bestStart = double.infinity;
    for (var g = 0; g < gpsPoints.length; g++) {
      final d = haversineMeters(gpsPoints[g].ll, prevEnd);
      if (d < bestStart) {
        bestStart = d;
        startIdx = g;
      }
    }
    var endIdx = startIdx;
    var bestEnd = double.infinity;
    for (var g = startIdx + 1; g < gpsPoints.length; g++) {
      final d = haversineMeters(gpsPoints[g].ll, nextStart);
      if (d < bestEnd) {
        bestEnd = d;
        endIdx = g;
      }
    }
    if (endIdx <= startIdx) endIdx = gpsPoints.length - 1;
    final startMs = gpsPoints[startIdx].tMs;
    final endMs = gpsPoints[endIdx].tMs;
    if (endMs <= startMs) continue;
    windows.add(ConnectorWindow(
      startMs: startMs,
      endMs: endMs,
      path: seg.points,
      cumulativeM: buildCumulativeMeters(seg.points),
    ));
  }
  return windows;
}

RouteTimeline? buildRouteTimeline(
  List<Map<String, dynamic>> rawPoints, {
  DateTime? sessionStart,
  DateTime? sessionEnd,
  List<LatLng> roadPath = const [],
  List<TrackSegment> drawableSegments = const [],
}) {
  final startBound = sessionStart?.toUtc().millisecondsSinceEpoch;
  final endBound = sessionEnd?.toUtc().millisecondsSinceEpoch;

  final typed = <({LatLng ll, int tMs})>[];
  for (final raw in rawPoints) {
    final lat = _toDouble(raw['latitude']);
    final lon = _toDouble(raw['longitude']);
    if (lat == null || lon == null) continue;
    final t = _parseRecordedAt(raw['recorded_at']);
    if (t == null) continue;
    final tMs = t.toUtc().millisecondsSinceEpoch;
    if (startBound != null && tMs < startBound) continue;
    if (endBound != null && tMs > endBound) continue;
    typed.add((ll: LatLng(lat, lon), tMs: tMs));
  }
  if (typed.length < 2) return null;
  typed.sort((a, b) => a.tMs.compareTo(b.tMs));

  final collapsed = <({LatLng ll, int tMs})>[];
  for (final point in typed) {
    if (collapsed.isEmpty) {
      collapsed.add(point);
      continue;
    }
    final last = collapsed.last;
    final dM = haversineMeters(last.ll, point.ll);
    final gapSec = (point.tMs - last.tMs) / 1000.0;
    if (dM < 1.2 && gapSec < 40) continue;
    collapsed.add(point);
  }
  if (collapsed.length < 2) return null;

  final road = normalizeRoadPath(roadPath);
  var points = collapsed
      .map((p) => RouteTimelinePoint(latLng: p.ll, tMs: p.tMs))
      .toList();
  if (road.length >= 2) {
    points = assignMonotonicPathM(points, road);
  }

  final startMs = points.first.tMs;
  final endMs = points.last.tMs;
  final connectorWindows = buildConnectorWindows(collapsed, drawableSegments);
  return RouteTimeline(
    points: points,
    durationMs: (endMs - startMs).clamp(0, 1 << 31),
    startMs: startMs,
    endMs: endMs,
    roadPath: road,
    cumulativeRoadM: road.length >= 2 ? buildCumulativeMeters(road) : const [],
    connectorWindows: connectorWindows,
  );
}

double? interpolatePathMByTime(RouteTimeline timeline, int elapsedMs) {
  final pts = timeline.points;
  if (pts.isEmpty || pts.first.pathM == null) return null;

  final targetMs = timeline.startMs + elapsedMs.clamp(0, timeline.durationMs);
  if (targetMs <= pts.first.tMs) return pts.first.pathM;
  if (targetMs >= pts.last.tMs) return pts.last.pathM;

  for (var i = 1; i < pts.length; i++) {
    final prev = pts[i - 1];
    final next = pts[i];
    if (targetMs > next.tMs) continue;

    final gapMs = next.tMs - prev.tMs;
    final p0 = prev.pathM ?? 0;
    final p1 = next.pathM ?? p0;
    final gpsMoveM = haversineMeters(prev.latLng, next.latLng);

    if (gapMs >= _stopMinMs &&
        (p1 - p0).abs() < _stopPathM &&
        gpsMoveM < _stopGpsM) {
      return p0;
    }
    if (gapMs >= gpsTimeGapMs) {
      return p0;
    }

    final span = math.max(1, gapMs);
    final t = (targetMs - prev.tMs) / span;
    return p0 + (p1 - p0) * t;
  }
  return pts.last.pathM;
}

LatLng _pointAlongPath(List<LatLng> path, List<double> cum, double distanceM) {
  if (path.length < 2) return path.isEmpty ? const LatLng(0, 0) : path.first;
  final total = cum.isNotEmpty ? cum.last : 0.0;
  final d = distanceM.clamp(0.0, total);
  if (d <= 0) return path.first;
  if (d >= total) return path.last;
  for (var i = 1; i < path.length; i++) {
    if (cum[i] < d) continue;
    final segLen = cum[i] - cum[i - 1];
    final ratio = segLen > 0 ? (d - cum[i - 1]) / segLen : 0.0;
    final a = path[i - 1];
    final b = path[i];
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * ratio,
      a.longitude + (b.longitude - a.longitude) * ratio,
    );
  }
  return path.last;
}

LatLng? positionAtTime(RouteTimeline timeline, int elapsedMs) {
  if (!timeline.canReplay) return null;

  final targetMs = timeline.startMs + elapsedMs.clamp(0, timeline.durationMs);
  for (final window in timeline.connectorWindows) {
    if (targetMs >= window.startMs && targetMs <= window.endMs && window.path.length >= 2) {
      final span = math.max(1, window.endMs - window.startMs);
      final ratio = ((targetMs - window.startMs) / span).clamp(0.0, 1.0);
      final total = window.cumulativeM.isNotEmpty ? window.cumulativeM.last : 0.0;
      return _pointAlongPath(window.path, window.cumulativeM, ratio * total);
    }
  }

  if (timeline.hasRoadPath) {
    final pts = timeline.points;
    for (var i = 1; i < pts.length; i++) {
      final prev = pts[i - 1];
      final next = pts[i];
      if (targetMs > next.tMs) continue;
      final gapMs = next.tMs - prev.tMs;
      if (gapMs >= gpsTimeGapMs && targetMs > prev.tMs && targetMs < next.tMs) {
        return prev.latLng;
      }
      break;
    }
    final road = timeline.roadPath;
    final cum = timeline.cumulativeRoadM;
    final pathM = interpolatePathMByTime(timeline, elapsedMs);
    if (pathM != null && pathM.isFinite) {
      return positionAtDistanceAlongRoad(road, cum, pathM);
    }
  }

  final pts = timeline.points;

  if (targetMs <= pts.first.tMs) return pts.first.latLng;
  if (targetMs >= pts.last.tMs) return pts.last.latLng;

  for (var i = 1; i < pts.length; i++) {
    final prev = pts[i - 1];
    final next = pts[i];
    if (targetMs > next.tMs) continue;
    final span = (next.tMs - prev.tMs).clamp(1, 1 << 31);
    final ratio = (targetMs - prev.tMs) / span;
    return LatLng(
      prev.latLng.latitude +
          (next.latLng.latitude - prev.latLng.latitude) * ratio,
      prev.latLng.longitude +
          (next.latLng.longitude - prev.latLng.longitude) * ratio,
    );
  }
  return pts.last.latLng;
}

/// Road polyline split into traveled (solid) and remaining (faded) for replay UI.
({List<LatLng> traveled, List<LatLng> remaining}) splitRoadPathAtElapsed(
  RouteTimeline timeline,
  List<LatLng> displayPath,
  int elapsedMs,
) {
  if (displayPath.length < 2 || !timeline.hasRoadPath) {
    return (traveled: const [], remaining: displayPath);
  }

  final pathM = interpolatePathMByTime(timeline, elapsedMs);
  if (pathM == null || pathM <= 0) {
    return (traveled: const [], remaining: displayPath);
  }

  final cum = buildCumulativeMeters(displayPath);
  final total = cum.last;
  if (pathM >= total) {
    return (traveled: List<LatLng>.from(displayPath), remaining: const []);
  }

  final traveled = <LatLng>[displayPath.first];
  for (var i = 1; i < displayPath.length; i++) {
    if (cum[i] <= pathM) {
      traveled.add(displayPath[i]);
    } else {
      final segLen = cum[i] - cum[i - 1];
      final ratio = segLen > 0 ? (pathM - cum[i - 1]) / segLen : 0.0;
      final a = displayPath[i - 1];
      final b = displayPath[i];
      traveled.add(
        LatLng(
          a.latitude + (b.latitude - a.latitude) * ratio,
          a.longitude + (b.longitude - a.longitude) * ratio,
        ),
      );
      break;
    }
  }

  if (traveled.length < 2) {
    return (traveled: const [], remaining: displayPath);
  }
  final splitPoint = traveled.last;
  final remaining = <LatLng>[splitPoint];
  var pastSplit = false;
  for (final p in displayPath) {
    if (!pastSplit) {
      if (haversineMeters(p, splitPoint) < 0.5) pastSplit = true;
      continue;
    }
    remaining.add(p);
  }
  if (remaining.length < 2) {
    return (traveled: traveled, remaining: const []);
  }
  return (traveled: traveled, remaining: remaining);
}

double bearingBetween(LatLng a, LatLng b) {
  const r = math.pi / 180;
  final lat1 = a.latitude * r;
  final lat2 = b.latitude * r;
  final dLon = (b.longitude - a.longitude) * r;
  final y = math.sin(dLon) * math.cos(lat2);
  final x =
      math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

String formatReplayClock(int ms) {
  final totalSec = (ms / 1000).floor().clamp(0, 1 << 30);
  final h = totalSec ~/ 3600;
  final m = (totalSec % 3600) ~/ 60;
  final s = totalSec % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

mixin RouteReplayTickerMixin<T extends StatefulWidget> on State<T>, TickerProvider {
  Ticker? _replayTicker;
  Duration? _replayLast;
  int replayElapsedMs = 0;
  bool replayPlaying = false;
  int replaySpeed = 4;
  RouteTimeline? replayTimeline;

  void initReplayTicker() {
    _replayTicker?.dispose();
    _replayTicker = createTicker(_onReplayTick);
  }

  void disposeReplayTicker() {
    _replayTicker?.dispose();
    _replayTicker = null;
  }

  void attachReplayTimeline(RouteTimeline? t) {
    replayTimeline = t;
    replayElapsedMs = 0;
    replayPlaying = false;
    _replayTicker?.stop();
    _replayLast = null;
    if (mounted) setState(() {});
  }

  bool get canReplayRoute {
    final t = replayTimeline;
    if (t == null || t.durationMs <= 0) return false;
    if (t.hasRoadPath) return true;
    return t.points.length >= 2;
  }

  int get replayDurationMs => replayTimeline?.durationMs ?? 0;

  LatLng? get replayPosition => replayTimeline == null
      ? null
      : positionAtTime(replayTimeline!, replayElapsedMs);

  void playReplay() {
    if (!canReplayRoute) return;
    if (replayElapsedMs >= replayDurationMs) replayElapsedMs = 0;
    replayPlaying = true;
    _replayLast = null;
    _replayTicker?.start();
    setState(() {});
  }

  void pauseReplay() {
    replayPlaying = false;
    _replayTicker?.stop();
    _replayLast = null;
    setState(() {});
  }

  void toggleReplay() {
    if (replayPlaying) {
      pauseReplay();
    } else {
      playReplay();
    }
  }

  void resetReplay() {
    pauseReplay();
    replayElapsedMs = 0;
    setState(() {});
  }

  void setReplayElapsed(int ms) {
    pauseReplay();
    replayElapsedMs = ms.clamp(0, replayDurationMs);
    setState(() {});
  }

  void setReplaySpeed(int speed) {
    if (!replaySpeeds.contains(speed)) return;
    replaySpeed = speed;
    setState(() {});
  }

  void _onReplayTick(Duration elapsed) {
    if (!replayPlaying || replayTimeline == null) return;
    if (_replayLast == null) {
      _replayLast = elapsed;
      return;
    }
    final delta = elapsed - _replayLast!;
    _replayLast = elapsed;
    final add = (delta.inMicroseconds / 1000 * replaySpeed).round();
    replayElapsedMs = (replayElapsedMs + add).clamp(0, replayDurationMs);
    if (replayElapsedMs >= replayDurationMs) {
      replayElapsedMs = replayDurationMs;
      pauseReplay();
      return;
    }
    setState(() {});
  }
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

DateTime? _parseRecordedAt(dynamic raw) {
  if (raw == null) return null;
  try {
    return DateTime.parse(raw.toString()).toUtc();
  } catch (_) {
    return null;
  }
}
