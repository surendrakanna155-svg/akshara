import '../../core/repositories/interfaces/auth_repository.dart';
import '../../core/security/erp_role.dart';
import 'auth_models.dart';

/// Maps server auth profile to mobile [UserRole] for routing.
UserRole userRoleFromAuthUser(AuthUser user) {
  final scope = user.scope?.toLowerCase();
  if (scope != null) {
    return switch (scope) {
      'parent' => UserRole.parent,
      'teacher' => UserRole.teacher,
      'student' => UserRole.student,
      'school' || 'staff' => UserRole.staff,
      _ => userRoleFromErpRole(user.erpRole),
    };
  }
  return userRoleFromErpRole(user.erpRole);
}

UserRole userRoleFromErpRole(ErpRole erpRole) {
  return switch (erpRole) {
    ErpRole.parent => UserRole.parent,
    ErpRole.teacher => UserRole.teacher,
    ErpRole.student => UserRole.student,
    _ => UserRole.staff,
  };
}

List<LinkedChild> linkedChildrenFromAuthUser(AuthUser user) {
  if (user.childIds.isEmpty) {
    return const [];
  }
  return [
    for (final id in user.childIds)
      LinkedChild(
        id: id,
        name: 'Child',
        classLabel: '',
      ),
  ];
}
