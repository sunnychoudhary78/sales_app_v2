import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/claims_repository.dart';

final myClaimPreviewProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(claimsRepositoryProvider).fetchMyPreview();
});

final managerClaimRequestsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(claimsRepositoryProvider).fetchManagerRequests();
});

