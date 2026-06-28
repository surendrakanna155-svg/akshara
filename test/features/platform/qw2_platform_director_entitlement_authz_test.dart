import 'package:akshara_erp/core/entitlements/entitlement_models.dart';
import 'package:akshara_erp/core/entitlements/entitlement_resolver.dart';
import 'package:akshara_erp/core/school_config/school_configuration_models.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/mutation_permission_registry.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:akshara_erp/router/route_guards.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW2 Batch 5 — Platform / Director / Entitlement gating.
///
/// QA-J-049 (Director portfolio-metric save), QA-J-053 (Super Admin create →
/// approve → provision a school), QA-J-054 (assign plan → entitlement takes
/// effect), QA-J-068 (capability gating: a Discovery-disabled module → Access
/// Denied even for a permission holder), QA-J-069 (entitlement lock → upgrade
/// view for a Trial/Standard plan). The write/persistence paths exist; this
/// proves the correct persona is authorized AND that the capability + entitlement
/// gates behave, against the real `MutationPermissionRegistry`,
/// `SchoolCapabilityRegistry` and `EntitlementResolver`.
Permission _gate(String module, String mutationId) =>
    MutationPermissionRegistry.forModule(module)
        .firstWhere((e) => e.mutationId == mutationId)
        .permission;

UserPermissions _persona(QaLoginPersona p) => UserPermissions.fromClaims(
      roles: p.erpRoles,
      explicitPermissions: p.customPermissions,
    );

void main() {
  group('QW2 · platform / director / entitlement', () {
    test('QA-J-049 · Director is authorized for director-portal writes '
        '(manageDirectorPortal), denied Control-Center', () {
      final director = _persona(QaLoginPersona.director);
      expect(_gate('director', 'exportReport'), Permission.manageDirectorPortal);
      expect(_gate('director', 'acknowledgeCompliance'),
          Permission.manageDirectorPortal);
      expect(director.has(Permission.manageDirectorPortal), isTrue);
      expect(director.has(Permission.viewControlCenter), isFalse);
    });

    test('QA-J-053 · Super Admin is authorized to create + provision a school '
        '(control-center + organization-builder provisioning)', () {
      final superAdmin = UserPermissions.forRole(ErpRole.superAdmin);
      expect(superAdmin.has(Permission.manageControlCenter), isTrue);
      expect(_gate('organization_builder', 'startProvisioning'),
          Permission.manageOrganizationBuilder);
      expect(superAdmin.has(_gate('organization_builder', 'startProvisioning')),
          isTrue);
    });

    test('QA-J-054 · Super Admin assigns a plan and the entitlement TAKES '
        'EFFECT (the slug unlocks the gated capability)', () {
      final superAdmin = UserPermissions.forRole(ErpRole.superAdmin);
      expect(superAdmin.has(Permission.manageControlCenter), isTrue);

      // A plan that grants the transport slug unlocks the transport capability;
      // a plan that does not leaves it locked. (effective = local ∩ planCeiling)
      const local = EntitlementResolver.unrestrictedCeiling;
      final unlocked = EntitlementResolver.resolveEffective(
        local: local,
        entitlements: {EntitlementSlugs.transport},
      );
      final locked = EntitlementResolver.resolveEffective(
        local: local,
        entitlements: const <String>{},
      );
      expect(unlocked.transport, isTrue, reason: 'granting the slug unlocks it');
      expect(locked.transport, isFalse, reason: 'no slug → stays locked');
    });

    test('QA-J-068 · Capability gating — a Discovery-disabled module is Access '
        'Denied regardless of permission', () {
      // Transport turned OFF in the Smart School Discovery wizard → the route is
      // not enabled even though a holder carries viewTransport/manageTransport.
      const transportOff = SchoolCapabilities(transport: false);
      const transportOn = SchoolCapabilities(transport: true);
      expect(
        isRouteEnabledForCapabilities(RouteNames.transport, transportOff),
        isFalse,
      );
      expect(
        isRouteEnabledForCapabilities(RouteNames.transport, transportOn),
        isTrue,
      );
    });

    test('QA-J-069 · Entitlement lock — a Trial/Standard plan without the slug '
        'gates the module (→ upgrade view); a paid plan allows it', () {
      // Trial: no entitlement slugs → the plan ceiling masks the module off.
      final trialCeiling = EntitlementResolver.planCeiling(const <String>{});
      expect(trialCeiling.transport, isFalse);
      expect(trialCeiling.hostel, isFalse);
      // A plan that grants the slug lifts the ceiling for that module.
      final paidCeiling =
          EntitlementResolver.planCeiling({EntitlementSlugs.transport});
      expect(paidCeiling.transport, isTrue);
    });
  });
}
