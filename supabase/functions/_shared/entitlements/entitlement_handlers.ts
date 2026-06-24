// B2 — Entitlement Layer · Step 2 · HTTP handlers (read-only).
//
//   GET /plans        — public plan catalog (auth required, no special perm).
//   GET /subscription — the caller org's resolved plan/status/entitlements/
//                       limits/usage. Gates on `viewSubscription` + school scope
//                       (org admins read it through the common pilot token).
//
// No write route in Step 2 — plan assignment (PUT /platform/.../subscription)
// is a later step. Scope locked: no billing/payments/renewals/invoicing.

import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { listPublicPlans } from "./entitlement_repository.ts";
import { resolveSubscription } from "./entitlement_service.ts";

function failure(error: unknown, message: string): Response {
  if (error instanceof TenantDbNotConfiguredError) {
    return tenantDbNotConfiguredResponse(error);
  }
  console.error(`${message}:`, error);
  return errorEnvelope("INTERNAL_ERROR", message, 500);
}

export async function handleGetPlans(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  try {
    const plans = await withTenantContext(
      config,
      auth.claims,
      (db) => listPublicPlans(db),
    );
    return jsonResponse(envelope({ plans }));
  } catch (error) {
    return failure(error, "Failed to load plan catalog");
  }
}

export async function handleGetSubscription(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewSubscription") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = auth.claims.school_id ?? null;
  try {
    const subscription = await withTenantContext(
      config,
      auth.claims,
      (db) => resolveSubscription(db, orgId, schoolId),
    );
    return jsonResponse(envelope({ subscription }));
  } catch (error) {
    return failure(error, "Failed to resolve subscription");
  }
}
