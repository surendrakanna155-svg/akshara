// SCE-1 slice 4 — approveClearanceWaiver client matrix mirrors the server seed
// (20260878: principal, vicePrincipal, schoolAdmin, management, superAdmin +
// org owners). The 5 client-side supervisory roles hold it; makers (manageSis
// without it) and everyone else do not — so the approver queue stays invisible.

import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/role_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const supervisory = {
    ErpRole.superAdmin,
    ErpRole.schoolAdmin,
    ErpRole.principal,
    ErpRole.vicePrincipal,
    ErpRole.management,
  };

  test('the 5 supervisory roles hold approveClearanceWaiver (checker)', () {
    for (final role in supervisory) {
      expect(
        RolePermissionMatrix.permissionsFor(role).contains(Permission.approveClearanceWaiver),
        isTrue,
        reason: '$role must be able to action the clearance waiver queue',
      );
    }
  });

  test('non-supervisory roles (incl. plain SIS makers) do NOT hold it', () {
    for (final role in [
      ErpRole.teacher,
      ErpRole.librarian,
      ErpRole.transportManager,
      ErpRole.admissionsCounselor,
      ErpRole.financeAdmin,
      ErpRole.parent,
      ErpRole.student,
    ]) {
      expect(
        RolePermissionMatrix.permissionsFor(role).contains(Permission.approveClearanceWaiver),
        isFalse,
        reason: '$role must not see the clearance waiver approver queue',
      );
    }
  });
}
