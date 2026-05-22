import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/utils/user_feedback.dart';
import '../providers/auth_provider.dart';
import '../widgets/login_brand_panel.dart';
import '../widgets/login_forgot_panel.dart';
import '../widgets/login_glass_shell.dart';
import '../widgets/login_otp_panel.dart';
import '../widgets/login_password_panel.dart';
import '../widgets/login_tracking_background.dart';

/// Which auth form is shown inside the shared login shell.
enum LoginAuthPage {
  password,
  otp,
  forgot,
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.initialPage = LoginAuthPage.password});

  final LoginAuthPage initialPage;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController loginCtrl;
  late final TextEditingController passCtrl;
  late final AnimationController _bgCtrl;

  bool _hidePassword = true;
  String _loginError = '';
  int _pageIndex = 0;
  int _otpKey = 0;
  int _forgotKey = 0;

  static const _switchDuration = Duration(milliseconds: 220);
  static const Curve _switchCurve = Curves.easeOutCubic;

  @override
  void initState() {
    super.initState();
    loginCtrl = TextEditingController();
    passCtrl = TextEditingController();
    _pageIndex = widget.initialPage.index;
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    loginCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  String get _shellTitle {
    switch (_pageIndex) {
      case 1:
        return 'Login with OTP';
      case 2:
        return 'Reset password';
      default:
        return '';
    }
  }

  void _goOtp() {
    setState(() => _pageIndex = 1);
  }

  void _goForgot() {
    setState(() => _pageIndex = 2);
  }

  void _goPassword({bool resetAux = false}) {
    setState(() {
      _pageIndex = 0;
      if (resetAux) {
        _otpKey++;
        _forgotKey++;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loginError = '');
    try {
      await ref.read(authProvider.notifier).loginWithPassword(
            login: loginCtrl.text,
            password: passCtrl.text,
          );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loginError = formatUserFacingError(e));
    }
  }

  Widget _authPanelBody() {
    switch (_pageIndex) {
      case 1:
        return LoginOtpPanel(key: ValueKey(_otpKey));
      case 2:
        return LoginForgotPanel(
          key: ValueKey(_forgotKey),
          onResetComplete: () => _goPassword(resetAux: true),
        );
      default:
        return LoginPasswordPanel(
          formKey: _formKey,
          loginCtrl: loginCtrl,
          passCtrl: passCtrl,
          hidePassword: _hidePassword,
          loginError: _loginError,
          isLoading: ref.watch(authProvider).isAuthenticating,
          onTogglePassword: () => setState(() => _hidePassword = !_hidePassword),
          onSubmit: _submit,
          onLoginWithOtp: () {
            setState(() => _loginError = '');
            _goOtp();
          },
          onForgotPassword: () {
            setState(() => _loginError = '');
            _goForgot();
          },
        );
    }
  }

  Widget _animatedPanelSwitcher() {
    return AnimatedSwitcher(
      duration: _switchDuration,
      switchInCurve: _switchCurve,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) {
        return Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.hardEdge,
          children: <Widget>[
            ...previous,
            ?current,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(parent: animation, curve: _switchCurve);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(_pageIndex),
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: _authPanelBody(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 940;
    final maxCardHeight = math.min(
      480.0,
      math.max(320.0, MediaQuery.sizeOf(context).height * 0.46),
    );

    final shell = RepaintBoundary(
      child: LoginGlassAuthShell(
        showBack: _pageIndex != 0,
        onBack: _pageIndex == 0 ? null : () => _goPassword(resetAux: true),
        headerTitle: _shellTitle,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxCardHeight),
          child: _animatedPanelSwitcher(),
        ),
      ),
    );

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: LoginTrackingBackground(animation: _bgCtrl),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Expanded(flex: 11, child: LoginBrandPanel()),
                            const SizedBox(width: 20),
                            Expanded(flex: 9, child: shell),
                          ],
                        )
                      : shell,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
