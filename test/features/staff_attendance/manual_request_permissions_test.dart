// Slice 4 — approveStaffAttendance client matrix mirrors the server seed
// (20260820000000: principal, vicePrincipal, schoolAdmin, hrManager,
// management, superAdmin + org owners; the client role model carries the five
// that exist app-side). Regular staff / teachers / parents never hold it —
// the approver queue must stay invisible to them.

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

  test('the 5 supervisory roles hold approveStaffAttendance', () {
    for (final role in supervisory) {
      expect(
        RolePermissionMatrix.permissionsFor(role)
            .contains(Permission.approveStaffAttendance),
        isTrue,
        reason: '$role must be able to action the manual-request queue',
      );
    }
  });

  test('non-supervisory staff and parents/students do NOT hold it', () {
    for (final role in [
      ErpRole.teacher,
      ErpRole.librarian,
      ErpRole.transportManager,
      ErpRole.hostelManager,
      ErpRole.inventoryManager,
      ErpRole.storekeeper,
      ErpRole.financeAdmin,
      ErpRole.admissionsCounselor,
      ErpRole.parent,
      ErpRole.student,
    ]) {
      expect(
        RolePermissionMatrix.permissionsFor(role)
            .contains(Permission.approveStaffAttendance),
        isFalse,
        reason: '$role must not see or action the approver queue',
      );
    }
  });

  test('every staff role still self-checks-in (markStaffAttendance untouched)', () {
    expect(
      RolePermissionMatrix.permissionsFor(ErpRole.teacher)
          .contains(Permission.markStaffAttendance),
      isTrue,
    );
    expect(
      RolePermissionMatrix.permissionsFor(ErpRole.parent)
          .contains(Permission.markStaffAttendance),
      isFalse,
    );
  });
}
