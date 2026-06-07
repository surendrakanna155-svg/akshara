import 'package:akshara_erp/core/analytics/analytics_service.dart';
import 'package:akshara_erp/core/audit/audit_logger.dart';
import 'package:akshara_erp/core/errors/error_reporting_service.dart';
import 'package:akshara_erp/core/errors/repository_error_handler.dart';
import 'package:akshara_erp/core/monitoring/monitoring_service.dart';
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
  });

  group('runRepositoryOperation', () {
    test('returns result when action succeeds', () async {
      final result = await runRepositoryOperation(
        reporting,
        'fetchStudents',
        () async => ['student-1'],
      );

      expect(result, ['student-1']);
      expect(monitoring.recordedErrors, isEmpty);
      expect(analytics.loggedEvents, isEmpty);
    });

    test('reports repository error and rethrows with stack trace', () async {
      await expectLater(
        runRepositoryOperation(
          reporting,
          'fetchStudents',
          () async => throw StateError('db unavailable'),
        ),
        throwsA(isA<StateError>()),
      );

      expect(monitoring.recordedErrors, hasLength(1));
      expect(monitoring.recordedErrors.first.error, isA<StateError>());
      expect(monitoring.recordedErrors.first.context, 'repository:fetchStudents');
      expect(analytics.loggedEvents.single.name, 'error.repository');
      expect(analytics.loggedEvents.single.parameters, {'operation': 'fetchStudents'});
    });
  });
}
