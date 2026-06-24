// B2 — Capability Gating → Entitlement Layer · Step 2 · pure resolution logic.
//
// The single source of truth for the resolution rule:
//
//   effectiveCapability(cap) = planAllows(cap) AND schoolConfigEnabled(cap)
//
// A plan says what an organization is *allowed* to use; the school's own
// configuration says what it has *chosen* to switch on. A school may narrow
// within its plan but can never exceed it. This module is intentionally
// DB-free and side-effect-free so it can be unit-tested exhaustively.
//
// Scope (locked): entitlement layer only — NO billing/renewals/invoicing/
// payments/MRR/addons/dedicated-DBs/white-label.

/**
 * Maps each of the 8 live `SchoolCapabilities` flags to its plan entitlement
 * slug. The flag names mirror `lib/core/school_config/school_configuration_models.dart`;
 * the slugs mirror the seed in `plan_entitlements`. Core modules (admissions,
 * finance, sis, management, attendance, exams) are granted to every plan and are
 * NOT in this map — they are never plan-gated, only the optional capabilities are.
 */
export const CAPABILITY_ENTITLEMENTS: Record<string, string> = {
  transport: "module.transport",
  hostel: "module.hostel",
  library: "module.library",
  inventory: "module.inventory",
  alumni: "module.alumni",
  hrPayroll: "module.hr_payroll",
  multiBranch: "module.multi_branch",
  trustOrganization: "module.trust_org",
};

/**
 * Default capability state when a school has not run the Discovery wizard yet,
 * mirroring the Dart `SchoolCapabilities` defaults (6 ops ON, multiBranch/trust
 * OFF). Used so a school with no `school_configuration` row resolves sensibly.
 */
export const DEFAULT_SCHOOL_CAPABILITIES: Record<string, boolean> = {
  transport: true,
  hostel: true,
  library: true,
  inventory: true,
  alumni: true,
  hrPayroll: true,
  multiBranch: false,
  trustOrganization: false,
};

/** Plan slug used whenever an org has no subscription row (fail-safe). */
export const FALLBACK_PLAN_SLUG = "trial";

/** Enterprise per-deal entitlement adjustments stored on the subscription row. */
export interface SubscriptionOverrides {
  /** Extra slugs granted beyond the plan (e.g. `["feature.ai_predictions"]`). */
  grant?: string[];
  /** Slugs revoked from the plan for this org. */
  revoke?: string[];
}

export interface ResolveInput {
  /** Entitlement slugs the org's plan grants (from `plan_entitlements`). */
  planEntitlements: string[];
  /** Enterprise per-deal overrides from `organization_subscriptions.overrides`. */
  overrides?: SubscriptionOverrides | null;
  /**
   * The school's `school_configuration.capabilities` JSONB (flag → bool). When
   * null/absent the school has not configured, so defaults apply.
   */
  schoolCapabilities?: Record<string, unknown> | null;
}

function normalizeOverrides(
  overrides?: SubscriptionOverrides | null,
): { grant: Set<string>; revoke: Set<string> } {
  return {
    grant: new Set(Array.isArray(overrides?.grant) ? overrides!.grant : []),
    revoke: new Set(Array.isArray(overrides?.revoke) ? overrides!.revoke : []),
  };
}

/**
 * The full set of entitlement slugs the plan ultimately allows for this org:
 * `(planEntitlements ∪ overrides.grant) − overrides.revoke`. This is the
 * authoritative "what is this org allowed to use" set used by enforcement.
 */
export function planAllowedEntitlements(
  planEntitlements: string[],
  overrides?: SubscriptionOverrides | null,
): Set<string> {
  const { grant, revoke } = normalizeOverrides(overrides);
  const allowed = new Set<string>(planEntitlements);
  for (const slug of grant) allowed.add(slug);
  for (const slug of revoke) allowed.delete(slug);
  return allowed;
}

/** True when the plan (plus overrides) allows the given entitlement slug. */
export function planAllows(
  slug: string,
  planEntitlements: string[],
  overrides?: SubscriptionOverrides | null,
): boolean {
  return planAllowedEntitlements(planEntitlements, overrides).has(slug);
}

/** Whether the school has switched a capability flag on (with sensible defaults). */
export function schoolConfigEnabled(
  flag: string,
  schoolCapabilities?: Record<string, unknown> | null,
): boolean {
  if (schoolCapabilities && Object.prototype.hasOwnProperty.call(schoolCapabilities, flag)) {
    return schoolCapabilities[flag] === true;
  }
  return DEFAULT_SCHOOL_CAPABILITIES[flag] ?? false;
}

/**
 * Resolves the effective state of the 8 capability flags:
 * `effective[flag] = planAllows(mappedSlug) AND schoolConfigEnabled(flag)`.
 * This is exactly the `SchoolCapabilities` shape the Flutter gating engine
 * already consumes — now bounded by the plan.
 */
export function resolveEffectiveCapabilities(
  input: ResolveInput,
): Record<string, boolean> {
  const allowed = planAllowedEntitlements(input.planEntitlements, input.overrides);
  const result: Record<string, boolean> = {};
  for (const [flag, slug] of Object.entries(CAPABILITY_ENTITLEMENTS)) {
    result[flag] = allowed.has(slug) &&
      schoolConfigEnabled(flag, input.schoolCapabilities);
  }
  return result;
}
