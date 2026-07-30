import 'package:dio/dio.dart';

import '../config/environment.dart';
import 'api_config.dart';
import 'interceptors/api_error_interceptor.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/correlation_id_interceptor.dart';
import 'interceptors/idempotency_key_interceptor.dart';
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
    // REL-1: mint an Idempotency-Key for every mutation BEFORE auth, so a
    // 401 refresh→replay carries the same key and the backend's universal
    // store-and-replay idempotency dedupes it (no duplicate row on retry).
    IdempotencyKeyInterceptor(),
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
    // Method + path + status only. Headers and bodies are NEVER logged.
    //
    // This used to log `requestHeader: true, requestBody: true,
    // responseBody: true`, gated on `enableLogging` — which is false for
    // production but TRUE for staging and development. `scripts/run_live.sh`
    // runs a staging-configured DEBUG build against the LIVE pilot backend, so
    // that combination printed, to the device log:
    //   · the `Authorization: Bearer <accessToken>` header (AuthInterceptor is
    //     registered earlier, so the token is already attached)
    //   · the OTP itself, in the /auth/verify-otp request body
    //   · access + refresh tokens, parent phone numbers and linked-child
    //     profiles in the response body
    // On a physical Android device anything able to read logcat could collect
    // those. The release guard makes this unshippable in a store build, but the
    // pilot/dev lane runs against real children's data, so "it can't reach
    // production" is not the same as "it is safe".
    //
    // A request line is enough to debug routing and status; a body is not worth
    // a token or a child's record.
    if (deps.environment.enableLogging)
      LogInterceptor(
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: false,
      ),
  ]);

  return dio;
}
