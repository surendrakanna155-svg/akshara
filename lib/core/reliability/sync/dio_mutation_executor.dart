import 'package:dio/dio.dart';

import '../model/mutation_request.dart';
import 'mutation_executor.dart';

/// Production [MutationExecutor] that sends a queued write through the app's
/// existing Dio stack. It attaches the `Idempotency-Key` header (the auth
/// interceptor already treats this as a safe-to-replay signal), so a retried
/// write is replayed by the server, never duplicated.
class DioMutationExecutor implements MutationExecutor {
  DioMutationExecutor(this._dio);

  final Dio _dio;

  @override
  Future<ExecutorResponse> send(MutationRequest request) async {
    try {
      final Response<dynamic> resp = await _dio.request<dynamic>(
        request.path,
        data: request.body,
        // Tenant/school scope is also applied as headers by the shared Dio's
        // TenantInterceptor; we forward the same scope as query params so a
        // queued write replays with parity to the original repository call.
        queryParameters:
            request.scope.isEmpty ? null : Map<String, dynamic>.from(request.scope),
        options: Options(
          method: request.method,
          headers: <String, dynamic>{'Idempotency-Key': request.idempotencyKey},
          // We want the envelope for any status, not a thrown exception.
          validateStatus: (_) => true,
        ),
      );
      return _toExecutorResponse(resp.statusCode ?? 0, resp.data);
    } on DioException catch (e) {
      if (_isNetworkFailure(e)) {
        throw NetworkUnavailableException(e.message);
      }
      // A response with a non-2xx status that slipped past validateStatus.
      if (e.response != null) {
        return _toExecutorResponse(
            e.response!.statusCode ?? 0, e.response!.data);
      }
      throw NetworkUnavailableException(e.message);
    }
  }

  bool _isNetworkFailure(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return true;
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return e.response == null;
    }
  }

  ExecutorResponse _toExecutorResponse(int statusCode, dynamic body) {
    Map<String, dynamic>? data;
    String? errorCode;
    String? errorMessage;
    if (body is Map) {
      final Map<String, dynamic> envelope = body.cast<String, dynamic>();
      final Object? d = envelope['data'];
      if (d is Map) data = d.cast<String, dynamic>();
      final Object? err = envelope['error'];
      if (err is Map) {
        errorCode = err['code'] as String?;
        errorMessage = err['message'] as String?;
      }
    }
    return ExecutorResponse(
      statusCode: statusCode,
      data: data,
      errorCode: errorCode,
      errorMessage: errorMessage,
    );
  }
}
