// SCE-1 — clearance read endpoint. GET /sis/students/{id}/clearance?lifecycle=…
//
// Read-only consolidated no-dues report for a student, scoped to a lifecycle
// event (default transfer_certificate — the strictest/exit policy). viewSis +
// school scope, mirroring the certificate register. No mutation, no audit.

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
import { StudentNotFoundError } from "../sis/sis_students_repository.ts";
import { resolveStudentId } from "../sis/sis_student_resolver.ts";
import { buildClearanceReport, LIFECYCLE_POLICIES } from "./clearance_engine.ts";
import { DEFAULT_CLEARANCE_REGISTRY } from "./clearance_contributors.ts";

const DEFAULT_LIFECYCLE = "transfer_certificate";

function requireClearanceRead(
  claims: Parameters<typeof requirePermission>[0],
): Response | null {
  return requirePermission(claims, "viewSis") ??
    requireSchoolOperationalScope(claims);
}

/** A known lifecycle key, or the strict default. An unknown value falls back to
 * the exit policy rather than the permissive DEFAULT_POLICY, so a typo can never
 * silently downgrade a blocking gate to advisory. */
function resolveLifecycle(raw: string | null): string {
  const key = (raw ?? "").trim();
  return key && key in LIFECYCLE_POLICIES ? key : DEFAULT_LIFECYCLE;
}

export async function handleStudentClearance(
  req: Request,
  config: AppConfig,
  studentIdOrCode: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireClearanceRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const lifecycle = resolveLifecycle(url.searchParams.get("lifecycle"));
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const report = await withTenantContext(config, auth.claims, async (db) => {
      const resolved = await resolveStudentId(db, orgId, schoolId, studentIdOrCode);
      if (!resolved) throw new StudentNotFoundError(studentIdOrCode);
      return await buildClearanceReport(
        db,
        { organizationId: orgId, schoolId },
        resolved,
        lifecycle,
        DEFAULT_CLEARANCE_REGISTRY,
      );
    });
    return jsonResponse(envelope(report));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    if (error instanceof StudentNotFoundError) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    throw error;
  }
}
