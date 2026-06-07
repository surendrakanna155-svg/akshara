import 'package:akshara_erp/core/monitoring/datadog_monitoring_service.dart';
import 'package:akshara_erp/core/monitoring/debug_monitoring_service.dart';
import 'package:akshara_erp/core/monitoring/noop_monitoring_service.dart';
import 'package:akshara_erp/core/monitoring/sentry_monitoring_service.dart';
import 'package:akshara_erp/core/monitoring/vendor_monitoring_config.dart';
import 'package:akshara_erp/core/monitoring/vendor_monitoring_transport.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingVendorMonitoringTransport implements VendorMonitoringTransport {
  final payloads = <VendorMonitoringPayload>[];

  @override
  void send(VendorMonitoringPayload payload) {
    payloads.add(payload);
  }
}

void main() {
  test('NoOpMonitoringService records nothing', () {
    const service = NoOpMonitoringService();
    expect(() => service.recordError(Exception('test')), returnsNormally);
    expect(() => service.recordEvent('test'), returnsNormally);
    expect(() => service.recordMetric('latency', 1.0), returnsNormally);
  });

  test('DebugMonitoringService accepts calls', () {
    const service = DebugMonitoringService();
    expect(() => service.recordError(Exception('test'), context: 'unit'),
        returnsNormally);
    expect(() => service.recordEvent('app.start'), returnsNormally);
  });

  group('SentryMonitoringService', () {
    test('sends errors, events, and metrics when DSN is configured', () {
      final transport = _RecordingVendorMonitoringTransport();
      final service = SentryMonitoringService(
        config: const VendorMonitoringConfig(
          vendor: MonitoringVendor.sentry,
          sentryDsn: 'https://example@sentry.io/1',
          environment: 'staging',
          release: 'v5.5',
        ),
        transport: transport,
      );

      service.recordError(
        Exception('boom'),
        context: 'unit',
        tags: {'module': 'core'},
      );
      service.recordEvent('app.start', properties: {'surface': 'erp'});
      service.recordMetric('api.latency', 42, tags: {'path': '/health'});

      expect(transport.payloads, hasLength(3));
      expect(transport.payloads.first.vendor, 'sentry');
      expect(transport.payloads.first.type, 'error');
      expect(transport.payloads.first.attributes['dsnConfigured'], 'true');
      expect(transport.payloads.first.attributes['environment'], 'staging');
      expect(transport.payloads.first.attributes['release'], 'v5.5');
      expect(transport.payloads.first.attributes['context'], 'unit');
      expect(transport.payloads.first.attributes['module'], 'core');
      expect(transport.payloads[1].name, 'app.start');
      expect(transport.payloads[2].attributes['value'], '42.0');
    });

    test('missing DSN drops payloads without throwing', () {
      final transport = _RecordingVendorMonitoringTransport();
      final service = SentryMonitoringService(
        config: const VendorMonitoringConfig(vendor: MonitoringVendor.sentry),
        transport: transport,
      );

      expect(() => service.recordError(Exception('boom')), returnsNormally);
      expect(() => service.recordEvent('app.start'), returnsNormally);
      expect(() => service.recordMetric('api.latency', 42), returnsNormally);
      expect(transport.payloads, isEmpty);
    });
  });

  group('DatadogMonitoringService', () {
    test('sends errors, events, and metrics when token is configured', () {
      final transport = _RecordingVendorMonitoringTransport();
      final service = DatadogMonitoringService(
        config: const VendorMonitoringConfig(
          vendor: MonitoringVendor.datadog,
          datadogClientToken: 'token',
          datadogSite: 'datadoghq.eu',
          environment: 'production',
          release: 'v5.5',
        ),
        transport: transport,
      );

      service.recordError(
        StateError('boom'),
        context: 'unit',
        tags: {'module': 'core'},
      );
      service.recordEvent('app.start', properties: {'surface': 'erp'});
      service.recordMetric('api.latency', 42, tags: {'path': '/health'});

      expect(transport.payloads, hasLength(3));
      expect(transport.payloads.first.vendor, 'datadog');
      expect(transport.payloads.first.type, 'error');
      expect(
          transport.payloads.first.attributes['clientTokenConfigured'], 'true');
      expect(transport.payloads.first.attributes['site'], 'datadoghq.eu');
      expect(transport.payloads.first.attributes['environment'], 'production');
      expect(transport.payloads.first.attributes['release'], 'v5.5');
      expect(transport.payloads.first.attributes['context'], 'unit');
      expect(transport.payloads.first.attributes['module'], 'core');
      expect(transport.payloads[1].name, 'app.start');
      expect(transport.payloads[2].attributes['value'], '42.0');
    });

    test('missing token drops payloads without throwing', () {
      final transport = _RecordingVendorMonitoringTransport();
      final service = DatadogMonitoringService(
        config: const VendorMonitoringConfig(vendor: MonitoringVendor.datadog),
        transport: transport,
      );

      expect(() => service.recordError(Exception('boom')), returnsNormally);
      expect(() => service.recordEvent('app.start'), returnsNormally);
      expect(() => service.recordMetric('api.latency', 42), returnsNormally);
      expect(transport.payloads, isEmpty);
    });
  });

  group('VendorMonitoringConfig', () {
    test('enables Sentry only when DSN is present', () {
      expect(
        const VendorMonitoringConfig(vendor: MonitoringVendor.sentry)
            .isVendorEnabled,
        isFalse,
      );
      expect(
        const VendorMonitoringConfig(
          vendor: MonitoringVendor.sentry,
          sentryDsn: 'dsn',
        ).isVendorEnabled,
        isTrue,
      );
    });

    test('enables Datadog only when client token is present', () {
      expect(
        const VendorMonitoringConfig(vendor: MonitoringVendor.datadog)
            .isVendorEnabled,
        isFalse,
      );
      expect(
        const VendorMonitoringConfig(
          vendor: MonitoringVendor.datadog,
          datadogClientToken: 'token',
        ).isVendorEnabled,
        isTrue,
      );
    });
  });
}
