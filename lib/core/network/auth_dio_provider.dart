import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/environment_provider.dart';
import '../tenant/tenant_provider.dart';
import '../../features/auth/auth_token_provider.dart';
import 'dio_client.dart';

/// Dio for auth endpoints — no refresh callback to avoid provider cycle.
final authDioProvider = Provider<Dio>((ref) {
  final environment = ref.watch(environmentProvider);

  return createDioClient(
    dependencies: DioClientDependencies(
      environment: environment,
      tokenAccessor: () => ref.read(authTokensProvider),
      tenantAccessor: () => ref.read(tenantContextProvider),
      refreshCallback: null,
      onTokensRefreshed: ref.read(onTokensRefreshedProvider),
      allowAnonymous: true,
    ),
  );
});
