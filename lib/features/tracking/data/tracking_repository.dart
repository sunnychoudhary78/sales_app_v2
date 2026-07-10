import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/network_providers.dart';
import '../../../core/storage/storage_keys.dart';
import '../../../core/storage/user_storage.dart';
import 'background_tracking_service.dart';
import 'models/tracking_session_model.dart';
import 'tracking_api_service.dart';

class TrackingRepository {
  final TrackingApiService _api;
  final UserStorage _userStorage;
  final BackgroundTrackingService _backgroundTracking;

  TrackingRepository(this._api, this._userStorage, this._backgroundTracking);

  static const _preCheckoutSyncMax = Duration(seconds: 20);

  Future<bool> checkIn() async {
    final hasPermission = await _backgroundTracking
        .ensureLocationServiceAndPermissions();
    if (!hasPermission) return false;

    await _backgroundTracking.ensureBatteryOptimizationExemption();

    final sessionId = await _api.checkIn();
    if (sessionId != null && sessionId.isNotEmpty) {
      await _userStorage.saveValue(StorageKeys.trackingSessionId, sessionId);
      await _userStorage.saveValue(
        StorageKeys.checkInTime,
        DateTime.now().toIso8601String(),
      );
      await _backgroundTracking.startTracking();
      return true;
    }
    return false;
  }

  Future<void> checkOut() async {
    final sessionId = await getStoredSessionId();

    // Best-effort upload before close; do not block checkout indefinitely.
    await _backgroundTracking.syncAllPendingOnce(
      overrideSessionId: sessionId,
      maxDuration: _preCheckoutSyncMax,
    );

    await _api.checkOut();

    // Drop local session immediately so UI and background GPS stop using stale state.
    await clearLocalSession();
    await _backgroundTracking.stopServiceOnly();

    if (sessionId != null && sessionId.isNotEmpty) {
      unawaited(
        _backgroundTracking.syncAllPendingOnce(
          overrideSessionId: sessionId,
          maxDuration: const Duration(seconds: 45),
        ),
      );
    }
  }

  Future<void> ensureBackgroundTrackingRunning() {
    return _backgroundTracking.ensureTrackingIfSessionActive();
  }

  Future<List<TrackingSessionModel>> fetchHistory({int limit = 50}) async {
    final rows = await _api.fetchHistory(limit: limit);
    return rows.map(TrackingSessionModel.fromJson).toList();
  }

  Future<({Map<String, dynamic> track, List<Map<String, dynamic>> visits})>
  fetchSessionMapBundle(String sessionId) async {
    final track = await _api.fetchSessionPointsBundle(sessionId);
    final visits = await _api.fetchSessionVisits(sessionId);
    return (track: track, visits: visits);
  }

  /// Aligns local prefs with server: clears stale "checked in" cache when the
  /// API has no open session (e.g. checkout succeeded on web/another device).
  Future<void> reconcileLocalSessionWithServer(String? currentUserId) async {
    final open = await _findOpenSessionRow(currentUserId);
    if (open == null) {
      final local = await getStoredSessionId();
      if (local != null && local.isNotEmpty) {
        await clearLocalSession();
        await _backgroundTracking.stopServiceOnly();
      }
      return;
    }

    final sessionId = (open['id'] ?? open['session_id'] ?? open['sessionId'])
        ?.toString();
    if (sessionId == null || sessionId.isEmpty) return;

    final checkInStr = (open['check_in_at'] ?? open['checkInAt'])?.toString();
    await _userStorage.saveValue(StorageKeys.trackingSessionId, sessionId);
    final parsed = checkInStr != null ? DateTime.tryParse(checkInStr) : null;
    await _userStorage.saveValue(
      StorageKeys.checkInTime,
      (parsed ?? DateTime.now()).toIso8601String(),
    );
  }

  /// When local storage lost session (e.g. reinstall) but server still has an open session.
  Future<bool> tryRestoreActiveSessionFromServer(String? currentUserId) async {
    final existing = await getStoredSessionId();
    if (existing != null && existing.isNotEmpty) return false;

    final open = await _findOpenSessionRow(currentUserId);
    if (open == null) return false;

    await reconcileLocalSessionWithServer(currentUserId);
    return true;
  }

  Future<Map<String, dynamic>?> _findOpenSessionRow(String? currentUserId) async {
    final rows = await _api.fetchHistory(limit: 10);
    for (final raw in rows) {
      if (currentUserId != null && currentUserId.isNotEmpty) {
        final itemUserId =
            (raw['user_id'] ??
                    (raw['user'] is Map ? (raw['user'] as Map)['id'] : null))
                ?.toString();
        if (itemUserId != null && itemUserId != currentUserId) {
          continue;
        }
      }
      final status = (raw['status'] ?? raw['state'] ?? '')
          .toString()
          .toLowerCase();
      if (status != 'open' && status != 'active' && status != 'running') {
        continue;
      }
      return raw;
    }
    return null;
  }

  Future<void> clearLocalSession() async {
    await _userStorage.remove(StorageKeys.trackingSessionId);
    await _userStorage.remove(StorageKeys.checkInTime);
    await _userStorage.remove(StorageKeys.lastLatitude);
    await _userStorage.remove(StorageKeys.lastLongitude);
    await _userStorage.remove(StorageKeys.trackingLastPointAt);
  }

  Future<String?> getStoredSessionId() {
    return _userStorage.getValue(StorageKeys.trackingSessionId);
  }

  Future<String?> getStoredCheckInTime() {
    return _userStorage.getValue(StorageKeys.checkInTime);
  }
}

final trackingRepositoryProvider = Provider<TrackingRepository>((ref) {
  return TrackingRepository(
    ref.read(trackingApiServiceProvider),
    ref.read(userStorageProvider),
    ref.read(backgroundTrackingServiceProvider),
  );
});
