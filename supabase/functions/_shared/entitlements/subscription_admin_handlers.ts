// B2 — Step 4.5 · platform plan-assignment handlers (superAdmin only).
//
//   GET /platform/subscriptions                         — list orgs + current plan.
//   PUT /platform/organizations/{id}/subscription       — assign/change a plan.
//
// Both gate on `managePlatformSubscriptions` (seeded to superAdmin only). This
// is the security boundary for the SECURITY DEFINER assignment functions, which
// bypass RLS by design. Assignment is audited. NO payment/billing/renewal — a
// plan change is purely an entitlement flip.

import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import { authenticateRequest, requirePermission } from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { emitMutationAudit, subscriptionAudit } from "../audit/mutation_audit_catalog.ts";
import {
  assignOrganizationSubscription,
  listAssignableOrganizations,
} from "./entitlement_repository.ts";
import { parseAssignmentBody } from "./subscription_assignment.ts";

const PERMISSION = "managePlatformSubscriptions";

function failure(error: unknown, message: string): Response {
  if (error instanceof TenantDbNotConfiguredError) {
    return tenantDbNotConfiguredResponse(error);
  }
  console.error(`${message}:`, error);
  return errorEnvelope("INTERNAL_ERROR", message, 500);
}

export async function handleListAssignments(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, PERMISSION);
  if (denied) return denied;

  try {
    const organizations = await withTenantContext(
      config,
      auth.claims,
      (db) => listAssignableOrganizations(db),
    );
    return jsonResponse(envelope({ organizations }));
  } catch (error) {
    return failure(error, "Failed to list subscription assignments");
  }
}

export async function handleAssignSubscription(
  req: Request,
  config: AppConfig,
  organizationId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, PERMISSION);
  if (denied) return denied;

  if (!organizationId) {
    return errorEnvelope("INVALID_PATH", "Organization id is required", 400);
  }
  const input = parseAssignmentBody(await readJson<Record<string, unknown>>(req));
  if (!input) {
    return errorEnvelope(
      "INVALID_BODY",
      "A valid planSlug (trial|standard|professional|enterprise) is required",
      422,
    );
  }

  try {
    const organization = await withTenantContext(config, auth.claims, async (db) => {
      await assignOrganizationSubscription(db, {
        organizationId,
        planSlug: input.planSlug,
        status: input.status,
        actorId: auth.claims.sub,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        subscriptionAudit.planAssigned(
          organizationId,
          input.planSlug,
          input.status,
          crypto.randomUUID(),
        ),
        req,
      );
      // Authoritative post-write state via the SECURITY DEFINER list (RLS-safe
      // for cross-org platform reads).
      const all = await listAssignableOrganizations(db);
      return all.find((o) => o.organizationId === organizationId) ?? {
        organizationId,
        organizationName: "",
        organizationSlug: "",
        planSlug: input.planSlug,
        status: input.status,
      };
    });
    return jsonResponse(envelope({ organization }));
  } catch (error) {
    // Unknown plan surfaces as a FK/check violation from the SECURITY DEFINER fn.
    if (error instanceof Error && /Unknown or inactive plan/.test(error.message)) {
      return errorEnvelope("INVALID_PLAN", "Unknown or inactive plan", 400);
    }
    return failure(error, "Failed to assign subscription");
  }
}
