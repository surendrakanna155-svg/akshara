import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../config/environment_provider.dart';
import '../network/interceptors/error_reporting_interceptor.dart';
import '../reliability/reliability_providers.dart';
import '../tenant/tenant_provider.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/auth/auth_token_provider.dart';
import 'dio_client.dart';

/// Shared [Dio] instance for all API remote data sources.
final dioProvider = Provider<Dio>((ref) {
  final environment = ref.watch(environmentProvider);

  final dio = createDioClient(
    dependencies: DioClientDependencies(
      environment: environment,
      tokenAccessor: () => ref.read(authTokensProvider),
      tenantAccessor: () => ref.read(tenantContextProvider),
      refreshCallback: ref.read(tokenRefreshCallbackProvider),
      onTokensRefreshed: ref.read(onTokensRefreshedProvider),
      onSessionExpired: () {
        ref.read(authProvider.notifier).logout();
      },
      allowAnonymous: !environment.requireAuthentication,
      // QA-X-004: reuse the platform's encrypted on-device store so reads are
      // cached and served offline. The store is bound once at bootstrap.
      readCacheStore: ref.read(reliabilityStoreProvider),
    ),
  );

  dio.interceptors.add(ErrorReportingInterceptor.fromRef(ref));

  return dio;
});
