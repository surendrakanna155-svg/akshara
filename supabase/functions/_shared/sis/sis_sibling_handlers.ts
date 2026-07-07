import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { resolveStudentId } from "./sis_student_resolver.ts";
import {
  listStudentSiblings,
  StudentNotFoundError,
} from "./sis_students_repository.ts";
import { studentSiblingItemToApi } from "./sis_mapper.ts";

function requireSisRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewSis") ??
    requireSchoolOperationalScope(claims);
}

/**
 * SIS-4 — GET /sis/students/{id}/siblings. Read-only "Siblings / Family" list
 * for a clerk viewing a student: other students in the SAME school who share an
 * active guardian with the subject (self-excluded), ordered by name. Gated on
 * the SIS read permission (viewSis) + school operational scope, same as the
 * document list GET. Out-of-scope / unknown student → 404 (never leaks another
 * school's roster). Returns `{ siblings: [...] }` (empty array when none).
 */
export async function handleListStudentSiblings(
  req: Request,
  config: AppConfig,
  studentIdOrCode: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireSisRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const siblings = await withTenantContext(config, auth.claims, async (db) => {
      const resolved = await resolveStudentId(db, orgId, schoolId, studentIdOrCode);
      if (!resolved) throw new StudentNotFoundError(studentIdOrCode);
      const rows = await listStudentSiblings(db, orgId, schoolId, resolved);
      return rows.map(studentSiblingItemToApi);
    });
    return jsonResponse(envelope({ siblings }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    if (error instanceof StudentNotFoundError) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    console.error("handleListStudentSiblings error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to list student siblings", 500);
  }
}
