import 'package:akshara_erp/core/entitlements/entitlement_models.dart';
import 'package:akshara_erp/core/entitlements/entitlement_provider.dart';
import 'package:akshara_erp/core/entitlements/entitlement_resolver.dart';
import 'package:akshara_erp/core/school_config/school_configuration_models.dart';
import 'package:akshara_erp/core/school_config/school_configuration_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _allOn = SchoolCapabilities(
  transport: true,
  hostel: true,
  library: true,
  inventory: true,
  alumni: true,
  hrPayroll: true,
  multiBranch: true,
  trustOrganization: true,
);

final _professional = EntitlementResolver.planCeiling({
  EntitlementSlugs.transport,
  EntitlementSlugs.hostel,
  EntitlementSlugs.library,
  EntitlementSlugs.inventory,
  EntitlementSlugs.alumni,
  EntitlementSlugs.hrPayroll,
  EntitlementSlugs.multiBranch,
});

void main() {
  group('schoolCapabilitiesProvider seam (effective = local ∩ ceiling)', () {
    test('Professional ceiling bounds an all-on school config', () {
      final container = ProviderContainer(overrides: [
        localSchoolCapabilitiesProvider.overrideWith((ref) => _allOn),
        planCapabilityCeilingProvider.overrideWith((ref) => _professional),
      ]);
      addTearDown(container.dispose);

      final caps = container.read(schoolCapabilitiesProvider);
      expect(caps.transport, isTrue);
      expect(caps.multiBranch, isTrue);
      expect(caps.trustOrganization, isFalse); // not in Professional
    });

    test('Trial ceiling locks all optional modules', () {
      final container = ProviderContainer(overrides: [
        localSchoolCapabilitiesProvider.overrideWith((ref) => _allOn),
        planCapabilityCeilingProvider
            .overrideWith((ref) => EntitlementResolver.planCeiling(const {})),
      ]);
      addTearDown(container.dispose);

      final caps = container.read(schoolCapabilitiesProvider);
      expect(caps.transport, isFalse);
      expect(caps.hostel, isFalse);
      expect(caps.trustOrganization, isFalse);
    });

    test('unrestricted ceiling preserves local config (entitlement layer off)', () {
      final container = ProviderContainer(overrides: [
        localSchoolCapabilitiesProvider
            .overrideWith((ref) => _allOn.copyWith(hostel: false)),
        planCapabilityCeilingProvider
            .overrideWith((ref) => EntitlementResolver.unrestrictedCeiling),
      ]);
      addTearDown(container.dispose);

      final caps = container.read(schoolCapabilitiesProvider);
      expect(caps.transport, isTrue);
      expect(caps.hostel, isFalse); // local choice preserved
      expect(caps.multiBranch, isTrue);
    });
  });

  group('defaults when entitlement layer is disabled', () {
    test('planCapabilityCeilingProvider is unrestricted', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // ENTITLEMENT_API_ENABLED defaults false → unrestricted ceiling.
      final ceiling = container.read(planCapabilityCeilingProvider);
      expect(ceiling.transport, isTrue);
      expect(ceiling.multiBranch, isTrue);
      expect(ceiling.trustOrganization, isTrue);
    });

    test('subscriptionProvider yields the Trial fallback', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final sub = container.read(subscriptionProvider);
      expect(sub.planSlug, 'trial');
      expect(sub.status, SubscriptionStatus.trial);
      expect(sub.entitlements, isEmpty);
    });
  });
}
