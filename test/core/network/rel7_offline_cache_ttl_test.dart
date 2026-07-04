import 'dart:async';

import 'package:akshara_erp/core/network/interceptors/offline_read_cache_interceptor.dart';
import 'package:akshara_erp/core/reliability/store/in_memory_reliability_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../reliability/reliability_fakes.dart';

/// P1-CODE-2 · REL-7 — the offline read cache must never serve a body older than
/// its TTL: a stale ERP fee balance / attendance mark from days ago must not be
/// presented as if it were current.
class _ErrorOutcome extends ErrorInterceptorHandler {
  Response<dynamic>? resolvedResponse;
  DioException? surfacedError;
  final Completer<void> _done = Completer<void>();
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
  void resolve(Response<dynamic> response, [bool _ = false]) {
    resolvedResponse = response;
    _finish();
  }
}

class _ResponseOutcome extends ResponseInterceptorHandler {
  @override
  void next(Response<dynamic> response) {}
}

RequestOptions _get(String path) => RequestOptions(path: path, method: 'GET');
DioException _offline(RequestOptions o) =>
    DioException(requestOptions: o, type: DioExceptionType.connectionError);

void main() {
  late InMemoryReliabilityStore store;
  late FixedClock clock;
  late OfflineReadCacheInterceptor interceptor;
  final DateTime t0 = DateTime.utc(2026, 7, 4, 9);

  setUp(() {
    store = InMemoryReliabilityStore();
    clock = FixedClock(t0);
    interceptor = OfflineReadCacheInterceptor(
      store,
      clock: clock,
      cacheTtl: const Duration(hours: 1),
    );
  });

  Future<void> cacheNow(RequestOptions o) async {
    interceptor.onResponse(
      Response<dynamic>(
          requestOptions: o, statusCode: 200, data: <String, dynamic>{'v': 1}),
      _ResponseOutcome(),
    );
    await Future<void>.delayed(Duration.zero);
  }

  test('serves a cached body that is within the TTL', () async {
    final o = _get('/student/dashboard');
    await cacheNow(o);
    clock.advance(const Duration(minutes: 30)); // < 1h TTL

    final h = _ErrorOutcome();
    interceptor.onError(_offline(o), h);
    await h.completed;

    expect(h.resolvedResponse, isNotNull);
    expect(h.surfacedError, isNull);
  });

  test('does NOT serve a body older than the TTL — the error surfaces instead',
      () async {
    final o = _get('/student/dashboard');
    await cacheNow(o);
    clock.advance(const Duration(hours: 2)); // > 1h TTL

    final h = _ErrorOutcome();
    interceptor.onError(_offline(o), h);
    await h.completed;

    expect(h.resolvedResponse, isNull,
        reason: 'a stale-past-TTL body must never be presented as current');
    expect(h.surfacedError, isNotNull);
  });

  test('an expired entry is dropped from the store on read', () async {
    final o = _get('/student/dashboard');
    await cacheNow(o);
    clock.advance(const Duration(hours: 2));

    final h = _ErrorOutcome();
    interceptor.onError(_offline(o), h);
    await h.completed;
    await Future<void>.delayed(Duration.zero); // let the fire-and-forget delete land

    // The key is scope|GET path; recompute minimally (no headers → '-|-|-').
    final cached =
        await store.getCache('-|-|-|GET /student/dashboard');
    expect(cached, isNull, reason: 'expired entries should not linger in the LRU');
  });

  test('default TTL is 24h', () {
    expect(OfflineReadCacheInterceptor.defaultCacheTtl,
        const Duration(hours: 24));
  });
}
