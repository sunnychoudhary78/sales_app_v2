import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/providers/auth_provider.dart';
import '../presentation/providers/location_disclosure_provider.dart';
import '../presentation/screens/location_tracking_disclosure_screen.dart';

/// Gates Daily Tracking check-in behind the prominent location disclosure.
class LocationDisclosureCoordinator {
  LocationDisclosureCoordinator._();

  /// Returns true when the user has accepted (now or previously) and check-in may proceed.
  static Future<bool> ensureAccepted(BuildContext context, WidgetRef ref) async {
    final userId =
        ref.read(authProvider).profile?.userId ??
        ref.read(authProvider).rawUser?['id']?.toString() ??
        '';
    if (userId.isEmpty) return false;

    final store = ref.read(locationDisclosureStoreProvider);
    if (await store.isAccepted(userId)) return true;

    if (!context.mounted) return false;
    final agreed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => const LocationTrackingDisclosureScreen(),
      ),
    );

    if (agreed != true) return false;

    await store.markAccepted(userId);
    return true;
  }
}
