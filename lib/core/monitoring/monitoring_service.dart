/// Vendor-agnostic monitoring contract.
///
/// Adapter implementations (Sentry, Datadog, etc.) implement this interface.
abstract class MonitoringService {
  void recordError(
    Object error, {
    StackTrace? stackTrace,
    String? context,
    Map<String, String>? tags,
  });

  void recordEvent(String name, {Map<String, String>? properties});

  void recordMetric(String name, double value, {Map<String, String>? tags});
}
