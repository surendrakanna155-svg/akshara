import 'package:akshara_erp/core/entitlements/entitlement_models.dart';
import 'package:akshara_erp/core/entitlements/entitlement_resolver.dart';
import 'package:akshara_erp/core/school_config/school_capability_registry.dart';
import 'package:akshara_erp/core/school_config/school_configuration_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plan entitlement sets mirroring the seed (migration 20260717000000).
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
final trialPlan = {..._core};
final standardPlan = {..._core};
final professionalPlan = {..._core, ..._ops, EntitlementSlugs.parentInsights};
final enterprisePlan = {
  ...professionalPlan,
  EntitlementSlugs.trustOrg,
  EntitlementSlugs.aiPredictions,
};

/// A school that has switched every module on (the widest local config).
const allOnLocal = SchoolCapabilities(
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
  group('plan ceiling × school config = effective capabilities', () {
    test('Trial: all optional modules plan-locked even with everything on', () {
      final caps = EntitlementResolver.resolveEffective(
        local: allOnLocal,
        entitlements: trialPlan,
      );
      expect(caps.transport, isFalse);
      expect(caps.hostel, isFalse);
      expect(caps.library, isFalse);
      expect(caps.inventory, isFalse);
      expect(caps.alumni, isFalse);
      expect(caps.hrPayroll, isFalse);
      expect(caps.multiBranch, isFalse);
      expect(caps.trustOrganization, isFalse);
      // Registry: only core modules remain.
      final ids = SchoolCapabilityRegistry.enabledModuleIds(caps);
      expect(ids, containsAll(['admissions', 'finance', 'sis', 'management']));
      expect(ids, isNot(contains('transport')));
      expect(ids, isNot(contains('hr')));
    });

    test('Standard: core only — ops still plan-locked', () {
      final caps = EntitlementResolver.resolveEffective(
        local: allOnLocal,
        entitlements: standardPlan,
      );
      expect(caps.transport, isFalse);
      expect(caps.multiBranch, isFalse);
      expect(caps.trustOrganization, isFalse);
    });

    test('Professional: ops + multiBranch on, trust still locked', () {
      final caps = EntitlementResolver.resolveEffective(
        local: allOnLocal,
        entitlements: professionalPlan,
      );
      expect(caps.transport, isTrue);
      expect(caps.hostel, isTrue);
      expect(caps.library, isTrue);
      expect(caps.inventory, isTrue);
      expect(caps.alumni, isTrue);
      expect(caps.hrPayroll, isTrue);
      expect(caps.multiBranch, isTrue);
      expect(caps.trustOrganization, isFalse);
      final ids = SchoolCapabilityRegistry.enabledModuleIds(caps);
      expect(ids, containsAll(['transport', 'hostel', 'hr', 'branch']));
      expect(ids, isNot(contains('director')));
    });

    test('Enterprise: every capability available (AI predictions included)', () {
      final caps = EntitlementResolver.resolveEffective(
        local: allOnLocal,
        entitlements: enterprisePlan,
      );
      expect(caps.transport, isTrue);
      expect(caps.multiBranch, isTrue);
      expect(caps.trustOrganization, isTrue);
      expect(enterprisePlan.contains(EntitlementSlugs.aiPredictions), isTrue);
      final ids = SchoolCapabilityRegistry.enabledModuleIds(caps);
      expect(ids, containsAll(['director', 'control_center', 'trust_intelligence']));
    });

    test('School narrows within plan: Professional but transport off locally', () {
      final caps = EntitlementResolver.resolveEffective(
        local: allOnLocal.copyWith(transport: false),
        entitlements: professionalPlan,
      );
      expect(caps.transport, isFalse); // school chose to disable
      expect(caps.hostel, isTrue); // others stay
    });

    test('School can never exceed plan: Standard + transport on locally', () {
      final caps = EntitlementResolver.resolveEffective(
        local: allOnLocal,
        entitlements: standardPlan,
      );
      expect(caps.transport, isFalse);
    });
  });

  group('Trial fallback', () {
    test('trialFallback grants no optional modules', () {
      final sub = ResolvedSubscription.trialFallback();
      expect(sub.planSlug, 'trial');
      expect(sub.status, SubscriptionStatus.trial);
      expect(sub.fallbackApplied, isTrue);
      expect(sub.entitlements, isEmpty);

      final caps = EntitlementResolver.resolveEffective(
        local: allOnLocal,
        entitlements: sub.entitlementSet,
      );
      expect(caps.transport, isFalse);
      expect(caps.trustOrganization, isFalse);
    });
  });

  group('unrestricted ceiling (entitlement layer disabled)', () {
    test('intersect with unrestricted ceiling preserves local config', () {
      final local = allOnLocal.copyWith(multiBranch: false, hostel: false);
      final caps = EntitlementResolver.intersect(
        local,
        EntitlementResolver.unrestrictedCeiling,
      );
      expect(caps.transport, isTrue);
      expect(caps.hostel, isFalse); // local off stays off
      expect(caps.multiBranch, isFalse);
      expect(caps.trustOrganization, isTrue);
    });
  });
}
