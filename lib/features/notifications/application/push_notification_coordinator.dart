import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_options.dart';
import '../../../core/providers/network_providers.dart';
import '../data/push_notification_support.dart';
import '../presentation/providers/notifications_provider.dart';

/// Registers FCM listeners, shows heads-up notifications, syncs device token with API.
class PushNotificationCoordinator {
  PushNotificationCoordinator._();
  static final PushNotificationCoordinator instance = PushNotificationCoordinator._();

  static const String _androidChannelId = 'high_importance_channel';

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedSub;
  Timer? _tokenRetryTimer;

  WidgetRef? _ref;
  bool _firebaseReady = false;

  /// Call after login (from [PushNotificationsBinding]) or after token refresh.
  Future<void> attach(WidgetRef ref) async {
    await detach();
    _ref = ref;

    await _initLocalNotifications();
    final ready = await _ensureFirebaseReady();
    if (!ready) return;

    final dio = ref.read(dioProvider);
    await registerTokenWithBackend(dio);

    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((t) {
      unawaited(_putFcmToken(dio, t));
    });

    _onMessageSub = FirebaseMessaging.onMessage.listen((message) async {
      await persistRemoteMessageIfApplicable(message);
      _ref?.invalidate(notificationsProvider);
      await _showHeadsUp(message);
    });

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      await persistRemoteMessageIfApplicable(initial);
      ref.invalidate(notificationsProvider);
    }

    _onOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      await persistRemoteMessageIfApplicable(message);
      _ref?.invalidate(notificationsProvider);
    });
  }

  Future<void> detach() async {
    _tokenRetryTimer?.cancel();
    await _tokenRefreshSub?.cancel();
    await _onMessageSub?.cancel();
    await _onOpenedSub?.cancel();
    _tokenRetryTimer = null;
    _tokenRefreshSub = null;
    _onMessageSub = null;
    _onOpenedSub = null;
    _ref = null;
  }

  /// Syncs the device FCM token with `/users/fcm-token` when authenticated.
  Future<void> registerTokenWithBackend(Dio dio) async {
    if (!_firebaseReady) {
      final ready = await _ensureFirebaseReady();
      if (!ready) return;
    }
    try {
      final t = await FirebaseMessaging.instance.getToken();
      if (t != null && t.isNotEmpty) {
        final synced = await _putFcmToken(dio, t);
        if (synced) return;
      }
    } catch (e) {
      debugPrint('FCM getToken: $e');
    }
    _scheduleTokenRetry(dio);
  }

  Future<bool> _ensureFirebaseReady() async {
    if (_firebaseReady) return true;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } catch (e) {
      debugPrint('Firebase init failed: $e');
      return false;
    }

    try {
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('FCM permission: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('FCM requestPermission: $e');
    }

    if (!kIsWeb && Platform.isAndroid) {
      final impl = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await impl?.requestNotificationsPermission();
    }

    _firebaseReady = true;
    return true;
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const init = InitializationSettings(android: androidInit);
    await _local.initialize(settings: init);

    if (!kIsWeb && Platform.isAndroid) {
      final impl = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await impl?.createNotificationChannel(
        const AndroidNotificationChannel(
          _androidChannelId,
          'High Importance Notifications',
          description: 'Visit reminders and account alerts.',
          importance: Importance.max,
        ),
      );
    }
  }

  void _scheduleTokenRetry(Dio dio, {int attempt = 1}) {
    if (attempt > 6) return;
    _tokenRetryTimer?.cancel();
    _tokenRetryTimer = Timer(Duration(seconds: attempt * 3), () async {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null && token.isNotEmpty) {
          final synced = await _putFcmToken(dio, token);
          if (synced) return;
        }
      } catch (e) {
        debugPrint('FCM token retry failed: $e');
      }
      _scheduleTokenRetry(dio, attempt: attempt + 1);
    });
  }

  Future<bool> _putFcmToken(Dio dio, String token) async {
    try {
      await dio.put<dynamic>('/users/fcm-token', data: {'fcm_token': token});
      debugPrint('FCM token registered with backend (${token.length} chars)');
      return true;
    } catch (e) {
      debugPrint('FCM token sync failed: $e');
      return false;
    }
  }

  Future<void> _showHeadsUp(RemoteMessage message) async {
    final n = message.notification;
    final data = message.data;

    final title = (n?.title?.isNotEmpty == true)
        ? n!.title!
        : data['title']?.toString();
    final body =
        (n?.body?.isNotEmpty == true) ? n!.body! : data['body']?.toString();

    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    final resolvedTitle =
        (title != null && title.isNotEmpty) ? title : 'Notification';
    final resolvedBody = body ?? '';

    if (!kIsWeb && Platform.isAndroid) {
      await _local.show(
        id: message.hashCode,
        title: resolvedTitle,
        body: resolvedBody,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannelId,
            'High Importance Notifications',
            channelDescription: 'Visit reminders and account alerts.',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
      return;
    }

    if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      await _local.show(
        id: message.hashCode,
        title: resolvedTitle,
        body: resolvedBody,
        notificationDetails: const NotificationDetails(
          iOS: DarwinNotificationDetails(),
        ),
      );
    }
  }
}
