import 'package:dio/dio.dart';

import 'incident_telemetry.dart';

/// Lightweight Dio interceptor that records every outbound API call's metadata
/// (method, path, status, correlation id) into the [IncidentTelemetryBuffer].
///
/// Metadata only — never request/response bodies, headers or tokens — so the
/// evidence snapshot stays PII-minimized by construction (ASIP_DESIGN §5). It
/// sits at the tail of the interceptor stack (added in `dio_provider.dart`) so it
/// observes the final status after auth-refresh/retry, and it never mutates the
/// request or short-circuits the chain.
class IncidentApiCallInterceptor extends Interceptor {
  IncidentApiCallInterceptor(this._buffer);

  final IncidentTelemetryBuffer _buffer;

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    _record(response.requestOptions, response.statusCode);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _record(err.requestOptions, err.response?.statusCode);
    handler.next(err);
  }

  void _record(RequestOptions options, int? statusCode) {
    final path = options.uri.path.isNotEmpty ? options.uri.path : options.path;
    // Don't self-report the support endpoints — that would be circular noise.
    if (path.contains('/support/incidents')) return;
    _buffer.recordApiCall(
      method: options.method,
      path: path,
      statusCode: statusCode,
      correlationId: options.extra['correlationId'] as String?,
    );
  }
}
