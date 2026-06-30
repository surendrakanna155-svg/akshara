import 'package:dio/dio.dart';

import '../config/environment.dart';
import 'api_config.dart';
import 'interceptors/api_error_interceptor.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/correlation_id_interceptor.dart';
import 'interceptors/offline_read_cache_interceptor.dart';
import 'interceptors/retry_interceptor.dart';
import 'interceptors/tenant_interceptor.dart';
import '../../features/auth/auth_token_models.dart';
import '../reliability/store/reliability_store.dart';
import '../tenant/tenant_context.dart';

/// Dependencies required to build a production-ready Dio client.
class DioClientDependencies {
  const DioClientDependencies({
    required this.environment,
    this.tokenAccessor,
    this.tenantAccessor,
    this.refreshCallback,
    this.onTokensRefreshed,
    this.onSessionExpired,
    this.allowAnonymous = true,
    this.readCacheStore,
  });

  final Environment environment;
  final AuthTokens? Function()? tokenAccessor;
  final TenantContext? Function()? tenantAccessor;
  final TokenRefreshCallback? refreshCallback;
  final void Function(AuthTokens tokens)? onTokensRefreshed;
  final void Function()? onSessionExpired;
  final bool allowAnonymous;

  /// When supplied, every idempotent `GET` is cached to this durable store and
  /// served back offline (QA-X-004). Omit it (tests / auth-only clients) to skip
  /// offline read caching entirely.
  final ReliabilityStore? readCacheStore;
}

/// Factory for a configured [Dio] instance with standard interceptors.
Dio createDioClient({DioClientDependencies? dependencies}) {
  final deps = dependencies ?? const DioClientDependencies(
    environment: Environment.development,
  );

  final dio = Dio(
    BaseOptions(
      baseUrl: deps.environment.apiBaseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {
        ApiConfig.apiVersionHeader: ApiConfig.apiVersion,
      },
    ),
  );

  dio.interceptors.addAll([
    CorrelationIdInterceptor(),
    if (deps.tenantAccessor != null)
      TenantInterceptor(tenantAccessor: deps.tenantAccessor!),
    AuthInterceptor(
      tokenAccessor: deps.tokenAccessor ?? () => null,
      refreshCallback: deps.refreshCallback,
      allowAnonymous: deps.allowAnonymous,
      onTokensRefreshed: deps.onTokensRefreshed,
      onSessionExpired: deps.onSessionExpired,
    ),
    // QA-X-008: bounded, idempotent-only (GET/HEAD) retry for transient 5xx/429
    // and connection/timeout errors. Placed *after* AuthInterceptor (so a 401
    // refresh+replay runs first) and *before* ApiErrorInterceptor (so it sees
    // the raw status code before the error is mapped to an ApiFailureException).
    RetryInterceptor(),
    // QA-X-004: offline read cache. Caches successful GET bodies and, once retry
    // has given up on a connectivity failure, serves the last good copy back —
    // *before* ApiErrorInterceptor maps the raw DioException away.
    if (deps.readCacheStore != null)
      OfflineReadCacheInterceptor(deps.readCacheStore!),
    ApiErrorInterceptor(),
    if (deps.environment.enableLogging)
      LogInterceptor(
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
      ),
  ]);

  return dio;
}
