import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_constants.dart';
import '../../../core/storage/storage_keys.dart';
import 'models/location_point.dart';
import 'tracking_db_service.dart';

class BackgroundTrackingService {
  const BackgroundTrackingService();

  Future<bool> ensureLocationServiceAndPermissions() async {
    var serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      for (var i = 0; i < 20; i++) {
        await Future.delayed(const Duration(seconds: 1));
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) break;
      }
      if (!serviceEnabled) return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return false;
    }

    final always = await Permission.locationAlways.status;
    if (!always.isGranted) {
      final result = await Permission.locationAlways.request();
      if (!result.isGranted) {
        await openAppSettings();
        return false;
      }
    }
    await Permission.notification.request();
    return true;
  }

  Future<void> initialize() async {
    final service = FlutterBackgroundService();
    const channel = AndroidNotificationChannel(
      'sales_tracking_location',
      'Sales tracking location',
      description: 'Keeps route tracking active during field visits.',
      importance: Importance.low,
    );

    final notifications = FlutterLocalNotificationsPlugin();
    if (Platform.isAndroid || Platform.isIOS) {
      await notifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
    }
    await notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: trackingServiceEntryPoint,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'sales_tracking_location',
        initialNotificationTitle: 'Sales tracking active',
        initialNotificationContent: 'Recording your GPS route',
        foregroundServiceNotificationId: 889,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: trackingServiceEntryPoint,
        onBackground: trackingIosBackgroundEntryPoint,
      ),
    );
  }

  Future<void> startTracking() async {
    await initialize();
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      await service.startService();
    }
  }

  Future<void> stopTracking({String? overrideSessionId}) async {
    await syncAllPendingOnce(overrideSessionId: overrideSessionId);
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke('stopService');
    }
  }

  Future<void> syncAllPendingOnce({String? overrideSessionId}) async {
    await _syncPoints(
      TrackingDbService.instance,
      overrideSessionId: overrideSessionId,
    );
  }
}

final backgroundTrackingServiceProvider = Provider<BackgroundTrackingService>((
  ref,
) {
  return const BackgroundTrackingService();
});

