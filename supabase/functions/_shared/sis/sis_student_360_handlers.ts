import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { envelope, errorEnvelope, jsonResponse } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requireAnyPermission,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { StudentNotFoundError } from "./sis_students_repository.ts";
import { buildStudent360Profile, buildStudentTimeline } from "./student_360_service.ts";

function requireStudent360Read(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requireAnyPermission(claims, ["viewStudent360", "viewSis"]) ??
    requireSchoolOperationalScope(claims);
}

function viewModeFromClaims(claims: AccessTokenClaims): "admin" | "teacher" | "principal" | "parent" {
  if (claims.scope === "parent") return "parent";
  if (claims.role_slugs.includes("principal")) return "principal";
  if (claims.role_slugs.includes("teacher")) return "teacher";
  return "admin";
}

async function runTenant<T>(
  config: AppConfig,
  claims: Parameters<typeof withTenantContext>[1],
  operation: Parameters<typeof withTenantContext<T>>[2],
): Promise<T> {
  return await withTenantContext(config, claims, operation);
}

export async function handleGetStudent360Profile(
  req: Request,
  config: AppConfig,
  studentId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireStudent360Read(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const profile = await runTenant(config, auth.claims, (db) =>
      buildStudent360Profile(
        db,
        orgId,
        schoolId,
        studentId,
        viewModeFromClaims(auth.claims),
      )
    );
    return jsonResponse(envelope({ studentId, profile }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    if (error instanceof StudentNotFoundError) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    const message = error instanceof Error ? error.message : "Student 360 profile failed";
    return errorEnvelope("STUDENT_360_ERROR", message, 500);
  }
}

export async function handleGetStudentTimeline(
  req: Request,
  config: AppConfig,
  studentId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireStudent360Read(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const items = await runTenant(config, auth.claims, (db) =>
      buildStudentTimeline(db, orgId, schoolId, studentId)
    );
    return jsonResponse(envelope({ studentId, items }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    const message = error instanceof Error ? error.message : "Student timeline failed";
    return errorEnvelope("STUDENT_360_ERROR", message, 500);
  }
}
