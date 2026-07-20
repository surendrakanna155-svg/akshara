// B2 — Step 4.6 · slab-limit enforcement (G5).
//
// Blocks count-growing creates once the org reaches its plan's slab + grace
// buffer. Gated by the enforcement master switch (entitlement_enforcement.ts):
// when enforcement is off the guards are no-ops, so deploying the edge never
// blocks creation until plans are assigned and the switch is flipped.
//
// Scope: entitlement caps only — NO billing. A 402 here means "plan limit
// reached, upgrade to add more", never a charge.

import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { resolveSubscription } from "./entitlement_service.ts";
import { entitlementEnforcementEnabled } from "./entitlement_enforcement.ts";

/**
 * True when adding ONE more item keeps the org within `limit` plus the grace
 * buffer. `limit == null` means unlimited. Pure for unit testing.
 */
export function withinSlab(
  current: number,
  limit: number | null,
  graceBufferPercent: number,
): boolean {
  if (limit == null) return true;
  const ceiling = Math.floor(limit * (1 + (graceBufferPercent || 0) / 100));
  return current + 1 <= ceiling;
}

/** The complete count-growing-create policy as a pure decision (no DB / no HTTP),
 * so the whole gate — suspension AND slab — is unit-testable, not just the slab math.
 *  - `status` from resolveSubscription ('trial'|'active'|'grace'|'suspended').
 *  - PRC-A cap 57: a SUSPENDED subscription blocks regardless of slab.
 *  - 'grace' rides `graceBufferPercent` (already widened in withinSlab).
 *  - `limit == null` = unlimited plan. */
export type CreateLimitDecision =
  | { allow: true }
  | { allow: false; reason: "suspended" }
  | { allow: false; reason: "slab" };

export function evaluateCreateLimit(
  status: string,
  current: number,
  limit: number | null,
  graceBufferPercent: number,
): CreateLimitDecision {
  if (status === "suspended") return { allow: false, reason: "suspended" };
  if (withinSlab(current, limit, graceBufferPercent)) return { allow: true };
  return { allow: false, reason: "slab" };
}

type LimitKind = "students" | "schools";

async function enforceLimit(
  config: AppConfig,
  claims: AccessTokenClaims,
  kind: LimitKind,
  count: (db: TenantQueryClient, organizationId: string) => Promise<number>,
): Promise<Response | null> {
  if (!entitlementEnforcementEnabled()) return null;
  try {
    return await withTenantContext(config, claims, async (db) => {
      const sub = await resolveSubscription(
        db,
        claims.tenant_id,
        claims.school_id ?? null,
      );
      const limit = kind === "students" ? sub.limits.students : sub.limits.schools;
      // Only hit the DB for a live count when a finite slab could actually bind AND
      // the subscription isn't already suspended (PRC-A cap 57: suspension blocks
      // regardless of count, so we skip the query). 'grace' rides graceBufferPercent
      // in evaluateCreateLimit and keeps operating through the grace window.
      const suspended = sub.status === "suspended";
      const current = (!suspended && limit != null)
        ? await count(db, claims.tenant_id)
        : 0;
      const decision = evaluateCreateLimit(
        sub.status,
        current,
        limit,
        sub.limits.graceBufferPercent,
      );
      if (decision.allow) return null;
      return decision.reason === "suspended"
        ? errorEnvelope(
          "SUBSCRIPTION_SUSPENDED",
          `Your ${sub.plan.name} subscription is suspended. Renew it to add more ${kind}.`,
          402,
        )
        : errorEnvelope(
          "PLAN_LIMIT_EXCEEDED",
          `Your ${sub.plan.name} plan allows up to ${limit} ${kind}. Upgrade to add more.`,
          402,
        );
    });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return null;
    // Fail-open: a limit-check failure must never break core creation flows.
    console.error(`Limit check (${kind}) failed:`, error);
    return null;
  }
}

/** 402 when the org is at its student slab + grace. Null otherwise / when off. */
export function enforceStudentLimit(
  config: AppConfig,
  claims: AccessTokenClaims,
): Promise<Response | null> {
  return enforceLimit(config, claims, "students", (db, orgId) =>
    db.queryCount(
      `SELECT count(*) AS count FROM students WHERE organization_id = $1`,
      [orgId],
    ));
}

