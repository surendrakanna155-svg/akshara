import 'package:flutter/foundation.dart';

/// Standardized API failure categories for UI and logging.
enum ApiFailureType {
  network,
  timeout,
  unauthorized,
  forbidden,
  server,
  notConnected,
  unknown,
}

/// User-facing API failure with optional retry support.
@immutable
class ApiFailure {
  const ApiFailure({
    required this.type,
    required this.message,
    this.code,
    this.statusCode,
    this.correlationId,
    this.cause,
  });

  final ApiFailureType type;
  final String message;
  final String? code;
  final int? statusCode;
  final String? correlationId;
  final Object? cause;

  bool get isRetryable => switch (type) {
        ApiFailureType.network => true,
        ApiFailureType.timeout => true,
        ApiFailureType.server => true,
        ApiFailureType.notConnected => true,
        ApiFailureType.unknown => true,
        ApiFailureType.unauthorized => false,
        ApiFailureType.forbidden => false,
      };

  String get displayMessage => message;

  String? get displayCode => code;

  ApiFailure copyWith({
    ApiFailureType? type,
    String? message,
    String? code,
    int? statusCode,
    String? correlationId,
    Object? cause,
  }) {
    return ApiFailure(
      type: type ?? this.type,
      message: message ?? this.message,
      code: code ?? this.code,
      statusCode: statusCode ?? this.statusCode,
      correlationId: correlationId ?? this.correlationId,
      cause: cause ?? this.cause,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApiFailure &&
          type == other.type &&
          message == other.message &&
          code == other.code &&
          statusCode == other.statusCode &&
          correlationId == other.correlationId;

  @override
  int get hashCode =>
      Object.hash(type, message, code, statusCode, correlationId);
}

/// Thrown by repositories/interceptors when an API call fails.
class ApiFailureException implements Exception {
  ApiFailureException(this.failure);

  final ApiFailure failure;

  @override
  String toString() => 'ApiFailureException: ${failure.message}';
}
