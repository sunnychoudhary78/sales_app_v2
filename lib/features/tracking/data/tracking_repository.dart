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

  Future<bool> checkIn() async {
    final hasPermission = await _backgroundTracking
        .ensureLocationServiceAndPermissions();
    if (!hasPermission) return false;

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
    await _backgroundTracking.syncAllPendingOnce(overrideSessionId: sessionId);
    await _api.checkOut();
    await _backgroundTracking.stopTracking(overrideSessionId: sessionId);
    await _userStorage.remove(StorageKeys.trackingSessionId);
    await _userStorage.remove(StorageKeys.checkInTime);
    await _userStorage.remove(StorageKeys.lastLatitude);
    await _userStorage.remove(StorageKeys.lastLongitude);
  }

  Future<void> ensureBackgroundTrackingRunning() {
    return _backgroundTracking.startTracking();
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

  /// When local storage lost session (e.g. reinstall) but server still has an open session.
  Future<bool> tryRestoreActiveSessionFromServer(String? currentUserId) async {
    final existing = await getStoredSessionId();
    if (existing != null && existing.isNotEmpty) return false;

    final rows = await _api.fetchHistory(limit: 5);
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
      final sessionId = (raw['id'] ?? raw['session_id'] ?? raw['sessionId'])
          ?.toString();
      final checkInStr = (raw['check_in_at'] ?? raw['checkInAt'])?.toString();
      if (sessionId != null && sessionId.isNotEmpty) {
        await _userStorage.saveValue(StorageKeys.trackingSessionId, sessionId);
      }
      final parsed = checkInStr != null ? DateTime.tryParse(checkInStr) : null;
      await _userStorage.saveValue(
        StorageKeys.checkInTime,
        (parsed ?? DateTime.now()).toIso8601String(),
      );
      return true;
    }
    return false;
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
