import 'erp_role.dart';
import 'permissions.dart';
import 'role_permissions.dart';

/// Resolves effective permissions for a user session.
class UserPermissions {
  const UserPermissions({
    required this.role,
    required this.permissionSet,
  });

  factory UserPermissions.forRole(ErpRole role) {
    return UserPermissions(
      role: role,
      permissionSet: RolePermissionMatrix.permissionsFor(role),
    );
  }

  factory UserPermissions.fromClaims({
    required ErpRole role,
    Iterable<Permission>? explicitPermissions,
  }) {
    if (explicitPermissions != null && explicitPermissions.isNotEmpty) {
      return UserPermissions(
        role: role,
        permissionSet: PermissionSet.from(explicitPermissions),
      );
    }
    return UserPermissions.forRole(role);
  }

  final ErpRole role;
  final PermissionSet permissionSet;

  bool has(Permission permission) => permissionSet.contains(permission);

  bool hasAny(Iterable<Permission> permissions) =>
      permissionSet.containsAny(permissions);

  bool hasAll(Iterable<Permission> permissions) =>
      permissionSet.containsAll(permissions);
}
