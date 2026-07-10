import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/storage_keys.dart';

class LocationDisclosureStore {
  LocationDisclosureStore(this._prefs);

  final SharedPreferences _prefs;

  Future<bool> isAccepted(String userId) async {
    if (userId.isEmpty) return false;
    return _prefs.getBool(StorageKeys.locationTrackingDisclosureAccepted(userId)) ??
        false;
  }

  Future<void> markAccepted(String userId) async {
    if (userId.isEmpty) return;
    await _prefs.setBool(
      StorageKeys.locationTrackingDisclosureAccepted(userId),
      true,
    );
  }

  /// Intentional reset only — e.g. when disclosure copy changes (bump key version).
  Future<void> resetForUser(String userId) async {
    if (userId.isEmpty) return;
    await _prefs.remove(StorageKeys.locationTrackingDisclosureAccepted(userId));
  }
}
