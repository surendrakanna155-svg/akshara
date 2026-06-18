import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audit/audit_provider.dart';
import '../network/auth_dio_provider.dart';
import '../repositories/api/auth/api_auth_repository.dart';
import '../repositories/api/auth/mapper/auth_mapper.dart';
import '../repositories/api/auth/remote/auth_remote_datasource.dart';
import '../repositories/interfaces/auth_repository.dart';
import '../repositories/mock/mock_auth_repository.dart';
import '../repositories/repository_config.dart';
import '../security/server_permission_models.dart';
import '../security/server_permission_provider.dart';
import '../security/permission_sync_service.dart';

export '../repositories/api/auth/api_auth_repository.dart'
    show AuthRepositoryAuditHook;

/// Audit hook wired into API auth repository operations.
final authRepositoryAuditHookProvider = Provider<AuthRepositoryAuditHook>(
  (ref) {
    return (type, {metadata}) {
      unawaited(
        recordAuditEvent(
          ref,
          type: type,
          userId: metadata?['userId'],
          tenantId: metadata?['tenantId'],
          metadata: metadata ?? const {},
        ),
      );
    };
  },
);

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSource(ref.watch(authDioProvider)),
);

final apiAuthRepositoryProvider = Provider<ApiAuthRepository>((ref) {
  return ApiAuthRepository(
    remote: ref.watch(authRemoteDataSourceProvider),
    mapper: const AuthMapper(),
    onAudit: ref.watch(authRepositoryAuditHookProvider),
  );
});

/// Auth repository — API when [isAuthApiEnabled]; mock otherwise.
///
/// When `ENABLE_API_MODE=true`, this provider never silently falls back to mock.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (isAuthApiEnabled(ref)) {
    return ref.read(apiAuthRepositoryProvider);
  }
  return const MockAuthRepository();
});

/// Returns true when global API mode and auth module flag are both enabled.
bool isAuthApiEnabled(Ref ref) {
  return isModuleApiEnabled(ref, authApiEnabledProvider);
}

/// Loads cached server permissions from device storage.
Future<void> loadCachedServerPermissions(Ref ref) async {
  final cached = await ref.read(serverPermissionCacheProvider).read();
  if (cached == null) return;
  ref.read(serverPermissionSyncProvider.notifier).state =
      ServerPermissionSyncState(snapshot: cached);
}

/// Caches permissions from OTP verification before optional network re-sync.
Future<void> applyVerificationPermissions(
  Ref ref, {
  required AuthVerificationResult result,
}) async {
  if (!isAuthApiEnabled(ref) || result.permissions.isEmpty) return;
  final policy = const AuthMapper().toPermissionPolicyFromVerification(
    result: result,
  );
  await cacheServerPermissionPolicy(ref, policy: policy);
}

/// Fetches permissions from auth server and caches locally (F1 RBAC sync).
Future<void> syncAuthPermissions(
  Ref ref, {
  required String userId,
  String? tenantId,
}) async {
  await syncAuthPermissionsFromServer(
    ref,
    userId: userId,
    tenantId: tenantId,
  );
}
