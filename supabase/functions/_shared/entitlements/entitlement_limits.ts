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
      if (limit == null) return null; // unlimited plan
      const current = await count(db, claims.tenant_id);
      if (withinSlab(current, limit, sub.limits.graceBufferPercent)) return null;
      return errorEnvelope(
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
