import 'package:akshara_erp/core/config/environment.dart';
import 'package:akshara_erp/core/config/environment_provider.dart';
import 'package:akshara_erp/core/monitoring/datadog_monitoring_service.dart';
import 'package:akshara_erp/core/monitoring/debug_monitoring_service.dart';
import 'package:akshara_erp/core/monitoring/noop_monitoring_service.dart';
import 'package:akshara_erp/core/monitoring/sentry_monitoring_service.dart';
import 'package:akshara_erp/core/monitoring/vendor_monitoring_config.dart';
import 'package:akshara_erp/core/observability/operational_metrics_registry.dart';
import 'package:akshara_erp/core/observability/observability_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('operational metrics registry has core metrics', () {
    expect(operationalMetricCount, greaterThanOrEqualTo(8));
    expect(
      kOperationalMetrics.map((m) => m.id),
      contains('audit.queue.pending_count'),
    );
  });

  group('monitoringServiceProvider', () {
    test('uses debug monitoring in logging-enabled development', () {
      final container = ProviderContainer(
        overrides: [
          environmentProvider.overrideWith((ref) => Environment.development),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(monitoringServiceProvider),
          isA<DebugMonitoringService>());
    });

    test('uses no-op monitoring in production without vendor credentials', () {
      final container = ProviderContainer(
        overrides: [
          environmentProvider.overrideWith((ref) => Environment.production),
          vendorMonitoringConfigProvider.overrideWith(
            (ref) => const VendorMonitoringConfig(
              vendor: MonitoringVendor.sentry,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(monitoringServiceProvider),
          isA<NoOpMonitoringService>());
    });

    test('uses Sentry adapter when configured', () {
      final container = ProviderContainer(
        overrides: [
          environmentProvider.overrideWith((ref) => Environment.production),
          vendorMonitoringConfigProvider.overrideWith(
            (ref) => const VendorMonitoringConfig(
              vendor: MonitoringVendor.sentry,
              sentryDsn: 'https://example@sentry.io/1',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(monitoringServiceProvider),
          isA<SentryMonitoringService>());
    });

    test('uses Datadog adapter when configured', () {
      final container = ProviderContainer(
        overrides: [
          environmentProvider.overrideWith((ref) => Environment.production),
          vendorMonitoringConfigProvider.overrideWith(
            (ref) => const VendorMonitoringConfig(
              vendor: MonitoringVendor.datadog,
              datadogClientToken: 'token',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(monitoringServiceProvider),
          isA<DatadogMonitoringService>());
    });
  });
}
