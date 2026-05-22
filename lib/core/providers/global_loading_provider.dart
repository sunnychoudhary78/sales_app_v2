import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/utils/user_feedback.dart';

class GlobalOverlayState {
  final bool isLoading;
  final bool isSuccess;
  final bool isError;
  final bool isMessage;
  final String message;

  const GlobalOverlayState._({
    required this.isLoading,
    required this.isSuccess,
    required this.isError,
    required this.isMessage,
    required this.message,
  });

  const GlobalOverlayState.idle()
      : this._(
          isLoading: false,
          isSuccess: false,
          isError: false,
          isMessage: false,
          message: '',
        );

  const GlobalOverlayState.loading(String message)
      : this._(
          isLoading: true,
          isSuccess: false,
          isError: false,
          isMessage: false,
          message: message,
        );

  const GlobalOverlayState.success(String message)
      : this._(
          isLoading: false,
          isSuccess: true,
          isError: false,
          isMessage: false,
          message: message,
        );

  const GlobalOverlayState.error(String message)
      : this._(
          isLoading: false,
          isSuccess: false,
          isError: true,
          isMessage: false,
          message: message,
        );

  const GlobalOverlayState.message(String message)
      : this._(
          isLoading: false,
          isSuccess: false,
          isError: false,
          isMessage: true,
          message: message,
        );
}

class GlobalOverlayNotifier extends Notifier<GlobalOverlayState> {
  Timer? _hideTimer;

  @override
  GlobalOverlayState build() => const GlobalOverlayState.idle();

  void showLoading([String message = 'Please wait...']) {
    _cancelHideTimer();
    state = GlobalOverlayState.loading(message);
  }

  void showSuccess(
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _cancelHideTimer();
    state = GlobalOverlayState.success(message);
    _hideTimer = Timer(duration, clear);
  }

  void showError(
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _cancelHideTimer();
    final msg = formatUserFacingError(message);
    state = GlobalOverlayState.error(
      msg.isEmpty ? 'Something went wrong' : msg,
    );
    _hideTimer = Timer(duration, clear);
  }

  void showMessage(
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _cancelHideTimer();
    state = GlobalOverlayState.message(message);
    _hideTimer = Timer(duration, clear);
  }

  void showApiError(Object error, {Duration duration = const Duration(seconds: 3)}) {
    showError(formatUserFacingError(error), duration: duration);
  }

  void clear() {
    _cancelHideTimer();
    state = const GlobalOverlayState.idle();
  }

  void _cancelHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }
}

final globalLoadingProvider =
    NotifierProvider<GlobalOverlayNotifier, GlobalOverlayState>(
  GlobalOverlayNotifier.new,
);
