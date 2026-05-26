import 'dart:ui';

import 'package:flutter/material.dart';

/// Frosted glass card shared by password / OTP / forgot flows on the login screen.
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

  static InputDecorationTheme inputTheme(ColorScheme scheme) {
    final inputFill = Colors.white.withValues(alpha: 0.06);
    final inputBorder = Colors.white.withValues(alpha: 0.22);
    return InputDecorationTheme(
      filled: true,
      fillColor: inputFill,
      labelStyle: const TextStyle(color: Color(0xFFE5E7EB)),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
      prefixIconColor: const Color(0xFFD1D5DB),
      suffixIconColor: const Color(0xFFD1D5DB),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFF87171)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFF87171), width: 1.2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final panelColor = Color.lerp(scheme.primary, Colors.black, 0.84)!.withValues(alpha: 0.48);
    const textColor = Colors.white;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: panelColor,
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Theme(
              data: theme.copyWith(
                inputDecorationTheme: inputTheme(scheme),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showBack && onBack != null) ...[
                    Row(
                      children: [
                        IconButton(
                          onPressed: onBack,
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          color: textColor.withValues(alpha: 0.92),
                          tooltip: 'Back',
                        ),
                        Expanded(
                          child: Text(
                            headerTitle ?? '',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: textColor,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  SizedBox(
                    height: 70,
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'IMT-Tracking',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Track. Perform. Grow',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.86),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 12),
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
