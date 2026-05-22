import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'api_constants.dart';

class DioClient {
  final Dio dio;

  DioClient({
    required TokenStorage tokenStorage,
    required Future<void> Function() onUnauthorized,
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
          final isAuthSensitive = e.requestOptions.path.contains('/auth/login') ||
              e.requestOptions.path.contains('/auth/change-password');
          if (!isAuthSensitive && e.response?.statusCode == 401) {
            await onUnauthorized();
          }
          handler.next(e);
        },
      ),
    );
  }
}

