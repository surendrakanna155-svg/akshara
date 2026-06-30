import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW5 · QA-J-056 — RE-SCOPED (owner decision, 2026-06-30) to the GA-ready
/// **School Branding** apply, NOT the platform white-label hub.
///
/// The platform white-label platform (QA-J-056's original target) is Phase-2 /
/// OFF live (owner decision O10; `manageWhiteLabelPlatform` removed from every
/// role; API returns empty stubs), so its apply/persist path is feature-blocked
/// and intentionally NOT tested. The GA-ready slice IS real: `PUT /school/branding`
/// (`school_completion_handlers.ts:278`, gated `manageSchoolBranding`) persists
/// per-school branding (`schools.white_label_config`) and is route-contract tested
/// in `qw4_school_completion_route_contract_test.ts`. This proves the branding
/// apply authorization and pins the Phase-2 boundary (platform white-label held by
/// no role).
UserPermissions _role(ErpRole r) => UserPermissions.forRole(r);

void main() {
  group('QW5 · QA-J-056 school branding apply authorization (re-scoped)', () {
    test('school leadership is authorized to view + apply school branding', () {
      for (final role in [
        ErpRole.superAdmin,
        ErpRole.schoolAdmin,
        ErpRole.principal,
        ErpRole.vicePrincipal,
      ]) {
        expect(_role(role).has(Permission.viewSchoolBranding), isTrue,
            reason: '${role.name} should view branding');
        expect(_role(role).has(Permission.manageSchoolBranding), isTrue,
            reason: '${role.name} should apply branding');
      }
    });

    test('non-leadership personas are DENIED the branding apply verb', () {
      expect(_role(ErpRole.teacher).has(Permission.manageSchoolBranding),
          isFalse);
      expect(_role(ErpRole.financeAdmin).has(Permission.manageSchoolBranding),
          isFalse);
      expect(_role(ErpRole.parent).has(Permission.manageSchoolBranding),
          isFalse);
    });

    test('Phase-2 boundary: the platform white-label gate is held by NO role '
        '(O10 — deferred, API OFF live)', () {
      for (final role in ErpRole.values) {
        expect(_role(role).has(Permission.manageWhiteLabelPlatform), isFalse,
            reason: '${role.name} must NOT hold the Phase-2 white-label gate');
      }
    });
  });
}
