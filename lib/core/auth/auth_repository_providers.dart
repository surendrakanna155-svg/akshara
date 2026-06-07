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

/// Fetches permissions from auth server and caches locally.
Future<void> syncAuthPermissions(
  Ref ref, {
  required String userId,
  String? tenantId,
}) async {
  if (!isAuthApiEnabled(ref)) return;

  ref.read(serverPermissionSyncProvider.notifier).state =
      ref.read(serverPermissionSyncProvider).copyWith(
            isSyncing: true,
            clearError: true,
          );

  try {
    final permissions = await ref.read(authRepositoryProvider).getPermissions();
    final policy = const AuthMapper().toPermissionPolicy(
      permissions: permissions,
      userId: userId,
      tenantId: tenantId,
    );
    await cacheServerPermissionPolicy(ref, policy: policy);
  } on Object catch (error) {
    ref.read(serverPermissionSyncProvider.notifier).state =
        ref.read(serverPermissionSyncProvider).copyWith(
              isSyncing: false,
              lastSyncError: error.toString(),
            );
    return;
  }

  ref.read(serverPermissionSyncProvider.notifier).state =
      ref.read(serverPermissionSyncProvider).copyWith(isSyncing: false);
}
