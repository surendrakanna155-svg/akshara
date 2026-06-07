import 'analytics_service.dart';

class NoOpAnalyticsService implements AnalyticsService {
  const NoOpAnalyticsService();

  @override
  void logEvent(String name, {Map<String, String>? parameters}) {}

  @override
  void setUserProperty(String name, String value) {}

  @override
  void setUserId(String? userId) {}
}
