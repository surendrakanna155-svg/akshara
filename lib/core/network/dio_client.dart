import 'package:dio/dio.dart';

import '../config/environment.dart';
import 'api_config.dart';
import 'interceptors/api_error_interceptor.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/correlation_id_interceptor.dart';
import 'interceptors/tenant_interceptor.dart';
import '../../features/auth/auth_token_models.dart';
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
  });

  final Environment environment;
  final AuthTokens? Function()? tokenAccessor;
  final TenantContext? Function()? tenantAccessor;
  final TokenRefreshCallback? refreshCallback;
  final void Function(AuthTokens tokens)? onTokensRefreshed;
  final void Function()? onSessionExpired;
  final bool allowAnonymous;
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
