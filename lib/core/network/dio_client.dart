import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'api_constants.dart';

bool _isSubscriptionInactive(DioException e) {
  if (e.response?.statusCode != 403) return false;
  final data = e.response?.data;
  if (data is Map && data['code'] == 'SUBSCRIPTION_INACTIVE') return true;
  return false;
}

bool _isAuthSensitivePath(String path) {
  return path.contains('/auth/login') ||
      path.contains('/auth/login-otp') ||
      path.contains('/auth/change-password');
}

class DioClient {
  final Dio dio;

  DioClient({
    required TokenStorage tokenStorage,
    required Future<void> Function() onUnauthorized,
    required Future<void> Function(String message) onSubscriptionInactive,
  }) : dio = Dio(
          BaseOptions(
            baseUrl: ApiConstants.baseUrl,
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 45),
            sendTimeout: const Duration(seconds: 45),
            contentType: 'application/json',
            headers: const {
              'Content-Type': 'application/json',
              'x-client-type': 'mobile',
            },
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokenStorage.getJwt();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'SALES_JWT_TOKEN $token';
          }
          handler.next(options);
        },
        onError: (e, handler) async {
          final path = e.requestOptions.path;
          final isAuthSensitive = _isAuthSensitivePath(path);

          if (!isAuthSensitive && e.response?.statusCode == 401) {
            await onUnauthorized();
          } else if (!isAuthSensitive && _isSubscriptionInactive(e)) {
            final data = e.response?.data;
            final message = data is Map && data['message'] != null
                ? data['message'].toString()
                : 'Company subscription is inactive or expired';
            await onSubscriptionInactive(message);
          }
          handler.next(e);
        },
      ),
    );
  }
}
