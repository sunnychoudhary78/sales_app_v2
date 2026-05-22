import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notifications_local_store.dart';

class NotificationsRepository {
  NotificationsRepository(this._local);

  final NotificationsLocalStore _local;

  /// Same-day filter as legacy [NotificationController.loadNotifications].
  Future<List<Map<String, dynamic>>> fetchForUser(String userId) async {
    if (userId.isEmpty) return const [];

    final rows = await _local.getNotificationsForUser(userId);
    final normalized = rows.map(_normalizeLocalRow).where(_isReceivedToday).toList();
    return normalized;
  }

  Future<void> markAsRead(int id, {required String userId}) async {
    await _local.markAsRead(id, userId: userId);
  }
}

Map<String, dynamic> _normalizeLocalRow(Map<String, dynamic> r) {
  final isReadInt = r['isRead'] is int ? r['isRead'] as int : int.tryParse('${r['isRead']}') ?? 0;
  return {
    'id': r['id'],
    'title': r['title']?.toString() ?? 'Notification',
    'body': r['body']?.toString() ?? '',
    'receivedAt': r['receivedAt']?.toString() ?? '',
    'type': r['type']?.toString(),
    'visitId': r['visitId']?.toString(),
    'is_read': isReadInt == 1,
  };
}

bool _isReceivedToday(Map<String, dynamic> n) {
  final raw = n['receivedAt']?.toString();
  if (raw == null || raw.isEmpty) return false;
  final d = DateTime.tryParse(raw)?.toLocal();
  if (d == null) return false;
  final now = DateTime.now();
  return d.year == now.year && d.month == now.month && d.day == now.day;
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(NotificationsLocalStore.instance);
});
