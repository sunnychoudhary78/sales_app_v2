import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/storage/storage_keys.dart';

/// Local SQLite store for in-app notification history (same idea as legacy sales_app).
class NotificationsLocalStore {
  NotificationsLocalStore._();
  static final NotificationsLocalStore instance = NotificationsLocalStore._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'sales_tracking_notifications.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE notifications(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            userId TEXT NOT NULL,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            type TEXT NOT NULL,
            visitId TEXT,
            receivedAt TEXT NOT NULL,
            isRead INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_notifications_user_received ON notifications(userId, receivedAt DESC)',
        );
      },
    );
  }

  Future<String?> _currentUserIdFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.userJson);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final m = Map<String, dynamic>.from(decoded);
      return (m['id'] ?? m['user_id'])?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Used from FCM background isolate (no Riverpod): resolve user id from persisted login.
  Future<String?> readLoggedInUserId() => _currentUserIdFromPrefs();

  Future<int> insertNotification({
    required String userId,
    required String title,
    required String body,
    String type = 'general',
    String? visitId,
    DateTime? receivedAt,
  }) async {
    final db = await database;
    return db.insert('notifications', {
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'visitId': visitId,
      'receivedAt': (receivedAt ?? DateTime.now()).toIso8601String(),
      'isRead': 0,
    });
  }

  Future<bool> hasFollowUpRowForVisit({
    required String userId,
    required String visitId,
  }) async {
    final db = await database;
    final rows = await db.query(
      'notifications',
      columns: ['id'],
      where: 'visitId = ? AND type = ? AND userId = ?',
      whereArgs: [visitId, 'followup', userId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getNotificationsForUser(String userId) async {
    final db = await database;
    return db.query(
      'notifications',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'receivedAt DESC',
    );
  }

  Future<void> markAsRead(int id, {required String userId}) async {
    final db = await database;
    await db.update(
      'notifications',
      {'isRead': 1},
      where: 'id = ? AND userId = ?',
      whereArgs: [id, userId],
    );
  }

  Future<int> unreadCount(String userId) async {
    final db = await database;
    final r = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM notifications WHERE isRead = 0 AND userId = ?',
      [userId],
    );
    if (r.isEmpty) return 0;
    return (r.first['c'] as int?) ?? 0;
  }

  /// Clears rows for user (e.g. account switch); optional — logout does not wipe history.
  Future<void> deleteAllForUser(String userId) async {
    final db = await database;
    await db.delete('notifications', where: 'userId = ?', whereArgs: [userId]);
  }
}
