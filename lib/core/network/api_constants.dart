class ApiConstants {
  static const String baseUrl =
      'https://sales.immortaltechnovation.com/sales-api/api';

  static const String login = '/auth/login';
  static const String loginOtpRequest = '/auth/login-otp-request';
  static const String loginOtpVerify = '/auth/login-otp-verify';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String userProfile = '/auth/me';
  static const String changePassword = '/auth/change-password';

  static const String uploadProfilePhoto = '/employee-photo/photo';

  static const String visits = '/visits';

  static const String checkIn = '/tracking/sessions/check-in';
  static const String checkOut = '/tracking/sessions/check-out';
  static const String batchPoints = '/tracking/points/batch';
  static const String trackingHistory = '/tracking/my-history';
  static const String trackingHomePerformance = '/tracking/my-home/performance';
  static const String trackingHomeTimeline = '/tracking/my-home/timeline';
  static const String trackingSessionBase = '/tracking/sessions';
  static const String trackingMySessionBase = '/tracking/my-sessions';
  static const String trackingLocationOff = '/tracking/sessions/location-off';
  static const String trackingHeartbeat = '/tracking/sessions/heartbeat';

  static const String productsQuery = '/products/query';
  static const String productCategories = '/products/categories';
  static String productById(String id) => '/products/$id';
  static const String claimSettings = '/claims/settings';
}
