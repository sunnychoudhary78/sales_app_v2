import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/presentation/screens/home_screen.dart';
import '../../../tracking/data/background_tracking_service.dart';
import '../../application/push_notification_coordinator.dart';
import '../../../visits/presentation/providers/visits_providers.dart';

/// Attaches FCM + local notification wiring for the lifetime of a logged-in session.
class PushNotificationsBinding extends ConsumerStatefulWidget {
  const PushNotificationsBinding({super.key});

  @override
  ConsumerState<PushNotificationsBinding> createState() =>
      _PushNotificationsBindingState();
}

class _PushNotificationsBindingState extends ConsumerState<PushNotificationsBinding>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationCoordinator.instance.attach(ref);
      unawaited(ref.read(visitsProvider.future));
      unawaited(
        ref.read(backgroundTrackingServiceProvider).ensureTrackingIfSessionActive(),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PushNotificationCoordinator.instance.detach();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        ref.read(backgroundTrackingServiceProvider).ensureTrackingIfSessionActive(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}
