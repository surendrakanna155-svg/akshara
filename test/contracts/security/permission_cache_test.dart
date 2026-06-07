import 'package:akshara_erp/core/security/permission_cache_service.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/server_permission_models.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryPermissionStore implements PermissionSnapshotStore {
  CachedPermissionSnapshot? snapshot;

  @override
  Future<void> clear() async {
    snapshot = null;
  }

  @override
  Future<CachedPermissionSnapshot?> read() async => snapshot;

  @override
  Future<void> write(CachedPermissionSnapshot value) async {
    snapshot = value;
  }
}

ServerPermissionPolicy _policy({
  int version = 1,
  Set<Permission> permissions = const {Permission.viewFinance},
}) {
  final now = DateTime.now();
  return ServerPermissionPolicy(
    version: version,
    syncedAt: now,
    userId: 'user_1',
    grants: [
      for (final permission in permissions)
        PermissionGrant(permission: permission, grantedAt: now),
    ],
    revocations: const [],
  );
}

void main() {
  group('PermissionCacheService', () {
    late _MemoryPermissionStore store;
    late PermissionCacheService service;

    setUp(() {
      store = _MemoryPermissionStore();
      service = PermissionCacheService(store);
    });

    test('savePolicy bumps version on repeated sync', () async {
      final first = await service.savePolicy(_policy(version: 1));
      expect(first.policy.version, 1);

      final second = await service.savePolicy(_policy(version: 1));
      expect(second.policy.version, 2);
      expect(service.versionTracker.localVersion, 2);
    });

    test('isStale detects expired snapshots', () async {
      final snapshot = CachedPermissionSnapshot(
        policy: _policy(),
        cachedAt: DateTime.now().subtract(const Duration(hours: 13)),
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      expect(service.isStale(snapshot), isTrue);
    });

    test('invalidate clears memory and store', () async {
      await service.savePolicy(_policy());
      expect(service.memorySnapshot, isNotNull);

      await service.invalidate();
      expect(service.memorySnapshot, isNull);
      expect(await store.read(), isNull);
      expect(service.versionTracker.localVersion, 0);
    });

    test('read hydrates version tracker from persisted snapshot', () async {
      store.snapshot = CachedPermissionSnapshot(
        policy: _policy(version: 7),
        cachedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      final loaded = await service.read();
      expect(loaded?.policy.version, 7);
      expect(service.versionTracker.localVersion, 7);
    });
  });

  group('PermissionVersionTracker', () {
    test('resolveVersionForSync prefers higher server version', () {
      const tracker = PermissionVersionTracker(localVersion: 3);
      final resolved = tracker.resolveVersionForSync(_policy(version: 5));
      expect(resolved, 5);
    });

    test('isOlderThan compares against incoming policy version', () {
      const tracker = PermissionVersionTracker(localVersion: 2);
      expect(tracker.isOlderThan(_policy(version: 3)), isTrue);
      expect(tracker.isOlderThan(_policy(version: 2)), isFalse);
    });
  });
}
