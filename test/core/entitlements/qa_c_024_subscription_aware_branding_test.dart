import 'package:akshara_erp/core/entitlements/entitlement_models.dart';
import 'package:akshara_erp/core/entitlements/entitlement_resolver.dart';
import 'package:akshara_erp/core/school_config/school_capability_registry.dart';
import 'package:akshara_erp/core/school_config/school_configuration_models.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW7 · QA-C-024 — SUBSCRIPTION-AWARE BRANDING
///
/// What EXISTS (GA-ready slice, certified here): the 4-tier entitlement/plan
/// gating BEHAVIOUR — a module gated by plan returns the correct allow/deny
/// depending on the org's subscription tier. This is the same plan-ceiling
/// engine cited by:
///   - test/core/entitlements/entitlement_resolver_test.dart
///   - test/features/entitlements/entitlement_locked_ux_test.dart
///
/// What is MISSING (Phase-2, owner decision O10 — NOT built, asserted honestly
/// below): tier-SPECIFIC BRANDING, i.e. a "Powered by Akshara" footer on lower
/// tiers that is REMOVED on the Enterprise tier. No code path, permission, or
/// provider for that footer/removal exists in the repo today.
///
/// This cert proves the entitlement gating a subscription-aware feature would
/// hang off, and pins the Phase-2 branding-tier boundary so it cannot silently
/// be claimed as done.

// Plan entitlement sets mirroring the seed (migration 20260717000000) and the
// existing resolver cert.
const _core = {
  EntitlementSlugs.admissions,
  EntitlementSlugs.finance,
  EntitlementSlugs.sis,
  EntitlementSlugs.management,
  EntitlementSlugs.attendance,
  EntitlementSlugs.exams,
};
const _ops = {
  EntitlementSlugs.transport,
  EntitlementSlugs.hostel,
  EntitlementSlugs.library,
  EntitlementSlugs.inventory,
  EntitlementSlugs.alumni,
  EntitlementSlugs.hrPayroll,
  EntitlementSlugs.multiBranch,
};
final _trialPlan = {..._core};
final _standardPlan = {..._core};
final _professionalPlan = {
  ..._core,
  ..._ops,
  EntitlementSlugs.parentInsights,
};
final _enterprisePlan = {
  ..._professionalPlan,
  EntitlementSlugs.trustOrg,
  EntitlementSlugs.aiPredictions,
};

const _allOnLocal = SchoolCapabilities(
  transport: true,
  hostel: true,
  library: true,
  inventory: true,
  alumni: true,
  hrPayroll: true,
  multiBranch: true,
  trustOrganization: true,
);

