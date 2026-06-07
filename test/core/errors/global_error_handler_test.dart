import 'dart:ui';

import 'package:akshara_erp/core/analytics/analytics_service.dart';
import 'package:akshara_erp/core/audit/audit_logger.dart';
import 'package:akshara_erp/core/errors/error_reporting_service.dart';
import 'package:akshara_erp/core/errors/global_error_handler.dart';
import 'package:akshara_erp/core/monitoring/monitoring_service.dart';
import 'package:flutter/foundation.dart';
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

class _NoOpAnalyticsService implements AnalyticsService {
  @override
  void logEvent(String name, {Map<String, String>? parameters}) {}

  @override
  void setUserProperty(String name, String value) {}

  @override
  void setUserId(String? userId) {}
}

void main() {
  late _RecordingMonitoringService monitoring;
  late ErrorReportingService reporting;
  FlutterExceptionHandler? previousFlutterOnError;
  ErrorCallback? previousPlatformOnError;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    monitoring = _RecordingMonitoringService();
    reporting = ErrorReportingService(
      monitoring: monitoring,
      analytics: _NoOpAnalyticsService(),
      auditLogger: AuditLogger(prefs),
    );
    previousFlutterOnError = FlutterError.onError;
    previousPlatformOnError = PlatformDispatcher.instance.onError;
  });

  tearDown(() {
    FlutterError.onError = previousFlutterOnError;
    PlatformDispatcher.instance.onError = previousPlatformOnError;
  });

  group('GlobalErrorHandler.install', () {
    test('routes Flutter framework errors to reporting', () {
      GlobalErrorHandler(reporting).install();

      final details = FlutterErrorDetails(
        exception: Exception('framework'),
        stack: StackTrace.current,
        library: 'widgets',
      );
      FlutterError.onError!(details);

      expect(monitoring.recordedErrors, hasLength(1));
      expect(monitoring.recordedErrors.first.error, details.exception);
      expect(monitoring.recordedErrors.first.context, 'flutter.framework');
    });

    test('routes platform dispatcher errors to reporting and swallows them', () {
      GlobalErrorHandler(reporting).install();

      final error = Exception('platform');
      final stack = StackTrace.current;
      final handled = PlatformDispatcher.instance.onError!(error, stack);

      expect(handled, isTrue);
      expect(monitoring.recordedErrors.single.error, error);
      expect(monitoring.recordedErrors.single.stackTrace, stack);
      expect(monitoring.recordedErrors.single.context, 'zone');
    });
  });

  group('runGuardedZone', () {
    test('reports uncaught async zone errors', () async {
      await runGuardedZone(
        reporting,
        () async {
          Future<void>.microtask(() => throw Exception('async zone'));
        },
      );
      await pumpEventQueue();

      expect(monitoring.recordedErrors, hasLength(1));
      expect(monitoring.recordedErrors.first.context, 'zone');
    });

    test('returns result when body completes successfully', () async {
      final result = await runGuardedZone(
        reporting,
        () async => 42,
      );

      expect(result, 42);
      expect(monitoring.recordedErrors, isEmpty);
    });
  });
}