@pragma('vm:entry-point')
Future<bool> trackingIosBackgroundEntryPoint(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void trackingServiceEntryPoint(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final db = TrackingDbService.instance;
  await db.database;

  Timer? syncTimer;
  StreamSubscription<Position>? positionSub;
  DateTime? lastWrittenAt;
  String? locationOffReportedSessionId;
  bool locationOffReported = false;

  Future<void> stop() async {
    syncTimer?.cancel();
    await positionSub?.cancel();
    service.stopSelf();
  }

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }

  service.on('stopService').listen((event) async {
    await stop();
  });

  final settings = Platform.isAndroid
      ? AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 5,
          intervalDuration: const Duration(seconds: 2),
        )
      : AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          activityType: ActivityType.fitness,
          distanceFilter: 5,
          pauseLocationUpdatesAutomatically: false,
          allowBackgroundLocationUpdates: true,
          showBackgroundLocationIndicator: true,
        );

  positionSub = Geolocator.getPositionStream(locationSettings: settings).listen((
    position,
  ) async {
    try {
      final sessionId = prefs.getString(StorageKeys.trackingSessionId);
      if (sessionId == null || sessionId.isEmpty) {
        await stop();
        return;
      }
      if (!position.latitude.isFinite || !position.longitude.isFinite) return;
      if (!position.accuracy.isFinite || position.accuracy > 55) return;

      final now = position.timestamp.toUtc();
      final last = await db.getLastPoint();
      if (last != null) {
        final dist = _distanceMeters(
          last.latitude,
          last.longitude,
          position.latitude,
          position.longitude,
        );
        final lastAt = DateTime.tryParse(last.recordedAt)?.toUtc();
        final gapSec = lastAt == null ? 9999 : now.difference(lastAt).inSeconds;
        if (dist < 5 && gapSec < 75) return;
        if (gapSec > 0 && gapSec <= 10 && dist > 200) return;
      }

      final bearing = last == null
          ? position.heading
          : _bearingDegrees(
              last.latitude,
              last.longitude,
              position.latitude,
              position.longitude,
            );
      await db.insertPoint(
        LocationPoint(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          speed: position.speed.isFinite ? position.speed : null,
          heading: bearing.isFinite ? bearing : null,
          recordedAt: now.toIso8601String(),
        ),
      );
      await prefs.setString(
        StorageKeys.lastLatitude,
        position.latitude.toString(),
      );
      await prefs.setString(
        StorageKeys.lastLongitude,
        position.longitude.toString(),
      );
      lastWrittenAt = now;

      if (service is AndroidServiceInstance &&
          await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: 'Sales tracking active',
          content:
              'GPS ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
        );
      }
    } catch (e) {
      debugPrint('Tracking point write failed: $e');
    }
  });

  syncTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
    try {
      final sessionId = prefs.getString(StorageKeys.trackingSessionId);
      if (sessionId == null || sessionId.isEmpty) {
        await stop();
        return;
      }

      if (locationOffReportedSessionId != sessionId) {
        locationOffReportedSessionId = sessionId;
        locationOffReported = false;
      }

      try {
        final enabled = await Geolocator.isLocationServiceEnabled();
        if (!enabled) {
          if (!locationOffReported) {
            locationOffReported = await _reportLocationOffToApi(
              sessionId: sessionId,
              reason: 'location_service_disabled',
            );
          }
        } else {
          final perm = await Geolocator.checkPermission();
          if (perm == LocationPermission.denied) {
            if (!locationOffReported) {
              locationOffReported = await _reportLocationOffToApi(
                sessionId: sessionId,
                reason: 'location_permission_denied',
              );
            }
          } else if (perm == LocationPermission.deniedForever) {
            if (!locationOffReported) {
              locationOffReported = await _reportLocationOffToApi(
                sessionId: sessionId,
                reason: 'location_permission_denied_forever',
              );
            }
          } else {
            locationOffReported = false;
          }
        }
      } catch (_) {}

      await _sendHeartbeat(sessionId);

      final gap = lastWrittenAt == null
          ? 0
          : DateTime.now().toUtc().difference(lastWrittenAt!).inSeconds;
      if (gap >= 90) {
        try {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              timeLimit: Duration(seconds: 12),
            ),
          );
          if (pos.accuracy.isFinite && pos.accuracy <= 55) {
            final last = await db.getLastPoint();
            final dist = last == null
                ? 9999.0
                : _distanceMeters(
                    last.latitude,
                    last.longitude,
                    pos.latitude,
                    pos.longitude,
                  );
            if (dist >= 5) {
              await db.insertPoint(
                LocationPoint(
                  latitude: pos.latitude,
                  longitude: pos.longitude,
                  accuracy: pos.accuracy,
                  speed: pos.speed.isFinite ? pos.speed : null,
                  heading: pos.heading.isFinite ? pos.heading : null,
                  recordedAt: pos.timestamp.toUtc().toIso8601String(),
                ),
              );
              lastWrittenAt = pos.timestamp.toUtc();
            }
          }
        } catch (_) {}
      }

      await _syncPoints(db);
    } catch (_) {}
  });
}

bool _syncRunning = false;

