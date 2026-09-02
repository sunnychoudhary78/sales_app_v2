import 'dart:ui';

import 'package:flutter/material.dart';

/// Modern theme-aware authentication shell.
/// Automatically adapts to Light / Dark / System mode
/// and uses the app ColorScheme.
class LoginGlassAuthShell extends StatelessWidget {
  const LoginGlassAuthShell({
    super.key,
    required this.child,
    this.showBack = false,
    this.onBack,
    this.headerTitle,
  });

  final Widget child;
  final bool showBack;
  final VoidCallback? onBack;
  final String? headerTitle;

  static InputDecorationTheme inputTheme(
    ColorScheme scheme,
    Brightness brightness,
  ) {
    final isDark = brightness == Brightness.dark;

    final inputFill = isDark
        ? scheme.surfaceContainerHighest.withOpacity(0.55)
        : scheme.surfaceContainerHighest.withOpacity(0.65);

    return InputDecorationTheme(
      filled: true,
      fillColor: inputFill,

      labelStyle: TextStyle(
        color: scheme.onSurfaceVariant,
      ),

      hintStyle: TextStyle(
        color: scheme.onSurfaceVariant.withOpacity(0.65),
      ),

      prefixIconColor: scheme.primary,
      suffixIconColor: scheme.onSurfaceVariant,

      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: scheme.outlineVariant.withOpacity(0.55),
        ),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: scheme.primary,
          width: 1.8,
        ),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: scheme.error,
        ),
      ),

      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: scheme.error,
          width: 1.8,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    /// Theme-aware glass surface
    final panelColor = isDark
        ? scheme.surface.withOpacity(0.82)
        : scheme.surface.withOpacity(0.90);

    final borderColor = isDark
        ? scheme.outlineVariant.withOpacity(0.40)
        : scheme.outlineVariant.withOpacity(0.65);

    final shadowColor = isDark
        ? Colors.black.withOpacity(0.28)
        : scheme.primary.withOpacity(0.10);

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 14,
          sigmaY: 14,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            color: panelColor,
            border: Border.all(
              color: borderColor,
            ),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),

          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              28,
              24,
              28,
              28,
            ),

            child: Theme(
              data: theme.copyWith(
                inputDecorationTheme: inputTheme(
                  scheme,
                  theme.brightness,
                ),
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  /// Back button for OTP / Forgot Password
                  if (showBack && onBack != null) ...[
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: onBack,
                            icon: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: scheme.onSurface,
                              size: 18,
                            ),
                            tooltip: 'Back',
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Text(
                            headerTitle ?? '',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),
                  ],

                  /// Logo
                  Center(
                    child: Container(
                      width: 78,
                      height: 78,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.primary.withOpacity(
                          isDark ? 0.16 : 0.10,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  /// App Name
                  Text(
                    'IMT-Tracking',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                      letterSpacing: 1.2,
                    ),
                  ),

                  const SizedBox(height: 4),

                  /// Tagline
                  Text(
                    'Track. Perform. Grow.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 26),

                  /// Password / OTP / Forgot Panel
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}