import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW5 · QA-J-023 — HR · recruitment pipeline + performance-review WRITES.
///
/// `hr_workflows_test` only exercised these as READ. The write paths are real:
/// `hr_write_handlers.ts` → `handleCreate/UpdateRecruitmentOpening` and
/// `handleCreate/UpdatePerformanceReview`, all guarded by
/// `createModuleWriteHandlers("manageHr")` (line 13). Those mutations are not in
/// the client `MutationPermissionRegistry` (server-enforced), so this proves the
/// gate at the permission layer: the HR scope (and school leadership) may move a
/// recruitment stage or save a performance review; non-HR personas cannot. The
/// persistence chain is the backend handler's responsibility.
UserPermissions _role(ErpRole r) => UserPermissions.forRole(r);

UserPermissions _persona(QaLoginPersona p) => UserPermissions.fromClaims(
      roles: p.erpRoles,
      explicitPermissions: p.customPermissions,
    );

void main() {
  group('QW5 · QA-J-023 HR recruitment / performance authorization', () {
    test('The scoped HR persona is authorized for recruitment + performance '
        'writes (manageHr), denied finance', () {
      final hr = _persona(QaLoginPersona.hr);
      expect(hr.has(Permission.manageHr), isTrue);
      // HR scope does not bleed into finance.
      expect(hr.has(Permission.manageFinance), isFalse);
    });

    test('School leadership roles that own HR also hold the write gate', () {
      expect(_role(ErpRole.superAdmin).has(Permission.manageHr), isTrue);
      expect(_role(ErpRole.schoolAdmin).has(Permission.manageHr), isTrue);
      expect(_role(ErpRole.management).has(Permission.manageHr), isTrue);
    });

    test('Non-HR personas are DENIED the recruitment / performance write verb',
        () {
      expect(_role(ErpRole.financeAdmin).has(Permission.manageHr), isFalse);
      expect(_role(ErpRole.teacher).has(Permission.manageHr), isFalse);
      expect(_role(ErpRole.parent).has(Permission.manageHr), isFalse);
    });
  });
}
