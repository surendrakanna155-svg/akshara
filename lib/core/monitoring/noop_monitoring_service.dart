import 'monitoring_service.dart';

/// No-op monitoring for development, tests, and production until adapter wired.
class NoOpMonitoringService implements MonitoringService {
  const NoOpMonitoringService();

  @override
  void recordError(
    Object error, {
    StackTrace? stackTrace,
    String? context,
    Map<String, String>? tags,
  }) {}

  @override
  void recordEvent(String name, {Map<String, String>? properties}) {}

  @override
  void recordMetric(String name, double value, {Map<String, String>? tags}) {}
}
