import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics_service.dart';
import '../audit/audit_event.dart';
import '../audit/audit_logger.dart';
import '../audit/audit_provider.dart';
import '../monitoring/monitoring_service.dart';
import '../observability/observability_providers.dart';

/// Central error reporting — integrates monitoring, analytics, and audit.
class ErrorReportingService {
  ErrorReportingService({
    required MonitoringService monitoring,
    required AnalyticsService analytics,
    required AuditLogger auditLogger,
  })  : _monitoring = monitoring,
        _analytics = analytics,
        _auditLogger = auditLogger;

  final MonitoringService _monitoring;
  final AnalyticsService _analytics;
  final AuditLogger _auditLogger;

  void reportFlutterError(FlutterErrorDetails details) {
    _monitoring.recordError(
      details.exception,
      stackTrace: details.stack,
      context: 'flutter.framework',
    );
    _analytics.logEvent(
      'error.flutter',
      parameters: {'library': details.library ?? 'unknown'},
    );
    unawaited(
      _auditLogger.logTyped(
        type: AuditEventType.errorReported,
        metadata: {'source': 'flutter.framework'},
      ),
    );
  }

  void reportZoneError(Object error, StackTrace stackTrace) {
    _monitoring.recordError(error, stackTrace: stackTrace, context: 'zone');
    _analytics.logEvent('error.zone');
    unawaited(
      _auditLogger.logTyped(
        type: AuditEventType.errorReported,
        metadata: {'source': 'zone'},
      ),
    );
  }

  void reportProviderError(
    Object error,
    StackTrace stackTrace,
    ProviderBase<Object?> provider,
  ) {
    _monitoring.recordError(
      error,
      stackTrace: stackTrace,
      context: 'riverpod:${provider.name ?? provider.runtimeType}',
    );
    _analytics.logEvent(
      'error.provider',
      parameters: {'provider': provider.name ?? provider.runtimeType.toString()},
    );
  }

  void reportApiFailure({
    required String path,
    required int? statusCode,
    String? correlationId,
    String? message,
  }) {
    _monitoring.recordEvent(
      'api.failure',
      properties: {
        'path': path,
        if (statusCode != null) 'statusCode': '$statusCode',
        if (correlationId != null) 'correlationId': correlationId,
        if (message != null) 'message': message,
      },
    );
    _analytics.logEvent(
      'error.api',
      parameters: {
        'path': path,
        if (statusCode != null) 'status': '$statusCode',
        if (correlationId != null) 'correlationId': correlationId,
      },
    );
  }

  void reportRepositoryError(Object error, {String? operation}) {
    _monitoring.recordError(
      error,
      context: operation != null ? 'repository:$operation' : 'repository',
    );
    _analytics.logEvent(
      'error.repository',
      parameters: {if (operation != null) 'operation': operation},
    );
  }
}

final errorReportingServiceProvider = Provider<ErrorReportingService>((ref) {
  return ErrorReportingService(
    monitoring: ref.watch(monitoringServiceProvider),
    analytics: ref.watch(analyticsServiceProvider),
    auditLogger: ref.watch(auditLoggerProvider),
  );
});
