import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/network_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/utils/permission_utils.dart';
import '../../data/home_repository.dart';
import '../../data/models/home_models.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(ref.read(dioProvider));
});

final homeDashboardProvider =
    AsyncNotifierProvider<HomeDashboardNotifier, HomeDashboardContent>(
  HomeDashboardNotifier.new,
);

class HomeDashboardNotifier extends AsyncNotifier<HomeDashboardContent> {
  /// Local calendar month-to-date: 1st of this month → today (inclusive).
  static ({DateTime start, DateTime end}) monthToDateRangeLocal() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month, now.day);
    return (start: start, end: end);
  }

  @override
  Future<HomeDashboardContent> build() async {
    final auth = ref.watch(authProvider);
    if (auth.profile == null) {
      return HomeDashboardContent.noInsights();
    }

    if (!hasPermission(auth.rawUser, 'tracking.sync')) {
      return HomeDashboardContent.noInsights();
    }

    final repo = ref.read(homeRepositoryProvider);
    final range = HomeDashboardNotifier.monthToDateRangeLocal();

    final results = await Future.wait([
      repo.fetchPerformance(from: range.start, to: range.end),
      repo.fetchTimeline(from: range.start, to: range.end),
    ]);

    return HomeDashboardContent(
      insightsEnabled: true,
      performance: results[0] as HomePerformanceData,
      timeline: results[1] as HomeTimelineData,
    );
  }
}
