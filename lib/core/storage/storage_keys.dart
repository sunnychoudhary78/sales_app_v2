class StorageKeys {
  static const String accessToken = 'SALES_JWT_TOKEN';
  static const String userJson = 'user_json';
  static const String trackingSessionId = 'tracking_session_id';
  static const String checkInTime = 'check_in_time';
  static const String lastLatitude = 'tracking_last_latitude';
  static const String lastLongitude = 'tracking_last_longitude';
  static const String trackingLastPointAt = 'tracking_last_point_at';

  /// `ThemeMode`: system | light | dark
  static const String themeMode = 'app_theme_mode';
  /// Primary seed color as 32-bit ARGB (`Color.toARGB32()`).
  static const String primarySeedColor = 'app_primary_seed_color';

  /// One-shot message shown on login after subscription-forced logout.
  static const String subscriptionInactiveMessage = 'subscription_inactive_message';

  /// Per-user acceptance of the Daily Tracking location disclosure (bump `_v1` to force re-show).
  static String locationTrackingDisclosureAccepted(String userId) =>
      'location_tracking_disclosure_v1_$userId';
}

