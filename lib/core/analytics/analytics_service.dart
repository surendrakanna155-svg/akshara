/// Vendor-agnostic product analytics contract.
abstract class AnalyticsService {
  void logEvent(String name, {Map<String, String>? parameters});

  void setUserProperty(String name, String value);

  void setUserId(String? userId);
}
