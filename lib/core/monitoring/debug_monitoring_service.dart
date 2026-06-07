import 'package:flutter/foundation.dart';

import 'monitoring_service.dart';

/// Console logging monitor for development diagnostics.
class DebugMonitoringService implements MonitoringService {
  const DebugMonitoringService();

  @override
  void recordError(
    Object error, {
    StackTrace? stackTrace,
    String? context,
    Map<String, String>? tags,
  }) {
    debugPrint(
      '[Monitoring] error${context != null ? ' ($context)' : ''}: $error',
    );
  }

  @override
  void recordEvent(String name, {Map<String, String>? properties}) {
    debugPrint('[Monitoring] event=$name props=$properties');
  }

  @override
  void recordMetric(String name, double value, {Map<String, String>? tags}) {
    debugPrint('[Monitoring] metric=$name value=$value tags=$tags');
  }
}
