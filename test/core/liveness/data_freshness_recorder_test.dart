// Living Dashboard — the freshness chain, end to end.
//
// The owner's rule is "never present cached data as live". The pure classifier
// is tested separately; these prove the WIRING carries the truth, because that
// is where it was lost before: the interceptor already knew a body came from
// cache and simply had nowhere to say so.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:akshara_erp/core/liveness/data_freshness.dart';
import 'package:akshara_erp/core/liveness/data_freshness_providers.dart';
import 'package:akshara_erp/core/liveness/data_freshness_recorder.dart';
import 'package:akshara_erp/core/network/interceptors/offline_read_cache_interceptor.dart';
import 'package:akshara_erp/core/reliability/model/cache_record.dart';
import 'package:akshara_erp/core/reliability/sync/reliability_clock.dart';
import 'package:akshara_erp/core/reliability/store/reliability_store.dart';

class _FixedClock implements ReliabilityClock {
  _FixedClock(this.at);
  DateTime at;
  @override
  DateTime now() => at;
}

/// Minimal store: only the cache methods matter here.
class _FakeStore implements ReliabilityStore {
  final Map<String, CacheRecord> cache = {};

  @override
  Future<CacheRecord?> getCache(String key) async => cache[key];

  @override
  Future<void> putCache(CacheRecord record) async {
    cache[record.key] = record;
  }

  @override
  Future<void> deleteCache(String key) async {
    cache.remove(key);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('recorder', () {
    test('exact path lookup, and query strings do not defeat it', () {
      final r = DataFreshnessRecorder();
      final at = DateTime.utc(2026, 7, 30, 12);
      r.record('/management/dashboard', DataOrigin.network, at);

      expect(r.observationFor('/management/dashboard')?.origin, DataOrigin.network);
      expect(r.observationFor('/management/dashboard?period=Q1')?.origin,
          DataOrigin.network);
      expect(r.observationFor('/finance/dashboard'), isNull);
    });

    test('notifies listeners so a watching surface re-classifies', () {
      final r = DataFreshnessRecorder();
      var notified = 0;
      r.addListener(() => notified++);
      r.record('/x', DataOrigin.network, DateTime.utc(2026));
      expect(notified, 1);
    });
  });

  group('interceptor → recorder', () {
    late _FakeStore store;
    late DataFreshnessRecorder recorder;
    late _FixedClock clock;
    late OfflineReadCacheInterceptor interceptor;

    final t0 = DateTime.utc(2026, 7, 30, 12, 0);

    setUp(() {
      store = _FakeStore();
      recorder = DataFreshnessRecorder();
      clock = _FixedClock(t0);
      interceptor = OfflineReadCacheInterceptor(
        store,
        clock: clock,
        freshnessRecorder: recorder,
      );
    });

    RequestOptions req([String path = '/management/dashboard']) =>
        RequestOptions(path: path, method: 'GET', baseUrl: 'https://api.test');

    test('a live 2xx records a NETWORK read', () async {
      final options = req();
      interceptor.onResponse(
        Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: <String, dynamic>{'ok': true},
        ),
        ResponseInterceptorHandler(),
      );

      final obs = recorder.observationFor('/management/dashboard');
      expect(obs?.origin, DataOrigin.network);
      expect(obs?.observedAt, t0);
    });

    test('a cache replay records CACHE, dated by the ENTRY not the replay', () async {
      final options = req();
      final storedAt = t0.subtract(const Duration(hours: 23));

      // Prime through a real response so the interceptor's own cache key is used,
      // then back-date the stored entry to 23 hours old.
      interceptor.onResponse(
        Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: <String, dynamic>{'ok': true},
        ),
        ResponseInterceptorHandler(),
      );
      await _settle();
      final key = store.cache.keys.single;
      final primed = store.cache[key]!;
      store.cache[key] = CacheRecord(
        key: key,
        scope: primed.scope,
        json: primed.json,
        updatedAt: storedAt,
      );

      interceptor.onError(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
        ErrorInterceptorHandler(),
      );
      await _settle();

      final obs = recorder.observationFor('/management/dashboard');
      expect(obs?.origin, DataOrigin.cache);
      expect(
        obs?.observedAt,
        storedAt,
        reason: 'the BODY is 23h old; replay time must not launder that',
      );

      // And the classifier must refuse to call it live, even though we are online.
      final state = classifyFreshness(
        origin: obs!.origin,
        observedAt: obs.observedAt,
        isOnline: true,
        now: t0,
      );
      expect(state.freshness, DataFreshness.cached);
      expect(presentFreshness(state).label, contains('Saved copy'));
      expect(presentFreshness(state).label, isNot(contains('Live')));
    });

    test('a connectivity failure with no cached body records FAILURE', () async {
      await _driveError(
        interceptor,
        DioException(
          requestOptions: req(),
          type: DioExceptionType.connectionError,
        ),
      );
      expect(
        recorder.observationFor('/management/dashboard')?.origin,
        DataOrigin.failure,
      );
    });

    test('a server error (not connectivity) also records FAILURE', () async {
      final options = req();
      await _driveError(
        interceptor,
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(requestOptions: options, statusCode: 500),
        ),
      );
      expect(
        recorder.observationFor('/management/dashboard')?.origin,
        DataOrigin.failure,
      );
    });
  });
}

/// Drive the interceptor's error path.
///
/// `handler.next(err)` completes the handler future with an error; attaching the
/// catcher BEFORE driving keeps that from surfacing as an unhandled async error
/// and failing the test for the wrong reason.
Future<void> _driveError(
  OfflineReadCacheInterceptor interceptor,
  DioException err,
) async {
  final handler = ErrorInterceptorHandler();
  handler.future.then((_) {}, onError: (Object _, StackTrace __) {});
  interceptor.onError(err, handler);
  await _settle();
}

/// Let the interceptor's fire-and-forget store writes and async error path run.
Future<void> _settle() => Future<void>.delayed(Duration.zero);
