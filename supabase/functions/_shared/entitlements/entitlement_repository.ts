// B2 — Entitlement Layer · Step 2 · data access (read-only in Step 2).
//
// Reads the plan catalog, an org's subscription, and the school's capability
// config off the `erp_tenant` RLS connection. No writes here — plan assignment
// (PUT /platform/.../subscription) lands in a later step; Step 2 is GET-only
// plus the read-side resolver/enforcement.

import type { TenantQueryClient } from "../tenant_db.ts";

// ── Tenant-isolation probes (QA-R-003 — per-org subscription isolation) ───────
// organization_subscriptions is ORG-keyed (one row per org, no school_id; RLS:
// organization_id = tenant AND scope IN ('organization','school')). The probe
// org A is the pilot org both probe schools belong to; probe org B is a SECOND
// tenant. A claim in org A (whether school- or org-scoped) must read only its
// own org's subscription row and never org B's. SUBSCRIPTION_PROBE_ORG_A_ROW is
// org A's own subscription row id (visible n=1); _ORG_B_ROW belongs to org B
// (cross-tenant, must be n=0).
export const SUBSCRIPTION_PROBE_ORG_B = "e3000000-0000-4000-8000-0000000000b1";
export const SUBSCRIPTION_PROBE_ORG_A_ROW = "e3000000-0000-4000-8000-0000000000a1";
export const SUBSCRIPTION_PROBE_ORG_B_ROW = "e3000000-0000-4000-8000-0000000000a2";
export const ORGANIZATION_SUBSCRIPTION_PROBE_SQL = `
  SELECT count(*)::text AS count FROM organization_subscriptions WHERE id = $1::uuid
`;

export interface PlanRow {
  slug: string;
  name: string;
  description: string;
  tierRank: number;
  studentSlabMin: number;
  studentSlabMax: number | null;
  maxSchools: number | null;
  /** PRC-A Batch 4 — plan storage cap in BYTES. null = unlimited (like maxSchools). */
  maxStorageBytes: number | null;
  /** W4 — plan SMS cap PER CALENDAR MONTH. null = unlimited (same convention as
   * maxSchools / maxStorageBytes). Config-driven; never hardcoded in the gate. */
  smsPerMonth: number | null;
  graceBufferPercent: number;
  trialLengthDays: number | null;
  trialGraceDays: number | null;
  basePricePaise: number;
  isTrial: boolean;
  isPublic: boolean;
  isActive: boolean;
}

export interface PlanWithEntitlements extends PlanRow {
  entitlements: string[];
}

export interface OrgSubscriptionRow {
  organizationId: string;
  planSlug: string;
  status: string;
  studentSlabMax: number | null;
  maxSchoolsOverride: number | null;
  trialEndsAt: string | null;
  graceEndsAt: string | null;
  studentCountCached: number;
  schoolCountCached: number;
  overrides: Record<string, unknown>;
  startedAt: string;
}

interface RawPlan {
  slug: string;
  name: string;
  description: string;
  tier_rank: number;
  student_slab_min: number;
  student_slab_max: number | null;
  max_schools: number | null;
  max_storage_bytes: string | number | null;
  max_sms_per_month: string | number | null;
  grace_buffer_percent: string | number;
  trial_length_days: number | null;
  trial_grace_days: number | null;
  base_price_paise: string | number;
  is_trial: boolean;
  is_public: boolean;
  is_active: boolean;
}

interface RawSubscription {
  organization_id: string;
  plan_slug: string;
  status: string;
  student_slab_max: number | null;
  max_schools_override: number | null;
  trial_ends_at: string | null;
  grace_ends_at: string | null;
  student_count_cached: number;
  school_count_cached: number;
  overrides: Record<string, unknown> | null;
  started_at: string;
}

function mapPlan(row: RawPlan): PlanRow {
  return {
    slug: row.slug,
    name: row.name,
    description: row.description,
    tierRank: Number(row.tier_rank),
    studentSlabMin: Number(row.student_slab_min),
    studentSlabMax: row.student_slab_max === null ? null : Number(row.student_slab_max),
    maxSchools: row.max_schools === null ? null : Number(row.max_schools),
    maxStorageBytes: row.max_storage_bytes == null ? null : Number(row.max_storage_bytes),
    smsPerMonth: row.max_sms_per_month == null ? null : Number(row.max_sms_per_month),
    graceBufferPercent: Number(row.grace_buffer_percent),
    trialLengthDays: row.trial_length_days === null ? null : Number(row.trial_length_days),
    trialGraceDays: row.trial_grace_days === null ? null : Number(row.trial_grace_days),
    basePricePaise: Number(row.base_price_paise),
    isTrial: row.is_trial,
    isPublic: row.is_public,
    isActive: row.is_active,
  };
}

const PLAN_COLUMNS = `slug, name, description, tier_rank, student_slab_min,
  student_slab_max, max_schools, max_storage_bytes, max_sms_per_month,
  grace_buffer_percent, trial_length_days, trial_grace_days, base_price_paise,
  is_trial, is_public, is_active`;

