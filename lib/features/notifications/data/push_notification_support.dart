import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../core/firebase/firebase_options.dart';
import 'notifications_local_store.dart';

/// Parses FCM payload and stores one row when there is displayable text.
Future<void> persistRemoteMessageIfApplicable(RemoteMessage message) async {
  final store = NotificationsLocalStore.instance;
  final userId = await store.readLoggedInUserId();
  if (userId == null || userId.isEmpty) return;

  final notification = message.notification;
  final data = message.data;

  String? title = notification?.title;
  String? body = notification?.body;
  title ??= data['title']?.toString();
  body ??= data['body']?.toString();

  if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
    return;
  }

  final resolvedTitle = (title != null && title.isNotEmpty) ? title : 'Notification';
  final resolvedBody = body ?? '';

  final visitId = (data['visitId'] ?? data['monthKey'] ?? data['claimId'])?.toString();
  final type = (data['type'] ?? 'general').toString();

  try {
    await store.insertNotification(
      userId: userId,
      title: resolvedTitle,
      body: resolvedBody,
      type: type,
      visitId: visitId,
    );
  } catch (e, st) {
    debugPrint('Notification persist failed: $e\n$st');
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('Firebase init in background handler: $e');
    return;
  }
  await persistRemoteMessageIfApplicable(message);
}
