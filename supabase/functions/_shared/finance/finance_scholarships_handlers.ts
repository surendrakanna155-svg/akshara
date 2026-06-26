import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { emitMutationAudit, financeAudit } from "../audit/mutation_audit_catalog.ts";
import {
  createScholarship,
  isScholarshipType,
  type ScholarshipType,
  ScholarshipNotFoundError,
  scholarshipToApi,
  updateScholarship,
} from "./finance_scholarships_repository.ts";

function requireFinanceWrite(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "manageFinance") ??
    requireSchoolOperationalScope(claims);
}

function optionalStr(
  body: Record<string, unknown>,
  snakeKey: string,
  camelKey: string,
): string | undefined {
  if (snakeKey in body && body[snakeKey] != null) return String(body[snakeKey]);
  if (camelKey in body && body[camelKey] != null) return String(body[camelKey]);
  return undefined;
}

export async function handleCreateScholarship(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Request body is required", 422);
  }

  const name = optionalStr(body, "name", "name");
  const rawType = optionalStr(body, "type", "type") ?? "merit";
  const maxDiscount = optionalStr(body, "max_discount", "maxDiscount") ?? "";
  const eligibility = optionalStr(body, "eligibility", "eligibility") ?? "";

  if (!name) {
    return errorEnvelope("VALIDATION_ERROR", "name is required", 422);
  }
  if (!isScholarshipType(rawType)) {
    return errorEnvelope("VALIDATION_ERROR", `Invalid type: ${rawType}`, 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const created = await withTenantContext(config, auth.claims, async (db) => {
      const row = await createScholarship(db, orgId, schoolId, {
        name,
        type: rawType as ScholarshipType,
        maxDiscount,
        eligibility,
        createdBy: auth.claims.sub,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        financeAudit.scholarshipCreated(row.id),
        req,
      );
      return row;
    });
    return jsonResponse(envelope(scholarshipToApi(created)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}

export async function handleUpdateScholarship(
  req: Request,
  config: AppConfig,
  scholarshipId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Request body is required", 422);
  }

  const rawType = optionalStr(body, "type", "type");
  if (rawType != null && !isScholarshipType(rawType)) {
    return errorEnvelope("VALIDATION_ERROR", `Invalid type: ${rawType}`, 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const updated = await withTenantContext(config, auth.claims, async (db) => {
      const row = await updateScholarship(db, orgId, schoolId, scholarshipId, {
        name: optionalStr(body, "name", "name"),
        type: rawType as ScholarshipType | undefined,
        maxDiscount: optionalStr(body, "max_discount", "maxDiscount"),
        eligibility: optionalStr(body, "eligibility", "eligibility"),
      });
      await emitMutationAudit(
        db,
        auth.claims,
        financeAudit.scholarshipUpdated(row.id),
        req,
      );
      return row;
    });
    return jsonResponse(envelope(scholarshipToApi(updated)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    if (error instanceof ScholarshipNotFoundError) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    throw error;
  }
}
