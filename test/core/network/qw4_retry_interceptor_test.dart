import 'dart:async';

import 'package:akshara_erp/core/network/interceptors/retry_interceptor.dart';
import 'package:akshara_erp/core/reliability/sync/backoff.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW4 · QA-X-008 — bounded, idempotent-only retry/backoff for transient 5xx/429
/// on GET/HEAD only.
///
/// DECISION (see FINDINGS): Phase 0 built `backoff.dart` + the sync engine for
/// the *write* path (mutations, idempotency keys, outbox). There was no
/// equivalent on the *read* path: a transient `503`/`429` on a plain `GET`
/// surfaced as a hard failure with no retry. That is a genuine resilience gap,
/// so this row BUILDS a minimal [RetryInterceptor] that re-issues only safe
/// idempotent reads, a bounded number of times, on the same [Backoff] curve the
/// write path uses — and never touches non-idempotent writes (those remain the
/// sync engine's responsibility).
///
/// The interceptor's re-issue uses an injected Dio so these tests exercise the
/// retry decision + bounded-attempt + backoff wiring with zero real network and
/// zero wall-clock delay.

/// A real [Dio] whose transport is replaced with a scripted adapter, so each
/// `fetch` consumes the next outcome ("fails twice, then succeeds") with no
/// real network. Counts calls via [_ScriptedAdapter.calls].
class _ScriptedDio extends DioMixin implements Dio {
  _ScriptedDio(List<int Function(RequestOptions)> statuses) {
    options = BaseOptions();
    // Treat every status as a non-throwing response; the interceptor inspects
    // the status code itself to decide whether to retry.
    options.validateStatus = (_) => true;
    httpClientAdapter = _ScriptedAdapter(statuses);
  }

  _ScriptedAdapter get _adapter => httpClientAdapter as _ScriptedAdapter;
  int get calls => _adapter.calls;
}

