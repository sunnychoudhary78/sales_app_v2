import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/network_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/utils/permission_utils.dart';
import '../../data/home_repository.dart';
import '../../data/models/home_models.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(ref.read(dioProvider));
});

class HomeSelectedMonthNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void setMonth(DateTime? value) {
    if (value != null && HomeDashboardNotifier.isCurrentMonthMtd(value)) {
      state = null;
    } else {
      state = value;
    }
  }
}

/// Selected calendar month for home metrics. `null` = current month month-to-date.
final homeSelectedMonthProvider =
    NotifierProvider<HomeSelectedMonthNotifier, DateTime?>(
  HomeSelectedMonthNotifier.new,
);

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

  static bool isCurrentMonthMtd(DateTime? selected) {
    if (selected == null) return true;
    final now = DateTime.now();
    return selected.year == now.year && selected.month == now.month;
  }

  /// [selected] null → MTD; otherwise full calendar month (1st → last day).
  static ({DateTime start, DateTime end}) rangeForSelectedMonth(DateTime? selected) {
    if (selected == null || isCurrentMonthMtd(selected)) {
      return monthToDateRangeLocal();
    }
    final start = DateTime(selected.year, selected.month, 1);
    final lastDay = DateTime(selected.year, selected.month + 1, 0).day;
    final end = DateTime(selected.year, selected.month, lastDay);
    return (start: start, end: end);
  }

  @override
  Future<HomeDashboardContent> build() async {
    final auth = ref.watch(authProvider);
    final selectedMonth = ref.watch(homeSelectedMonthProvider);

    if (auth.profile == null) {
      return HomeDashboardContent.noInsights();
    }

    if (!hasPermission(auth.rawUser, 'tracking.sync')) {
      return HomeDashboardContent.noInsights();
    }

    final repo = ref.read(homeRepositoryProvider);
    final range = rangeForSelectedMonth(selectedMonth);
    final isMtd = isCurrentMonthMtd(selectedMonth);

    final results = await Future.wait([
      repo.fetchPerformance(from: range.start, to: range.end),
      repo.fetchTimeline(from: range.start, to: range.end),
    ]);

    return HomeDashboardContent(
      insightsEnabled: true,
      isCurrentMonthMtd: isMtd,
      performance: results[0] as HomePerformanceData,
      timeline: results[1] as HomeTimelineData,
      displayRangeStart: range.start,
      displayRangeEnd: range.end,
    );
  }
}
