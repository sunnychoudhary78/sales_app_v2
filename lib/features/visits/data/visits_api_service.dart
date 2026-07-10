import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_constants.dart';
import '../../../core/providers/network_providers.dart';

class VisitsApiService {
  final Dio _dio;
  VisitsApiService(this._dio);

  Future<List<Map<String, dynamic>>> fetchVisits({
    Map<String, dynamic>? queryParameters,
  }) async {
    final res = await _dio.get(
      ApiConstants.visits,
      queryParameters: queryParameters,
    );
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

  Future<Map<String, dynamic>> fetchVisitsWithMeta({
    Map<String, dynamic>? queryParameters,
  }) async {
    final res = await _dio.get(
      ApiConstants.visits,
      queryParameters: queryParameters,
    );
    final data = res.data;
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final rows = map['data'];
      final list = rows is List
          ? rows
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];
      final meta = map['meta'] is Map
          ? Map<String, dynamic>.from(map['meta'] as Map)
          : null;
      return {'data': list, 'meta': meta};
    }
    if (data is List) {
      return {
        'data': data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
        'meta': null,
      };
    }
    return {'data': <Map<String, dynamic>>[], 'meta': null};
  }

  Future<List<Map<String, dynamic>>> fetchTeamMembers() async {
    final res = await _dio.get('${ApiConstants.visits}/team-members');
    final data = res.data;
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  Future<void> createVisit({
    required Map<String, dynamic> fields,
    required File imageFile,
  }) async {
    final payload = Map<String, dynamic>.from(fields)
      ..['photo'] = await MultipartFile.fromFile(
        imageFile.path,
        filename: 'visit_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
    final formData = FormData.fromMap(payload);
    await _dio.post(ApiConstants.visits, data: formData);
  }
}

final visitsApiServiceProvider = Provider<VisitsApiService>((ref) {
  return VisitsApiService(ref.read(dioProvider));
});

