import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_constants.dart';
import '../../../../core/providers/network_providers.dart';
import '../../../../core/providers/user_data_invalidation.dart';
import '../../../../core/storage/storage_keys.dart';
import '../../../../main.dart';
import '../../../notifications/application/push_notification_coordinator.dart';
import '../../../tracking/data/background_tracking_service.dart';
import 'auth_state.dart';

class AuthNotifier extends Notifier<AuthState> {
  bool _isLoggingOut = false;

  @override
  AuthState build() => const AuthState.initial();

  String _sanitizeAuthMessage(String raw) {
    var s = raw.trim();
    if (s.startsWith('Exception:')) {
      s = s.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
    }
    if (RegExp(r'535|5\.7\.8|gsmtp|badcredentials|username and password not accepted',
            caseSensitive: false)
        .hasMatch(s)) {
      return 'Could not send email. If your account has a mobile number, use it for an SMS OTP, '
          'or ask your administrator to fix email settings.';
    }
    return s;
  }

  String _dioErrorMessage(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return _sanitizeAuthMessage(data['message'].toString());
    }
    return fallback;
  }

  Future<void> _persistLoginBody(Map<String, dynamic> body) async {
    final token = (body['SALES_JWT_TOKEN'] ?? body['token'])?.toString();
    final user = body['user'];

    if (token == null || token.isEmpty) {
      throw Exception('Token not found in response');
    }

    if (user is! Map) {
      throw Exception('User data not found in response');
    }

    final rawUser = Map<String, dynamic>.from(user);

    final role = rawUser['role'];
    if (role is Map && role['can_login_mobile'] != true) {
      throw Exception('You do not have permission to login to the mobile app');
    }

    final tokenStorage = ref.read(tokenStorageProvider);
    final userStorage = ref.read(userStorageProvider);
    await tokenStorage.saveJwt(token);
    await userStorage.saveUser(rawUser);

    final name = (rawUser['name'] ?? rawUser['full_name'] ?? 'User').toString();
    final userId = (rawUser['id'] ?? rawUser['user_id'] ?? '0').toString();
    final email = rawUser['email']?.toString();

    state = AuthState(
      isInitializing: false,
      isAuthenticating: false,
      profile: AuthProfile(userId: userId, name: name, email: email),
      rawUser: rawUser,
    );

    Future.microtask(() async {
      try {
        final dio = ref.read(dioProvider);
        await PushNotificationCoordinator.instance.registerTokenWithBackend(dio);
      } catch (_) {}
    });
  }

  Future<void> tryAutoLogin() async {
    state = state.copyWith(isInitializing: true);

    try {
      final tokenStorage = ref.read(tokenStorageProvider);
      final userStorage = ref.read(userStorageProvider);

      final token = await tokenStorage.getJwt();
      final rawUser = await userStorage.getUser();

      if (token != null && token.isNotEmpty && rawUser != null) {
        final name =
            (rawUser['name'] ?? rawUser['full_name'] ?? 'User').toString();
        final userId = (rawUser['id'] ?? rawUser['user_id'] ?? '0').toString();
        final email = rawUser['email']?.toString();

        state = AuthState(
          isInitializing: false,
          isAuthenticating: false,
          profile: AuthProfile(userId: userId, name: name, email: email),
          rawUser: rawUser,
        );

        Future.microtask(() async {
          try {
            final dio = ref.read(dioProvider);
            await PushNotificationCoordinator.instance
                .registerTokenWithBackend(dio);
          } catch (_) {}
        });
        return;
      }
    } catch (_) {
      try {
        await ref.read(tokenStorageProvider).clear();
        await ref.read(userStorageProvider).clear();
      } catch (_) {}
    }

    state = const AuthState(
      isInitializing: false,
      isAuthenticating: false,
      profile: null,
      rawUser: null,
    );
  }

  Future<void> loginWithPassword({
    required String login,
    required String password,
  }) async {
    state = state.copyWith(isAuthenticating: true);

    final dio = ref.read(dioProvider);

    try {
      final res = await dio.post<dynamic>(
        ApiConstants.login,
        data: {
          'login': login.trim(),
          'password': password.trim(),
        },
      );

      final raw = res.data;
      if (raw is! Map) {
        state = state.copyWith(isAuthenticating: false);
        throw Exception('Invalid response from server');
      }

      await _persistLoginBody(Map<String, dynamic>.from(raw));
    } on DioException catch (e) {
      state = state.copyWith(isAuthenticating: false);
      throw Exception(_dioErrorMessage(e, 'Invalid email or password'));
    } catch (_) {
      state = state.copyWith(isAuthenticating: false);
      rethrow;
    }
  }

  /// Sends OTP for passwordless login; does not change [AuthState.profile].
  Future<void> requestLoginOtp({required String login}) async {
    final dio = ref.read(dioProvider);
    try {
      await dio.post<dynamic>(
        ApiConstants.loginOtpRequest,
        data: {'login': login.trim()},
      );
    } on DioException catch (e) {
      throw Exception(_dioErrorMessage(e, 'Failed to send OTP'));
    }
  }

  Future<void> verifyLoginOtp({
    required String login,
    required String otp,
  }) async {
    state = state.copyWith(isAuthenticating: true);
    final dio = ref.read(dioProvider);

    try {
      final res = await dio.post<dynamic>(
        ApiConstants.loginOtpVerify,
        data: {
          'login': login.trim(),
          'otp': otp.trim(),
        },
      );

      final raw = res.data;
      if (raw is! Map) {
        state = state.copyWith(isAuthenticating: false);
        throw Exception('Invalid response from server');
      }

      await _persistLoginBody(Map<String, dynamic>.from(raw));
    } on DioException catch (e) {
      state = state.copyWith(isAuthenticating: false);
      throw Exception(_dioErrorMessage(e, 'OTP verification failed'));
    } catch (_) {
      state = state.copyWith(isAuthenticating: false);
      rethrow;
    }
  }

  Future<void> requestForgotPasswordOtp({required String login}) async {
    final dio = ref.read(dioProvider);
    try {
      await dio.post<dynamic>(
        ApiConstants.forgotPassword,
        data: {'login': login.trim()},
      );
    } on DioException catch (e) {
      throw Exception(_dioErrorMessage(e, 'Could not send reset OTP'));
    }
  }

  Future<void> resetPasswordWithOtp({
    required String login,
    required String otp,
    required String newPassword,
  }) async {
    final dio = ref.read(dioProvider);
    try {
      await dio.post<dynamic>(
        ApiConstants.resetPassword,
        data: {
          'login': login.trim(),
          'otp': otp.trim(),
          'newPassword': newPassword.trim(),
        },
      );
    } on DioException catch (e) {
      throw Exception(_dioErrorMessage(e, 'Could not reset password'));
    }
  }

  Future<void> logout() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    try {
      // Update UI first so authenticated screens disappear immediately.
      state = const AuthState(
        isInitializing: false,
        isAuthenticating: false,
        profile: null,
        rawUser: null,
      );
      invalidateAllUserScopedData(ref);
      _returnToLoginRoot();

      try {
        final dio = ref.read(dioProvider);
        await dio.put<dynamic>('/users/fcm-token', data: {'fcm_token': null});
      } catch (_) {}

      try {
        await PushNotificationCoordinator.instance.detach();
      } catch (_) {}

      try {
        final userStorage = ref.read(userStorageProvider);
        final sessionId =
            await userStorage.getValue(StorageKeys.trackingSessionId);
        await ref
            .read(backgroundTrackingServiceProvider)
            .stopTracking(overrideSessionId: sessionId);
      } catch (_) {}

      final tokenStorage = ref.read(tokenStorageProvider);
      final userStorage = ref.read(userStorageProvider);
      await tokenStorage.clear();
      await userStorage.clear();

      invalidateAllUserScopedData(ref);
      _returnToLoginRoot();
    } finally {
      _isLoggingOut = false;
    }
  }

  void _returnToLoginRoot() {
    Future.microtask(() {
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
    });
  }

  /// Persists a new profile picture URL (after [uploadProfilePhoto] or from server).
  Future<void> applyProfilePictureUrl(String imageUrl) async {
    final current = state.rawUser;
    if (current == null) return;

    final updated = Map<String, dynamic>.from(current)
      ..['profile_picture'] = imageUrl;

    final userStorage = ref.read(userStorageProvider);
    await userStorage.saveUser(updated);

    final name = (updated['name'] ?? updated['full_name'] ?? 'User').toString();
    final userId = (updated['id'] ?? updated['user_id'] ?? '0').toString();
    final email = updated['email']?.toString();

    state = AuthState(
      isInitializing: false,
      isAuthenticating: false,
      profile: AuthProfile(userId: userId, name: name, email: email),
      rawUser: updated,
    );
  }

  /// POST multipart to legacy `employee-photo/photo` endpoint (same as sales_app).
  Future<void> uploadProfilePhoto(File imageFile) async {
    final dio = ref.read(dioProvider);
    final formData = FormData.fromMap({
      'photo': await MultipartFile.fromFile(
        imageFile.path,
        filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ),
    });

    final res = await dio.post<dynamic>(
      ApiConstants.uploadProfilePhoto,
      data: formData,
    );

    final raw = res.data;
    if (raw is! Map) {
      throw Exception('Invalid response from server');
    }
    if (raw['success'] != true) {
      throw Exception(raw['message']?.toString() ?? 'Upload failed');
    }
    final data = raw['data'];
    if (data is! Map) {
      throw Exception('Invalid upload payload');
    }
    final url = (data['image_url'] ?? data['profile_picture'])?.toString();
    if (url == null || url.isEmpty) {
      throw Exception('No image URL returned');
    }
    await applyProfilePictureUrl(url);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

