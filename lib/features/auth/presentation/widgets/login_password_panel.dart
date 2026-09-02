import 'package:flutter/material.dart';

class LoginPasswordPanel extends StatelessWidget {
  const LoginPasswordPanel({
    super.key,
    required this.formKey,
    required this.loginCtrl,
    required this.passCtrl,
    required this.hidePassword,
    this.loginError = '',
    required this.isLoading,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.onLoginWithOtp,
    required this.onForgotPassword,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController loginCtrl;
  final TextEditingController passCtrl;
  final bool hidePassword;
  final String loginError;
  final bool isLoading;

  final VoidCallback onTogglePassword;
  final Future<void> Function() onSubmit;
  final VoidCallback onLoginWithOtp;
  final VoidCallback onForgotPassword;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final textColor = scheme.onSurface;
    final mutedTextColor = scheme.onSurfaceVariant;

    final fieldColor = isDark
        ? scheme.surfaceContainerHighest.withOpacity(0.45)
        : scheme.surfaceContainerHighest.withOpacity(0.65);

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          /// Mobile / Email Field
          _LoginTextField(
            controller: loginCtrl,
            label: 'Mobile / Email',
            hint: 'Enter your mobile or email',
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
            fieldColor: fieldColor,
            scheme: scheme,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Enter mobile or email';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          /// Password Field
          _LoginTextField(
            controller: passCtrl,
            label: 'Password',
            hint: 'Enter your password',
            icon: Icons.lock_outline_rounded,
            obscureText: hidePassword,
            fieldColor: fieldColor,
            scheme: scheme,
            suffix: IconButton(
              onPressed: onTogglePassword,
              icon: Icon(
                hidePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: mutedTextColor,
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Enter password';
              }

              if (value.trim().length < 6) {
                return 'Password must be at least 6 characters';
              }

              return null;
            },
          ),

          /// Forgot Password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: isLoading ? null : onForgotPassword,
              style: TextButton.styleFrom(
                foregroundColor: scheme.primary,
                padding: const EdgeInsets.only(
                  top: 10,
                  bottom: 10,
                ),
              ),
              child: const Text(
                'Forgot Password?',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          /// Error Message
          if (loginError.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: scheme.onErrorContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      loginError,
                      style: TextStyle(
                        color: scheme.onErrorContainer,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),

          /// Sign In Button
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: isLoading ? null : () => onSubmit(),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isLoading
                    ? SizedBox(
                        key: const ValueKey('loading'),
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: scheme.onPrimary,
                        ),
                      )
                    : Row(
                        key: const ValueKey('signin'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 20,
                          ),
                        ],
                      ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          /// Divider
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: scheme.outlineVariant,
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'OR',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: mutedTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              Expanded(
                child: Divider(
                  color: scheme.outlineVariant,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          /// Login with OTP
          OutlinedButton.icon(
            onPressed: isLoading ? null : onLoginWithOtp,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: scheme.primary,
              side: BorderSide(
                color: scheme.primary.withOpacity(0.45),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(Icons.phone_android_rounded),
            label: const Text(
              'Login with OTP',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginTextField extends StatelessWidget {
  const _LoginTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.fieldColor,
    required this.scheme,
    required this.validator,
    this.textInputAction,
    this.obscureText = false,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Color fieldColor;
  final ColorScheme scheme;
  final String? Function(String?) validator;

  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: textInputAction,
      style: TextStyle(
        color: scheme.onSurface,
        fontWeight: FontWeight.w500,
      ),
      cursorColor: scheme.primary,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,

        filled: true,
        fillColor: fieldColor,

        prefixIcon: Icon(
          icon,
          color: scheme.primary,
        ),

        suffixIcon: suffix,

        labelStyle: TextStyle(
          color: scheme.onSurfaceVariant,
        ),

        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withOpacity(0.7),
        ),

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
            color: scheme.outlineVariant.withOpacity(0.5),
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
      ),
    );
  }
}