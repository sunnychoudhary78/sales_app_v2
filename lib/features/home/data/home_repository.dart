import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_constants.dart';
import 'models/home_models.dart';

class HomeRepository {
  HomeRepository(this._dio);

  final Dio _dio;

  static String _ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d.toLocal());

  /// When [from]/[to] are omitted, uses local month-to-date (1st → today).
  Future<HomePerformanceData> fetchPerformance({
    DateTime? from,
    DateTime? to,
  }) async {
    final now = DateTime.now();
    final end = to ?? DateTime(now.year, now.month, now.day);
    final start = from ?? DateTime(end.year, end.month, 1);

    final res = await _dio.get<Map<String, dynamic>>(
      ApiConstants.trackingHomePerformance,
      queryParameters: <String, dynamic>{
        'from': _ymd(start),
        'to': _ymd(end),
      },
    );

    final body = res.data;
    if (body == null || body['success'] != true) {
      throw DioException(
        requestOptions: res.requestOptions,
        message: body?['message']?.toString() ?? 'Performance request failed',
      );
    }
    return HomePerformanceData.fromJson(body);
  }

  Future<HomeTimelineData> fetchTimeline({
    DateTime? from,
    DateTime? to,
  }) async {
    final now = DateTime.now();
    final end = to ?? DateTime(now.year, now.month, now.day);
    final start = from ?? DateTime(end.year, end.month, 1);

    final res = await _dio.get<Map<String, dynamic>>(
      ApiConstants.trackingHomeTimeline,
      queryParameters: <String, dynamic>{
        'from': _ymd(start),
        'to': _ymd(end),
      },
    );

    final body = res.data;
    if (body == null || body['success'] != true) {
      throw DioException(
        requestOptions: res.requestOptions,
        message: body?['message']?.toString() ?? 'Timeline request failed',
      );
    }
    return HomeTimelineData.fromJson(body);
  }
}
