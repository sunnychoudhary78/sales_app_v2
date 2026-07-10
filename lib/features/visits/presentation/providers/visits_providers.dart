import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/data/follow_up_notification_sync.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../data/models/visit_filter_state.dart';
import '../../data/models/visit_model.dart';
import '../../data/visits_repository.dart';

class VisitsListState {
  const VisitsListState({
    required this.visits,
    required this.meta,
    required this.filters,
    this.teamMembers = const [],
    this.teamMembersLoading = false,
  });

  final List<VisitModel> visits;
  final VisitsListMeta meta;
  final VisitListFilters filters;
  final List<VisitTeamMember> teamMembers;
  final bool teamMembersLoading;

  VisitsListState copyWith({
    List<VisitModel>? visits,
    VisitsListMeta? meta,
    VisitListFilters? filters,
    List<VisitTeamMember>? teamMembers,
    bool? teamMembersLoading,
  }) {
    return VisitsListState(
      visits: visits ?? this.visits,
      meta: meta ?? this.meta,
      filters: filters ?? this.filters,
      teamMembers: teamMembers ?? this.teamMembers,
      teamMembersLoading: teamMembersLoading ?? this.teamMembersLoading,
    );
  }
}

class VisitsNotifier extends AsyncNotifier<VisitsListState> {
  @override
  Future<VisitsListState> build() async {
    return _load(const VisitListFilters());
  }

  Future<VisitsListState> _load(VisitListFilters filters) async {
    final repo = ref.read(visitsRepositoryProvider);
    final result = await repo.fetchVisits(filters);

    final uid = ref.read(authProvider).profile?.userId;
    if (uid != null && uid.isNotEmpty) {
      final ownResult = await repo.fetchVisits(VisitListFilters.mineOnly);
      await syncTodayFollowUpNotificationRows(
        currentUserId: uid,
        visits: ownResult.visits,
      );
      ref.invalidate(notificationsProvider);
    }

    List<VisitTeamMember> teamMembers = const [];
    if (result.meta.canFilterTeam) {
      teamMembers = await repo.fetchTeamMembers();
    }

    return VisitsListState(
      visits: result.visits,
      meta: result.meta,
      filters: filters,
      teamMembers: teamMembers,
    );
  }

  Future<void> applyFilters(VisitListFilters filters) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load(filters));
  }

  Future<void> refresh() async {
    final current = state.asData?.value.filters ?? const VisitListFilters();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load(current));
  }

  Future<void> createVisit({
    required Map<String, dynamic> fields,
    required File imageFile,
  }) async {
    await ref
        .read(visitsRepositoryProvider)
        .createVisit(fields: fields, imageFile: imageFile);
    try {
      await refresh();
    } catch (_) {
      // Visit was saved; list refresh can be retried from the visits screen.
    }
  }
}

final visitsProvider =
    AsyncNotifierProvider<VisitsNotifier, VisitsListState>(
  VisitsNotifier.new,
);
