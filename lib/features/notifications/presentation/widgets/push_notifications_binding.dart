import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/presentation/screens/home_screen.dart';
import '../../application/push_notification_coordinator.dart';
import '../../../visits/presentation/providers/visits_providers.dart';

/// Attaches FCM + local notification wiring for the lifetime of a logged-in session.
class PushNotificationsBinding extends ConsumerStatefulWidget {
  const PushNotificationsBinding({super.key});

  @override
  ConsumerState<PushNotificationsBinding> createState() =>
      _PushNotificationsBindingState();
}

class _PushNotificationsBindingState extends ConsumerState<PushNotificationsBinding> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationCoordinator.instance.attach(ref);
      unawaited(ref.read(visitsProvider.future));
    });
  }

  @override
  void dispose() {
    PushNotificationCoordinator.instance.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}
