// B2 — Step 4.6 · backend enforcement master switch.
// ICA-G2 — phased rollout: a master MODE (kill-switch) + PER-ORG enablement.
//
// Backend entitlement enforcement (module 402 guards + slab-limit guards) is
// always wired, but only ACTS when the rollout mode says so. This lets the edge
// deploy "dark": ship the code, assign every live org its real plan via the
// Step-4.5 admin screen, THEN turn enforcement on — gradually, one validated org
// at a time, WITHOUT a redeploy.
//
// ── MASTER MODE (env, default OFF) ────────────────────────────────────────────
//   off        (default) → enforce NOWHERE. Exactly today's safe behavior; the
//                           current pilot is unaffected. Zero risk.
//   allowlist            → enforce ONLY for orgs whose per-org flag
//                           (organizations.entitlement_enforcement_enabled) is
//                           true. This is the gradual rollout dial: an operator
//                           validates one org, flips its flag, and enforcement
//                           begins for that org alone — no redeploy, no restart.
//   all                  → enforce EVERYWHERE (the eventual end state).
//
// Resolved from `ENTITLEMENT_ENFORCEMENT_MODE`. For backward compatibility the
// legacy boolean `ENTITLEMENT_ENFORCEMENT=true` maps to "all" (its exact historical
// meaning — "enforce everywhere"), so an operator who already set the old flag
// keeps today's behavior with no config churn. Read from the env each call so
// changing the dial needs only an edge restart, not a redeploy.
//
// ── PER-ORG FLAG ──────────────────────────────────────────────────────────────
// A single resolver — `isEntitlementEnforcedForOrg(orgId, db)` — is the ONE place
// every enforcement path (module 402 gate + slab/SMS limits) asks "is this org
// enforced right now?". It combines the master mode with the per-org flag, so the
// rollout state lives in exactly one function.

import type { TenantQueryClient } from "../tenant_db.ts";

/** Master rollout mode for backend entitlement enforcement (ICA-G2). */
export type EntitlementEnforcementMode = "off" | "allowlist" | "all";

/**
 * Resolve the master rollout mode from the environment.
 *
 * Precedence:
 *   1. `ENTITLEMENT_ENFORCEMENT_MODE` ∈ {off, allowlist, all} — the phased dial.
 *   2. Legacy `ENTITLEMENT_ENFORCEMENT=true` → "all" (its historical semantics),
 *      so the old single-boolean deploy keeps behaving exactly as before.
 *   3. Anything else / nothing set → "off" (default — enforce nowhere).
 *
 * Fails safe to "off" if the env is unreadable (restricted context).
 */
export function entitlementEnforcementMode(): EntitlementEnforcementMode {
  try {
    const raw = (Deno.env.get("ENTITLEMENT_ENFORCEMENT_MODE") ?? "")
      .trim()
      .toLowerCase();
    if (raw === "off" || raw === "allowlist" || raw === "all") return raw;
    // Legacy boolean flag → "all" (backward compatibility with the old switch).
    if ((Deno.env.get("ENTITLEMENT_ENFORCEMENT") ?? "").toLowerCase() === "true") {
      return "all";
    }
    return "off";
  } catch {
    // Env not readable (e.g. restricted context) → fail safe to OFF.
    return "off";
  }
}

/**
 * Master gate: is the enforcement machinery active in ANY mode (i.e. not "off")?
 * Cheap and DB-free — the outer wrappers use it to decide whether to even
 * authenticate and open a tenant context. When this is false (mode "off", the
 * default), enforcement runs NOWHERE and every caller passes straight through,
 * exactly as before ICA-G2. The FINAL, per-org decision is made by
 * `isEntitlementEnforcedForOrg` once a tenant connection is open.
 */
export function entitlementEnforcementEnabled(): boolean {
  return entitlementEnforcementMode() !== "off";
}

/**
 * The single per-org enforcement decision used by every enforcement path
 * (module 402 gate + slab/SMS limits):
 *   off       → false (enforce nowhere; the default).
 *   all       → true  (enforce everywhere; no DB read needed).
 *   allowlist → true ONLY when this org's
 *               `organizations.entitlement_enforcement_enabled` flag is set,
 *               enabling gradual org-by-org rollout without a redeploy.
 * Fail-safe: unknown org / null flag → false (an org is enforced only when it has
 * been explicitly opted in).
 */
export async function isEntitlementEnforcedForOrg(
  organizationId: string,
  db: TenantQueryClient,
): Promise<boolean> {
  const mode = entitlementEnforcementMode();
  if (mode === "off") return false;
  if (mode === "all") return true;
  // allowlist — consult the per-org flag. The tenant RLS connection can read only
  // its OWN org row (organizations_tenant_access: id = app_current_tenant_id()),
  // and the caller always passes its own tenant id, so this is a single-row lookup.
  return await isOrgEntitlementFlagEnabled(db, organizationId);
}

/**
 * Reads `organizations.entitlement_enforcement_enabled` for `organizationId`.
 * Missing row / NULL / false → false. Only an explicit `true` opts the org in.
 */
async function isOrgEntitlementFlagEnabled(
  db: TenantQueryClient,
  organizationId: string,
): Promise<boolean> {
  const rows = await db.queryObject<{ enabled: boolean | null }>(
    `SELECT entitlement_enforcement_enabled AS enabled
       FROM organizations WHERE id = $1 LIMIT 1`,
    [organizationId],
  );
  return rows[0]?.enabled === true;
}
