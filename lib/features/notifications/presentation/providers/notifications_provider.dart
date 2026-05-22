import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/notifications_repository.dart';

final notificationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final uid = ref.watch(authProvider.select((a) => a.profile?.userId));
  if (uid == null || uid.isEmpty) return const [];
  return ref.read(notificationsRepositoryProvider).fetchForUser(uid);
});

final unreadCountProvider = Provider<int>((ref) {
  final async = ref.watch(notificationsProvider);
  return async.maybeWhen(
    data: (list) => list.where((n) => n['is_read'] != true).length,
    orElse: () => 0,
  );
});
