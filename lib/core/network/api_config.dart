import '../config/environment.dart';

/// HTTP header names and timeout defaults for Dio clients.
abstract final class ApiConfig {
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const String apiVersionHeader = 'X-Api-Version';
  static const String apiVersion = '1';
  static const String tenantIdHeader = 'X-Tenant-Id';
  static const String schoolIdHeader = 'X-School-Id';
  static const String organizationIdHeader = 'X-Organization-Id';
  static const String userIdHeader = 'X-User-Id';
  static const String correlationIdHeader = 'X-Correlation-Id';

  /// Default base URL for the active environment (no hardcoded placeholder host).
  static String defaultBaseUrl([Environment? environment]) {
    return (environment ?? Environment.development).apiBaseUrl;
  }
}
