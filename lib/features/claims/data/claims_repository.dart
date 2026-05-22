import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/network_providers.dart';

class ClaimsRepository {
  final Dio _dio;
  ClaimsRepository(this._dio);

  Future<Map<String, dynamic>> fetchMyPreview() async {
    final res = await _dio.get('/claims/my/preview');
    final data = res.data;
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    return {};
  }

  /// Same contract as legacy Sales App `POST /claims/my/submit`.
  Future<void> submitMyClaim({
    required String action,
    double? correctedDistanceKm,
    String? remarks,
    double advancePaymentAmount = 0,
    List<Map<String, dynamic>> extraExpenses = const [],
  }) async {
    final payload = <String, dynamic>{
      'action': action,
      'advance_payment_amount': advancePaymentAmount,
      'extra_expenses': extraExpenses,
    };
    if (action == 'disagree') {
      if (correctedDistanceKm != null) {
        payload['corrected_distance_km'] = correctedDistanceKm;
      }
      if (remarks != null && remarks.trim().isNotEmpty) {
        payload['remarks'] = remarks.trim();
      }
    } else if (remarks != null && remarks.trim().isNotEmpty) {
      payload['remarks'] = remarks.trim();
    }
    await _dio.post('/claims/my/submit', data: payload);
  }

  Future<List<Map<String, dynamic>>> fetchManagerRequests() async {
    final res = await _dio.get(
      '/claims/manager/requests',
      queryParameters: {'status': 'Disputed,Approved,Rejected', 'page': 1, 'limit': 50},
    );
    final data = res.data;
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  Future<void> reviewRequest({
    required String claimId,
    required String action,
    String? managerRemarks,
    double? approvedDistanceKm,
  }) async {
    final payload = <String, dynamic>{
      'action': action,
      if (managerRemarks != null && managerRemarks.trim().isNotEmpty)
        'manager_remarks': managerRemarks.trim(),
    };
    if (approvedDistanceKm != null) {
      payload['approved_distance_km'] = approvedDistanceKm;
    }
    await _dio.post(
      '/claims/manager/requests/$claimId/review',
      data: payload,
    );
  }
}

final claimsRepositoryProvider = Provider<ClaimsRepository>((ref) {
  return ClaimsRepository(ref.read(dioProvider));
});
