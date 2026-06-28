import 'package:akshara_erp/core/security/mutation_permission_registry.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW2 · QA-J-020 — HR add/edit employee under the HR persona (not the god-admin).
///
/// The employee CRUD *persistence* chain (create→edit→activate→deactivate) is
/// already proven by `hr_employee_crud_e2e` — but it runs as superAdmin. The
/// QW2 gap is proving a SCOPED HR persona is authorized for those writes (and a
/// non-HR role is not), so the journey holds for a real HR user, not just a
/// god-login. This is the deterministic authorization proof; the UI-under-HR-
/// persona run is the Patrol follow-up.
UserPermissions _resolve(QaLoginPersona persona) => UserPermissions.fromClaims(
      roles: persona.erpRoles,
      explicitPermissions: persona.customPermissions,
    );

/// The HR employee write mutations and the permission each is gated on.
const _employeeWriteMutations = ['createEmployee', 'updateEmployee', 'setEmployeeStatus'];

void main() {
  final hrMutations = MutationPermissionRegistry.forModule('hr');

  MutationPermissionEntry entry(String mutationId) =>
      hrMutations.firstWhere((e) => e.mutationId == mutationId);

  group('QA-J-020 · HR employee writes are gated on manageHr', () {
    test('the registry gates create/update/setStatus employee on manageHr', () {
      for (final id in _employeeWriteMutations) {
        expect(entry(id).permission, Permission.manageHr,
            reason: '$id must require manageHr');
      }
    });

    test('the HR persona is AUTHORIZED for every employee write mutation', () {
      final hr = _resolve(QaLoginPersona.hr);
      for (final id in _employeeWriteMutations) {
        expect(hr.has(entry(id).permission), isTrue,
            reason: 'HR persona must be allowed to $id (not a god-login)');
      }
    });

    test('a scoped non-HR persona is DENIED the employee write mutations', () {
      // Finance + Librarian hold real, narrow scopes — neither has manageHr.
      for (final persona in [QaLoginPersona.finance, QaLoginPersona.staff]) {
        final perms = _resolve(persona);
        for (final id in _employeeWriteMutations) {
          expect(perms.has(entry(id).permission), isFalse,
              reason: '${persona.buttonLabel} must NOT be able to $id');
        }
      }
    });

    test('HR is scoped — authorized for HR writes but not finance/SIS writes',
        () {
      final hr = _resolve(QaLoginPersona.hr);
      expect(hr.has(Permission.manageHr), isTrue);
      expect(hr.has(Permission.manageFinance), isFalse);
      expect(hr.has(Permission.manageSis), isFalse);
      expect(hr.has(Permission.viewControlCenter), isFalse);
    });
  });
}
