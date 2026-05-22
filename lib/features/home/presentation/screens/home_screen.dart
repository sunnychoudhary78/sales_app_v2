import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_side_drawer.dart';
import '../../../../shared/widgets/premium_shell.dart';
import '../widgets/home_dashboard_body.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      drawer: const AppSideDrawer(),
      appBar: SalesGlassAppBar(
        title: 'Dashboard',
        showDrawer: true,
        actions: const [
          SizedBox(width: 4),
        ],
      ),
      body: const HomeDashboardBody(),
    );
  }
}
