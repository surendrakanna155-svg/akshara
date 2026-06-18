import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_repository_providers.dart';
import '../repositories/interfaces/auth_repository.dart';
import 'permission_cache_service.dart';
import 'server_permission_models.dart';
import 'server_permission_provider.dart';

/// Outcome of a server permission sync attempt.
class PermissionSyncResult {
  const PermissionSyncResult._({
    this.snapshot,
    this.error,
  });

  const PermissionSyncResult.success(CachedPermissionSnapshot snapshot)
      : this._(snapshot: snapshot);

  const PermissionSyncResult.failure(String message) : this._(error: message);

  final CachedPermissionSnapshot? snapshot;
  final String? error;

  bool get isSuccess => snapshot != null && error == null;
}

/// Fetches server RBAC policy from auth API and updates local cache.
class PermissionSyncService {
  PermissionSyncService({
    required PermissionCacheService cacheService,
    required AuthRepository authRepository,
  })  : _cacheService = cacheService,
        _authRepository = authRepository;

  final PermissionCacheService _cacheService;
  final AuthRepository _authRepository;

  Future<PermissionSyncResult> fetchAndCache({
    required String userId,
    String? tenantId,
    Duration ttl = kDefaultPermissionCacheTtl,
  }) async {
    try {
      final policy = await _authRepository.fetchPermissionPolicy(
        userId: userId,
        tenantId: tenantId,
      );
      final snapshot = await _cacheService.savePolicy(policy, ttl: ttl);
      return PermissionSyncResult.success(snapshot);
    } on Object catch (error) {
      return PermissionSyncResult.failure(error.toString());
    }
  }
}

final permissionSyncServiceProvider = Provider<PermissionSyncService>((ref) {
  return PermissionSyncService(
    cacheService: ref.watch(permissionCacheServiceProvider),
    authRepository: ref.watch(authRepositoryProvider),
  );
});

void _applySyncResult(Ref ref, PermissionSyncResult result) {
  if (result.isSuccess) {
    ref.read(serverPermissionSyncProvider.notifier).state =
        ServerPermissionSyncState(snapshot: result.snapshot);
    return;
  }

  ref.read(serverPermissionSyncProvider.notifier).state =
      ref.read(serverPermissionSyncProvider).copyWith(
            isSyncing: false,
            lastSyncError: result.error,
          );
}

/// Auth-layer hook: fetch permissions from server and cache locally.
Future<void> syncAuthPermissionsFromServer(
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

  final result = await ref.read(permissionSyncServiceProvider).fetchAndCache(
        userId: userId,
        tenantId: tenantId,
      );

  if (result.isSuccess) {
    ref.read(serverPermissionSyncProvider.notifier).state =
        ref.read(serverPermissionSyncProvider).copyWith(
              isSyncing: false,
              snapshot: result.snapshot,
              clearError: true,
            );
    return;
  }

  _applySyncResult(ref, result);
}

/// Auth-layer hook: hydrate in-memory sync state from device cache.
Future<void> loadCachedServerPermissionsHook(Ref ref) async {
  await hydrateServerPermissionCache(ref);
}
