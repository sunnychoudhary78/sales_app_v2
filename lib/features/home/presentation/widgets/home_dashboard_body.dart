import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/utils/permission_utils.dart';
import '../providers/home_dashboard_provider.dart';
import 'home_distance_chart_card.dart';
import 'home_live_tracking_card.dart';
import 'home_timeline_section.dart';
import 'home_tracking_hero.dart';
import 'home_welcome_header.dart';

/// Main scrollable dashboard: welcome and optional tracking insights.
class HomeDashboardBody extends ConsumerWidget {
  const HomeDashboardBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final raw = auth.rawUser;
    final dashboardAsync = ref.watch(homeDashboardProvider);
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.9, -0.55),
                  radius: 1.05,
                  colors: [
                    scheme.primary.withValues(alpha: 0.1),
                    scheme.tertiary.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.surfaceContainerLowest.withValues(alpha: 0),
                  scheme.surfaceContainerLowest,
                ],
                stops: const [0.0, 0.22],
              ),
            ),
          ),
        ),
        RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(homeDashboardProvider);
            await ref.read(homeDashboardProvider.future);
          },
          child: dashboardAsync.when(
            loading: () => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 120),
              children: const [
                Center(child: CircularProgressIndicator()),
              ],
            ),
            error: (e, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              children: [
                HomeWelcomeHeader(
                  name: auth.profile?.name ?? '',
                  subtitle:
                      'Could not load live metrics. Pull to retry or open Tracking.',
                ),
                const SizedBox(height: 16),
                _ErrorInsightCard(message: e.toString()),
              ],
            ),
            data: (data) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 44),
                children: [
                  if (data.insightsEnabled) ...[
                    HomeTrackingDashboardHero(
                      performance: data.performance,
                      displayName: auth.profile?.name ?? '',
                      showLiveBadge: data.isCurrentMonthMtd,
                      displayRangeStart: data.displayRangeStart,
                      displayRangeEnd: data.displayRangeEnd,
                    ).animate().fadeIn(duration: 340.ms).slideY(begin: 0.05, end: 0),
                    const SizedBox(height: 20),
                    if (data.isCurrentMonthMtd) ...[
                      HomeLiveTrackingCard(live: data.performance.live)
                          .animate()
                          .fadeIn(delay: 70.ms, duration: 360.ms),
                      const SizedBox(height: 20),
                    ],
                    HomeDistanceChartCard(byDay: data.performance.byDay)
                        .animate()
                        .fadeIn(delay: 110.ms, duration: 380.ms),
                    const SizedBox(height: 20),
                    HomeTimelineSection(events: data.timeline.events)
                        .animate()
                        .fadeIn(delay: 140.ms, duration: 380.ms),
                  ] else ...[
                    HomeWelcomeHeader(
                      name: auth.profile?.name ?? '',
                      subtitle:
                          'Enable tracking sync to see your live distance, visits, and timeline here.',
                    ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.06, end: 0),
                    const SizedBox(height: 20),
                    _InsightsLockedCard(hasTrackingPermission: hasPermission(raw, 'tracking.sync'))
                        .animate()
                        .fadeIn(duration: 320.ms),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ErrorInsightCard extends StatelessWidget {
  const _ErrorInsightCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.error.withValues(alpha: 0.25)),
      ),
      child: Text(
        message.replaceFirst(RegExp(r'^Exception:\s*'), ''),
        style: TextStyle(
          color: scheme.onErrorContainer,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _InsightsLockedCard extends StatelessWidget {
  const _InsightsLockedCard({required this.hasTrackingPermission});

  final bool hasTrackingPermission;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final msg = hasTrackingPermission
        ? 'Dashboard metrics will appear after the next sync.'
        : 'Ask your administrator for the "tracking.sync" permission to see distance, visits, and timeline on Home.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(Icons.insights_outlined, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: scheme.onSurface.withValues(alpha: 0.75),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
