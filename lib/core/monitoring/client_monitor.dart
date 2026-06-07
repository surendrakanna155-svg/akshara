import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    debugPrint('[ClientMonitor] error${context != null ? ' ($context)' : ''}: $error');
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

final clientMonitorProvider = Provider<ClientMonitor>((ref) {
  return const NoOpClientMonitor();
});
