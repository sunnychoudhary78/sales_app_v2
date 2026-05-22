import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'storage_keys.dart';

class UserStorage {
  Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.userJson, jsonEncode(user));
  }

  Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.userJson);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.userJson);
    await prefs.remove(StorageKeys.trackingSessionId);
    await prefs.remove(StorageKeys.checkInTime);
    await prefs.remove(StorageKeys.lastLatitude);
    await prefs.remove(StorageKeys.lastLongitude);
  }

  Future<void> saveValue(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<String?> getValue(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}

