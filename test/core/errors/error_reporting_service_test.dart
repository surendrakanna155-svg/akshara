import 'package:akshara_erp/core/analytics/analytics_service.dart';
import 'package:akshara_erp/core/audit/audit_event.dart';
import 'package:akshara_erp/core/audit/audit_logger.dart';
import 'package:akshara_erp/core/errors/error_reporting_service.dart';
import 'package:akshara_erp/core/monitoring/monitoring_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecordingMonitoringService implements MonitoringService {
  final recordedErrors = <({
    Object error,
    StackTrace? stackTrace,
    String? context,
  })>[];
  final recordedEvents = <({
    String name,
    Map<String, String>? properties,
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
  void recordEvent(String name, {Map<String, String>? properties}) {
    recordedEvents.add((name: name, properties: properties));
  }

  @override
  void recordMetric(String name, double value, {Map<String, String>? tags}) {}
}

class RecordingAnalyticsService implements AnalyticsService {
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
  late RecordingMonitoringService monitoring;
  late RecordingAnalyticsService analytics;
  late AuditLogger auditLogger;
  late ErrorReportingService reporting;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    monitoring = RecordingMonitoringService();
    analytics = RecordingAnalyticsService();
    auditLogger = AuditLogger(prefs);
    reporting = ErrorReportingService(
      monitoring: monitoring,
      analytics: analytics,
      auditLogger: auditLogger,
    );
  });

  group('ErrorReportingService', () {
    test('reportFlutterError records monitoring, analytics, and audit', () async {
      final details = FlutterErrorDetails(
        exception: Exception('framework failure'),
        stack: StackTrace.current,
        library: 'rendering',
      );

      reporting.reportFlutterError(details);
      await pumpEventQueue();

      expect(monitoring.recordedErrors, hasLength(1));
      expect(monitoring.recordedErrors.first.error, details.exception);
      expect(monitoring.recordedErrors.first.stackTrace, details.stack);
      expect(monitoring.recordedErrors.first.context, 'flutter.framework');

      expect(analytics.loggedEvents, hasLength(1));
      expect(analytics.loggedEvents.first.name, 'error.flutter');
      expect(analytics.loggedEvents.first.parameters, {'library': 'rendering'});

      final auditEvents = await auditLogger.readByType(AuditEventType.errorReported);
      expect(auditEvents, hasLength(1));
      expect(auditEvents.first.metadata['source'], 'flutter.framework');
    });

    test('reportFlutterError uses unknown library when null', () {
      final details = FlutterErrorDetails(
        exception: Exception('framework failure'),
        stack: StackTrace.current,
        library: null,
      );

      reporting.reportFlutterError(details);

      expect(analytics.loggedEvents.single.parameters, {'library': 'unknown'});
    });

    test('reportZoneError records monitoring, analytics, and audit', () async {
      final error = Exception('zone failure');
      final stack = StackTrace.current;

      reporting.reportZoneError(error, stack);
      await pumpEventQueue();

      expect(monitoring.recordedErrors.single.error, error);
      expect(monitoring.recordedErrors.single.stackTrace, stack);
      expect(monitoring.recordedErrors.single.context, 'zone');
      expect(analytics.loggedEvents.single.name, 'error.zone');

      final auditEvents = await auditLogger.readByType(AuditEventType.errorReported);
      expect(auditEvents.single.metadata['source'], 'zone');
    });

    test('reportProviderError records monitoring and analytics', () {
      final provider = Provider<int>((ref) => 1);
      final error = Exception('provider failure');
      final stack = StackTrace.current;

      reporting.reportProviderError(error, stack, provider);

      expect(monitoring.recordedErrors.single.error, error);
      expect(monitoring.recordedErrors.single.stackTrace, stack);
      expect(
        monitoring.recordedErrors.single.context,
        'riverpod:${provider.name ?? provider.runtimeType}',
      );
      expect(analytics.loggedEvents.single.name, 'error.provider');
      expect(
        analytics.loggedEvents.single.parameters,
        {'provider': provider.name ?? provider.runtimeType.toString()},
      );
    });

    test('reportApiFailure records monitoring and analytics with optional fields', () {
      reporting.reportApiFailure(
        path: '/finance/invoices',
        statusCode: 503,
        correlationId: 'corr-1',
        message: 'Service unavailable',
      );

      expect(monitoring.recordedEvents.single.name, 'api.failure');
      expect(
        monitoring.recordedEvents.single.properties,
        {
          'path': '/finance/invoices',
          'statusCode': '503',
          'correlationId': 'corr-1',
          'message': 'Service unavailable',
        },
      );
      expect(analytics.loggedEvents.single.name, 'error.api');
      expect(
        analytics.loggedEvents.single.parameters,
        {
          'path': '/finance/invoices',
          'status': '503',
          'correlationId': 'corr-1',
        },
      );
    });

    test('reportApiFailure omits null optional fields', () {
      reporting.reportApiFailure(path: '/sis/students', statusCode: null);

      expect(monitoring.recordedEvents.single.properties, {'path': '/sis/students'});
      expect(analytics.loggedEvents.single.parameters, {'path': '/sis/students'});
    });

    test('reportRepositoryError records monitoring and analytics', () {
      final error = Exception('repository failure');

      reporting.reportRepositoryError(error, operation: 'fetchStudents');

      expect(monitoring.recordedErrors.single.error, error);
      expect(monitoring.recordedErrors.single.context, 'repository:fetchStudents');
      expect(analytics.loggedEvents.single.name, 'error.repository');
      expect(analytics.loggedEvents.single.parameters, {'operation': 'fetchStudents'});
    });

    test('reportRepositoryError uses default context without operation', () {
      reporting.reportRepositoryError(Exception('repository failure'));

      expect(monitoring.recordedErrors.single.context, 'repository');
      expect(analytics.loggedEvents.single.parameters, isEmpty);
    });
  });
}