/// Returns the scripted status code for each successive request.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._statuses);

  final List<int Function(RequestOptions)> _statuses;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final status = _statuses[calls](options);
    calls++;
    return ResponseBody.fromString('{}', status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

/// Drives an interceptor's [onError] and resolves with the final outcome.
class _OutcomeHandler extends ErrorInterceptorHandler {
  Response<dynamic>? resolvedResponse;
  DioException? surfacedError;
  final _done = Completer<void>();

  Future<void> get completed => _done.future;
  void _finish() {
    if (!_done.isCompleted) _done.complete();
  }

  @override
  void next(DioException err) {
    surfacedError = err;
    _finish();
  }

  @override
  void resolve(Response<dynamic> response,
      [bool callFollowingResponseInterceptor = false]) {
    resolvedResponse = response;
    _finish();
  }

  @override
  void reject(DioException error, [bool callFollowingErrorInterceptor = false]) {
    surfacedError = error;
    _finish();
  }
}

DioException _statusError(RequestOptions options, int status) => DioException(
      requestOptions: options,
      response: Response(requestOptions: options, statusCode: status),
    );

void main() {
  // No real backoff sleep: collect requested delays instead of waiting.
  RetryInterceptor buildInterceptor(
    Dio retryClient, {
    int maxRetries = 3,
    List<Duration>? recordedDelays,
  }) {
    return RetryInterceptor(
      maxRetries: maxRetries,
      retryClient: retryClient,
      backoff: const Backoff(base: Duration(milliseconds: 10)),
      delay: (d) async => recordedDelays?.add(d),
    );
  }

  group('RetryInterceptor · idempotent-only retry (QA-X-008)', () {
    test('retries a transient 503 on GET, then resolves on success', () async {
      final options = RequestOptions(path: '/read', method: 'GET');
      final dio = _ScriptedDio([
        // First retry still fails with 503...
        (o) => 503,
        // ...second retry succeeds.
        (o) => 200,
      ]);
      final delays = <Duration>[];
      final interceptor = buildInterceptor(dio, recordedDelays: delays);

      final handler = _OutcomeHandler();
      interceptor.onError(_statusError(options, 503), handler);
      await handler.completed;

      expect(dio.calls, 2, reason: 'one failed retry + one successful retry');
      expect(handler.resolvedResponse?.statusCode, 200);
      expect(handler.surfacedError, isNull);
      expect(delays.length, 2, reason: 'a backoff delay precedes each retry');
    });

    test('retries 429 on GET', () async {
      final options = RequestOptions(path: '/read', method: 'GET');
      final dio = _ScriptedDio([
        (o) => 200,
      ]);
      final interceptor = buildInterceptor(dio);

      final handler = _OutcomeHandler();
      interceptor.onError(_statusError(options, 429), handler);
      await handler.completed;

      expect(dio.calls, 1);
      expect(handler.resolvedResponse?.statusCode, 200);
    });

    test('does NOT retry a POST (non-idempotent write)', () async {
      final options = RequestOptions(path: '/write', method: 'POST');
      final dio = _ScriptedDio([]); // must never be called
      final interceptor = buildInterceptor(dio);

      final handler = _OutcomeHandler();
      interceptor.onError(_statusError(options, 503), handler);
      await handler.completed;

      expect(dio.calls, 0, reason: 'writes must never be auto-retried here');
      expect(handler.surfacedError?.response?.statusCode, 503);
      expect(handler.resolvedResponse, isNull);
    });

    test('does NOT retry a non-transient 4xx (e.g. 404) on GET', () async {
      final options = RequestOptions(path: '/missing', method: 'GET');
      final dio = _ScriptedDio([]);
      final interceptor = buildInterceptor(dio);

      final handler = _OutcomeHandler();
      interceptor.onError(_statusError(options, 404), handler);
      await handler.completed;

      expect(dio.calls, 0);
      expect(handler.surfacedError?.response?.statusCode, 404);
    });

    test('does NOT retry a 401 (that is AuthInterceptor\'s concern)', () async {
      final options = RequestOptions(path: '/secure', method: 'GET');
      final dio = _ScriptedDio([]);
      final interceptor = buildInterceptor(dio);

      final handler = _OutcomeHandler();
      interceptor.onError(_statusError(options, 401), handler);
      await handler.completed;

      expect(dio.calls, 0);
      expect(handler.surfacedError?.response?.statusCode, 401);
    });

    test('gives up after maxRetries and surfaces the last error', () async {
      final options = RequestOptions(path: '/read', method: 'GET');
      // Every retry fails with 503.
      final dio = _ScriptedDio(
        List.generate(5, (_) => (RequestOptions o) => 503),
      );
      final delays = <Duration>[];
      final interceptor =
          buildInterceptor(dio, maxRetries: 3, recordedDelays: delays);

      final handler = _OutcomeHandler();
      interceptor.onError(_statusError(options, 503), handler);
      await handler.completed;

      expect(dio.calls, 3, reason: 'bounded to exactly maxRetries attempts');
      expect(delays.length, 3, reason: 'one backoff per attempt');
      expect(handler.surfacedError?.response?.statusCode, 503);
      expect(handler.resolvedResponse, isNull);
    });

    test('retries a connection error (no response) on GET', () async {
      final options = RequestOptions(path: '/read', method: 'GET');
      final dio = _ScriptedDio([
        (o) => 200,
      ]);
      final interceptor = buildInterceptor(dio);

      final connErr = DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
      final handler = _OutcomeHandler();
      interceptor.onError(connErr, handler);
      await handler.completed;

      expect(dio.calls, 1);
      expect(handler.resolvedResponse?.statusCode, 200);
    });

    test('does NOT retry a cancel error on GET', () async {
      final options = RequestOptions(path: '/read', method: 'GET');
      final dio = _ScriptedDio([]);
      final interceptor = buildInterceptor(dio);

      final cancelErr = DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
      );
      final handler = _OutcomeHandler();
      interceptor.onError(cancelErr, handler);
      await handler.completed;

      expect(dio.calls, 0);
      expect(handler.surfacedError?.type, DioExceptionType.cancel);
    });

    test('retries HEAD (idempotent) the same as GET', () async {
      final options = RequestOptions(path: '/head', method: 'HEAD');
      final dio = _ScriptedDio([
        (o) => 200,
      ]);
      final interceptor = buildInterceptor(dio);

      final handler = _OutcomeHandler();
      interceptor.onError(_statusError(options, 502), handler);
      await handler.completed;

      expect(dio.calls, 1);
      expect(handler.resolvedResponse?.statusCode, 200);
    });
  });
}
