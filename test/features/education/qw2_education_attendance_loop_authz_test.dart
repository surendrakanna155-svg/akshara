import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/mutation_permission_registry.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW2 Batch 6 (closeable rows) — question-paper chain + attendance-correction
/// loop authorization.
///
/// QA-J-064 (teacher builds/moderates a question paper → principal validates +
/// publishes) and QA-J-066 (teacher submits an attendance correction → principal
/// approves → reflected). The build/approve persistence is covered by
/// education_remark_e2e / patrol_batch1-2b; the QW2 gap is the two-actor scoping
/// — the teacher owns the build/submit verbs, the principal owns the
/// validate/approve verbs, and neither can do the other's.
Permission _gate(String module, String mutationId) =>
    MutationPermissionRegistry.forModule(module)
        .firstWhere((e) => e.mutationId == mutationId)
        .permission;

void main() {
  final teacher = UserPermissions.forRole(ErpRole.teacher);
  final principal = UserPermissions.forRole(ErpRole.principal);

  group('QW2 · education + attendance-loop authorization', () {
    test('QA-J-064 · Teacher builds/moderates a paper (manageEducation + '
        'manageExams/manageExamMarks); principal validates + publishes', () {
      // Build / moderate side — teacher.
      expect(teacher.has(Permission.manageEducation), isTrue);
      expect(teacher.has(_gate('academics', 'updateExamMark')),
          isTrue); // manageExamMarks
      // Validate / publish side — principal (the teacher cannot self-validate).
      expect(principal.has(Permission.approveExamResults), isTrue);
      expect(principal.has(Permission.publishExamResults), isTrue);
      expect(teacher.has(Permission.approveExamResults), isFalse);
      expect(teacher.has(Permission.publishExamResults), isFalse);
    });

    test(
        'QA-J-066 · Teacher submits an attendance correction '
        '(submitAttendanceCorrection); principal resolves it '
        '(approveAttendanceCorrection)', () {
      final submit = _gate('teacher', 'submitAttendanceCorrection');
      expect(submit, Permission.submitAttendanceCorrection);
      expect(teacher.has(submit), isTrue);
      // The approval verb is the principal's, not the submitter's. The real
      // resolve path is the unified Approval Center (resolveApprovalRequestProvider
      // → /approvals/:id/approve|reject), gated per-type via
      // approvalPermissionForType(attendanceCorrection) — NOT the
      // mutation-registry 'resolveManagementApproval' entry this test used to
      // check, which #1 gap-sweep (2026-07) found was dead client code with no
      // caller (POST /management/tasks/:id/resolve has no backend route) and
      // has since been removed.
      const resolve = Permission.approveAttendanceCorrection;
      expect(principal.has(resolve), isTrue);
      expect(teacher.has(resolve), isFalse);
    });
  });
}
