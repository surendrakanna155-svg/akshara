// B2 — Entitlement Layer · Step 2 · resolution service.
//
// Combines the repository (subscription + plan + entitlements + school config)
// with the pure resolver to produce the authoritative entitlement view for an
// organization. Implements the Trial fail-safe: an org with no subscription row
// is resolved exactly as if it were on the Trial plan, so a missing assignment
// can never silently unlock paid modules.

import type { TenantQueryClient } from "../tenant_db.ts";
import {
  getOrgSubscription,
  getPlanWithEntitlements,
  getSchoolCapabilities,
  type OrgSubscriptionRow,
  type PlanWithEntitlements,
} from "./entitlement_repository.ts";
import {
  FALLBACK_PLAN_SLUG,
  planAllowedEntitlements,
  resolveEffectiveCapabilities,
  type SubscriptionOverrides,
} from "./entitlement_resolver.ts";

export interface ResolvedSubscription {
  plan: {
    slug: string;
    name: string;
    tierRank: number;
  };
  /** 'trial' | 'active' | 'grace' | 'suspended'; 'trial' when no row exists. */
  status: string;
  /** True when the org had no subscription row and was resolved as Trial. */
  fallbackApplied: boolean;
  trialEndsAt: string | null;
  graceEndsAt: string | null;
  /** Plan-allowed entitlement slugs (plan ∪ overrides.grant − overrides.revoke). */
  entitlements: string[];
  /** The 8 capability flags after plan ∩ school-config resolution. */
  capabilities: Record<string, boolean>;
  limits: {
    students: number | null;
    schools: number | null;
    /** PRC-A Batch 4 — plan storage cap in BYTES. null = unlimited. */
    storageBytes: number | null;
    /** W4 — plan SMS cap per calendar month. null = unlimited. Config-driven
     * from the plan's `max_sms_per_month`; enforced by enforceSmsQuota. */
    sms: number | null;
    graceBufferPercent: number;
  };
  usage: {
    students: number;
    schools: number;
  };
}

/**
 * Resolves the full entitlement view for an org (and a school, when known so the
 * capability intersection can be computed). Missing subscription → Trial.
 */
export async function resolveSubscription(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string | null,
): Promise<ResolvedSubscription> {
  const subscription = await getOrgSubscription(db, organizationId);
  const fallbackApplied = subscription === null;
  const planSlug = subscription?.planSlug ?? FALLBACK_PLAN_SLUG;

  // Load the resolved plan; if it has somehow gone missing, fall back to Trial.
  let plan = await getPlanWithEntitlements(db, planSlug);
  if (!plan && planSlug !== FALLBACK_PLAN_SLUG) {
    plan = await getPlanWithEntitlements(db, FALLBACK_PLAN_SLUG);
  }
  if (!plan) {
    // Catalog is unseeded — fail safe to an empty Trial-equivalent.
    plan = emptyTrialPlan();
  }

  const overrides = (subscription?.overrides ?? {}) as SubscriptionOverrides;
  const schoolCapabilities = schoolId
    ? await getSchoolCapabilities(db, schoolId)
    : null;

  const allowed = planAllowedEntitlements(plan.entitlements, overrides);
  const capabilities = resolveEffectiveCapabilities({
    planEntitlements: plan.entitlements,
    overrides,
    schoolCapabilities,
  });

  return {
    plan: { slug: plan.slug, name: plan.name, tierRank: plan.tierRank },
    status: subscription?.status ?? "trial",
    fallbackApplied,
    trialEndsAt: subscription?.trialEndsAt ?? null,
    graceEndsAt: subscription?.graceEndsAt ?? null,
    entitlements: [...allowed].sort(),
    capabilities,
    limits: {
      students: resolveStudentLimit(subscription, plan),
      schools: resolveSchoolLimit(subscription, plan),
      storageBytes: resolveStorageLimit(subscription, plan),
      sms: resolveSmsLimit(subscription, plan),
      graceBufferPercent: plan.graceBufferPercent,
    },
    usage: {
      students: subscription?.studentCountCached ?? 0,
      schools: subscription?.schoolCountCached ?? 0,
    },
  };
}

function resolveStudentLimit(
  sub: OrgSubscriptionRow | null,
  plan: PlanWithEntitlements,
): number | null {
  if (sub?.studentSlabMax != null) return sub.studentSlabMax;
  return plan.studentSlabMax;
}

function resolveSchoolLimit(
  sub: OrgSubscriptionRow | null,
  plan: PlanWithEntitlements,
): number | null {
  if (sub?.maxSchoolsOverride != null) return sub.maxSchoolsOverride;
  return plan.maxSchools;
}

// PRC-A Batch 4 — storage cap in bytes. Plan-level only for now (no per-org
// override column yet), so it is simply the plan's value. null = unlimited.
function resolveStorageLimit(
  _sub: OrgSubscriptionRow | null,
  plan: PlanWithEntitlements,
): number | null {
  return plan.maxStorageBytes;
}

// W4 — monthly SMS cap. Plan-level only (no per-org override column), so it is
// simply the plan's value. null = unlimited. Config-driven: the number lives in
// subscription_plans.max_sms_per_month, never hardcoded in the gate.
function resolveSmsLimit(
  _sub: OrgSubscriptionRow | null,
  plan: PlanWithEntitlements,
): number | null {
  return plan.smsPerMonth;
}

function emptyTrialPlan(): PlanWithEntitlements {
  return {
    slug: FALLBACK_PLAN_SLUG,
    name: "Trial",
    description: "",
    tierRank: 0,
    studentSlabMin: 0,
    studentSlabMax: 100,
    maxSchools: 1,
    maxStorageBytes: null, // Trial fallback = unlimited (enforcement is also dark).
    smsPerMonth: null, // Trial fallback = unlimited (enforcement is also dark).
    graceBufferPercent: 10,
    trialLengthDays: 30,
    trialGraceDays: 7,
    basePricePaise: 0,
    isTrial: true,
    isPublic: true,
    isActive: true,
    entitlements: [],
  };
}
