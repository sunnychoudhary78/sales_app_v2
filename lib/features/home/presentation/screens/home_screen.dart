import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sales_tracking_v2/features/home/presentation/widgets/dashboard_app_bar_title.dart';

import '../../../../shared/widgets/app_side_drawer.dart';
import '../../../../shared/widgets/premium_shell.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/home_dashboard_provider.dart';
import '../widgets/home_dashboard_body.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authProvider);
    final user = auth.rawUser;

    final displayName =
        (user?['name'] ?? auth.profile?.name ?? '').toString();

    final selectedMonth = ref.watch(homeSelectedMonthProvider);
    final now = DateTime.now();
    final monthForLabel = (selectedMonth != null &&
            !HomeDashboardNotifier.isCurrentMonthMtd(selectedMonth))
        ? selectedMonth
        : DateTime(now.year, now.month, 1);
    final currentPeriod = DateFormat('MMMM yyyy').format(monthForLabel);
    final isLive = HomeDashboardNotifier.isCurrentMonthMtd(selectedMonth);

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      drawer: const AppSideDrawer(),
      appBar: SalesGlassAppBar(
        titleWidget: DashboardAppBarTitle(
          displayName: displayName,
          periodLabel: currentPeriod,
          showLiveBadge: isLive,
        ),
        showDrawer: true,
      ),
      body: const HomeDashboardBody(),
    );
  }
}
