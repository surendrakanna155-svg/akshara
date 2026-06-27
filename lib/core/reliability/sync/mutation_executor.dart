import '../model/mutation_request.dart';

/// Abstraction over the actual network send, so the gateway/engine are testable
/// without Dio and so the real implementation can attach the `Idempotency-Key`
/// header, tenant scope and correlation id in one place.
abstract interface class MutationExecutor {
  /// Sends [request] to the backend. Returns an [ExecutorResponse] for ANY HTTP
  /// status (including 4xx/5xx). Throws [NetworkUnavailableException] when the
  /// request never reached the server (offline / DNS / timeout) — that is the
  /// signal to queue/retry rather than fail.
  Future<ExecutorResponse> send(MutationRequest request);
}

/// A server HTTP response, normalised to the Akshara envelope.
class ExecutorResponse {
  const ExecutorResponse({
    required this.statusCode,
    this.data,
    this.errorCode,
    this.errorMessage,
  });

  final int statusCode;

  /// The `data` payload of a success envelope (the created/updated row).
  final Map<String, dynamic>? data;

  /// The `error.code` of an error envelope (e.g. `CONFLICT`,
  /// `IDEMPOTENCY_CONFLICT`, `VALIDATION_ERROR`, `FORBIDDEN`).
  final String? errorCode;
  final String? errorMessage;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
  bool get isServerError => statusCode >= 500;
  bool get isConflict => statusCode == 409;
}

/// Thrown by an executor when the request could not reach the server at all.
class NetworkUnavailableException implements Exception {
  const NetworkUnavailableException([this.message]);
  final String? message;
  @override
  String toString() => 'NetworkUnavailableException(${message ?? ''})';
}
