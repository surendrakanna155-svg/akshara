/// REST paths for the Auth API module.
abstract final class AuthApiPaths {
  static const String base = '/auth';

  static const String login = '$base/login';
  static const String verifyOtp = '$base/verify-otp';
  static const String refresh = '$base/refresh';
  static const String logout = '$base/logout';
  static const String me = '$base/me';
  static const String permissions = '$base/permissions';
  static const String revokeSession = '$base/sessions/revoke';
  static const String logoutAllSessions = '$base/sessions/logout-all';
}
