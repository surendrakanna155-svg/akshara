/// Supported production monitoring vendors.
enum MonitoringVendor {
  none,
  sentry,
  datadog,
}

/// Environment-driven vendor monitoring configuration.
class VendorMonitoringConfig {
  const VendorMonitoringConfig({
    required this.vendor,
    this.sentryDsn = '',
    this.datadogClientToken = '',
    this.datadogSite = 'datadoghq.com',
    this.environment = '',
    this.release = '',
  });

  factory VendorMonitoringConfig.fromDartDefine() {
    const rawVendor = String.fromEnvironment(
      'MONITORING_VENDOR',
      defaultValue: 'none',
    );
    return VendorMonitoringConfig(
      vendor: _parseVendor(rawVendor),
      sentryDsn: const String.fromEnvironment('SENTRY_DSN'),
      datadogClientToken: const String.fromEnvironment('DATADOG_CLIENT_TOKEN'),
      datadogSite: const String.fromEnvironment(
        'DATADOG_SITE',
        defaultValue: 'datadoghq.com',
      ),
      environment: const String.fromEnvironment('APP_ENV'),
      release: const String.fromEnvironment('APP_RELEASE'),
    );
  }

  final MonitoringVendor vendor;
  final String sentryDsn;
  final String datadogClientToken;
  final String datadogSite;
  final String environment;
  final String release;

  bool get hasCredentials => switch (vendor) {
        MonitoringVendor.sentry => sentryDsn.trim().isNotEmpty,
        MonitoringVendor.datadog => datadogClientToken.trim().isNotEmpty,
        MonitoringVendor.none => false,
      };

  bool get isVendorEnabled => vendor != MonitoringVendor.none && hasCredentials;

  static MonitoringVendor _parseVendor(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'sentry' => MonitoringVendor.sentry,
      'datadog' => MonitoringVendor.datadog,
      _ => MonitoringVendor.none,
    };
  }
}
