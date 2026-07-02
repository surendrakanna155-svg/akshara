import 'package:dio/dio.dart';

import '../repositories/api/api_exception.dart';
import 'api_failure.dart';

/// Maps transport and repository exceptions to [ApiFailure].
class ApiFailureMapper {
  const ApiFailureMapper();

  ApiFailure fromException(
    Object error, {
    String? correlationId,
  }) {
    if (error is ApiFailureException) {
      return error.failure.copyWith(
        correlationId: correlationId ?? error.failure.correlationId,
      );
    }

    if (error is ApiNotConnectedException) {
      return ApiFailure(
        type: ApiFailureType.notConnected,
        message: 'Service is not available yet. Please try again later.',
        code: 'API_NOT_CONNECTED',
        correlationId: correlationId,
        cause: error,
      );
    }

    if (error is DioException) {
      return _fromDio(error, correlationId: correlationId);
    }

    return ApiFailure(
      type: ApiFailureType.unknown,
      message: 'Something went wrong. Please try again.',
      code: 'UNKNOWN',
      correlationId: correlationId,
      cause: error,
    );
  }

  ApiFailure _fromDio(DioException error, {String? correlationId}) {
    final status = error.response?.statusCode;
    final id = correlationId ??
        error.requestOptions.headers['X-Correlation-Id'] as String?;

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return ApiFailure(
        type: ApiFailureType.timeout,
        message: 'Request timed out. Check your connection and try again.',
        code: 'TIMEOUT',
        statusCode: status,
        correlationId: id,
        cause: error,
      );
    }

    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.unknown) {
      return ApiFailure(
        type: ApiFailureType.network,
        message: 'Unable to reach the server. Check your network connection.',
        code: 'NETWORK',
        statusCode: status,
        correlationId: id,
        cause: error,
      );
    }

    if (status == 401) {
      return ApiFailure(
        type: ApiFailureType.unauthorized,
        message: 'Your session has expired. Please sign in again.',
        code: 'UNAUTHORIZED',
        statusCode: status,
        correlationId: id,
        cause: error,
      );
    }

    if (status == 403) {
      return ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to perform this action.',
        code: 'FORBIDDEN',
        statusCode: status,
        correlationId: id,
        cause: error,
      );
    }

    if (status != null && status >= 500) {
      return ApiFailure(
        type: ApiFailureType.server,
        message: 'Server error. Our team has been notified.',
        code: 'SERVER_ERROR',
        statusCode: status,
        correlationId: id,
        cause: error,
      );
    }

    // Other 4xx (e.g. 409 conflict, 422 validation): the backend returns a
    // precise, user-actionable message in the `{error:{code,message}}` envelope
    // (e.g. PAYROLL_RUN_ALREADY_PROCESSED, PAYROLL_ENTRY_INVALID,
    // LEAVE_ALREADY_DECIDED). Surface that server message rather than a generic
    // one, so money-safety / integrity conflicts reach the user verbatim.
    final serverError = _serverError(error.response?.data);
    return ApiFailure(
      type: ApiFailureType.unknown,
      message: serverError?.message ?? 'Something went wrong. Please try again.',
      code: serverError?.code ?? 'HTTP_${status ?? 'ERROR'}',
      statusCode: status,
      correlationId: id,
      cause: error,
    );
  }

  /// Extracts the `{error:{code,message}}` envelope from a response body when
  /// present. Tolerant of the body being a Map, a non-Map, or missing.
  ({String? code, String? message})? _serverError(Object? data) {
    if (data is! Map) return null;
    final error = data['error'];
    if (error is! Map) return null;
    final message = error['message'];
    final code = error['code'];
    final messageStr = message is String && message.trim().isNotEmpty
        ? message.trim()
        : null;
    final codeStr = code is String && code.trim().isNotEmpty ? code.trim() : null;
    if (messageStr == null && codeStr == null) return null;
    return (code: codeStr, message: messageStr);
  }
}

/// Global mapper instance for repositories and interceptors.
const apiFailureMapper = ApiFailureMapper();
