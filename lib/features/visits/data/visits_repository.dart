import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/visit_model.dart';
import 'visits_api_service.dart';

class VisitsRepository {
  final VisitsApiService _apiService;
  VisitsRepository(this._apiService);

  Future<List<VisitModel>> fetchVisits() async {
    final rows = await _apiService.fetchVisits();
    return rows.map(VisitModel.fromJson).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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

