import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/shared_preferences_provider.dart';
import 'permission_cache_service.dart';
import 'server_permission_models.dart';

const String kServerPermissionSnapshotKey = 'server_permission_snapshot_v1';

/// Local cache for server RBAC policy snapshots (no HTTP sync in v2.0).
class ServerPermissionCache implements PermissionSnapshotStore {
  ServerPermissionCache(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<CachedPermissionSnapshot?> read() async {
    final raw = _prefs.getString(kServerPermissionSnapshotKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return CachedPermissionSnapshot.fromJson(json);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(CachedPermissionSnapshot snapshot) async {
    await _prefs.setString(
      kServerPermissionSnapshotKey,
      jsonEncode(snapshot.toJson()),
    );
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(kServerPermissionSnapshotKey);
  }
}

final serverPermissionCacheProvider = Provider<ServerPermissionCache>((ref) {
  return ServerPermissionCache(ref.watch(sharedPreferencesProvider));
});

final permissionCacheServiceProvider = Provider<PermissionCacheService>((ref) {
  return PermissionCacheService(ref.watch(serverPermissionCacheProvider));
});

/// Loads a persisted snapshot into [serverPermissionSyncProvider].
Future<void> hydrateServerPermissionCache(Ref ref) async {
  final snapshot = await ref.read(permissionCacheServiceProvider).read();
  if (snapshot == null) return;
  ref.read(serverPermissionSyncProvider.notifier).state =
      ServerPermissionSyncState(snapshot: snapshot);
}

final serverPermissionSyncProvider =
    StateProvider<ServerPermissionSyncState>((ref) {
  return const ServerPermissionSyncState();
});

/// Applies a policy snapshot to local cache (future server sync entry point).
Future<void> cacheServerPermissionPolicy(
  Ref ref, {
  required ServerPermissionPolicy policy,
  Duration ttl = kDefaultPermissionCacheTtl,
}) async {
  final snapshot =
      await ref.read(permissionCacheServiceProvider).savePolicy(policy, ttl: ttl);
  ref.read(serverPermissionSyncProvider.notifier).state =
      ServerPermissionSyncState(snapshot: snapshot);
}
