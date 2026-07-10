import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'tracking_polyline_utils.dart';
import 'tracking_route_replay.dart';

/// Direction arrow markers along a route polyline (~every [spacingMeters]).
List<Marker> buildRouteDirectionArrowMarkers(
  List<LatLng> path, {
  double spacingMeters = 85,
  Color color = const Color(0xFF2563EB),
  double iconSize = 14,
}) {
  if (path.length < 2) return const [];

  final markers = <Marker>[];
  double sinceLast = spacingMeters;

  for (var i = 0; i < path.length - 1; i++) {
    final a = path[i];
    final b = path[i + 1];
    final segLen = haversineMeters(a, b);
    if (segLen < 0.5) continue;

    var distAlong = 0.0;
    while (distAlong + sinceLast <= segLen) {
      distAlong += sinceLast;
      sinceLast = spacingMeters;
      final t = (distAlong / segLen).clamp(0.0, 1.0);
      final lat = a.latitude + (b.latitude - a.latitude) * t;
      final lng = a.longitude + (b.longitude - a.longitude) * t;
      final bearing = bearingBetween(a, b);
      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: iconSize + 8,
          height: iconSize + 8,
          alignment: Alignment.center,
          rotate: true,
          child: Transform.rotate(
            angle: bearing * math.pi / 180,
            child: Icon(
              Icons.navigation_rounded,
              size: iconSize,
              color: color,
            ),
          ),
        ),
      );
    }
    sinceLast = math.max(0, sinceLast - segLen);
  }

  return markers;
}

/// Merges drawable segment lists into one continuous path for display.
List<LatLng> mergeDisplayPath(List<List<LatLng>> segments) {
  return flattenGpsSegments(segments);
}