/** 402 when the org is at its school slab. Null otherwise / when off. */
export function enforceSchoolLimit(
  config: AppConfig,
  claims: AccessTokenClaims,
): Promise<Response | null> {
  return enforceLimit(config, claims, "schools", (db, orgId) =>
    db.queryCount(
      `SELECT count(*) AS count FROM schools
        WHERE organization_id = $1 AND deleted_at IS NULL`,
      [orgId],
    ));
}

// ─── W4 · per-plan monthly SMS quota (owner decision #1) ─────────────────────
//
// SMS is billed per message, so its cap is a HARD monthly count — there is no
// grace buffer (unlike the soft student/school slabs). The number is config-
// driven: it lives in subscription_plans.max_sms_per_month → sub.limits.sms,
// never hardcoded here. null = unlimited. Enforcement rides the SAME master
// switch as the slab limits (entitlementEnforcementEnabled) so it ships dark and
// flips on with them; a check failure fails OPEN (never blocks a live send).

/** The complete monthly-SMS-quota decision as a pure function (no DB / no HTTP),
 * mirroring {@link evaluateCreateLimit}:
 *  - a SUSPENDED subscription blocks regardless of count (same as the slabs).
 *  - `limit == null` = unlimited plan → always allowed.
 *  - otherwise allow while the month's count is strictly BELOW the cap; the send
 *    that would make `current == limit` is the last one allowed, the next is
 *    blocked with reason 'quota'. */
export type SmsQuotaDecision =
  | { allow: true }
  | { allow: false; reason: "suspended" }
  | { allow: false; reason: "quota" };

export function evaluateSmsQuota(
  status: string,
  currentCount: number,
  limit: number | null,
): SmsQuotaDecision {
  if (status === "suspended") return { allow: false, reason: "suspended" };
  if (limit == null) return { allow: true };
  if (currentCount < limit) return { allow: true };
  return { allow: false, reason: "quota" };
}

/** Count of SMS this org has SENT in the current calendar month, read from the
 * authoritative delivery ledger (notification_deliveries, the only table that
 * records SMS sends). status='sent' rows carry a sent_at; coalesce guards any
 * legacy row. This is the usage the monthly cap meters. */
function countSmsSentThisMonth(
  db: TenantQueryClient,
  organizationId: string,
): Promise<number> {
  return db.queryCount(
    `SELECT count(*) AS count FROM notification_deliveries
      WHERE organization_id = $1
        AND channel = 'sms'
        AND status = 'sent'
        AND coalesce(sent_at, created_at) >= date_trunc('month', timezone('utc', now()))`,
    [organizationId],
  );
}

/**
 * 402 when the org has hit its plan's monthly SMS cap; null otherwise / when
 * enforcement is off / plan unlimited / on any error (fail-open). Never throws.
 * Deploy-dark behind the same `ENTITLEMENT_ENFORCEMENT` switch as the slab
 * limits, and structured exactly like {@link enforceStudentLimit}: resolve the
 * plan, and only hit the DB for a live count when a finite cap could actually
 * bind AND the subscription isn't already suspended.
 */
export async function enforceSmsQuota(
  config: AppConfig,
  claims: AccessTokenClaims,
): Promise<Response | null> {
  if (!entitlementEnforcementEnabled()) return null;
  try {
    return await withTenantContext(config, claims, async (db) => {
      const sub = await resolveSubscription(
        db,
        claims.tenant_id,
        claims.school_id ?? null,
      );
      const limit = sub.limits.sms;
      const suspended = sub.status === "suspended";
      const current = (!suspended && limit != null)
        ? await countSmsSentThisMonth(db, claims.tenant_id)
        : 0;
      const decision = evaluateSmsQuota(sub.status, current, limit);
      if (decision.allow) return null;
      return decision.reason === "suspended"
        ? errorEnvelope(
          "SUBSCRIPTION_SUSPENDED",
          `Your ${sub.plan.name} subscription is suspended. Renew it to send more SMS.`,
          402,
        )
        : errorEnvelope(
          "SMS_QUOTA_EXCEEDED",
          `Your ${sub.plan.name} plan allows ${limit} SMS per month, and this month's quota is used up. Upgrade to send more.`,
          402,
        );
    });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return null;
    // Fail-open: a quota-check failure must never break a live send (matches the
    // student/school slab limits and the storage quota).
    console.error("SMS quota check failed:", error);
    return null;
  }
}
