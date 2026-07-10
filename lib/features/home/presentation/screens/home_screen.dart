import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      drawer: const AppSideDrawer(),
      appBar: SalesGlassAppBar(
        title: 'Dashboard',
        showDrawer: true,
        actions: [
          if (showMonthPicker) const HomeMonthPicker(),
          const SizedBox(width: 4),
        ],
      ),
      body: const HomeDashboardBody(),
    );
  }
}
