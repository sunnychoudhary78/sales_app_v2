import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/device/battery_level.dart';
import '../../../core/device/device_info_payload.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/providers/network_providers.dart';

class TrackingApiService {
  final Dio _dio;
  TrackingApiService(this._dio);

  Future<String?> checkIn() async {
    final payload = await _buildCheckInPayload();
    final res = await _dio.post(ApiConstants.checkIn, data: payload);
    final data = res.data;
    if (data is Map) {
      final session = data['session'] ?? data['data'];
      if (session is Map) return session['id']?.toString();
      return data['session_id']?.toString();
    }
    return null;
  }

  /// Returns true when the session is closed (including already-closed 404).
  Future<bool> checkOut() async {
    final payload = await _buildLocationPayload(includeBattery: true);
    try {
      await _dio.post(ApiConstants.checkOut, data: payload);
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return true;
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchHistory({int limit = 50}) async {
    final res =
        await _dio.get(ApiConstants.trackingHistory, queryParameters: {'limit': limit});
    final data = res.data;
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  /// Road-snapped points + route metadata (same contract as legacy Sales App).
  ///
  /// Tries `/tracking/my-sessions/:id/*` first (field `tracking.sync`).
  /// On 401/403, retries `/tracking/sessions/:id/*` so managers with `tracking.view`
  /// (but not necessarily `tracking.sync`) still load subordinate routes.
  Future<Map<String, dynamic>> fetchSessionPointsBundle(String sessionId) async {
    Future<Response<dynamic>> getPoints(String basePath) {
      return _dio.get(
        '$basePath/$sessionId/points',
        queryParameters: const {'route': 'road'},
      );
    }

    try {
      final res = await getPoints(ApiConstants.trackingMySessionBase);
      final data = res.data;
      if (data is Map) return Map<String, dynamic>.from(data);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        try {
          final res = await getPoints(ApiConstants.trackingSessionBase);
          final data = res.data;
          if (data is Map) return Map<String, dynamic>.from(data);
        } catch (_) {}
      }
    } catch (_) {}
    return const {};
  }

  Future<List<Map<String, dynamic>>> fetchSessionVisits(String sessionId) async {
    List<Map<String, dynamic>> parseVisitsBody(dynamic data) {
      if (data is Map && data['visits'] is List) {
        return (data['visits'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return const [];
    }

    try {
      final res =
          await _dio.get('${ApiConstants.trackingMySessionBase}/$sessionId/visits');
      return parseVisitsBody(res.data);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        try {
          final res =
              await _dio.get('${ApiConstants.trackingSessionBase}/$sessionId/visits');
          return parseVisitsBody(res.data);
        } catch (_) {}
      }
    } catch (_) {}
    return const [];
  }

  Future<Map<String, dynamic>> _buildCheckInPayload() async {
    final payload = await _buildLocationPayload();
    final deviceInfo = await readDeviceInfoPayload();
    if (deviceInfo != null && deviceInfo.isNotEmpty) {
      payload['device_info'] = deviceInfo;
    }
    return payload;
  }

  Future<Map<String, dynamic>> _buildLocationPayload({bool includeBattery = false}) async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final payload = <String, dynamic>{
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'accuracy': pos.accuracy,
        'recorded_at': pos.timestamp.toUtc().toIso8601String(),
      };
      if (includeBattery) {
        final batteryPercent = await readBatteryPercent();
        if (batteryPercent != null) {
          payload['battery_percent'] = batteryPercent;
        }
      }
      return payload;
    } catch (_) {
      return {};
    }
  }
}

final trackingApiServiceProvider = Provider<TrackingApiService>((ref) {
  return TrackingApiService(ref.read(dioProvider));
});

