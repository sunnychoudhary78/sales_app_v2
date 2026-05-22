import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sms_autofill/sms_autofill.dart';

import '../../../../shared/utils/user_feedback.dart';
import '../providers/auth_provider.dart';

/// OTP request + verify inside the login glass shell (same background as password).
class LoginOtpPanel extends ConsumerStatefulWidget {
  const LoginOtpPanel({super.key});

  @override
  ConsumerState<LoginOtpPanel> createState() => _LoginOtpPanelState();
}

class _LoginOtpPanelState extends ConsumerState<LoginOtpPanel> with CodeAutoFill {
  final _loginKey = GlobalKey<FormState>();
  final _loginCtrl = TextEditingController();
  late final List<TextEditingController> _otpCtrls;
  late final List<FocusNode> _otpNodes;
  Timer? _countdownTimer;

  bool _otpPhase = false;
  int _otpSecondsLeft = 0;
  bool _sendingOtp = false;
  bool _verifyingOtp = false;
  String _otpInlineError = '';
  String _loginStepError = '';

  static const _textSecondary = Color(0xE6FFFFFF);

  @override
  void initState() {
    super.initState();
    _otpCtrls = List.generate(6, (_) => TextEditingController());
    _otpNodes = List.generate(6, (_) => FocusNode());
    listenForCode();
  }

  @override
  void dispose() {
    cancel();
    _countdownTimer?.cancel();
    _loginCtrl.dispose();
    for (final c in _otpCtrls) {
      c.dispose();
    }
    for (final n in _otpNodes) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  void codeUpdated() {
    final c = code;
    if (c == null || !_otpPhase) return;
    final digits = c.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 6) return;
    final otp = digits.substring(0, 6);
    for (var i = 0; i < 6; i++) {
      _otpCtrls[i].text = otp[i];
    }
    _submitOtp();
  }

  String get _otpJoined => _otpCtrls.map((e) => e.text).join();

  void _syncOtpFromBoxes() {
    setState(() => _otpInlineError = '');
  }

  void _startOtpTimer() {
    _countdownTimer?.cancel();
    _otpSecondsLeft = 300;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_otpSecondsLeft <= 1) {
        t.cancel();
        setState(() => _otpSecondsLeft = 0);
      } else {
        setState(() => _otpSecondsLeft--);
      }
    });
  }

  String _mmss(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _sendOtp() async {
    if (!_loginKey.currentState!.validate()) return;
    setState(() {
      _sendingOtp = true;
      _loginStepError = '';
    });
    try {
      await ref.read(authProvider.notifier).requestLoginOtp(login: _loginCtrl.text);
      if (!mounted) return;
      setState(() {
        _otpPhase = true;
        _otpInlineError = '';
        _loginStepError = '';
      });
      _startOtpTimer();
      for (final c in _otpCtrls) {
        c.clear();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _otpNodes.first.requestFocus();
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loginStepError = formatUserFacingError(e));
      }
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  Future<void> _submitOtp() async {
    final login = _loginCtrl.text.trim();
    final otp = _otpJoined.trim();
    if (otp.length != 6) {
      setState(() => _otpInlineError = 'Enter 6 digit OTP');
      return;
    }
    if (_otpSecondsLeft <= 0) {
      setState(() => _otpInlineError = 'OTP has expired. Please resend OTP.');
      return;
    }
    setState(() {
      _otpInlineError = '';
      _verifyingOtp = true;
    });
    try {
      await ref.read(authProvider.notifier).verifyLoginOtp(login: login, otp: otp);
    } catch (e) {
      if (mounted) {
        setState(() => _otpInlineError = formatUserFacingError(e));
      }
    } finally {
      if (mounted) setState(() => _verifyingOtp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return _otpPhase ? _buildOtpStep(context, scheme) : _buildLoginStep(context, scheme);
  }

  Widget _buildLoginStep(BuildContext context, ColorScheme scheme) {
    return Form(
      key: _loginKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enter mobile or email to receive an OTP.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: _textSecondary,
                ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _loginCtrl,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Mobile / Email',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter mobile or email' : null,
          ),
          if (_loginStepError.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _loginStepError,
              style: TextStyle(color: scheme.error, fontSize: 13, height: 1.3),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: _sendingOtp ? null : _sendOtp,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _sendingOtp
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Send OTP'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep(BuildContext context, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: () {
                _countdownTimer?.cancel();
                setState(() {
                  _otpPhase = false;
                  _otpSecondsLeft = 0;
                  _otpInlineError = '';
                });
              },
              icon: Icon(Icons.edit_outlined, size: 18, color: scheme.primary),
              label: Text(
                'Change',
                style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Enter OTP sent to ${_loginCtrl.text}',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: _textSecondary,
              ),
        ),
        const SizedBox(height: 20),
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
                        color: _otpInlineError.isNotEmpty
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
                    _syncOtpFromBoxes();
                    if (v.isNotEmpty && i < 5) {
                      _otpNodes[i + 1].requestFocus();
                    } else if (v.isEmpty && i > 0) {
                      _otpNodes[i - 1].requestFocus();
                    }
                    if (_otpJoined.replaceAll(RegExp(r'\s'), '').length == 6) {
                      _submitOtp();
                    }
                  },
                ),
              ),
            );
          }),
        ),
        if (_otpInlineError.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_otpInlineError, style: TextStyle(color: scheme.error, fontSize: 13)),
        ],
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _otpSecondsLeft > 0
                  ? 'OTP valid for ${_mmss(_otpSecondsLeft)}'
                  : 'OTP expired',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
            TextButton(
              onPressed: _sendingOtp ? null : _sendOtp,
              child: Text(
                _sendingOtp ? 'Sending...' : 'Resend OTP',
                style: TextStyle(fontWeight: FontWeight.w600, color: scheme.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 46,
          child: ElevatedButton(
            onPressed: _verifyingOtp ? null : _submitOtp,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _verifyingOtp
                ? SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: scheme.onPrimary),
                  )
                : const Text('Submit OTP'),
          ),
        ),
      ],
    );
  }
}
