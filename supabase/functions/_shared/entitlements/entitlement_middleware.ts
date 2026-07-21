// B2 — Entitlement Layer · Step 2 · server-side enforcement.
//
// `requireEntitlement` is the defense-in-depth gate: a module route returns
// `402 PLAN_UPGRADE_REQUIRED` when the caller's plan does not allow the module's
// entitlement slug. This is distinct from `403 FORBIDDEN` (RBAC: you lack the
// permission) — 402 means "your plan does not include this; upgrade to unlock".
// The real UX gating is client-side (later step); this guards the API regardless.
//
// `enforceEntitlement` resolves the caller org's plan-allowed entitlements off the
// RLS connection (missing subscription → Trial), then applies `requireEntitlement`.
// `withEntitlement` wraps a module router so enforcement runs only for that
// module's path prefix, leaving every other route untouched.
//
// Scope locked: no billing/payments/renewals/invoicing. A 402 here is purely an
// entitlement signal — it never initiates a charge.

import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
} from "../permission_middleware.ts";
import {
  TenantDbNotConfiguredError,
  type TenantQueryClient,
  withTenantContext,
} from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { resolveSubscription } from "./entitlement_service.ts";
import {
  entitlementEnforcementEnabled,
  isEntitlementEnforcedForOrg,
} from "./entitlement_enforcement.ts";
import { CAPABILITY_ENTITLEMENTS } from "./entitlement_resolver.ts";

/**
 * Reverse of `CAPABILITY_ENTITLEMENTS`: entitlement slug → capability flag.
 * Used so the gate can distinguish "your plan doesn't include this" (402) from
 * "your plan allows it but the school switched it off" (403 MODULE_DISABLED).
 */
const ENTITLEMENT_TO_CAPABILITY: Record<string, string> = Object.fromEntries(
  Object.entries(CAPABILITY_ENTITLEMENTS).map(([flag, slug]) => [slug, flag]),
);

export type ModuleRoute = (
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
) => Promise<Response | null>;

/**
 * Pure gate: returns a 402 response when `slug` is absent from the allowed set,
 * otherwise null. Kept side-effect-free so it can be unit-tested directly.
 */
export function requireEntitlement(
  allowed: Iterable<string>,
  slug: string,
): Response | null {
  const set = allowed instanceof Set ? allowed : new Set(allowed);
  if (!set.has(slug)) {
    return errorEnvelope(
      "PLAN_UPGRADE_REQUIRED",
      `This module requires a plan upgrade: ${slug}`,
      402,
    );
  }
  return null;
}

/**
 * Pure two-tier gate: 402 when the plan doesn't include the slug, else 403
 * MODULE_DISABLED when the slug maps to an optional capability the school has
 * switched off, else null (allowed). Side-effect-free for unit testing.
 */
export function gateModuleAccess(
  allowed: Iterable<string>,
  capabilities: Record<string, boolean>,
  slug: string,
): Response | null {
  const planDenied = requireEntitlement(allowed, slug);
  if (planDenied) return planDenied;
  const flag = ENTITLEMENT_TO_CAPABILITY[slug];
  if (flag && capabilities[flag] === false) {
    return errorEnvelope(
      "MODULE_DISABLED",
      `This module is disabled for this school: ${slug}`,
      403,
    );
  }
  return null;
}

/**
 * Pure gate: a SUSPENDED subscription blocks every entitled module, regardless of
 * what the plan allows.
 *
 * PRC-A cap 57 — `organization_subscriptions.status` ('trial'|'active'|'grace'|
 * 'suspended') was stored, resolved and returned to the client, but NOTHING
 * server-side ever read it: a suspended org kept full API access as long as its
 * plan included the slug, so "suspended" was a client-side decoration.
 *
 * 'grace' deliberately still PASSES — that is what a grace window means. Note the
 * grace window is not self-expiring: status is admin-set (subscription_admin_handlers)
 * and nothing transitions grace → suspended when `graceEndsAt` lapses, so an
 * expired grace stays open until an admin suspends it. Auto-blocking on a lapsed
 * `graceEndsAt` would cut off a live school on a schedule nobody configured — a
 * commercial policy decision, not an engineering one, so it is NOT assumed here.
 *
 * 402 (not 403) matches this module's existing convention: a plan/subscription
 * signal, never a charge (the billing scope-lock still holds).
 */
export function gateSubscriptionStatus(status: string): Response | null {
  if (status === "suspended") {
    return errorEnvelope(
      "SUBSCRIPTION_SUSPENDED",
      "This organisation's subscription is suspended — modules are unavailable until it is reactivated.",
      402,
    );
  }
  return null;
}

/**
 * The complete entitlement decision for ONE already-open tenant connection.
 *
 * ICA-G2 — the per-org rollout gate runs FIRST: when enforcement is not active
 * for this org (master mode "off", or "allowlist" with the org's flag unset) this
 * returns null immediately, so the request proceeds exactly as it does today.
 * Only when the org IS enforced does it resolve the subscription and apply the
 * suspended-subscription block (PRC-A cap 57) then the plan/capability gate.
 *
 * Extracted from `enforceEntitlement` so the ON path can be exercised end-to-end
 * against a fake TenantQueryClient (seeded org + seeded plan) with no live
 * Postgres — `enforceEntitlement` is now just auth + withTenantContext wrapped
 * around this function, which is the identical code that runs in production.
 *
 * Returns a Response to deny (402 plan-gate / 402 suspended / 403 module-disabled)
 * or null to allow.
 */
export async function resolveEntitlementDecision(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string | null,
  slug: string,
): Promise<Response | null> {
  // ICA-G2 phased rollout: is enforcement active for THIS org right now?
  if (!(await isEntitlementEnforcedForOrg(orgId, db))) return null;

  const resolved = await resolveSubscription(db, orgId, schoolId);
  // PRC-A cap 57 — subscription state first: a suspended org is blocked from
  // every entitled module before the plan/capability gates are even consulted.
  const suspended = gateSubscriptionStatus(resolved.status);
  if (suspended) return suspended;
  // G3 — plan ceiling (402) first, then school-disabled enforcement (403):
  // the plan may allow the optional module while the school has switched it
  // off in its own config, in which case the backend must not be callable.
  return gateModuleAccess(resolved.entitlements, resolved.capabilities, slug);
}

/**
 * Resolves the caller org's plan-allowed entitlements and enforces `slug`.
 * Returns a Response to short-circuit (401/402/500) or null to proceed.
 */
export async function enforceEntitlement(
  req: Request,
  config: AppConfig,
  slug: string,
): Promise<Response | null> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = auth.claims.school_id ?? null;
  try {
    return await withTenantContext(
      config,
      auth.claims,
      (db) => resolveEntitlementDecision(db, orgId, schoolId, slug),
    );
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    console.error(`Entitlement check failed for ${slug}:`, error);
    return errorEnvelope("INTERNAL_ERROR", "Entitlement check failed", 500);
  }
}

/**
 * Wraps a module router so `slug` is enforced for requests whose path falls under
 * `pathPrefix`; all other paths pass straight through to the wrapped route (which
 * returns null when it does not own the path). Non-invasive: no edits to the
 * module routers themselves.
 */
export function withEntitlement(
  route: ModuleRoute,
  pathPrefix: string,
  slug: string,
): ModuleRoute {
  return async (req, config, method, path) => {
    if (
      entitlementEnforcementEnabled() &&
      (path === pathPrefix || path.startsWith(`${pathPrefix}/`))
    ) {
      const denied = await enforceEntitlement(req, config, slug);
      if (denied) return denied;
    }
    return route(req, config, method, path);
  };
}
