import 'package:dio/dio.dart';

import '../../errors/api_failure.dart';
import '../../errors/api_failure_mapper.dart';

/// Converts [DioException] instances into [ApiFailureException].
class ApiErrorInterceptor extends Interceptor {
  ApiErrorInterceptor({ApiFailureMapper? mapper})
      : _mapper = mapper ?? apiFailureMapper;

  final ApiFailureMapper _mapper;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final correlationId = err.requestOptions.extra['correlationId'] as String? ??
        err.requestOptions.headers['X-Correlation-Id'] as String?;
    final failure = _mapper.fromException(err, correlationId: correlationId);
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: ApiFailureException(failure),
        message: failure.message,
      ),
    );
  }
}
