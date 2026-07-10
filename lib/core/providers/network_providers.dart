import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_client.dart';
import '../storage/token_storage.dart';
import '../storage/user_storage.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage();
});

final userStorageProvider = Provider<UserStorage>((ref) {
  return UserStorage();
});

final dioClientProvider = Provider<DioClient>((ref) {
  final tokenStorage = ref.read(tokenStorageProvider);
  return DioClient(
    tokenStorage: tokenStorage,
    onUnauthorized: () async {
      await ref.read(authProvider.notifier).logout();
    },
    onSubscriptionInactive: (message) async {
      await ref.read(authProvider.notifier).storeSubscriptionInactiveMessage(message);
      await ref.read(authProvider.notifier).logout();
    },
  );
});

final dioProvider = Provider<Dio>((ref) {
  return ref.read(dioClientProvider).dio;
});
