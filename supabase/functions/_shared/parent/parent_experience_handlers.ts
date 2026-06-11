import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { emitMutationAudit, parentExperienceAudit } from "../audit/mutation_audit_catalog.ts";
import {
  buildParentExperienceHub,
  recordParentAcknowledgement,
} from "./parent_experience_service.ts";
import { requestReplacement } from "../inventory_distribution/inventory_distribution_repository.ts";

function requireParentScope(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewParentExperience");
}

export async function handleParentExperienceHub(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireParentScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const studentId = url.searchParams.get("studentId");
  if (!studentId) {
    return errorEnvelope("VALIDATION_ERROR", "studentId is required", 400);
  }

  try {
    const hub = await withTenantContext(config, auth.claims, async (db) =>
      buildParentExperienceHub(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        studentId,
      )
    );
    return jsonResponse(envelope(hub));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    const message = error instanceof Error ? error.message : "Failed to load parent experience hub";
    return errorEnvelope("PARENT_EXPERIENCE_ERROR", message, 500);
  }
}

export async function handleParentAcknowledge(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireParentScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    studentId?: string;
    distributionId?: string;
    acknowledgementType?: string;
    notes?: string;
  }>(req);
  if (!body.studentId || !body.distributionId) {
    return errorEnvelope("VALIDATION_ERROR", "studentId and distributionId are required", 400);
  }
  const ackType = body.acknowledgementType === "replacement_requested"
    ? "replacement_requested"
    : "received";

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const ack = await recordParentAcknowledgement(db, orgId, schoolId, {
        studentId: body.studentId!,
        distributionId: body.distributionId!,
        acknowledgedBy: auth.claims.sub,
        acknowledgementType: ackType,
        notes: body.notes,
      });
      if (ackType === "replacement_requested") {
        await requestReplacement(
          db,
          orgId,
          schoolId,
          body.distributionId!,
          auth.claims.sub,
          body.notes,
        );
      }
      await emitMutationAudit(
        db,
        auth.claims,
        parentExperienceAudit.acknowledge(body.distributionId!, ackType),
        req,
      );
      return ack;
    });
    return jsonResponse(envelope(result));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    const message = error instanceof Error ? error.message : "Acknowledgement failed";
    return errorEnvelope("PARENT_ACK_ERROR", message, 500);
  }
}
