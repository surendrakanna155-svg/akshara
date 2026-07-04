// School configuration HTTP handlers — school scope.
//
// GET  /school-config gates on `viewSchoolSetup`.
// PUT  /school-config gates on `manageSchoolSetup` (admin / principal / owner).
// Both require an active school scope with a school_id; the school-scope RLS on
// `school_configuration` (not these handlers) guarantees a caller only ever
// touches their own school's gating. A GET that finds no row returns
// `{ configuration: null }` so the app falls back to its local default.

import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import {
  TenantDbNotConfiguredError,
  withTenantContext,
} from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";
import {
  getSchoolConfig,
  saveSchoolConfig,
  type SchoolConfigInput,
} from "./school_config_repository.ts";

function gate(claims: AccessTokenClaims, permission: string): Response | null {
  return requirePermission(claims, permission) ??
    requireSchoolOperationalScope(claims);
}

function failure(error: unknown, message: string): Response {
  if (error instanceof TenantDbNotConfiguredError) {
    return tenantDbNotConfiguredResponse(error);
  }
  console.error(`${message}:`, error);
  return errorEnvelope("INTERNAL_ERROR", message, 500);
}

export async function handleGetSchoolConfig(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = gate(auth.claims, "viewSchoolSetup");
  if (denied) return denied;

  const schoolId = schoolIdFromClaims(auth.claims);
  try {
    const configuration = await withTenantContext(
      config,
      auth.claims,
      (db) => getSchoolConfig(db, schoolId),
    );
    return jsonResponse(envelope({ configuration }));
  } catch (error) {
    return failure(error, "Failed to load school configuration");
  }
}

function parseBody(body: Record<string, unknown> | null): SchoolConfigInput | null {
  if (!body) return null;
  const capabilities = body.capabilities;
  if (typeof capabilities !== "object" || capabilities === null) return null;
  return {
    schoolType: String(body.schoolType ?? "day_school"),
    curriculum: String(body.curriculum ?? "cbse"),
    operationsModel: String(body.operationsModel ?? "single_school"),
    branchCount: Number(body.branchCount ?? 1) || 1,
    capabilities: capabilities as Record<string, unknown>,
  };
}

export async function handlePutSchoolConfig(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = gate(auth.claims, "manageSchoolSetup");
  if (denied) return denied;

  const input = parseBody(await readJson<Record<string, unknown>>(req));
  if (!input) {
    return errorEnvelope("INVALID_BODY", "A capabilities object is required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  try {
    const configuration = await withTenantContext(config, auth.claims, async (db) => {
      const saved = await saveSchoolConfig(db, orgId, schoolId, auth.claims.sub, input);
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit("schoolConfig.updated", "schoolConfiguration", schoolId, {
          schoolType: saved.schoolType,
          curriculum: saved.curriculum,
        }),
        req,
      );
      return saved;
    });
    return jsonResponse(envelope({ configuration }));
  } catch (error) {
    return failure(error, "Failed to save school configuration");
  }
}
