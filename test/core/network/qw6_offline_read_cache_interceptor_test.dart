import 'dart:async';

import 'package:akshara_erp/core/network/api_config.dart';
import 'package:akshara_erp/core/network/dio_client.dart';
import 'package:akshara_erp/core/network/interceptors/api_error_interceptor.dart';
import 'package:akshara_erp/core/network/interceptors/offline_read_cache_interceptor.dart';
import 'package:akshara_erp/core/network/interceptors/retry_interceptor.dart';
import 'package:akshara_erp/core/config/environment.dart';
import 'package:akshara_erp/core/reliability/store/in_memory_reliability_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW6 · QA-X-004 — offline read cache interceptor.
///
/// Mirrors the row's spec end-to-end: load a screen online → drop the network →
/// re-open → the previously-loaded body is served from the encrypted on-device
/// cache (tagged as a saved copy) instead of an error. Also proves the safety
/// rails: writes/non-2xx/sensitive paths are never cached, server errors never
/// serve stale data, and cache entries are tenant-scoped.

/// Captures the outcome of [Interceptor.onResponse].
class _ResponseOutcome extends ResponseInterceptorHandler {
  Response<dynamic>? nextResponse;
  @override
  void next(Response<dynamic> response) => nextResponse = response;
}

/// Captures the outcome of [Interceptor.onError] (next vs resolve).
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

RequestOptions _get(
  String path, {
  Map<String, dynamic>? query,
  Map<String, dynamic>? headers,
  String method = 'GET',
}) =>
    RequestOptions(
      path: path,
      method: method,
      queryParameters: query ?? const <String, dynamic>{},
      headers: headers ?? <String, dynamic>{},
    );

Response<dynamic> _okResponse(RequestOptions options, Map<String, dynamic> body) =>
    Response<dynamic>(requestOptions: options, statusCode: 200, data: body);

DioException _offline(RequestOptions options) => DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
    );