Future<void> _syncPoints(
  TrackingDbService db, {
  String? overrideSessionId,
}) async {
  if (_syncRunning) return;
  _syncRunning = true;
  try {
    final points = await db.getUnsyncedPoints();
    if (points.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final token = await const FlutterSecureStorage().read(
      key: StorageKeys.accessToken,
    );
    final sessionId =
        overrideSessionId ?? prefs.getString(StorageKeys.trackingSessionId);
    if (token == null ||
        token.isEmpty ||
        sessionId == null ||
        sessionId.isEmpty) {
      return;
    }

    final client = dio.Dio(
      dio.BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 45),
        sendTimeout: const Duration(seconds: 45),
        headers: {
          'Authorization': 'SALES_JWT_TOKEN $token',
          'Content-Type': 'application/json',
          'x-client-type': 'mobile',
        },
      ),
    );

    const chunkSize = 50;
    for (var i = 0; i < points.length; i += chunkSize) {
      final batch = points.sublist(i, math.min(i + chunkSize, points.length));
      final res = await client.post(
        ApiConstants.batchPoints,
        data: {
          'session_id': sessionId,
          'points': [
            for (final p in batch)
              {
                'latitude': p.latitude,
                'longitude': p.longitude,
                'recorded_at': p.recordedAt,
                'accuracy': p.accuracy,
                'speed': p.speed,
                'heading': p.heading,
                'is_offline': true,
              },
          ],
        },
      );
      if ((res.statusCode ?? 0) < 200 || (res.statusCode ?? 0) >= 300) break;
      await db.markPointsAsSynced(
        batch.map((p) => p.id).whereType<int>().toList(),
      );
    }
    await db.clearSyncedPoints();
  } catch (e) {
    debugPrint('Tracking sync failed: $e');
  } finally {
    _syncRunning = false;
  }
}

/// Notifies manager via API when GPS is disabled or permission revoked (legacy Sales App parity).
Future<bool> _reportLocationOffToApi({
  required String sessionId,
  required String reason,
}) async {
  try {
    final token = await const FlutterSecureStorage().read(
      key: StorageKeys.accessToken,
    );
    if (token == null || token.isEmpty) return false;

    final client = dio.Dio(
      dio.BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        headers: {
          'Authorization': 'SALES_JWT_TOKEN $token',
          'Content-Type': 'application/json',
          'x-client-type': 'mobile',
        },
      ),
    );

    final resp = await client.post(
      ApiConstants.trackingLocationOff,
      data: {
        'session_id': sessionId,
        'reason': reason,
      },
    );
    final body = resp.data;
    if (body is Map && body['success'] == true) {
      final sent = body['sent'] == true;
      final notifiedAt = body['location_off_notified_at'];
      if (sent == true ||
          (notifiedAt != null && notifiedAt.toString().isNotEmpty)) {
        return true;
      }
    }
  } catch (e) {
    debugPrint('Location-off report failed: $e');
  }
  return false;
}

Future<void> _sendHeartbeat(String sessionId) async {
  try {
    final token = await const FlutterSecureStorage().read(
      key: StorageKeys.accessToken,
    );
    if (token == null || token.isEmpty) return;
    final client = dio.Dio(
      dio.BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'Authorization': 'SALES_JWT_TOKEN $token',
          'Content-Type': 'application/json',
          'x-client-type': 'mobile',
        },
      ),
    );
    await client.post(
      ApiConstants.trackingHeartbeat,
      data: {
        'session_id': sessionId,
        'at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  } catch (_) {}
}

double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  double toRad(double v) => v * math.pi / 180.0;
  final dLat = toRad(lat2 - lat1);
  final dLon = toRad(lon2 - lon1);
  final aLat = toRad(lat1);
  final bLat = toRad(lat2);
  final h =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(aLat) * math.cos(bLat) * math.sin(dLon / 2) * math.sin(dLon / 2);
  return r * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

double _bearingDegrees(double lat1, double lon1, double lat2, double lon2) {
  double toRad(double v) => v * math.pi / 180.0;
  double toDeg(double v) => v * 180.0 / math.pi;
  final phi1 = toRad(lat1);
  final phi2 = toRad(lat2);
  final delta = toRad(lon2 - lon1);
  final y = math.sin(delta) * math.cos(phi2);
  final x =
      math.cos(phi1) * math.sin(phi2) -
      math.sin(phi1) * math.cos(phi2) * math.cos(delta);
  return (toDeg(math.atan2(y, x)) + 360.0) % 360.0;
}
