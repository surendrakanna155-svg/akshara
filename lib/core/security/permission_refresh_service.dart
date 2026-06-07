import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_repository_providers.dart';
import 'permission_cache_service.dart';
import 'permission_sync_service.dart';
import 'server_permission_models.dart';
import 'server_permission_provider.dart';

/// Lifecycle events that may trigger a permission refresh.
enum PermissionRefreshTrigger {
  login,
  tokenRefresh,
  appResume,
}

/// Orchestrates permission refresh on login, token refresh, and app resume.
class PermissionRefreshService {
  PermissionRefreshService(this._cacheService);

  final PermissionCacheService _cacheService;

  Future<void> refreshIfNeeded(
    Ref ref, {
    required PermissionRefreshTrigger trigger,
    required String userId,
    String? tenantId,
    bool force = false,
  }) async {
    if (!isAuthApiEnabled(ref)) return;

    final snapshot = await _cacheService.read();
    final shouldSync = force ||
        snapshot == null ||
        _cacheService.isStale(snapshot) ||
        switch (trigger) {
          PermissionRefreshTrigger.login => true,
          PermissionRefreshTrigger.tokenRefresh => true,
          PermissionRefreshTrigger.appResume =>
            _cacheService.isStale(snapshot),
        };

    if (shouldSync) {
      await syncAuthPermissionsFromServer(
        ref,
        userId: userId,
        tenantId: tenantId,
      );
      return;
    }

    ref.read(serverPermissionSyncProvider.notifier).state =
        ServerPermissionSyncState(snapshot: snapshot);
  }
}

final permissionRefreshServiceProvider =
    Provider<PermissionRefreshService>((ref) {
  return PermissionRefreshService(ref.watch(permissionCacheServiceProvider));
});

/// Refresh hook for post-login permission sync.
Future<void> refreshPermissionsOnLogin(
  Ref ref, {
  required String userId,
  String? tenantId,
}) {
  return ref.read(permissionRefreshServiceProvider).refreshIfNeeded(
        ref,
        trigger: PermissionRefreshTrigger.login,
        userId: userId,
        tenantId: tenantId,
        force: true,
      );
}

/// Refresh hook after access-token refresh.
Future<void> refreshPermissionsOnTokenRefresh(
  Ref ref, {
  required String userId,
  String? tenantId,
}) {
  return ref.read(permissionRefreshServiceProvider).refreshIfNeeded(
        ref,
        trigger: PermissionRefreshTrigger.tokenRefresh,
        userId: userId,
        tenantId: tenantId,
        force: true,
      );
}

/// Refresh hook when app resumes — sync only when cache is missing or stale.
Future<void> refreshPermissionsOnAppResume(
  Ref ref, {
  required String userId,
  String? tenantId,
}) {
  return ref.read(permissionRefreshServiceProvider).refreshIfNeeded(
        ref,
        trigger: PermissionRefreshTrigger.appResume,
        userId: userId,
        tenantId: tenantId,
      );
}
