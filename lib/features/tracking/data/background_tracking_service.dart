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

import '../../../core/device/battery_level.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/storage/storage_keys.dart';
import 'models/location_point.dart';
import 'tracking_db_service.dart';

/// GPS fixes worse than 55m accuracy are not recorded (matches API batch ingest).
const double _kMaxRecordAccuracyM = 55;

/// Force a GPS fix when no point was written for this long.
const int _kGpsFallbackSec = 90;

/// Restart position stream when stale this long (service alive but stream stalled).
const int _kStreamRestartSec = 180;

/// Restart background service from app process when last point is older than this.
const int _kAppRestartStaleSec = 180;

/// Silent channel id — new id so existing installs are not stuck with old sound settings.
const String _kTrackingNotificationChannelId = 'sales_tracking_location_silent';

/// Minimum interval between foreground notification text updates (avoids alert sounds).
const int _kNotificationUpdateMinSec = 60;

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

  /// Best-effort; check-in proceeds even if the user declines.
  Future<bool> ensureBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isGranted) return true;
    final result = await Permission.ignoreBatteryOptimizations.request();
    return result.isGranted;
  }

  Future<bool> isBatteryOptimizationIgnored() async {
    if (!Platform.isAndroid) return true;
    return (await Permission.ignoreBatteryOptimizations.status).isGranted;
  }

  Future<void> initialize() async {
    final service = FlutterBackgroundService();
    const channel = AndroidNotificationChannel(
      _kTrackingNotificationChannelId,
      'Sales tracking location',
      description: 'Keeps route tracking active during field visits.',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
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
        notificationChannelId: _kTrackingNotificationChannelId,
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

  /// Restarts the background service when a session is open but GPS is stale.
  Future<void> ensureTrackingIfSessionActive() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString(StorageKeys.trackingSessionId);
    if (sessionId == null || sessionId.isEmpty) return;

    final staleSec = await _lastPointAgeSeconds(prefs);
    final service = FlutterBackgroundService();
    final running = await service.isRunning();

    if (!running || staleSec >= _kAppRestartStaleSec) {
      debugPrint(
        'Tracking restart: running=$running staleSec=$staleSec session=$sessionId',
      );
      await startTracking();
    }
  }

  Future<int> _lastPointAgeSeconds(SharedPreferences prefs) async {
    final raw = prefs.getString(StorageKeys.trackingLastPointAt);
    final last = raw != null ? DateTime.tryParse(raw)?.toUtc() : null;
    if (last == null) return 9999;
    return DateTime.now().toUtc().difference(last).inSeconds;
  }

  Future<void> stopTracking({String? overrideSessionId}) async {
    await syncAllPendingOnce(overrideSessionId: overrideSessionId);
    await stopServiceOnly();
  }

  Future<void> stopServiceOnly() async {
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke('stopService');
    }
  }

  Future<void> syncAllPendingOnce({
    String? overrideSessionId,
    Duration? maxDuration,
  }) async {
    final sync = _syncPoints(
      TrackingDbService.instance,
      overrideSessionId: overrideSessionId,
    );
    if (maxDuration == null) {
      await sync;
      return;
    }
    try {
      await sync.timeout(maxDuration);
    } on TimeoutException {
      debugPrint('Tracking sync timed out after ${maxDuration.inSeconds}s');
    }
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
  Timer? gpsWatchdogTimer;
  StreamSubscription<Position>? positionSub;
  DateTime? lastWrittenAt;
  String? locationOffReportedSessionId;
  bool locationOffReported = false;
  DateTime? lastNotificationUpdateAt;

  final androidService = service is AndroidServiceInstance ? service : null;

  Future<void> persistLastWrittenAt(DateTime at) async {
    lastWrittenAt = at;
    await prefs.setString(StorageKeys.trackingLastPointAt, at.toIso8601String());
  }

  DateTime? readPersistedLastWrittenAt() {
    final raw = prefs.getString(StorageKeys.trackingLastPointAt);
    return raw != null ? DateTime.tryParse(raw)?.toUtc() : null;
  }

  lastWrittenAt = readPersistedLastWrittenAt();

  Future<void> updateTrackingNotification() async {
    final android = androidService;
    if (android == null) return;
    if (!await android.isForegroundService()) return;

    final now = DateTime.now().toUtc();
    if (lastNotificationUpdateAt != null &&
        now.difference(lastNotificationUpdateAt!).inSeconds <
            _kNotificationUpdateMinSec) {
      return;
    }

    final unsynced = (await db.getUnsyncedPoints()).length;
    final last = lastWrittenAt ?? readPersistedLastWrittenAt();
    final ageSec = last == null
        ? -1
        : DateTime.now().toUtc().difference(last).inSeconds;

    String ageLabel;
    if (ageSec < 0) {
      ageLabel = 'waiting for GPS';
    } else if (ageSec < 60) {
      ageLabel = '${ageSec}s ago';
    } else {
      ageLabel = '${(ageSec / 60).floor()}m ago';
    }

    final pending = unsynced > 0 ? ' • $unsynced pending' : '';
    final warn = ageSec >= 300 ? ' — GPS may be paused' : '';

    android.setForegroundNotificationInfo(
      title: 'Sales tracking active',
      content: 'Last GPS: $ageLabel$pending$warn',
    );
    lastNotificationUpdateAt = now;
  }

  Future<bool> tryRecordPosition(Position position) async {
    final sessionId = prefs.getString(StorageKeys.trackingSessionId);
    if (sessionId == null || sessionId.isEmpty) return false;
    if (!position.latitude.isFinite || !position.longitude.isFinite) {
      return false;
    }
    if (!position.accuracy.isFinite ||
        position.accuracy > _kMaxRecordAccuracyM) {
      return false;
    }

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
      final gapSec =
          lastAt == null ? 9999 : now.difference(lastAt).inSeconds;
      if (dist < 5 && gapSec < 75) return false;
      if (gapSec > 0 && gapSec <= 10 && dist > 200) return false;
    }

    final bearing = last == null
        ? position.heading
        : _bearingDegrees(
            last.latitude,
            last.longitude,
            position.latitude,
            position.longitude,
          );
    final batteryPercent = await readBatteryPercent();
    await db.insertPoint(
      LocationPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: position.speed.isFinite ? position.speed : null,
        heading: bearing.isFinite ? bearing : null,
        batteryPercent: batteryPercent,
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
    await persistLastWrittenAt(now);
    return true;
  }

  Future<void> forceGpsFallback({required bool allowStationary}) async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!pos.accuracy.isFinite || pos.accuracy > _kMaxRecordAccuracyM) {
        return;
      }
      final last = await db.getLastPoint();
      final dist = last == null
          ? 9999.0
          : _distanceMeters(
              last.latitude,
              last.longitude,
              pos.latitude,
              pos.longitude,
            );
      if (!allowStationary && dist < 5) return;
      await tryRecordPosition(pos);
    } catch (e) {
      debugPrint('GPS fallback failed: $e');
    }
  }

  final locationSettings = Platform.isAndroid
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

  Future<void> stopTrackingService() async {
    syncTimer?.cancel();
    gpsWatchdogTimer?.cancel();
    await positionSub?.cancel();
    service.stopSelf();
  }

  void startPositionStream() {
    positionSub?.cancel();
    positionSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) async {
      try {
        final sessionId = prefs.getString(StorageKeys.trackingSessionId);
        if (sessionId == null || sessionId.isEmpty) {
          await stopTrackingService();
          return;
        }
        await tryRecordPosition(position);
      } catch (e) {
        debugPrint('Tracking point write failed: $e');
      }
    });
  }

  if (androidService != null) {
    androidService.setAsForegroundService();
  }

  service.on('stopService').listen((event) async {
    await stopTrackingService();
  });

  startPositionStream();
  unawaited(updateTrackingNotification());

  gpsWatchdogTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
    try {
      final sessionId = prefs.getString(StorageKeys.trackingSessionId);
      if (sessionId == null || sessionId.isEmpty) {
        await stopTrackingService();
        return;
      }

      final persisted = readPersistedLastWrittenAt();
      if (persisted != null) {
        lastWrittenAt = persisted;
      }
      final gap = lastWrittenAt == null
          ? 9999
          : DateTime.now().toUtc().difference(lastWrittenAt!).inSeconds;

      if (gap >= _kGpsFallbackSec) {
        await forceGpsFallback(allowStationary: gap >= _kGpsFallbackSec);
      }
      if (gap >= _kStreamRestartSec) {
        debugPrint('Restarting GPS position stream after ${gap}s gap');
        startPositionStream();
      }

      await updateTrackingNotification();
    } catch (e) {
      debugPrint('GPS watchdog failed: $e');
    }
  });

  syncTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
    try {
      final sessionId = prefs.getString(StorageKeys.trackingSessionId);
      if (sessionId == null || sessionId.isEmpty) {
        await stopTrackingService();
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
      await _syncPoints(db);
      await updateTrackingNotification();
    } catch (_) {}
  });
}

bool _syncRunning = false;
Completer<void>? _syncCompleter;

Future<void> _syncPoints(
  TrackingDbService db, {
  String? overrideSessionId,
}) async {
  if (_syncRunning) {
    final pending = _syncCompleter?.future;
    if (pending != null) await pending;
    return;
  }
  _syncRunning = true;
  _syncCompleter = Completer<void>();
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
                if (p.batteryPercent != null)
                  'battery_percent': p.batteryPercent,
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
    final completer = _syncCompleter;
    _syncCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
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
