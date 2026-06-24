import '../school_config/school_configuration_models.dart';
import 'entitlement_models.dart';

/// B2 — Entitlement Layer · Step 3 · client resolution (pure).
///
/// Mirrors the backend resolver (`_shared/entitlements/entitlement_resolver.ts`):
///
///   effectiveCapability = planAllows ∩ schoolConfigEnabled
///
/// The plan defines a *ceiling* (which of the 8 capability flags the org is
/// allowed to use); the school's own configuration narrows within that ceiling.
/// A school can switch a module off, but can never switch on a module its plan
/// does not include. Pure and dependency-light so it is exhaustively unit-tested.
abstract final class EntitlementResolver {
  /// Maps each capability flag to its plan entitlement slug (inverse of the
  /// backend `CAPABILITY_ENTITLEMENTS`).
  static const Map<String, String> capabilityEntitlements = {
    'transport': EntitlementSlugs.transport,
    'hostel': EntitlementSlugs.hostel,
    'library': EntitlementSlugs.library,
    'inventory': EntitlementSlugs.inventory,
    'alumni': EntitlementSlugs.alumni,
    'hrPayroll': EntitlementSlugs.hrPayroll,
    'multiBranch': EntitlementSlugs.multiBranch,
    'trustOrganization': EntitlementSlugs.trustOrg,
  };

  /// A ceiling with every capability allowed — the no-restriction sentinel used
  /// when the entitlement layer is disabled, so existing journeys are unchanged.
  static const SchoolCapabilities unrestrictedCeiling = SchoolCapabilities(
    transport: true,
    hostel: true,
    library: true,
    inventory: true,
    alumni: true,
    hrPayroll: true,
    multiBranch: true,
    trustOrganization: true,
  );

  /// Derives the capability ceiling allowed by a set of plan entitlement slugs.
  /// A flag is allowed iff the plan grants its mapped slug.
  static SchoolCapabilities planCeiling(Set<String> entitlements) {
    return SchoolCapabilities(
      transport: entitlements.contains(EntitlementSlugs.transport),
      hostel: entitlements.contains(EntitlementSlugs.hostel),
      library: entitlements.contains(EntitlementSlugs.library),
      inventory: entitlements.contains(EntitlementSlugs.inventory),
      alumni: entitlements.contains(EntitlementSlugs.alumni),
      hrPayroll: entitlements.contains(EntitlementSlugs.hrPayroll),
      multiBranch: entitlements.contains(EntitlementSlugs.multiBranch),
      trustOrganization: entitlements.contains(EntitlementSlugs.trustOrg),
    );
  }

  /// `effective = local ∩ ceiling` — the school config narrowed by the plan.
  static SchoolCapabilities intersect(
    SchoolCapabilities local,
    SchoolCapabilities ceiling,
  ) {
    return SchoolCapabilities(
      transport: local.transport && ceiling.transport,
      hostel: local.hostel && ceiling.hostel,
      library: local.library && ceiling.library,
      inventory: local.inventory && ceiling.inventory,
      alumni: local.alumni && ceiling.alumni,
      hrPayroll: local.hrPayroll && ceiling.hrPayroll,
      multiBranch: local.multiBranch && ceiling.multiBranch,
      trustOrganization: local.trustOrganization && ceiling.trustOrganization,
    );
  }

  /// Convenience: resolve effective capabilities directly from a subscription's
  /// plan-allowed entitlement slugs and the local school configuration.
  static SchoolCapabilities resolveEffective({
    required SchoolCapabilities local,
    required Set<String> entitlements,
  }) {
    return intersect(local, planCeiling(entitlements));
  }
}
