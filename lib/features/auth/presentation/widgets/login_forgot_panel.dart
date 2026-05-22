import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/global_loading_provider.dart';
import '../../../../shared/utils/user_feedback.dart';
import '../providers/auth_provider.dart';

/// Forgot password (email → OTP → new password) inside the login glass shell.
class LoginForgotPanel extends ConsumerStatefulWidget {
  const LoginForgotPanel({super.key, required this.onResetComplete});

  /// After a successful password reset, parent animates back to the password form.
  final VoidCallback onResetComplete;

  @override
  ConsumerState<LoginForgotPanel> createState() => _LoginForgotPanelState();
}

class _LoginForgotPanelState extends ConsumerState<LoginForgotPanel> {
  final _formKey = GlobalKey<FormState>();
  final _loginCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  late final List<TextEditingController> _otpCtrls;
  late final List<FocusNode> _otpNodes;

  bool _otpStep = false;
  bool _loading = false;
  String _otpError = '';
  String _formError = '';
  String _formSuccess = '';
  bool _hideNewPass = true;

  static const _textSecondary = Color(0xE6FFFFFF);

  @override
  void initState() {
    super.initState();
    _otpCtrls = List.generate(6, (_) => TextEditingController());
    _otpNodes = List.generate(6, (_) => FocusNode());
  }

  @override
  void dispose() {
    _loginCtrl.dispose();
    _newPassCtrl.dispose();
    for (final c in _otpCtrls) {
      c.dispose();
    }
    for (final n in _otpNodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _otpJoined => _otpCtrls.map((e) => e.text).join();

  void _otpFromBoxesSync() {
    setState(() => _otpError = '');
  }

  String? _validateLogin(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email or mobile is required';
    if (v.contains('@')) {
      final emailOk = RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v);
      return emailOk ? null : 'Enter a valid email';
    }
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return 'Enter a valid mobile number';
    return null;
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    final regex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^\da-zA-Z]).{8,15}$');
    return regex.hasMatch(value) ? null : 'Min 8 chars, 1 upper, 1 lower, 1 number, 1 special';
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _formError = '';
      _formSuccess = '';
    });
    try {
      await ref.read(authProvider.notifier).requestForgotPasswordOtp(login: _loginCtrl.text);
      if (!mounted) return;
      setState(() {
        _otpStep = true;
        _otpError = '';
        _formSuccess = 'OTP sent successfully';
      });
      for (final c in _otpCtrls) {
        c.clear();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _otpNodes.first.requestFocus();
      });
    } catch (e) {
      if (mounted) {
        setState(() => _formError = formatUserFacingError(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    final otp = _otpJoined.trim();
    if (otp.length != 6) {
      setState(() => _otpError = 'OTP must be 6 digits');
      return;
    }
    setState(() {
      _otpError = '';
      _formError = '';
      _formSuccess = '';
      _loading = true;
    });
    try {
      await ref.read(authProvider.notifier).resetPasswordWithOtp(
            login: _loginCtrl.text,
            otp: otp,
            newPassword: _newPassCtrl.text,
          );
      if (!mounted) return;
      ref.read(globalLoadingProvider.notifier).showMessage(
        'Password reset successfully. Please sign in.',
      );
      widget.onResetComplete();
    } catch (e) {
      if (mounted) {
        final msg = formatUserFacingError(e);
        if (msg.toLowerCase().contains('otp')) {
          setState(() => _otpError = msg);
        } else {
          setState(() => _formError = msg);
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Form(
      key: _formKey,
      child: _otpStep ? _otpBody(context, scheme) : _emailBody(context, scheme),
    );
  }

  List<Widget> _feedbackTexts(BuildContext context, ColorScheme scheme) {
    if (_formError.isEmpty && _formSuccess.isEmpty) return const [];

    return [
      const SizedBox(height: 12),
      if (_formError.isNotEmpty)
        Text(
          _formError,
          style: TextStyle(color: scheme.error, fontSize: 13, height: 1.3),
        ),
      if (_formSuccess.isNotEmpty)
        Text(
          _formSuccess,
          style: TextStyle(
            color: Colors.greenAccent.shade200,
            fontSize: 13,
            height: 1.3,
          ),
        ),
    ];
  }

  Widget _emailBody(BuildContext context, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter your mobile or email and we will send an OTP to reset your password.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: _textSecondary,
              ),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _loginCtrl,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(
            labelText: 'Mobile / Email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          validator: _validateLogin,
        ),
        ..._feedbackTexts(context, scheme),
        const SizedBox(height: 24),
        SizedBox(
          height: 46,
          child: ElevatedButton(
            onPressed: _loading ? null : _sendOtp,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _loading
                ? SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: scheme.onPrimary),
                  )
                : const Text('Send OTP'),
          ),
        ),
      ],
    );
  }

  Widget _otpBody(BuildContext context, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton.icon(
          onPressed: () {
            setState(() {
              _otpStep = false;
              _otpError = '';
              _formError = '';
              _formSuccess = '';
            });
          },
          icon: Icon(Icons.arrow_back_rounded, size: 18, color: scheme.primary),
          label: Text(
            'Change email / mobile',
            style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          'Enter OTP sent to ${_loginCtrl.text}',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: _textSecondary,
              ),
        ),
        const SizedBox(height: 16),
        Row(
          children: List.generate(6, (i) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                child: TextField(
                  controller: _otpCtrls[i],
                  focusNode: _otpNodes[i],
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _otpError.isNotEmpty
                            ? scheme.error
                            : Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: scheme.primary, width: 2),
                    ),
                  ),
                  onChanged: (v) {
                    if (v.length > 1) {
                      final last = v.substring(v.length - 1);
                      _otpCtrls[i].text = last;
                      _otpCtrls[i].selection = TextSelection.collapsed(offset: 1);
                    }
                    _otpFromBoxesSync();
                    if (v.isNotEmpty && i < 5) {
                      _otpNodes[i + 1].requestFocus();
                    } else if (v.isEmpty && i > 0) {
                      _otpNodes[i - 1].requestFocus();
                    }
                  },
                ),
              ),
            );
          }),
        ),
        if (_otpError.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_otpError, style: TextStyle(color: scheme.error, fontSize: 13)),
        ],
        ..._feedbackTexts(context, scheme),
        const SizedBox(height: 16),
        TextFormField(
          controller: _newPassCtrl,
          style: const TextStyle(color: Colors.white),
          obscureText: _hideNewPass,
          decoration: InputDecoration(
            labelText: 'New password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _hideNewPass = !_hideNewPass),
              icon: Icon(_hideNewPass ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            ),
            helperText: 'Min 8 chars, 1 upper, 1 lower, 1 number, 1 special',
            helperStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11),
          ),
          validator: _validateNewPassword,
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 46,
          child: ElevatedButton(
            onPressed: _loading ? null : _resetPassword,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _loading
                ? SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: scheme.onPrimary),
                  )
                : const Text('Reset password'),
          ),
        ),
      ],
    );
  }
}
