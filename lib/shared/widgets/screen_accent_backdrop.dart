import 'package:flutter/material.dart';

/// Hardcoded accents for drawer routes — blended with [ColorScheme] so seed colors
/// still drive surfaces, buttons, and app bars; these only add atmosphere.
abstract final class DrawerRouteAccents {
  static const Color visits = Color(0xFF7C3AED);
  static const Color visitsMagenta = Color(0xFFEC4899);
  static const Color addVisit = Color(0xFFEA580C);
  static const Color addVisitWarm = Color(0xFFFBBF24);
  static const Color trackingTeal = Color(0xFF0D9488);
  static const Color trackingCyan = Color(0xFF0891B2);
  static const Color products = Color(0xFF059669);
  static const Color productsSky = Color(0xFF0EA5E9);
  static const Color myClaim = Color(0xFF2563EB);
  static const Color myClaimSky = Color(0xFF38BDF8);
  static const Color claimRequests = Color(0xFFE11D48);
  static const Color claimRequestsAmber = Color(0xFFFB923C);
  static const Color settings = Color(0xFF0EA5E9);
  static const Color settingsSlate = Color(0xFF94A3B8);
  static const Color profile = Color(0xFF8B5CF6);
}

/// Soft radial + linear wash behind scrollable content. Keeps theme as source of truth.
class ScreenAccentBackdrop extends StatelessWidget {
  const ScreenAccentBackdrop({
    super.key,
    required this.child,
    this.spot,
    this.spot2,
    this.spotAlignment = const Alignment(0.82, -0.48),
    this.spot2Alignment = const Alignment(-0.74, 0.62),
  });

  final Widget child;
  final Color? spot;
  final Color? spot2;
  final Alignment spotAlignment;
  final Alignment spot2Alignment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hub = spot ?? scheme.primary;
    final rim = Color.lerp(hub, scheme.tertiary, 0.35) ?? scheme.tertiary;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: spotAlignment,
                  radius: 1.08,
                  colors: [
                    (Color.lerp(hub, scheme.primary, 0.2) ?? hub)
                        .withValues(alpha: 0.14),
                    rim.withValues(alpha: 0.065),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.44, 1.0],
                ),
              ),
            ),
          ),
        ),
        if (spot2 != null)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: spot2Alignment,
                    radius: 0.92,
                    colors: [
                      spot2!.withValues(alpha: 0.085),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.surfaceContainerLowest.withValues(alpha: 0),
                    scheme.surfaceContainerLowest,
                  ],
                  stops: const [0.0, 0.22],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
