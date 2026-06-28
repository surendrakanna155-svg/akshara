import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW1 · QA-J-019/024/037/047/058 — proves the 4 RBAC-isolation personas resolve
/// to correctly scoped effective permissions via the SAME path the route guards
/// use (`UserPermissions.fromClaims`, explicit perms override the role union).
/// This is the fast unit guard; the Patrol journeys assert the live route guards.
UserPermissions _resolve(QaLoginPersona persona) {
  return UserPermissions.fromClaims(
    roles: persona.erpRoles,
    explicitPermissions: persona.customPermissions,
  );
}

void main() {
  group('QA persona RBAC scoping', () {
    test('HR persona: reaches HR, denied finance + control-center + SIS', () {
      final p = _resolve(QaLoginPersona.hr);
      expect(p.has(Permission.viewHr), isTrue);
      expect(p.has(Permission.manageHr), isTrue);
      expect(p.has(Permission.viewEmployees), isTrue);
      expect(p.has(Permission.viewFinance), isFalse);
      expect(p.has(Permission.viewControlCenter), isFalse);
      expect(p.has(Permission.manageSis), isFalse);
    });

    test('Director persona: reaches director portal, denied control-center + '
        'single-school manage', () {
      final p = _resolve(QaLoginPersona.director);
      expect(p.has(Permission.viewDirectorPortal), isTrue);
      expect(p.has(Permission.manageDirectorPortal), isTrue);
      expect(p.has(Permission.viewControlCenter), isFalse);
      expect(p.has(Permission.manageSis), isFalse);
      expect(p.has(Permission.viewFinance), isFalse);
      // Single-school director holds NO chain-only view perms (QA-J-048 negative).
      expect(p.has(Permission.viewFranchiseOperations), isFalse);
      expect(p.has(Permission.viewMultiSchoolOperations), isFalse);
      expect(p.has(Permission.viewOrganizationBuilder), isFalse);
      expect(QaLoginPersona.director.isChainOrg, isFalse);
    });

    test('Chain Director persona (QA-J-048 positive): director scope PLUS chain '
        'perms, flags a chain org, still denied control-center', () {
      final p = _resolve(QaLoginPersona.chainDirector);
      // Director scope is retained.
      expect(p.has(Permission.viewDirectorPortal), isTrue);
      expect(p.has(Permission.manageDirectorPortal), isTrue);
      // Chain-only view perms are added (necessary to reach the gated routes).
      expect(p.has(Permission.viewFranchiseOperations), isTrue);
      expect(p.has(Permission.viewBranchOperations), isTrue);
      expect(p.has(Permission.viewMultiSchoolOperations), isTrue);
      expect(p.has(Permission.viewOrganizationBuilder), isTrue);
      // It flags a chain org — the ChainScope gate's grant condition.
      expect(QaLoginPersona.chainDirector.isChainOrg, isTrue);
      // Still scoped: never the platform control-center, never single-school SIS.
      expect(p.has(Permission.viewControlCenter), isFalse);
      expect(p.has(Permission.manageSis), isFalse);
      expect(p.has(Permission.viewFinance), isFalse);
    });

    test('School Admin persona: single-school modules, denied control-center',
        () {
      final p = _resolve(QaLoginPersona.schoolAdmin);
      expect(p.has(Permission.viewSis), isTrue);
      expect(p.has(Permission.manageSis), isTrue);
      expect(p.has(Permission.viewAdmissions), isTrue);
      expect(p.has(Permission.viewControlCenter), isFalse);
      expect(p.has(Permission.manageControlCenter), isFalse);
    });

    test('Staff (librarian) persona: library only, denied finance + employees',
        () {
      final p = _resolve(QaLoginPersona.staff);
      expect(p.has(Permission.viewLibrary), isTrue);
      expect(p.has(Permission.manageLibrary), isTrue);
      expect(p.has(Permission.viewFinance), isFalse);
      expect(p.has(Permission.manageEmployees), isFalse);
      expect(p.has(Permission.viewControlCenter), isFalse);
    });

    test('none of the QW1 RBAC personas hold superAdmin control-center power',
        () {
      for (final persona in [
        QaLoginPersona.hr,
        QaLoginPersona.schoolAdmin,
        QaLoginPersona.director,
        QaLoginPersona.staff,
        QaLoginPersona.chainDirector,
      ]) {
        expect(
          _resolve(persona).has(Permission.viewControlCenter),
          isFalse,
          reason: '${persona.buttonLabel} must not reach control-center',
        );
      }
    });
  });
}
