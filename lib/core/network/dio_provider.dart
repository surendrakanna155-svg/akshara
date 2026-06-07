import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../config/environment_provider.dart';
import '../tenant/tenant_provider.dart';
import '../../features/auth/auth_token_provider.dart';
import 'dio_client.dart';

/// Shared [Dio] instance for all API remote data sources.
final dioProvider = Provider<Dio>((ref) {
  final environment = ref.watch(environmentProvider);

  return createDioClient(
    dependencies: DioClientDependencies(
      environment: environment,
      tokenAccessor: () => ref.read(authTokensProvider),
      tenantAccessor: () => ref.read(tenantContextProvider),
      refreshCallback: ref.read(tokenRefreshCallbackProvider),
      onTokensRefreshed: ref.read(onTokensRefreshedProvider),
      allowAnonymous: true,
    ),
  );
});
