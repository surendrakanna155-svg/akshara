import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/environment.dart';
import '../config/environment_provider.dart';
import '../analytics/analytics_service.dart';
import '../analytics/debug_analytics_service.dart';
import '../analytics/noop_analytics_service.dart';
import '../monitoring/datadog_monitoring_service.dart';
import '../monitoring/debug_monitoring_service.dart';
import '../monitoring/monitoring_service.dart';
import '../monitoring/noop_monitoring_service.dart';
import '../monitoring/sentry_monitoring_service.dart';
import '../monitoring/vendor_monitoring_config.dart';

/// Feature flags for observability subsystems.
class ObservabilityConfig {
  const ObservabilityConfig({
    required this.enableMonitoring,
    required this.enableAnalytics,
    required this.enableErrorReporting,
    required this.vendorConfig,
  });

  factory ObservabilityConfig.forEnvironment(
    Environment environment, {
    VendorMonitoringConfig vendorConfig =
        const VendorMonitoringConfig(vendor: MonitoringVendor.none),
  }) {
    final vendorEnabled = vendorConfig.isVendorEnabled;
    return ObservabilityConfig(
      enableMonitoring: environment.enableLogging || vendorEnabled,
      enableAnalytics: environment.enableLogging,
      enableErrorReporting: true,
      vendorConfig: vendorConfig,
    );
  }

  final bool enableMonitoring;
  final bool enableAnalytics;
  final bool enableErrorReporting;
  final VendorMonitoringConfig vendorConfig;
}

final vendorMonitoringConfigProvider = Provider<VendorMonitoringConfig>((ref) {
  return VendorMonitoringConfig.fromDartDefine();
});

final observabilityConfigProvider = Provider<ObservabilityConfig>((ref) {
  return ObservabilityConfig.forEnvironment(
    ref.watch(environmentProvider),
    vendorConfig: ref.watch(vendorMonitoringConfigProvider),
  );
});

final monitoringServiceProvider = Provider<MonitoringService>((ref) {
  final config = ref.watch(observabilityConfigProvider);
  if (!config.enableMonitoring) return const NoOpMonitoringService();
  return switch (config.vendorConfig.vendor) {
    MonitoringVendor.sentry when config.vendorConfig.hasCredentials =>
      SentryMonitoringService(config: config.vendorConfig),
    MonitoringVendor.datadog when config.vendorConfig.hasCredentials =>
      DatadogMonitoringService(config: config.vendorConfig),
    _ => const DebugMonitoringService(),
  };
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  final config = ref.watch(observabilityConfigProvider);
  if (!config.enableAnalytics) return const NoOpAnalyticsService();
  return const DebugAnalyticsService();
});
