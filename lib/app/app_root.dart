import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/company_context.dart';
import '../core/providers/user_data_invalidation.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/notifications/presentation/widgets/push_notifications_binding.dart';

class AppRoot extends ConsumerStatefulWidget {
  const AppRoot({super.key});

  @override
  ConsumerState<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<AppRoot> {
  bool _autoLoginAttempted = false;
  String? _lastTenantKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_autoLoginAttempted) return;
      _autoLoginAttempted = true;
      await ref.read(authProvider.notifier).tryAutoLogin();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final company = CompanyContext.fromUser(auth.rawUser);
    final userId = auth.profile?.userId;
    final tenantKey =
        userId != null ? company.tenantScopeKey(userId) : null;

    if (tenantKey != null && _lastTenantKey != tenantKey) {
      _lastTenantKey = tenantKey;
      invalidateAllUserScopedData(ref);
    } else if (tenantKey == null) {
      _lastTenantKey = null;
    }

    if (auth.isInitializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (auth.profile == null) return const LoginScreen();

    final uid = auth.profile!.userId;
    return PushNotificationsBinding(
      key: ValueKey<String>(uid),
    );
  }
}
