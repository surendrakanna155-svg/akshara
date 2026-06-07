import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/api_failure.dart';
import 'permissions.dart';
import 'rbac_service.dart';

/// Thrown when a mutation is blocked by RBAC.
class PermissionDeniedException implements Exception {
  const PermissionDeniedException(this.permission, {this.message});

  final Permission permission;
  final String? message;

  @override
  String toString() =>
      message ?? 'Permission denied: ${permission.name}';
}

bool isManagePermission(Permission permission) =>
    permission.name.startsWith('manage');

bool isApprovePermission(Permission permission) =>
    permission.name.startsWith('approve');

void assertManagePermission(RbacService rbac, Permission permission) {
  if (!rbac.hasManagePermission(permission)) {
    throw ApiFailureException(
      ApiFailure(
        type: ApiFailureType.forbidden,
        message:
            'You do not have permission to ${permission.name}.',
        code: 'RBAC_${permission.name.toUpperCase()}',
      ),
    );
  }
}

void assertApprovePermission(RbacService rbac, Permission permission) {
  if (!rbac.hasApprovePermission(permission)) {
    throw ApiFailureException(
      ApiFailure(
        type: ApiFailureType.forbidden,
        message:
            'You do not have permission to ${permission.name}.',
        code: 'RBAC_${permission.name.toUpperCase()}',
      ),
    );
  }
}

void assertManagePermissionRef(Ref ref, Permission permission) {
  assertManagePermission(ref.read(rbacServiceProvider), permission);
}

void assertApprovePermissionRef(Ref ref, Permission permission) {
  assertApprovePermission(ref.read(rbacServiceProvider), permission);
}

void assertManageAdmissions(RbacService rbac) =>
    assertManagePermission(rbac, Permission.manageAdmissions);

void assertApproveAdmissions(RbacService rbac) =>
    assertApprovePermission(rbac, Permission.approveAdmissions);

void assertManageFinance(RbacService rbac) =>
    assertManagePermission(rbac, Permission.manageFinance);

void assertApproveRefunds(RbacService rbac) =>
    assertApprovePermission(rbac, Permission.approveRefunds);

void assertManageSis(RbacService rbac) =>
    assertManagePermission(rbac, Permission.manageSis);
