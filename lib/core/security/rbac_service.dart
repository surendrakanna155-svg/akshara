import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_models.dart';
import '../../features/auth/auth_provider.dart';
import '../security/server_permission_provider.dart';
import 'erp_role.dart';
import 'permissions.dart';
import 'mutation_permission_validator.dart';
import 'user_permissions.dart';

/// Authorization service — single source of truth for permission checks.
class RbacService {
  const RbacService(this._permissions);

  final UserPermissions? _permissions;

  bool get isAuthenticated => _permissions != null;

  ErpRole? get role => _permissions?.role;

  PermissionSet get permissions =>
      _permissions?.permissionSet ?? const PermissionSet({});

  bool hasPermission(Permission permission) =>
      _permissions?.has(permission) ?? false;

  bool hasAnyPermission(Iterable<Permission> permissions) =>
      _permissions?.hasAny(permissions) ?? false;

  bool hasAllPermissions(Iterable<Permission> permissions) =>
      _permissions?.hasAll(permissions) ?? false;

  bool hasManagePermission(Permission permission) =>
      isManagePermission(permission) && hasPermission(permission);

  bool hasApprovePermission(Permission permission) =>
      isApprovePermission(permission) && hasPermission(permission);
}

/// Resolves [UserPermissions] from the active auth session.
final userPermissionsProvider = Provider<UserPermissions?>((ref) {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) return null;

  final claims = auth.claims;
  if (claims != null) {
    final sync = ref.watch(serverPermissionSyncProvider);
    final snapshot = sync.snapshot;
    if (snapshot != null &&
        !snapshot.isStale &&
        snapshot.policy.userId == claims.userId &&
        snapshot.policy.effectivePermissions.isNotEmpty) {
      return UserPermissions(
        role: claims.erpRole,
        permissionSet: PermissionSet.from(snapshot.policy.effectivePermissions),
      );
    }

    return UserPermissions.fromClaims(
      role: claims.erpRole,
      explicitPermissions: claims.permissions,
    );
  }

  return switch (auth.role) {
    UserRole.staff => UserPermissions.forRole(ErpRole.superAdmin),
    UserRole.teacher => UserPermissions.forRole(ErpRole.teacher),
    UserRole.parent => UserPermissions.forRole(ErpRole.parent),
    UserRole.student => UserPermissions.forRole(ErpRole.student),
    null => null,
  };
});

final rbacServiceProvider = Provider<RbacService>((ref) {
  return RbacService(ref.watch(userPermissionsProvider));
});

final currentPermissionsProvider = Provider<PermissionSet>((ref) {
  return ref.watch(rbacServiceProvider).permissions;
});

final canViewFinanceProvider = Provider<bool>((ref) {
  return ref.watch(rbacServiceProvider).hasPermission(Permission.viewFinance);
});

final canManageFinanceProvider = Provider<bool>((ref) {
  return ref.watch(rbacServiceProvider).hasPermission(Permission.manageFinance);
});

final canApproveRefundsProvider = Provider<bool>((ref) {
  return ref
      .watch(rbacServiceProvider)
      .hasPermission(Permission.approveRefunds);
});

final canViewAdmissionsProvider = Provider<bool>((ref) {
  return ref
      .watch(rbacServiceProvider)
      .hasPermission(Permission.viewAdmissions);
});

final canManageAdmissionsProvider = Provider<bool>((ref) {
  return ref
      .watch(rbacServiceProvider)
      .hasPermission(Permission.manageAdmissions);
});

final canApproveAdmissionsProvider = Provider<bool>((ref) {
  return ref
      .watch(rbacServiceProvider)
      .hasPermission(Permission.approveAdmissions);
});

final canViewSisProvider = Provider<bool>((ref) {
  return ref.watch(rbacServiceProvider).hasPermission(Permission.viewSis);
});

final canManageSisProvider = Provider<bool>((ref) {
  return ref.watch(rbacServiceProvider).hasPermission(Permission.manageSis);
});

final canManageCommunicationProvider = Provider<bool>((ref) {
  return ref
      .watch(rbacServiceProvider)
      .hasPermission(Permission.manageCommunication);
});

final canViewManagementProvider = Provider<bool>((ref) {
  return ref
      .watch(rbacServiceProvider)
      .hasPermission(Permission.viewManagement);
});

final canViewTransportProvider = Provider<bool>((ref) {
  return ref.watch(rbacServiceProvider).hasPermission(Permission.viewTransport);
});

final canViewHrProvider = Provider<bool>((ref) {
  return ref.watch(rbacServiceProvider).hasPermission(Permission.viewHr);
});

final canViewHostelProvider = Provider<bool>((ref) {
  return ref.watch(rbacServiceProvider).hasPermission(Permission.viewHostel);
});

final canViewLibraryProvider = Provider<bool>((ref) {
  return ref.watch(rbacServiceProvider).hasPermission(Permission.viewLibrary);
});

final canViewInventoryProvider = Provider<bool>((ref) {
  return ref
      .watch(rbacServiceProvider)
      .hasPermission(Permission.viewInventory);
});

final canViewAlumniProvider = Provider<bool>((ref) {
  return ref.watch(rbacServiceProvider).hasPermission(Permission.viewAlumni);
});

final canViewControlCenterProvider = Provider<bool>((ref) {
  return ref
      .watch(rbacServiceProvider)
      .hasPermission(Permission.viewControlCenter);
});

final canViewAdminHubProvider = Provider<bool>((ref) {
  return ref.watch(rbacServiceProvider).hasPermission(Permission.viewAdminHub);
});
