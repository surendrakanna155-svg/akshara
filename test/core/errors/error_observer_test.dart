import 'package:akshara_erp/core/analytics/analytics_service.dart';
import 'package:akshara_erp/core/audit/audit_logger.dart';
import 'package:akshara_erp/core/errors/error_observer.dart';
import 'package:akshara_erp/core/errors/error_reporting_service.dart';
import 'package:akshara_erp/core/monitoring/monitoring_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingMonitoringService implements MonitoringService {
  final recordedErrors = <({
    Object error,
    StackTrace? stackTrace,
    String? context,
  })>[];

  @override
  void recordError(
    Object error, {
    StackTrace? stackTrace,
    String? context,
    Map<String, String>? tags,
  }) {
    recordedErrors.add((error: error, stackTrace: stackTrace, context: context));
  }

  @override
  void recordEvent(String name, {Map<String, String>? properties}) {}

  @override
  void recordMetric(String name, double value, {Map<String, String>? tags}) {}
}

class _RecordingAnalyticsService implements AnalyticsService {
  final loggedEvents = <({
    String name,
    Map<String, String>? parameters,
  })>[];

  @override
  void logEvent(String name, {Map<String, String>? parameters}) {
    loggedEvents.add((name: name, parameters: parameters));
  }

  @override
  void setUserProperty(String name, String value) {}

  @override
  void setUserId(String? userId) {}
}

void main() {
  late _RecordingMonitoringService monitoring;
  late _RecordingAnalyticsService analytics;
  late ErrorReportingService reporting;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    monitoring = _RecordingMonitoringService();
    analytics = _RecordingAnalyticsService();
    reporting = ErrorReportingService(
      monitoring: monitoring,
      analytics: analytics,
      auditLogger: AuditLogger(prefs),
    );
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('AksharaErrorObserver', () {
    test('providerDidFail reports provider errors', () {
      final provider = Provider<String>((ref) => 'ok');
      final error = StateError('provider failed');
      final stack = StackTrace.current;
      final observer = AksharaErrorObserver(reporting);

      observer.providerDidFail(provider, error, stack, container);

      expect(monitoring.recordedErrors, hasLength(1));
      expect(monitoring.recordedErrors.first.error, error);
      expect(monitoring.recordedErrors.first.stackTrace, stack);
      expect(
        monitoring.recordedErrors.first.context,
        'riverpod:${provider.name ?? provider.runtimeType}',
      );
      expect(analytics.loggedEvents.single.name, 'error.provider');
      expect(
        analytics.loggedEvents.single.parameters,
        {'provider': provider.name ?? provider.runtimeType.toString()},
      );
    });
  });
}
