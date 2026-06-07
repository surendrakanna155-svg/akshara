import 'dart:async';

import 'package:flutter/foundation.dart';

import 'error_reporting_service.dart';

/// Installs Flutter framework and platform dispatcher error hooks.
class GlobalErrorHandler {
  GlobalErrorHandler(this._reporting);

  final ErrorReportingService _reporting;

  void install() {
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      _reporting.reportFlutterError(details);
      if (kDebugMode) {
        previousOnError?.call(details);
        FlutterError.presentError(details);
      }
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _reporting.reportZoneError(error, stack);
      return true;
    };
  }
}

/// Runs [body] inside a guarded zone that reports uncaught async errors.
Future<T> runGuardedZone<T>(
  ErrorReportingService reporting,
  Future<T> Function() body,
) {
  return runZonedGuarded(
    body,
    (error, stack) => reporting.reportZoneError(error, stack),
  )!;
}
