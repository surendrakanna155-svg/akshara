import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'error_reporting_service.dart';

/// Riverpod observer that reports provider failures to observability pipeline.
class AksharaErrorObserver extends ProviderObserver {
  AksharaErrorObserver(this._reporting);

  final ErrorReportingService _reporting;

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    _reporting.reportProviderError(error, stackTrace, provider);
  }
}
