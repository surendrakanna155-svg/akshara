import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW5 · QA-J-018 — Teacher · view student-risk and ACT (intervention).
///
/// The student-risk screen surfaces AI risk snapshots; the actionable leg is the
/// teacher logging an intervention, which is a REAL backend write
/// (`teacher_assistant_handlers.ts` → `handleCreateIntervention` → INSERT into
/// `teacher_interventions`). That write is server-gated by `manageTeacherAssistant`
/// (`requirePermission(auth.claims, "manageTeacherAssistant")`, handler line 64) —
/// it is intentionally NOT in the client `MutationPermissionRegistry`, so this
/// proves the gate at the permission layer the server enforces: the teacher (and
/// school leadership) may record an intervention; read-only / unrelated roles
/// cannot. The persistence chain itself is the backend handler's responsibility.
UserPermissions _role(ErpRole r) => UserPermissions.forRole(r);

void main() {
  group('QW5 · QA-J-018 teacher intervention authorization', () {
    test('Teacher is authorized to record a student-risk intervention '
        '(manageTeacherAssistant)', () {
      expect(_role(ErpRole.teacher).has(Permission.manageTeacherAssistant),
          isTrue);
    });

    test('School leadership (schoolAdmin / superAdmin) also holds the '
        'intervention write gate', () {
      expect(_role(ErpRole.schoolAdmin).has(Permission.manageTeacherAssistant),
          isTrue);
      expect(_role(ErpRole.superAdmin).has(Permission.manageTeacherAssistant),
          isTrue);
    });

    test('Read-only / unrelated personas are DENIED the intervention write '
        'verb', () {
      // The risk snapshot may be visible, but recording an intervention is a
      // teacher/leadership action — parents, students and functional managers
      // (finance/library) cannot perform it.
      expect(_role(ErpRole.parent).has(Permission.manageTeacherAssistant),
          isFalse);
      expect(_role(ErpRole.student).has(Permission.manageTeacherAssistant),
          isFalse);
      expect(_role(ErpRole.financeAdmin).has(Permission.manageTeacherAssistant),
          isFalse);
      expect(_role(ErpRole.librarian).has(Permission.manageTeacherAssistant),
          isFalse);
    });
  });
}
