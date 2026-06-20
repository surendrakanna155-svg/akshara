import 'erp_role.dart';
import 'permissions.dart';
import 'role_permissions.dart';

/// Resolves effective permissions for a user session.
///
/// Multi-role: a user can hold several [ErpRole]s; [permissionSet] is the UNION
/// of every held role's permissions. [roles] is the source of truth (primary
/// first); the legacy single-role [role] accessor returns the primary role and
/// [UserPermissions.forRole] keeps working for existing callers.
class UserPermissions {
  UserPermissions({
    ErpRole? role,
    List<ErpRole>? roles,
    required this.permissionSet,
  })  : assert(
          role != null || (roles != null && roles.isNotEmpty),
          'Provide role or a non-empty roles',
        ),
        roles = _normalizeRoles(role, roles);

  /// Single-role factory (backward compatible).
  factory UserPermissions.forRole(ErpRole role) {
    return UserPermissions(
      roles: <ErpRole>[role],
      permissionSet: RolePermissionMatrix.permissionsFor(role),
    );
  }

  /// Multi-role factory — permissions are the union across [roles].
  factory UserPermissions.forRoles(Iterable<ErpRole> roles) {
    final list = roles.toList(growable: false);
    return UserPermissions(
      roles: list,
      permissionSet: RolePermissionMatrix.permissionsForRoles(list),
    );
  }

  factory UserPermissions.fromClaims({
    ErpRole? role,
    List<ErpRole>? roles,
    Iterable<Permission>? explicitPermissions,
  }) {
    final resolved = _normalizeRoles(role, roles);
    if (explicitPermissions != null && explicitPermissions.isNotEmpty) {
      return UserPermissions(
        roles: resolved,
        permissionSet: PermissionSet.from(explicitPermissions),
      );
    }
    return UserPermissions.forRoles(resolved);
  }

  /// All roles the user holds, primary first. Never empty.
  final List<ErpRole> roles;

  /// Primary (first) role — backward-compatible single-role accessor.
  ErpRole get role => roles.first;

  final PermissionSet permissionSet;

  bool hasRole(ErpRole role) => roles.contains(role);

  bool has(Permission permission) => permissionSet.contains(permission);

  bool hasAny(Iterable<Permission> permissions) =>
      permissionSet.containsAny(permissions);

  bool hasAll(Iterable<Permission> permissions) =>
      permissionSet.containsAll(permissions);

  static List<ErpRole> _normalizeRoles(ErpRole? single, List<ErpRole>? many) {
    final source = (many != null && many.isNotEmpty)
        ? many
        : (single != null ? <ErpRole>[single] : const <ErpRole>[]);
    final out = <ErpRole>[];
    for (final r in source) {
      if (!out.contains(r)) out.add(r);
    }
    return List.unmodifiable(out);
  }
}
