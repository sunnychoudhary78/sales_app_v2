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

  static const _textColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: loginCtrl,
            style: const TextStyle(color: _textColor),
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Mobile / Email',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter mobile or email' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: passCtrl,
            style: const TextStyle(color: _textColor),
            obscureText: hidePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: onTogglePassword,
                icon: Icon(
                  hidePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter password';
              if (v.trim().length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          if (loginError.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              loginError,
              style: TextStyle(color: scheme.error, fontSize: 13, height: 1.3),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : () => onSubmit(),
              icon: Icon(isLoading ? Icons.hourglass_top_rounded : Icons.login_rounded),
              label: Text(isLoading ? 'Signing in...' : 'Sign in'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onLoginWithOtp,
                      child: Text(
                        'Login with OTP',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: onForgotPassword,
                      child: Text(
                        'Forgot Password?',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
