import 'error_reporting_service.dart';

/// Executes a repository operation and reports failures centrally.
Future<T> runRepositoryOperation<T>(
  ErrorReportingService reporting,
  String operation,
  Future<T> Function() action,
) async {
  try {
    return await action();
  } catch (error, stackTrace) {
    reporting.reportRepositoryError(error, operation: operation);
    Error.throwWithStackTrace(error, stackTrace);
  }
}
