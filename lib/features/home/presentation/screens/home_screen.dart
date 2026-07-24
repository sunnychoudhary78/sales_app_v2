import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sales_tracking_v2/features/home/presentation/widgets/dashboard_app_bar_title.dart';

import '../../../../shared/utils/permission_utils.dart';
import '../../../../shared/widgets/app_side_drawer.dart';
import '../../../../shared/widgets/premium_shell.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/home_dashboard_body.dart';
import '../widgets/home_month_picker.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authProvider).rawUser;
    final showMonthPicker = hasPermission(user, 'tracking.sync');

    // 1. User Name extracting logic cleanly
    final displayName = user is Map
        ? (user?['displayName']?.toString() ?? '')
        : (user?.displayName ?? '');

     final currentPeriod = 'July 2026'; 

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      drawer: const AppSideDrawer(),
      appBar: SalesGlassAppBar(
        titleWidget: DashboardAppBarTitle(
          displayName: displayName,
          periodLabel: currentPeriod, // Passed dynamic value here
          showLiveBadge: true,
        ),
        showDrawer: true,
        // actions: [
        //   // Clear actions bar if permission is available
        //   if (showMonthPicker) const HomeMonthPicker(),
        //   const SizedBox(width: 8),
        // ],
      ),
      body: const HomeDashboardBody(),
    );
  }
}