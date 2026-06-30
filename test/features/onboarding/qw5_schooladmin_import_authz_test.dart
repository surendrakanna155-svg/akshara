import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW5 · QA-J-065 — Cross-cutting · bulk student import (bad-row + rollback) under
/// the **schoolAdmin** persona.
///
/// The rich import journey (valid commit, bad-row rejection, SAVEPOINT/ROLLBACK)
/// is already proven by `first_time_student_onboarding_live_test` — but as
/// superAdmin. The remaining P2 gap is single-school scope: the importer is gated
/// by `manageOnboarding` (`onboarding_handlers.ts:29`), which the schoolAdmin holds
/// (migration `20260614900000_school_onboarding.sql`). This proves the schoolAdmin
/// can run the import under their own scope while non-onboarding personas cannot —
/// the persistence/rollback chain itself is the live test's responsibility.
UserPermissions _role(ErpRole r) => UserPermissions.forRole(r);

void main() {
  group('QW5 · QA-J-065 schoolAdmin bulk-import authorization', () {
    test('School Admin is authorized to run the bulk student import '
        '(manageOnboarding)', () {
      expect(_role(ErpRole.schoolAdmin).has(Permission.manageOnboarding),
          isTrue);
    });

    test('non-onboarding personas are DENIED the import', () {
      expect(_role(ErpRole.teacher).has(Permission.manageOnboarding), isFalse);
      expect(_role(ErpRole.financeAdmin).has(Permission.manageOnboarding),
          isFalse);
      expect(_role(ErpRole.parent).has(Permission.manageOnboarding), isFalse);
      expect(_role(ErpRole.student).has(Permission.manageOnboarding), isFalse);
    });
  });
}
