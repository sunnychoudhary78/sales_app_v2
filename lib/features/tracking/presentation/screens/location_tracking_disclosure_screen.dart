import 'package:flutter/material.dart';

import '../../../../shared/widgets/premium_shell.dart';

/// Full-screen disclosure shown before Daily Tracking location permissions.
///
/// All colors are derived from the application's ColorScheme so this screen
/// automatically follows the selected primary color and light/dark theme.
class LocationTrackingDisclosureScreen extends StatelessWidget {
  const LocationTrackingDisclosureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: scheme.surfaceContainerLowest,
        appBar: const SalesGlassAppBar(
          title: 'Location for daily tracking',
          showNotificationAction: false,
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  children: [
                    /// HERO SECTION
                    _HeroCard(scheme: scheme, textTheme: textTheme),

                    const SizedBox(height: 16),

                    /// WHAT WE COLLECT
                    _DisclosureSection(
                      title: 'What we collect',
                      sectionIcon: Icons.gps_fixed_rounded,
                      children: const [
                        _DisclosureItem(
                          icon: Icons.my_location_rounded,
                          title: 'Precise location',
                          description:
                              'We collect your precise GPS location during an active check-in session.',
                        ),
                        _DisclosureItem(
                          icon: Icons.route_rounded,
                          title: 'Your field route',
                          description:
                              'Your precise location is recorded to build your field route.',
                        ),
                        _DisclosureItem(
                          icon: Icons.phone_android_rounded,
                          title: 'Background tracking',
                          description:
                              'Location may be collected while the app is in the background or when your screen is off.',
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    /// WHY AND WHEN
                    _DisclosureSection(
                      title: 'Why and when',
                      sectionIcon: Icons.schedule_rounded,
                      children: const [
                        _DisclosureItem(
                          icon: Icons.route_rounded,
                          title: 'Track your workday',
                          description:
                              'This helps record your field route, distance travelled, and visit-related mileage.',
                        ),
                        _DisclosureItem(
                          icon: Icons.timer_outlined,
                          title: 'Only during check-in',
                          description:
                              'Location is collected only while you are checked in to an active Daily Tracking session.',
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    /// WHO RECEIVES DATA
                    _DisclosureSection(
                      title: 'Who receives this data',
                      sectionIcon: Icons.shield_outlined,
                      children: const [
                        _DisclosureItem(
                          icon: Icons.business_rounded,
                          title: 'Your employer',
                          description:
                              'Location data is shared only with your employer for attendance, route tracking, and reporting.',
                        ),
                        _DisclosureItem(
                          icon: Icons.privacy_tip_outlined,
                          title: 'Your privacy',
                          description:
                              'Your location is not used for advertising and is not sold to third parties.',
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    /// PRIVACY / TRUST MESSAGE
                    _PrivacyNotice(scheme: scheme, textTheme: textTheme),
                  ],
                ),
              ),

              /// BOTTOM ACTIONS
              SafeArea(
                top: false,
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    border: Border(
                      top: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 54,
                        child: FilledButton.icon(
                          onPressed: () => Navigator.of(context).pop(true),
                          icon: const Icon(
                            Icons.verified_user_rounded,
                            size: 20,
                          ),
                          label: const Text('I understand and agree'),
                          style: FilledButton.styleFrom(
                            backgroundColor: scheme.primary,
                            foregroundColor: scheme.onPrimary,
                            elevation: 0,
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(false),
                          icon: const Icon(Icons.schedule_rounded, size: 19),
                          label: const Text('Not now'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: scheme.primary,
                            side: BorderSide(
                              color: scheme.primary.withValues(alpha: 0.6),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
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

/// ---------------------------------------------------------------------------
/// HERO CARD
/// ---------------------------------------------------------------------------
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.scheme,
    required this.textTheme,
  });

  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 180,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: scheme.primary.withValues(alpha: 0.08),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.15),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              /// LEFT: MAP ILLUSTRATION
              SizedBox(
                width: constraints.maxWidth * 0.30,
                child: _MapIllustration(
                  scheme: scheme,
                ),
              ),

              const SizedBox(width: 10),

              /// CENTER: HERO TEXT
              Expanded(
                child: _HeroText(
                  scheme: scheme,
                  textTheme: textTheme,
                ),
              ),

              const SizedBox(width: 8),

              /// RIGHT: SHIELD BADGE
              // SizedBox(
              //   width: 42,
              //   child: Align(
              //     alignment: Alignment.topRight,
              //     child: _ShieldBadge(
              //       scheme: scheme,
              //     ),
              //   ),
              // ),
            ],
          );
        },
      ),
    );
  }
}



class _HeroText extends StatelessWidget {
  const _HeroText({required this.scheme, required this.textTheme});

  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Help us track\nyour work better',
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Please read this before allowing location access for Daily Tracking.',
          style: textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _MapIllustration extends StatelessWidget {
  const _MapIllustration({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      width: 100,
      child: Image.asset(
        'assets/map.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Icon(
                Icons.location_on_rounded,
                size: 48,
                color: scheme.primary,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// SECTION CARD
/// ---------------------------------------------------------------------------

class _DisclosureSection extends StatelessWidget {
  const _DisclosureSection({
    required this.title,
    required this.sectionIcon,
    required this.children,
  });

  final String title;
  final IconData sectionIcon;
  final List<_DisclosureItem> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(sectionIcon, color: scheme.primary, size: 22),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) ...[
              const SizedBox(height: 14),
              Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 14),
            ],
          ],
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// DISCLOSURE ITEM
/// ---------------------------------------------------------------------------

class _DisclosureItem extends StatelessWidget {
  const _DisclosureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: scheme.primary, size: 21),
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                description,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// PRIVACY NOTICE
/// ---------------------------------------------------------------------------

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice({required this.scheme, required this.textTheme});

  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.privacy_tip_rounded,
              color: scheme.primary,
              size: 22,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your privacy matters',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'Location tracking automatically stops when you check out of your Daily Tracking session.',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
