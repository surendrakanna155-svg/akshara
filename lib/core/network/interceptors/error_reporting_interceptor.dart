import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../errors/api_failure.dart';
import '../../errors/error_reporting_service.dart';

/// Reports API failures to the observability pipeline after [ApiErrorInterceptor].
class ErrorReportingInterceptor extends Interceptor {
  ErrorReportingInterceptor(this._readReporting);

  final ErrorReportingService Function() _readReporting;

  factory ErrorReportingInterceptor.fromRef(Ref ref) {
    return ErrorReportingInterceptor(
      () => ref.read(errorReportingServiceProvider),
    );
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final failure = err.error;
    if (failure is ApiFailureException) {
      _readReporting().reportApiFailure(
        path: err.requestOptions.path,
        statusCode: err.response?.statusCode,
        correlationId: failure.failure.correlationId,
        message: failure.failure.message,
      );
    } else {
      _readReporting().reportApiFailure(
        path: err.requestOptions.path,
        statusCode: err.response?.statusCode,
      );
    }
    handler.next(err);
  }
}
