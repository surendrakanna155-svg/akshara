import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/mutation_permission_registry.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW2 Batch 2 — Teacher module-write authorization.
///
/// QA-J-015 (grade/review homework), QA-J-016 (class-teacher approve/reject a
/// student leave), QA-J-017 (apply for own leave → an approver sees it). The
/// write/persistence paths exist (teacher_mutations_provider + teacher suites);
/// the QW2 gap is proving the teacher is correctly scoped — authorized for the
/// teacher writes, able to approve a STUDENT leave but NOT to approve their OWN
/// (staff) leave, which the HR approver owns. Deterministic gate proof against
/// the same `MutationPermissionRegistry` the real flows use.
Permission _gate(String module, String mutationId) =>
    MutationPermissionRegistry.forModule(module)
        .firstWhere((e) => e.mutationId == mutationId)
        .permission;

void main() {
  final teacher = UserPermissions.forRole(ErpRole.teacher);

  group('QW2 · teacher write authorization', () {
    test('QA-J-015 · Teacher is authorized to grade/review homework '
        '(manageHomework); parent/student/finance are not', () {
      expect(teacher.has(Permission.manageHomework), isTrue);
      for (final r in [
        ErpRole.parent,
        ErpRole.student,
        ErpRole.financeAdmin,
      ]) {
        expect(UserPermissions.forRole(r).has(Permission.manageHomework), isFalse,
            reason: '$r must not grade homework');
      }
    });

    test('QA-J-016 · Class teacher can approve/reject a STUDENT leave '
        '(approveStudentLeave); other roles cannot', () {
      final approve = _gate('management', 'resolveApprovalApprove');
      final reject = _gate('management', 'resolveApprovalReject');
      expect(approve, Permission.approveStudentLeave);
      expect(reject, Permission.approveStudentLeave);
      expect(teacher.has(approve), isTrue);
      for (final r in [
        ErpRole.parent,
        ErpRole.student,
        ErpRole.financeAdmin,
        ErpRole.librarian,
      ]) {
        expect(UserPermissions.forRole(r).has(approve), isFalse,
            reason: '$r must not approve a student leave');
      }
    });

    test('QA-J-017 · Teacher applies for own leave (self-service) but CANNOT '
        'approve it; the HR approver (manageHr) owns staff-leave approval', () {
      // Staff-leave approval gates on manageHr — the teacher does NOT hold it,
      // so a teacher can never self-approve their own leave.
      final approveStaffLeave = _gate('hr', 'approveLeaveRequest');
      expect(approveStaffLeave, Permission.manageHr);
      expect(teacher.has(approveStaffLeave), isFalse);

      // The HR approver scope (manageHr) is the one that sees + approves it.
      final hrApprover = UserPermissions.fromClaims(
        roles: const [ErpRole.management],
        explicitPermissions: const [Permission.manageHr, Permission.viewHr],
      );
      expect(hrApprover.has(approveStaffLeave), isTrue);
    });
  });
}
