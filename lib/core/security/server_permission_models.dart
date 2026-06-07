import 'package:flutter/foundation.dart';

import 'permissions.dart';

/// A permission granted by the server policy engine.
@immutable
class PermissionGrant {
  const PermissionGrant({
    required this.permission,
    required this.grantedAt,
    this.source = 'server',
    this.expiresAt,
  });

  final Permission permission;
  final DateTime grantedAt;
  final String source;
  final DateTime? expiresAt;

  bool get isActive {
    if (expiresAt == null) return true;
    return DateTime.now().isBefore(expiresAt!);
  }

  factory PermissionGrant.fromJson(Map<String, dynamic> json) {
    final name = json['permission'] as String? ?? '';
    Permission? permission;
    for (final p in Permission.values) {
      if (p.name == name) {
        permission = p;
        break;
      }
    }

    return PermissionGrant(
      permission: permission ?? Permission.viewAdminHub,
      grantedAt: DateTime.tryParse(json['grantedAt'] as String? ?? '') ??
          DateTime.now(),
      source: json['source'] as String? ?? 'server',
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'permission': permission.name,
        'grantedAt': grantedAt.toIso8601String(),
        'source': source,
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
      };
}

/// A permission explicitly revoked by server policy.
@immutable
class PermissionRevocation {
  const PermissionRevocation({
    required this.permission,
    required this.revokedAt,
    this.reason,
  });

  final Permission permission;
  final DateTime revokedAt;
  final String? reason;

  factory PermissionRevocation.fromJson(Map<String, dynamic> json) {
    final name = json['permission'] as String? ?? '';
    Permission? permission;
    for (final p in Permission.values) {
      if (p.name == name) {
        permission = p;
        break;
      }
    }

    return PermissionRevocation(
      permission: permission ?? Permission.viewAdminHub,
      revokedAt: DateTime.tryParse(json['revokedAt'] as String? ?? '') ??
          DateTime.now(),
      reason: json['reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'permission': permission.name,
        'revokedAt': revokedAt.toIso8601String(),
        if (reason != null) 'reason': reason,
      };
}

/// Server-side RBAC policy snapshot (synced from backend when available).
@immutable
class ServerPermissionPolicy {
  const ServerPermissionPolicy({
    required this.version,
    required this.grants,
    required this.revocations,
    required this.syncedAt,
    this.tenantId,
    this.userId,
  });

  final int version;
  final List<PermissionGrant> grants;
  final List<PermissionRevocation> revocations;
  final DateTime syncedAt;
  final String? tenantId;
  final String? userId;

  Set<Permission> get effectivePermissions {
    final revoked = revocations.map((r) => r.permission).toSet();
    final active = <Permission>{};
    for (final grant in grants) {
      if (grant.isActive && !revoked.contains(grant.permission)) {
        active.add(grant.permission);
      }
    }
    return active;
  }

  factory ServerPermissionPolicy.fromJson(Map<String, dynamic> json) {
    return ServerPermissionPolicy(
      version: json['version'] as int? ?? 1,
      grants: [
        for (final item in json['grants'] as List<dynamic>? ?? const [])
          if (item is Map<String, dynamic>)
            PermissionGrant.fromJson(item),
      ],
      revocations: [
        for (final item in json['revocations'] as List<dynamic>? ?? const [])
          if (item is Map<String, dynamic>)
            PermissionRevocation.fromJson(item),
      ],
      syncedAt: DateTime.tryParse(json['syncedAt'] as String? ?? '') ??
          DateTime.now(),
      tenantId: json['tenantId'] as String?,
      userId: json['userId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'grants': grants.map((g) => g.toJson()).toList(),
        'revocations': revocations.map((r) => r.toJson()).toList(),
        'syncedAt': syncedAt.toIso8601String(),
        if (tenantId != null) 'tenantId': tenantId,
        if (userId != null) 'userId': userId,
      };

  ServerPermissionPolicy copyWith({
    int? version,
    List<PermissionGrant>? grants,
    List<PermissionRevocation>? revocations,
    DateTime? syncedAt,
    String? tenantId,
    String? userId,
  }) {
    return ServerPermissionPolicy(
      version: version ?? this.version,
      grants: grants ?? this.grants,
      revocations: revocations ?? this.revocations,
      syncedAt: syncedAt ?? this.syncedAt,
      tenantId: tenantId ?? this.tenantId,
      userId: userId ?? this.userId,
    );
  }
}

/// Locally cached server policy for offline RBAC reconciliation.
@immutable
class CachedPermissionSnapshot {
  const CachedPermissionSnapshot({
    required this.policy,
    required this.cachedAt,
    this.expiresAt,
  });

  final ServerPermissionPolicy policy;
  final DateTime cachedAt;
  final DateTime? expiresAt;

  bool get isStale {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  factory CachedPermissionSnapshot.fromJson(Map<String, dynamic> json) {
    return CachedPermissionSnapshot(
      policy: ServerPermissionPolicy.fromJson(
        json['policy'] as Map<String, dynamic>? ?? const {},
      ),
      cachedAt: DateTime.tryParse(json['cachedAt'] as String? ?? '') ??
          DateTime.now(),
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'policy': policy.toJson(),
        'cachedAt': cachedAt.toIso8601String(),
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
      };
}

/// Tracks local permission policy version across cache writes and server syncs.
@immutable
class PermissionVersionTracker {
  const PermissionVersionTracker({
    this.localVersion = 0,
    this.lastSyncedVersion,
  });

  final int localVersion;
  final int? lastSyncedVersion;

  /// Chooses the policy version to persist after applying a server payload.
  int resolveVersionForSync(ServerPermissionPolicy incoming) {
    if (incoming.version > localVersion) {
      return incoming.version;
    }
    if (localVersion == 0) {
      return incoming.version > 0 ? incoming.version : 1;
    }
    return localVersion + 1;
  }

  PermissionVersionTracker afterSync(int resolvedVersion) {
    return PermissionVersionTracker(
      localVersion: resolvedVersion,
      lastSyncedVersion: resolvedVersion,
    );
  }

  bool isOlderThan(ServerPermissionPolicy policy) =>
      localVersion < policy.version;
}

/// In-memory server policy sync state (no HTTP calls in v2.0).
class ServerPermissionSyncState {
  const ServerPermissionSyncState({
    this.snapshot,
    this.lastSyncError,
    this.isSyncing = false,
  });

  final CachedPermissionSnapshot? snapshot;
  final String? lastSyncError;
  final bool isSyncing;

  ServerPermissionSyncState copyWith({
    CachedPermissionSnapshot? snapshot,
    String? lastSyncError,
    bool? isSyncing,
    bool clearSnapshot = false,
    bool clearError = false,
  }) {
    return ServerPermissionSyncState(
      snapshot: clearSnapshot ? null : (snapshot ?? this.snapshot),
      lastSyncError: clearError ? null : (lastSyncError ?? this.lastSyncError),
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }
}
