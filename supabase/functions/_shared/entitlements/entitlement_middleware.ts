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
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { resolveSubscription } from "./entitlement_service.ts";
import { entitlementEnforcementEnabled } from "./entitlement_enforcement.ts";

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
    const resolved = await withTenantContext(
      config,
      auth.claims,
      (db) => resolveSubscription(db, orgId, schoolId),
    );
    return requireEntitlement(resolved.entitlements, slug);
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
