import 'dart:async';

import 'package:dio/dio.dart';

import '../../reliability/sync/backoff.dart';

/// Bounded, idempotent-only retry for transient transport failures (QA-X-008).
///
/// A read (`GET`/`HEAD`) that fails with a transient server/transport error —
/// `502`/`503`/`504`, `429`, or a connection/timeout — is safe to re-issue
/// because it has no side effect. This interceptor re-sends such a request a
/// bounded number of times with exponential backoff (reusing [Backoff], the
/// same curve the write-path sync engine uses), then surfaces the final error
/// so the existing [ApiErrorInterceptor] / caller handling still applies.
///
/// It deliberately does **not** retry:
///   • non-idempotent verbs (`POST`/`PUT`/`PATCH`/`DELETE`) — replaying them
///     could duplicate a side effect; those go through the reliability
///     write-path (sync engine + idempotency keys), not here,
///   • `4xx` other than `429` — a client error won't fix itself,
///   • a `401` — that is the [AuthInterceptor]'s refresh+replay concern.
///
/// Wire it into the interceptor stack *before* the error-mapping interceptor so
/// it observes the raw [DioException] (status code intact) and can decide to
/// retry before the error is converted into an `ApiFailureException`.
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    Backoff? backoff,
    this.maxRetries = 3,
    Dio? retryClient,
    Future<void> Function(Duration delay)? delay,
  })  : _backoff = backoff ?? const Backoff(base: Duration(milliseconds: 200)),
        _retryClient = retryClient,
        _delay = delay ?? Future<void>.delayed;

  /// Idempotent methods that carry no side effect and are safe to re-issue.
  static const Set<String> _idempotentMethods = {'GET', 'HEAD'};

  /// Transient HTTP statuses worth a bounded retry.
  static const Set<int> _retryableStatuses = {429, 502, 503, 504};

  final Backoff _backoff;

  /// Maximum number of *additional* attempts after the first failure.
  final int maxRetries;

  /// Optional injected client used to re-issue the request (tests supply a fake
  /// Dio without a real network). Falls back to a throwaway [Dio] built from the
  /// failed request's base options.
  final Dio? _retryClient;

  /// Injectable sleep so tests run without real wall-clock delay.
  final Future<void> Function(Duration delay) _delay;

  /// Per-request attempt counter, tracked in [RequestOptions.extra].
  static const String _attemptKey = 'retry_attempt';

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;

    if (!_shouldRetry(err)) {
      handler.next(err);
      return;
    }

    final attempt = (options.extra[_attemptKey] as int? ?? 0) + 1;
    if (attempt > maxRetries) {
      handler.next(err);
      return;
    }
    options.extra[_attemptKey] = attempt;

    await _delay(_backoff.delayFor(attempt));

    try {
      final response = await _resend(options);
      handler.resolve(response);
    } on DioException catch (retryError) {
      // Re-enter onError so the next attempt (or the final surfaced error) is
      // handled uniformly; the attempt counter in extra is preserved.
      onError(retryError, handler);
    }
  }

  bool _shouldRetry(DioException err) {
    if (!_idempotentMethods.contains(err.requestOptions.method.toUpperCase())) {
      return false;
    }
    final status = err.response?.statusCode;
    if (status != null) {
      return _retryableStatuses.contains(status);
    }
    // No response → transport-level failure. Retry only the safe transient ones.
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      default:
        return false;
    }
  }

  Future<Response<dynamic>> _resend(RequestOptions options) {
    final dio = _retryClient ?? Dio(BaseOptions(baseUrl: options.baseUrl));
    return dio.fetch<dynamic>(options);
  }
}
