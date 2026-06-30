import 'package:akshara_erp/core/entitlements/entitlement_models.dart';
import 'package:akshara_erp/core/entitlements/entitlement_resolver.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/mutation_permission_registry.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW5 · QA-J-050 (director board-pack export) + QA-J-051 (entitlement lock).
///
/// QA-J-050: "Generate AI exec summary + export board-pack PDF" is REAL —
/// `director_handlers.ts` → `handleExportReport` assembles a live board pack and
/// `AksharaReportExportService.buildDirectorBoardPackPdf` emits an actual PDF
/// artifact (AI summary via Claude with a deterministic fallback). The export is
/// gated by `manageDirectorPortal` (registry `director/exportReport`). This proves
/// the director persona is authorized and unrelated personas are not.
///
/// QA-J-051: even a `manageDirectorPortal` HOLDER is gated by the entitlement
/// ceiling — a Trial/Standard plan without the `module.multi_branch` slug masks
/// the director module off (→ upgrade view, not a 403), and a paid plan lifts it.
UserPermissions _role(ErpRole r) => UserPermissions.forRole(r);

UserPermissions _persona(QaLoginPersona p) => UserPermissions.fromClaims(
      roles: p.erpRoles,
      explicitPermissions: p.customPermissions,
    );

Permission _gate(String module, String mutationId) =>
    MutationPermissionRegistry.forModule(module)
        .firstWhere((e) => e.mutationId == mutationId)
        .permission;

void main() {
  group('QW5 · QA-J-050 director board-pack export authorization', () {
    test('board-pack export is gated by manageDirectorPortal and the director '
        'persona holds it', () {
      expect(_gate('director', 'exportReport'), Permission.manageDirectorPortal);
      final director = _persona(QaLoginPersona.director);
      expect(director.has(Permission.manageDirectorPortal), isTrue);
    });

    test('unrelated personas are DENIED the board-pack export verb', () {
      expect(_role(ErpRole.financeAdmin).has(Permission.manageDirectorPortal),
          isFalse);
      expect(_role(ErpRole.teacher).has(Permission.manageDirectorPortal),
          isFalse);
      expect(_role(ErpRole.librarian).has(Permission.manageDirectorPortal),
          isFalse);
      expect(_role(ErpRole.parent).has(Permission.manageDirectorPortal),
          isFalse);
    });
  });

  group('QW5 · QA-J-051 director entitlement lock', () {
    test('a permission holder is STILL gated off when the plan lacks the '
        'multi-branch slug (→ upgrade view)', () {
      // The director persona carries the manage permission...
      expect(_persona(QaLoginPersona.director).has(Permission.manageDirectorPortal),
          isTrue);
      // ...but a Trial/Standard plan (no slugs) masks the director module off.
      final trialCeiling = EntitlementResolver.planCeiling(const <String>{});
      expect(trialCeiling.multiBranch, isFalse);
    });

    test('a paid plan that grants the slug unlocks the director module', () {
      final paidCeiling =
          EntitlementResolver.planCeiling({EntitlementSlugs.multiBranch});
      expect(paidCeiling.multiBranch, isTrue);

      // effective = local ∩ ceiling: the gate only opens when BOTH allow it.
      final effective = EntitlementResolver.resolveEffective(
        local: EntitlementResolver.unrestrictedCeiling,
        entitlements: {EntitlementSlugs.multiBranch},
      );
      expect(effective.multiBranch, isTrue);
    });
  });
}
