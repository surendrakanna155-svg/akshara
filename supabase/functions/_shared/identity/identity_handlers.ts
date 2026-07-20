// PRA-P1-05 (S2) — permission-override admin endpoints (identity plane).
//
// Grant or deny a single permission for one user within the caller's own school.
// Gated on `manageManagement` (school-admin governance authority) and always
// audited — creating an override changes what a user can do, so it must be a
// deliberate, traceable, admin-only act. The write runs on the service-role
// client (the override table carries no RLS); tenant isolation is enforced here:
// the target membership must resolve within the CALLER's `claims.school_id`.

import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import { authenticateRequest, requirePermission } from "../permission_middleware.ts";
import { withTenantContext } from "../tenant_db.ts";
import { createServiceClient } from "../db.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";
import {
  type OverrideEffect,
  removeMembershipOverride,
  resolveSchoolMembershipId,
  setMembershipOverride,
  UnknownPermissionError,
} from "./membership_overrides_repository.ts";

interface OverrideBody {
  userId?: string;
  permission?: string;
  effect?: string;
  reason?: string;
}

/** POST /identity/permission-overrides — set a grant/deny override. */
export async function handleSetMembershipOverride(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "manageManagement");
  if (denied) return denied;

  const schoolId = auth.claims.school_id;
  if (auth.claims.scope !== "school" || !schoolId) {
    return errorEnvelope(
      "FORBIDDEN",
      "Permission overrides are managed within a school scope",
      403,
    );
  }

  const body = await readJson<OverrideBody>(req);
  if (!body?.userId || !body?.permission || !body?.effect) {
    return errorEnvelope("VALIDATION_ERROR", "userId, permission and effect are required", 422);
  }
  if (body.effect !== "grant" && body.effect !== "deny") {
    return errorEnvelope("VALIDATION_ERROR", "effect must be 'grant' or 'deny'", 422);
  }

  const service = createServiceClient(config);
  const membershipId = await resolveSchoolMembershipId(service, body.userId, schoolId);
  if (!membershipId) {
    return errorEnvelope(
      "MEMBERSHIP_NOT_FOUND",
      "No school membership for that user in your school",
      404,
    );
  }

  try {
    await setMembershipOverride(service, {
      schoolMembershipId: membershipId,
      permissionSlug: body.permission,
      effect: body.effect as OverrideEffect,
      reason: body.reason ?? null,
    });
  } catch (err) {
    if (err instanceof UnknownPermissionError) {
      return errorEnvelope("VALIDATION_ERROR", err.message, 422);
    }
    throw err;
  }

  await withTenantContext(config, auth.claims, (db) =>
    emitMutationAudit(
      db,
      auth.claims,
      moduleEntityAudit("identity.permission_override.set", "school_membership", membershipId, {
        userId: body.userId,
        permission: body.permission,
        effect: body.effect,
      }),
      req,
    ));

  return jsonResponse(envelope({
    success: true,
    schoolMembershipId: membershipId,
    permission: body.permission,
    effect: body.effect,
  }));
}

/** POST /identity/permission-overrides/remove — clear an override. */
export async function handleRemoveMembershipOverride(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "manageManagement");
  if (denied) return denied;

  const schoolId = auth.claims.school_id;
  if (auth.claims.scope !== "school" || !schoolId) {
    return errorEnvelope(
      "FORBIDDEN",
      "Permission overrides are managed within a school scope",
      403,
    );
  }

  const body = await readJson<OverrideBody>(req);
  if (!body?.userId || !body?.permission) {
    return errorEnvelope("VALIDATION_ERROR", "userId and permission are required", 422);
  }

  const service = createServiceClient(config);
  const membershipId = await resolveSchoolMembershipId(service, body.userId, schoolId);
  if (!membershipId) {
    return errorEnvelope(
      "MEMBERSHIP_NOT_FOUND",
      "No school membership for that user in your school",
      404,
    );
  }

  const removed = await removeMembershipOverride(service, {
    schoolMembershipId: membershipId,
    permissionSlug: body.permission,
  });

  await withTenantContext(config, auth.claims, (db) =>
    emitMutationAudit(
      db,
      auth.claims,
      moduleEntityAudit("identity.permission_override.removed", "school_membership", membershipId, {
        userId: body.userId,
        permission: body.permission,
        removed,
      }),
      req,
    ));

  return jsonResponse(envelope({ success: true, removed }));
}
