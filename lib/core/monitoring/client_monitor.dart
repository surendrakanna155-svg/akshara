import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../observability/observability_providers.dart';
import 'monitoring_service.dart';

/// Client-side monitoring hook for errors and API failures in production.
abstract class ClientMonitor {
  void recordError(Object error, {StackTrace? stackTrace, String? context});
  void recordApiFailure({
    required String path,
    required int? statusCode,
    String? correlationId,
  });
}

/// No-op monitor used in development and tests.
class NoOpClientMonitor implements ClientMonitor {
  const NoOpClientMonitor();

  @override
  void recordError(Object error, {StackTrace? stackTrace, String? context}) {}

  @override
  void recordApiFailure({
    required String path,
    required int? statusCode,
    String? correlationId,
  }) {}
}

/// Debug monitor that logs to console.
class DebugClientMonitor implements ClientMonitor {
  const DebugClientMonitor();

  @override
  void recordError(Object error, {StackTrace? stackTrace, String? context}) {
    debugPrint(
      '[ClientMonitor] error${context != null ? ' ($context)' : ''}: $error',
    );
  }

  @override
  void recordApiFailure({
    required String path,
    required int? statusCode,
    String? correlationId,
  }) {
    debugPrint(
      '[ClientMonitor] API failure $path status=$statusCode correlation=$correlationId',
    );
  }
}

/// Bridges legacy [ClientMonitor] to [MonitoringService].
class MonitoringClientAdapter implements ClientMonitor {
  MonitoringClientAdapter(this._service);

  final MonitoringService _service;

  @override
  void recordError(Object error, {StackTrace? stackTrace, String? context}) {
    _service.recordError(error, stackTrace: stackTrace, context: context);
  }

  @override
  void recordApiFailure({
    required String path,
    required int? statusCode,
    String? correlationId,
  }) {
    _service.recordEvent(
      'api.failure',
      properties: {
        'path': path,
        if (statusCode != null) 'statusCode': '$statusCode',
        if (correlationId != null) 'correlationId': correlationId,
      },
    );
  }
}

final clientMonitorProvider = Provider<ClientMonitor>((ref) {
  return MonitoringClientAdapter(ref.watch(monitoringServiceProvider));
});
