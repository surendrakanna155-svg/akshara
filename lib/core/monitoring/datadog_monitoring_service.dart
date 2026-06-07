import 'monitoring_service.dart';
import 'vendor_monitoring_config.dart';
import 'vendor_monitoring_transport.dart';

/// Datadog adapter for the vendor-agnostic [MonitoringService] contract.
class DatadogMonitoringService implements MonitoringService {
  DatadogMonitoringService({
    required VendorMonitoringConfig config,
    VendorMonitoringTransport transport = const NoOpVendorMonitoringTransport(),
  })  : _config = config,
        _transport = transport;

  final VendorMonitoringConfig _config;
  final VendorMonitoringTransport _transport;

  @override
  void recordError(
    Object error, {
    StackTrace? stackTrace,
    String? context,
    Map<String, String>? tags,
  }) {
    _send(
      type: 'error',
      name: error.runtimeType.toString(),
      attributes: {
        'message': error.toString(),
        if (context != null) 'context': context,
        if (stackTrace != null) 'stackTrace': stackTrace.toString(),
        ...?tags,
      },
    );
  }

  @override
  void recordEvent(String name, {Map<String, String>? properties}) {
    _send(type: 'event', name: name, attributes: properties ?? const {});
  }

  @override
  void recordMetric(String name, double value, {Map<String, String>? tags}) {
    _send(
      type: 'metric',
      name: name,
      attributes: {
        'value': '$value',
        ...?tags,
      },
    );
  }

  void _send({
    required String type,
    required String name,
    required Map<String, String> attributes,
  }) {
    if (!_config.hasCredentials) return;
    _transport.send(
      VendorMonitoringPayload(
        vendor: 'datadog',
        type: type,
        name: name,
        attributes: {
          'clientTokenConfigured': 'true',
          'site': _config.datadogSite,
          if (_config.environment.isNotEmpty)
            'environment': _config.environment,
          if (_config.release.isNotEmpty) 'release': _config.release,
          ...attributes,
        },
      ),
    );
  }
}
