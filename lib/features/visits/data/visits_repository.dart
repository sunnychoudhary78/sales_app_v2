import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/visit_filter_state.dart';
import 'models/visit_model.dart';
import 'visits_api_service.dart';

class VisitsFetchResult {
  const VisitsFetchResult({
    required this.visits,
    required this.meta,
  });

  final List<VisitModel> visits;
  final VisitsListMeta meta;
}

class VisitsRepository {
  final VisitsApiService _apiService;
  VisitsRepository(this._apiService);

  Future<VisitsFetchResult> fetchVisits(VisitListFilters filters) async {
    final payload = await _apiService.fetchVisitsWithMeta(
      queryParameters: filters.toQueryParams(),
    );
    final rows = payload['data'];
    final list = rows is List
        ? rows
            .whereType<Map>()
            .map((e) => VisitModel.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <VisitModel>[];
    list.sort((a, b) => b.visitDate.compareTo(a.visitDate));
    final meta = VisitsListMeta.fromJson(
      payload['meta'] is Map ? Map<String, dynamic>.from(payload['meta'] as Map) : null,
    );
    return VisitsFetchResult(visits: list, meta: meta);
  }

  Future<List<VisitTeamMember>> fetchTeamMembers() async {
    final rows = await _apiService.fetchTeamMembers();
    return rows.map(VisitTeamMember.fromJson).toList();
  }

  Future<void> createVisit({
    required Map<String, dynamic> fields,
    required File imageFile,
  }) {
    return _apiService.createVisit(fields: fields, imageFile: imageFile);
  }
}

final visitsRepositoryProvider = Provider<VisitsRepository>((ref) {
  return VisitsRepository(ref.read(visitsApiServiceProvider));
});
