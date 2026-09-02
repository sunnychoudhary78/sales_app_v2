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
enum LoginAuthPage { password, otp, forgot }

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
  String? _subscriptionBanner;
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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final msg = await ref
          .read(authProvider.notifier)
          .consumeSubscriptionInactiveMessage();
      if (!mounted || msg == null || msg.isEmpty) return;
      setState(() => _subscriptionBanner = msg);
    });
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
      await ref
          .read(authProvider.notifier)
          .loginWithPassword(login: loginCtrl.text, password: passCtrl.text);
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
          onTogglePassword: () =>
              setState(() => _hidePassword = !_hidePassword),
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
          children: <Widget>[...previous, ?current],
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    final size = MediaQuery.sizeOf(context);

    final isWide = size.width >= 940;
    final isDark = brightness == Brightness.dark;

    final primary = colorScheme.primary;
    final secondary = colorScheme.secondary;
    final surface = colorScheme.surface;

    final backgroundStart = isDark
        ? Color.alphaBlend(primary.withOpacity(0.20), const Color(0xFF0B1020))
        : Color.alphaBlend(primary.withOpacity(0.12), surface);

    final backgroundEnd = isDark
        ? const Color(0xFF111827)
        : colorScheme.surface;

    final maxCardHeight = math.min(500.0, math.max(320.0, size.height * 0.52));

    final shell = RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: surface.withOpacity(isDark ? 0.72 : 0.88),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: colorScheme.outlineVariant.withOpacity(isDark ? 0.35 : 0.55),
          ),
          boxShadow: [
            BoxShadow(
              color: primary.withOpacity(isDark ? 0.16 : 0.10),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: LoginGlassAuthShell(
            showBack: _pageIndex != 0,
            onBack: _pageIndex == 0 ? null : () => _goPassword(resetAux: true),
            headerTitle: _shellTitle,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxCardHeight),
              child: _animatedPanelSwitcher(),
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: backgroundEnd,
      body: Stack(
        children: [
          /// Main theme gradient background
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    backgroundStart,
                    backgroundEnd,
                    isDark ? const Color(0xFF0B1020) : colorScheme.surface,
                  ],
                ),
              ),
            ),
          ),

          /// Top abstract shape like reference image
          Positioned(
            top: -size.width * 0.25,
            right: -size.width * 0.25,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: -0.35,
                child: Container(
                  width: isWide ? 420 : size.width * 0.75,
                  height: isWide ? 300 : size.width * 0.55,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    gradient: LinearGradient(
                      colors: [
                        primary.withOpacity(0.85),
                        secondary.withOpacity(0.55),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          /// Bottom decorative glow
          Positioned(
            bottom: -120,
            left: -80,
            child: IgnorePointer(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withOpacity(isDark ? 0.16 : 0.08),
                ),
              ),
            ),
          ),

          /// Subscription banner
          if (_subscriptionBanner != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: MaterialBanner(
                  backgroundColor: colorScheme.errorContainer,
                  leading: Icon(
                    Icons.warning_amber_rounded,
                    color: colorScheme.onErrorContainer,
                  ),
                  content: Text(
                    _subscriptionBanner!,
                    style: TextStyle(color: colorScheme.onErrorContainer),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _subscriptionBanner = null;
                        });
                      },
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              ),
            ),

          /// Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 40 : 20,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1150),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Expanded(flex: 11, child: LoginBrandPanel()),

                            const SizedBox(width: 48),

                            Expanded(flex: 9, child: shell),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            /// Mobile branding
                            Padding(
                              padding: const EdgeInsets.only(bottom: 28),
                              child: Icon(
                                Icons.location_on_rounded,
                                size: 48,
                                color: primary,
                              ),
                            ),

                            shell,
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
