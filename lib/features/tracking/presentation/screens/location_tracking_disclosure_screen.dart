import 'package:flutter/material.dart';

import '../../../../shared/widgets/premium_shell.dart';
import '../../../../shared/widgets/screen_accent_backdrop.dart';

/// Full-screen prominent disclosure shown before Daily Tracking location permissions.
class LocationTrackingDisclosureScreen extends StatelessWidget {
  const LocationTrackingDisclosureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: scheme.surfaceContainerLowest,
        appBar: const SalesGlassAppBar(
          title: 'Location for daily tracking',
          showNotificationAction: false,
        ),
        body: ScreenAccentBackdrop(
          spot: DrawerRouteAccents.trackingTeal,
          spot2: DrawerRouteAccents.trackingCyan,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    const PremiumFeatureHeader(
                      icon: Icons.location_on_rounded,
                      title: 'How we use your location',
                      subtitle:
                          'Please read this before allowing location access for Daily Tracking.',
                    ),
                    PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const PremiumSectionTitle(
                            title: 'What we collect',
                            subtitle:
                                'Precise GPS location during an active check-in session.',
                          ),
                          const SizedBox(height: 12),
                          _DisclosureBullet(
                            icon: Icons.gps_fixed_rounded,
                            text:
                                'Your precise location is recorded to build your field route.',
                          ),
                          const SizedBox(height: 10),
                          _DisclosureBullet(
                            icon: Icons.nights_stay_rounded,
                            text:
                                'Location may be collected while the app is in the background or when your screen is off.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const PremiumSectionTitle(
                            title: 'Why and when',
                          ),
                          const SizedBox(height: 12),
                          _DisclosureBullet(
                            icon: Icons.route_rounded,
                            text:
                                'This helps record your field route, distance travelled, and visit-related mileage for your workday.',
                          ),
                          const SizedBox(height: 10),
                          _DisclosureBullet(
                            icon: Icons.timer_rounded,
                            text:
                                'Location is collected only while you are checked in to an active Daily Tracking session. It stops when you check out.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const PremiumSectionTitle(
                            title: 'Who receives this data',
                          ),
                          const SizedBox(height: 12),
                          _DisclosureBullet(
                            icon: Icons.business_rounded,
                            text:
                                'Location data is shared only with your employer for attendance, route tracking, and reporting.',
                          ),
                          const SizedBox(height: 10),
                          _DisclosureBullet(
                            icon: Icons.block_rounded,
                            text:
                                'It is not used for advertising and is not sold to third parties.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.primary,
                          foregroundColor: scheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('I understand and agree'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Not now'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisclosureBullet extends StatelessWidget {
  const _DisclosureBullet({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: scheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: scheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
