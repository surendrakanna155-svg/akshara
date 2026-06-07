import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/environment.dart';
import '../config/environment_provider.dart';
import '../analytics/analytics_service.dart';
import '../analytics/debug_analytics_service.dart';
import '../analytics/noop_analytics_service.dart';
import '../monitoring/debug_monitoring_service.dart';
import '../monitoring/monitoring_service.dart';
import '../monitoring/noop_monitoring_service.dart';

/// Feature flags for observability subsystems.
class ObservabilityConfig {
  const ObservabilityConfig({
    required this.enableMonitoring,
    required this.enableAnalytics,
    required this.enableErrorReporting,
  });

  factory ObservabilityConfig.forEnvironment(Environment environment) {
    return ObservabilityConfig(
      enableMonitoring: environment.enableLogging,
      enableAnalytics: environment.enableLogging,
      enableErrorReporting: true,
    );
  }

  final bool enableMonitoring;
  final bool enableAnalytics;
  final bool enableErrorReporting;
}

final observabilityConfigProvider = Provider<ObservabilityConfig>((ref) {
  return ObservabilityConfig.forEnvironment(ref.watch(environmentProvider));
});

final monitoringServiceProvider = Provider<MonitoringService>((ref) {
  final config = ref.watch(observabilityConfigProvider);
  if (!config.enableMonitoring) return const NoOpMonitoringService();
  return const DebugMonitoringService();
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  final config = ref.watch(observabilityConfigProvider);
  if (!config.enableAnalytics) return const NoOpAnalyticsService();
  return const DebugAnalyticsService();
});
