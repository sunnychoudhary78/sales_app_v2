import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/data/follow_up_notification_sync.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../data/models/visit_model.dart';
import '../../data/visits_repository.dart';

class VisitsNotifier extends AsyncNotifier<List<VisitModel>> {
  Future<List<VisitModel>> _loadAndSyncFollowUps() async {
    final list = await ref.read(visitsRepositoryProvider).fetchVisits();
    final uid = ref.read(authProvider).profile?.userId;
    if (uid != null && uid.isNotEmpty) {
      await syncTodayFollowUpNotificationRows(currentUserId: uid, visits: list);
      ref.invalidate(notificationsProvider);
    }
    return list;
  }

  @override
  Future<List<VisitModel>> build() async {
    return _loadAndSyncFollowUps();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadAndSyncFollowUps);
  }

  Future<void> createVisit({
    required Map<String, dynamic> fields,
    required File imageFile,
  }) async {
    await ref
        .read(visitsRepositoryProvider)
        .createVisit(fields: fields, imageFile: imageFile);
    await refresh();
  }
}

final visitsProvider = AsyncNotifierProvider<VisitsNotifier, List<VisitModel>>(
  VisitsNotifier.new,
);

