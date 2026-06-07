import 'server_permission_models.dart';

/// Default TTL for cached server permission snapshots.
const Duration kDefaultPermissionCacheTtl = Duration(hours: 12);

/// Abstraction for persisted permission snapshot storage.
abstract class PermissionSnapshotStore {
  Future<CachedPermissionSnapshot?> read();
  Future<void> write(CachedPermissionSnapshot snapshot);
  Future<void> clear();
}

/// Wraps a [PermissionSnapshotStore] with version tracking, stale detection,
/// and invalidation.
class PermissionCacheService {
  PermissionCacheService(this._store);

  final PermissionSnapshotStore _store;
  PermissionVersionTracker _versionTracker = const PermissionVersionTracker();
  CachedPermissionSnapshot? _memory;

  PermissionVersionTracker get versionTracker => _versionTracker;

  CachedPermissionSnapshot? get memorySnapshot => _memory;

  Future<CachedPermissionSnapshot?> read() async {
    _memory ??= await _store.read();
    if (_memory != null) {
      _versionTracker = PermissionVersionTracker(
        localVersion: _memory!.policy.version,
        lastSyncedVersion: _memory!.policy.version,
      );
    }
    return _memory;
  }

  bool isStale(CachedPermissionSnapshot? snapshot) {
    final target = snapshot ?? _memory;
    if (target == null) return true;
    return target.isStale;
  }

  bool isVersionStale(ServerPermissionPolicy policy) {
    return _versionTracker.isOlderThan(policy);
  }

  Future<CachedPermissionSnapshot> savePolicy(
    ServerPermissionPolicy policy, {
    Duration ttl = kDefaultPermissionCacheTtl,
  }) async {
    final resolvedVersion = _versionTracker.resolveVersionForSync(policy);
    final syncedPolicy = policy.copyWith(version: resolvedVersion);
    final snapshot = CachedPermissionSnapshot(
      policy: syncedPolicy,
      cachedAt: DateTime.now(),
      expiresAt: DateTime.now().add(ttl),
    );
    await _store.write(snapshot);
    _memory = snapshot;
    _versionTracker = _versionTracker.afterSync(resolvedVersion);
    return snapshot;
  }

  Future<void> invalidate() async {
    await _store.clear();
    _memory = null;
    _versionTracker = const PermissionVersionTracker();
  }
}
