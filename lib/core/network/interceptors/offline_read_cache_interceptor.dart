import 'package:dio/dio.dart';

import '../../reliability/model/cache_record.dart';
import '../../reliability/sync/reliability_clock.dart';
import '../../reliability/store/reliability_store.dart';
import '../api_config.dart';

/// Offline read cache (QA-X-004).
///
/// The reliability platform already persists *writes* (the outbox) and
/// in-progress forms (drafts). This interceptor is the read-side counterpart and
/// the single choke point for it — every idempotent `GET` inherits offline
/// caching with no per-screen code, the same way every write inherits the
/// outbox.
///
///   • On a successful `GET` it stores the response body in the encrypted
///     on-device [ReliabilityStore], keyed by method + path + query + tenant
///     scope.
///   • On a `GET` that fails with a *connectivity* error — after
///     [RetryInterceptor] has exhausted its bounded retries — it serves the last
///     good body back, so a previously-loaded dashboard / timetable / notice
///     list still renders instead of an error screen. The served response is
///     tagged (`extra['offline_cache'] == true` + [offlineCacheHeader]) so the
///     UI can show a "showing saved copy" indicator.
///
/// It deliberately does **not** cache non-idempotent verbs, non-2xx responses,
/// non-map bodies, or security-sensitive endpoints (auth / legal / session /
/// token) — a stale legal or auth status must never be served from cache.
///
/// Wire it into the stack *after* [RetryInterceptor] (so transient failures are
/// retried online first) and *before* the error-mapping interceptor (so it sees
/// the raw [DioException] type, not an already-mapped `ApiFailureException`).
class OfflineReadCacheInterceptor extends Interceptor {
  OfflineReadCacheInterceptor(
    this._store, {
    ReliabilityClock clock = const SystemReliabilityClock(),
    bool Function(RequestOptions options)? shouldCache,
    this.cacheTtl = defaultCacheTtl,
  })  : _clock = clock,
        _shouldCache = shouldCache ?? _defaultShouldCache;

  final ReliabilityStore _store;
  final ReliabilityClock _clock;
  final bool Function(RequestOptions options) _shouldCache;

  /// REL-7 — maximum age an offline-cached read may be served at. A body older
  /// than this is treated as a cache miss (the error surfaces instead) so the UI
  /// never presents genuinely stale data — an ERP fee balance / attendance mark
  /// from days ago dressed as current — as if it were live. Tune per deployment;
  /// the default keeps a day of previously-loaded screens available offline.
  final Duration cacheTtl;

  /// Default offline-cache freshness window.
  static const Duration defaultCacheTtl = Duration(hours: 24);

  /// Response header / extra flag marking a body that came from the offline
  /// cache rather than the network.
  static const String offlineCacheHeader = 'X-NIKSHA-Offline-Cache';
  static const String offlineCacheExtraKey = 'offline_cache';

  /// Path fragments never cached — serving a stale auth/legal/session/token
  /// answer offline could bypass a live security gate.
  static const List<String> _sensitiveFragments = <String>[
    'auth',
    'legal',
    'session',
    'token',
  ];

  static bool _defaultShouldCache(RequestOptions options) {
    if (options.method.toUpperCase() != 'GET') return false;
    final String path = options.uri.path.toLowerCase();
    for (final String fragment in _sensitiveFragments) {
      if (path.contains(fragment)) return false;
    }
    return true;
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final RequestOptions options = response.requestOptions;
    final dynamic data = response.data;
    final bool cacheable = _shouldCache(options) &&
        (response.statusCode ?? 0) >= 200 &&
        (response.statusCode ?? 0) < 300 &&
        data is Map<String, dynamic>;
    if (cacheable) {
      // Fire-and-forget: caching must never block or fail a live read.
      _store
          .putCache(CacheRecord(
            key: _cacheKey(options),
            scope: _scope(options),
            json: Map<String, dynamic>.from(data),
            updatedAt: _clock.now(),
          ))
          .catchError((Object _) {});
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final RequestOptions options = err.requestOptions;
    if (!_shouldCache(options) || !_isConnectivityFailure(err)) {
      handler.next(err);
      return;
    }
    final CacheRecord? cached = await _store.getCache(_cacheKey(options));
    if (cached == null) {
      handler.next(err);
      return;
    }
    // REL-7 — never serve a body older than the TTL. Drop the expired entry (so
    // it stops occupying the LRU) and let the original connectivity error stand.
    if (_clock.now().difference(cached.updatedAt) > cacheTtl) {
      _store.deleteCache(_cacheKey(options)).catchError((Object _) {});
      handler.next(err);
      return;
    }
    handler.resolve(
      Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: cached.json,
        headers: Headers.fromMap(<String, List<String>>{
          offlineCacheHeader: <String>[cached.updatedAt.toIso8601String()],
        }),
        extra: <String, dynamic>{
          ...options.extra,
          offlineCacheExtraKey: true,
        },
      ),
    );
  }

  /// A failure with no HTTP response and a transport-level type — i.e. the
  /// device could not reach the server (offline / DNS / connection reset).
  bool _isConnectivityFailure(DioException err) {
    if (err.response != null) return false;
    switch (err.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return true;
      case DioExceptionType.unknown:
        return true;
      default:
        return false;
    }
  }

  String _scope(RequestOptions options) {
    final Object? tenant = options.headers[ApiConfig.tenantIdHeader];
    final Object? school = options.headers[ApiConfig.schoolIdHeader];
    final Object? user = options.headers[ApiConfig.userIdHeader];
    return '${tenant ?? '-'}|${school ?? '-'}|${user ?? '-'}';
  }

  String _cacheKey(RequestOptions options) {
    final Uri uri = options.uri;
    final List<String> params = uri.queryParameters.entries
        .map((MapEntry<String, String> e) => '${e.key}=${e.value}')
        .toList()
      ..sort();
    final String query = params.isEmpty ? '' : '?${params.join('&')}';
    return '${_scope(options)}|${options.method.toUpperCase()} ${uri.path}$query';
  }
}