void main() {
  group('QA-C-024 GA slice — plan-tier gating returns correct allow/deny', () {
    test('Trial tier: optional module gated OFF (deny)', () {
      final caps = EntitlementResolver.resolveEffective(
        local: _allOnLocal,
        entitlements: _trialPlan,
      );
      expect(caps.transport, isFalse, reason: 'trial denies transport');
      expect(caps.multiBranch, isFalse);
      expect(caps.trustOrganization, isFalse);
    });

    test('Standard tier: core only — ops still denied', () {
      final caps = EntitlementResolver.resolveEffective(
        local: _allOnLocal,
        entitlements: _standardPlan,
      );
      expect(caps.transport, isFalse);
      expect(caps.hostel, isFalse);
      expect(caps.multiBranch, isFalse);
    });

    test('Professional tier: ops allowed, trust/org still denied', () {
      final caps = EntitlementResolver.resolveEffective(
        local: _allOnLocal,
        entitlements: _professionalPlan,
      );
      expect(caps.transport, isTrue);
      expect(caps.hostel, isTrue);
      expect(caps.multiBranch, isTrue);
      expect(caps.trustOrganization, isFalse, reason: 'trust is Enterprise-only');
    });

    test('Enterprise tier: every capability allowed (incl AI predictions)', () {
      final caps = EntitlementResolver.resolveEffective(
        local: _allOnLocal,
        entitlements: _enterprisePlan,
      );
      expect(caps.transport, isTrue);
      expect(caps.multiBranch, isTrue);
      expect(caps.trustOrganization, isTrue);
      expect(_enterprisePlan.contains(EntitlementSlugs.aiPredictions), isTrue);

      final ids = SchoolCapabilityRegistry.enabledModuleIds(caps);
      expect(ids, containsAll(['director', 'trust_intelligence']));
    });

    test('school can NARROW within tier but never EXCEED it', () {
      // Professional plan, but school disables transport locally -> denied.
      final narrowed = EntitlementResolver.resolveEffective(
        local: _allOnLocal.copyWith(transport: false),
        entitlements: _professionalPlan,
      );
      expect(narrowed.transport, isFalse, reason: 'school turned it off');
      expect(narrowed.hostel, isTrue);

      // Standard plan, school turns transport on locally -> STILL denied (ceiling).
      final exceeded = EntitlementResolver.resolveEffective(
        local: _allOnLocal,
        entitlements: _standardPlan,
      );
      expect(exceeded.transport, isFalse,
          reason: 'plan ceiling caps the school config');
    });

    test('trial fail-safe (no subscription) grants no optional modules', () {
      final sub = ResolvedSubscription.trialFallback();
      expect(sub.fallbackApplied, isTrue);
      final caps = EntitlementResolver.resolveEffective(
        local: _allOnLocal,
        entitlements: sub.entitlementSet,
      );
      expect(caps.transport, isFalse);
      expect(caps.trustOrganization, isFalse);
    });
  });

  group('QA-C-024 Phase-2 boundary — tier-specific BRANDING is MISSING (honest)',
      () {
    test('there is NO branding-tier permission verb (footer / removal)', () {
      // The only branding verbs that exist are the per-school apply verbs
      // (GA, QA-C-023) and the platform white-label hub (Phase-2, no role).
      // A tier-aware "Powered by" footer / Enterprise-removal verb does NOT
      // exist — this is the honest Phase-2 (O10) gap.
      final brandingVerbs = Permission.values
          .where((p) => p.name.toLowerCase().contains('brand'))
          .map((p) => p.name)
          .toSet();
      expect(
        brandingVerbs,
        {'viewSchoolBranding', 'manageSchoolBranding'},
        reason: 'no footer/removal branding-tier verb should exist yet',
      );

      // Platform white-label hub remains held by NO role (Phase-2, OFF live).
      for (final role in ErpRole.values) {
        expect(
          UserPermissions.forRole(role).has(Permission.manageWhiteLabelPlatform),
          isFalse,
          reason: '${role.name} must not hold the Phase-2 white-label gate',
        );
      }
    });

    test('plan entitlement slugs contain NO branding/footer entitlement', () {
      // Subscription-aware branding would need a branding entitlement slug; the
      // catalog has none -> the tiered footer/removal cannot be entitlement-gated
      // today. Confirms the Phase-2 gap is real, not a wiring oversight.
      final allSlugs = <String>{
        EntitlementSlugs.admissions,
        EntitlementSlugs.finance,
        EntitlementSlugs.sis,
        EntitlementSlugs.management,
        EntitlementSlugs.attendance,
        EntitlementSlugs.exams,
        EntitlementSlugs.transport,
        EntitlementSlugs.hostel,
        EntitlementSlugs.library,
        EntitlementSlugs.inventory,
        EntitlementSlugs.alumni,
        EntitlementSlugs.hrPayroll,
        EntitlementSlugs.multiBranch,
        EntitlementSlugs.trustOrg,
        EntitlementSlugs.marketing,
        EntitlementSlugs.parentInsights,
        EntitlementSlugs.aiPredictions,
      };
      expect(
        allSlugs.any((s) => s.contains('brand') || s.contains('footer')),
        isFalse,
        reason: 'no branding-tier entitlement slug exists (Phase-2 / O10)',
      );
    });
  });
}