/** All active, public plans with their entitlement slugs — drives GET /plans. */
export async function listPublicPlans(
  db: TenantQueryClient,
): Promise<PlanWithEntitlements[]> {
  const plans = await db.queryObject<RawPlan>(
    `SELECT ${PLAN_COLUMNS} FROM subscription_plans
      WHERE is_active = true AND is_public = true
      ORDER BY tier_rank`,
  );
  const entRows = await db.queryObject<{ plan_slug: string; entitlement_slug: string }>(
    `SELECT plan_slug, entitlement_slug FROM plan_entitlements`,
  );
  const bySlug = new Map<string, string[]>();
  for (const r of entRows) {
    const list = bySlug.get(r.plan_slug) ?? [];
    list.push(r.entitlement_slug);
    bySlug.set(r.plan_slug, list);
  }
  return plans.map((p) => ({
    ...mapPlan(p),
    entitlements: (bySlug.get(p.slug) ?? []).sort(),
  }));
}

/** A single plan with its entitlement slugs, or null if unknown/inactive. */
export async function getPlanWithEntitlements(
  db: TenantQueryClient,
  slug: string,
): Promise<PlanWithEntitlements | null> {
  const plans = await db.queryObject<RawPlan>(
    `SELECT ${PLAN_COLUMNS} FROM subscription_plans WHERE slug = $1 LIMIT 1`,
    [slug],
  );
  const plan = plans[0];
  if (!plan) return null;
  const entRows = await db.queryObject<{ entitlement_slug: string }>(
    `SELECT entitlement_slug FROM plan_entitlements WHERE plan_slug = $1`,
    [slug],
  );
  return {
    ...mapPlan(plan),
    entitlements: entRows.map((r) => r.entitlement_slug).sort(),
  };
}

/** The org's subscription row, or null when none exists (→ Trial fallback). */
export async function getOrgSubscription(
  db: TenantQueryClient,
  organizationId: string,
): Promise<OrgSubscriptionRow | null> {
  const rows = await db.queryObject<RawSubscription>(
    `SELECT organization_id, plan_slug, status, student_slab_max,
            max_schools_override, trial_ends_at, grace_ends_at,
            student_count_cached, school_count_cached, overrides, started_at
       FROM organization_subscriptions
      WHERE organization_id = $1
      LIMIT 1`,
    [organizationId],
  );
  const row = rows[0];
  if (!row) return null;
  return {
    organizationId: row.organization_id,
    planSlug: row.plan_slug,
    status: row.status,
    studentSlabMax: row.student_slab_max === null ? null : Number(row.student_slab_max),
    maxSchoolsOverride: row.max_schools_override === null
      ? null
      : Number(row.max_schools_override),
    trialEndsAt: row.trial_ends_at ? new Date(row.trial_ends_at).toISOString() : null,
    graceEndsAt: row.grace_ends_at ? new Date(row.grace_ends_at).toISOString() : null,
    studentCountCached: Number(row.student_count_cached ?? 0),
    schoolCountCached: Number(row.school_count_cached ?? 0),
    overrides: row.overrides ?? {},
    startedAt: new Date(row.started_at).toISOString(),
  };
}

export interface OrganizationAssignmentRow {
  organizationId: string;
  organizationName: string;
  organizationSlug: string;
  planSlug: string;
  status: string;
}

/**
 * Lists every organization with its current plan/status (SECURITY DEFINER —
 * platform-level, drives the assign screen). Caller must already be gated on
 * `managePlatformSubscriptions`.
 */
export async function listAssignableOrganizations(
  db: TenantQueryClient,
): Promise<OrganizationAssignmentRow[]> {
  const rows = await db.queryObject<{
    organization_id: string;
    organization_name: string;
    organization_slug: string;
    plan_slug: string;
    status: string;
  }>(`SELECT * FROM list_subscription_assignments()`);
  return rows.map((r) => ({
    organizationId: r.organization_id,
    organizationName: r.organization_name,
    organizationSlug: r.organization_slug,
    planSlug: r.plan_slug,
    status: r.status,
  }));
}

/**
 * Assigns/changes an organization's plan (SECURITY DEFINER upsert). Caller must
 * already be gated on `managePlatformSubscriptions`. No payment is taken.
 */
export async function assignOrganizationSubscription(
  db: TenantQueryClient,
  params: {
    organizationId: string;
    planSlug: string;
    status: string;
    actorId: string;
  },
): Promise<void> {
  await db.queryObject(
    `SELECT assign_organization_subscription($1, $2, $3, $4)`,
    [params.organizationId, params.planSlug, params.status, params.actorId],
  );
}

/** The school's capability JSONB (flag → bool), or null if unconfigured. */
export async function getSchoolCapabilities(
  db: TenantQueryClient,
  schoolId: string,
): Promise<Record<string, unknown> | null> {
  const rows = await db.queryObject<{ capabilities: Record<string, unknown> }>(
    `SELECT capabilities FROM school_configuration WHERE school_id = $1 LIMIT 1`,
    [schoolId],
  );
  return rows[0]?.capabilities ?? null;
}