void main() {
  late InMemoryReliabilityStore store;
  late OfflineReadCacheInterceptor interceptor;

  setUp(() {
    store = InMemoryReliabilityStore();
    interceptor = OfflineReadCacheInterceptor(store);
  });

  Future<void> cache(RequestOptions options, Map<String, dynamic> body) async {
    interceptor.onResponse(_okResponse(options, body), _ResponseOutcome());
    // onResponse caches fire-and-forget; let the write land.
    await Future<void>.delayed(Duration.zero);
  }

  group('caching successful reads (QA-X-004)', () {
    test('caches a successful GET body, then serves it offline', () async {
      final options = _get('/student/dashboard',
          query: <String, dynamic>{'studentId': 's1'});
      await cache(options, <String, dynamic>{'attendance': 92});

      final handler = _ErrorOutcome();
      interceptor.onError(_offline(options), handler);
      await handler.completed;

      expect(handler.resolvedResponse, isNotNull,
          reason: 'offline read served from cache, not surfaced as an error');
      expect(handler.surfacedError, isNull);
      expect((handler.resolvedResponse!.data as Map)['attendance'], 92);
      expect(handler.resolvedResponse!.extra[
              OfflineReadCacheInterceptor.offlineCacheExtraKey],
          isTrue,
          reason: 'served body is tagged as a saved copy for the UI');
    });

    test('propagates the error when nothing is cached', () async {
      final handler = _ErrorOutcome();
      interceptor.onError(_offline(_get('/student/dashboard')), handler);
      await handler.completed;

      expect(handler.resolvedResponse, isNull);
      expect(handler.surfacedError, isNotNull);
    });
  });

  group('safety rails (QA-X-004)', () {
    test('does NOT cache a POST', () async {
      final options = _get('/finance/collect', method: 'POST');
      await cache(options, <String, dynamic>{'ok': true});

      final handler = _ErrorOutcome();
      interceptor.onError(_offline(options), handler);
      await handler.completed;
      expect(handler.surfacedError, isNotNull,
          reason: 'writes are never served from cache');
    });

    test('does NOT cache a non-2xx GET', () async {
      final options = _get('/student/dashboard');
      interceptor.onResponse(
        Response<dynamic>(
            requestOptions: options,
            statusCode: 500,
            data: const <String, dynamic>{'error': 'boom'}),
        _ResponseOutcome(),
      );
      await Future<void>.delayed(Duration.zero);
      expect(await store.getCache(_keyFor(options)), isNull);
    });

    test('does NOT cache or serve a sensitive auth/legal path', () async {
      final options = _get('/legal/status');
      await cache(options, <String, dynamic>{'accepted': true});
      expect(await store.getCache(_keyFor(options)), isNull,
          reason: 'a stale legal/auth answer must never be served offline');

      final handler = _ErrorOutcome();
      interceptor.onError(_offline(options), handler);
      await handler.completed;
      expect(handler.surfacedError, isNotNull);
    });

    test('does NOT serve stale data on a real server error (response present)',
        () async {
      final options = _get('/student/dashboard');
      await cache(options, <String, dynamic>{'attendance': 92});

      final serverError = DioException(
        requestOptions: options,
        response: Response<dynamic>(requestOptions: options, statusCode: 500),
        type: DioExceptionType.badResponse,
      );
      final handler = _ErrorOutcome();
      interceptor.onError(serverError, handler);
      await handler.completed;
      expect(handler.surfacedError, isNotNull,
          reason: 'a 500 is a live failure, not an offline condition');
      expect(handler.resolvedResponse, isNull);
    });

    test('scopes cache entries by tenant (no cross-tenant leak)', () async {
      final t1 = _get('/student/dashboard',
          headers: <String, dynamic>{ApiConfig.tenantIdHeader: 'tenant-1'});
      final t2 = _get('/student/dashboard',
          headers: <String, dynamic>{ApiConfig.tenantIdHeader: 'tenant-2'});
      await cache(t1, <String, dynamic>{'school': 'one'});

      // tenant-2 has no cached copy → offline read surfaces the error.
      final handler = _ErrorOutcome();
      interceptor.onError(_offline(t2), handler);
      await handler.completed;
      expect(handler.surfacedError, isNotNull,
          reason: 'tenant-2 must not read tenant-1\'s cached dashboard');
    });
  });

  group('interceptor wiring (QA-X-004)', () {
    test('createDioClient installs the cache interceptor between retry and '
        'error-mapping when a store is supplied', () {
      final dio = createDioClient(
        dependencies: DioClientDependencies(
          environment: Environment.development,
          readCacheStore: InMemoryReliabilityStore(),
        ),
      );
      final types = dio.interceptors.map((Interceptor i) => i.runtimeType).toList();
      final retryIdx = types.indexOf(RetryInterceptor);
      final cacheIdx = types.indexOf(OfflineReadCacheInterceptor);
      final errorIdx = types.indexOf(ApiErrorInterceptor);

      expect(cacheIdx, greaterThan(retryIdx),
          reason: 'cache runs after retry has exhausted online attempts');
      expect(cacheIdx, lessThan(errorIdx),
          reason: 'cache sees the raw DioException before it is mapped');
    });

    test('createDioClient omits the cache interceptor without a store', () {
      final dio = createDioClient(
        dependencies: const DioClientDependencies(
            environment: Environment.development),
      );
      expect(
        dio.interceptors.whereType<OfflineReadCacheInterceptor>(),
        isEmpty,
      );
    });
  });
}

/// Recomputes the interceptor's cache key for assertions (scope|METHOD path?q).
String _keyFor(RequestOptions options) {
  String header(String name) => (options.headers[name] ?? '-').toString();
  final scope =
      '${header(ApiConfig.tenantIdHeader)}|${header(ApiConfig.schoolIdHeader)}|${header(ApiConfig.userIdHeader)}';
  final params = options.uri.queryParameters.entries
      .map((MapEntry<String, String> e) => '${e.key}=${e.value}')
      .toList()
    ..sort();
  final query = params.isEmpty ? '' : '?${params.join('&')}';
  return '$scope|${options.method.toUpperCase()} ${options.uri.path}$query';
}
