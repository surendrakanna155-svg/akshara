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
  DuplicateAssignmentError,
  DuplicateStudentAccountError,
  HandoffNotReadyError,
  assignFeeStructure,
  assignFromHandoff,
  bulkAssignFeeStructure,
  cancelAssignment,
  getAssignment,
  getStudentAccount,
  listAssignments,
} from "./finance_assignments_repository.ts";
import {
  assignmentToApi,
  listEnvelope,
  studentAccountToApi,
} from "./finance_mapper.ts";

function parsePagination(url: URL): { page: number; pageSize: number } {
  const page = Math.max(1, parseInt(url.searchParams.get("page") ?? "1", 10) || 1);
  const pageSize = Math.min(
    100,
    Math.max(1, parseInt(url.searchParams.get("pageSize") ?? "20", 10) || 20),
  );
  return { page, pageSize };
}

function optionalStr(
  body: Record<string, unknown>,
  snakeKey: string,
  camelKey: string,
): string | undefined {
  if (snakeKey in body && body[snakeKey] != null) {
    return String(body[snakeKey]);
  }
  if (camelKey in body && body[camelKey] != null) {
    return String(body[camelKey]);
  }
  return undefined;
}

async function runTenant<T>(
  config: AppConfig,
  claims: Parameters<typeof withTenantContext>[1],
  operation: Parameters<typeof withTenantContext<T>>[2],
): Promise<T> {
  return await withTenantContext(config, claims, operation);
}

function mapAssignmentError(error: unknown): Response | null {
  if (error instanceof DuplicateAssignmentError) {
    return errorEnvelope("CONFLICT", error.message, 409);
  }
  if (error instanceof DuplicateStudentAccountError) {
    return errorEnvelope("CONFLICT", error.message, 409);
  }
  if (error instanceof HandoffNotReadyError) {
    return errorEnvelope("VALIDATION_ERROR", error.message, 422);
  }
  if (error instanceof Error) {
    if (error.message.startsWith("Handoff not found")) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    if (error.message.startsWith("Fee structure not found")) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    if (error.message.includes("fee_structure_id is required")) {
      return errorEnvelope("VALIDATION_ERROR", error.message, 422);
    }
  }
  return null;
}

export async function handleListFeeAssignments(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "viewFinance") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const pagination = parsePagination(url);
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, (db) =>
      listAssignments(db, orgId, schoolId, pagination)
    );
    return jsonResponse(
      envelope(
        listEnvelope(
          result.items.map(assignmentToApi),
          {
            page: result.page,
            pageSize: result.pageSize,
            total: result.total,
            hasMore: result.hasMore,
          },
        ),
      ),
    );
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    throw error;
  }
}

export async function handleGetFeeAssignment(
  req: Request,
  config: AppConfig,
  assignmentId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "viewFinance") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const assignment = await runTenant(config, auth.claims, (db) =>
      getAssignment(db, orgId, schoolId, assignmentId)
    );
    if (!assignment) {
      return errorEnvelope("NOT_FOUND", `Assignment not found: ${assignmentId}`, 404);
    }
    return jsonResponse(envelope(assignmentToApi(assignment)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    throw error;
  }
}

export async function handleCreateFeeAssignment(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "manageFinance") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const handoffId = optionalStr(body, "handoff_id", "handoffId");

  try {
    const result = await runTenant(config, auth.claims, async (db) => {
      let assignmentResult;
      if (handoffId) {
        const feeStructureId = optionalStr(body, "fee_structure_id", "feeStructureId") ?? null;
        assignmentResult = await assignFromHandoff(
          db,
          orgId,
          schoolId,
          handoffId,
          feeStructureId,
          auth.claims.sub,
        );
      } else {
        const studentId = optionalStr(body, "student_id", "studentId");
        const feeStructureId = optionalStr(body, "fee_structure_id", "feeStructureId");
        const academicYear = optionalStr(body, "academic_year", "academicYear");
        if (!studentId || !feeStructureId || !academicYear) {
          throw new Error("VALIDATION:student_id, fee_structure_id, and academic_year are required");
        }

        assignmentResult = await assignFeeStructure(db, orgId, schoolId, {
          studentId,
          feeStructureId,
          academicYear,
          assignedBy: auth.claims.sub,
        });
      }
      await emitMutationAudit(
        db,
        auth.claims,
        financeAudit.feeAssignmentCreated(assignmentResult.assignment.id),
        req,
      );
      return assignmentResult;
    });

    return jsonResponse(
      envelope(studentAccountToApi(result)),
      { status: 201 },
    );
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    const mapped = mapAssignmentError(error);
    if (mapped) return mapped;
    if (error instanceof Error && error.message.startsWith("VALIDATION:")) {
      return errorEnvelope("VALIDATION_ERROR", error.message.slice(11), 422);
    }
    throw error;
  }
}

/**
 * Client contract: POST /finance/fee-assignments/bulk (PRC-A gap fix — a real
 * school assigning a fee structure to a whole class had no way to do it
 * without repeating the single-assign flow per student). Body:
 * `{ feeStructureId, academicYear, studentIds[] }` (snake/camel accepted, like
 * every other handler here). manageFinance-gated, same as the single-assign
 * paths above.
 *
 * Partial-failure contract: a student who already has this exact structure
 * for this academic year is SKIPPED and reported in `skipped` — not a 409 —
 * because that is the common, expected shape of a class-wide call, not an
 * error. Any other failure (bad fee structure id, etc.) aborts the whole
 * batch via the usual error mapping below.
 */
export async function handleBulkAssignFeeStructures(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "manageFinance") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  const feeStructureId = optionalStr(body, "fee_structure_id", "feeStructureId");
  const academicYear = optionalStr(body, "academic_year", "academicYear");
  if (!feeStructureId || !academicYear) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "fee_structure_id and academic_year are required",
      422,
    );
  }

  const rawStudentIds = body["student_ids"] ?? body["studentIds"];
  if (!Array.isArray(rawStudentIds) || rawStudentIds.length === 0) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "student_ids must be a non-empty array",
      422,
    );
  }
  const studentIds = rawStudentIds.map((id) => String(id));

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, async (db) => {
      const bulkResult = await bulkAssignFeeStructure(db, orgId, schoolId, {
        feeStructureId,
        academicYear,
        studentIds,
        assignedBy: auth.claims.sub,
      });
      // Only audit when something actually assigned — an all-duplicate pass
      // (every student already had this structure) changed nothing, mirroring
      // FIN-D5's "a zero pass is a read" idiom.
      if (bulkResult.assigned.length > 0) {
        await emitMutationAudit(
          db,
          auth.claims,
          financeAudit.feeAssignmentBulkAssigned(
            schoolId,
            feeStructureId,
            bulkResult.assigned.length,
            bulkResult.skipped.length,
            `${Date.now()}`,
          ),
          req,
        );
      }
      return bulkResult;
    });

    return jsonResponse(
      envelope({
        assigned: result.assigned.map(studentAccountToApi),
        skipped: result.skipped.map((s) => ({
          studentId: s.studentId,
          reason: s.reason,
        })),
        total: result.total,
      }),
      { status: 201 },
    );
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    const mapped = mapAssignmentError(error);
    if (mapped) return mapped;
    throw error;
  }
}

/** Client contract: POST /finance/fee-assignment/assign */
export async function handleAssignFeePlan(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "manageFinance") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  const handoffId = optionalStr(body, "handoff_id", "handoffId");
  if (!handoffId) {
    return errorEnvelope("VALIDATION_ERROR", "handoff_id is required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const feeStructureId = optionalStr(body, "fee_structure_id", "feeStructureId") ?? null;

  try {
    const result = await runTenant(config, auth.claims, async (db) => {
      const assigned = await assignFromHandoff(db, orgId, schoolId, handoffId, feeStructureId, auth.claims.sub);
      await emitMutationAudit(db, auth.claims, financeAudit.feeAssignmentCreated(assigned.assignment.id), req);
      return assigned;
    });
    return jsonResponse(envelope(studentAccountToApi(result)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    const mapped = mapAssignmentError(error);
    if (mapped) return mapped;
    throw error;
  }
}

export async function handleCancelFeeAssignment(
  req: Request,
  config: AppConfig,
  assignmentId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "manageFinance") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, async (db) => {
      const cancelled = await cancelAssignment(db, orgId, schoolId, assignmentId);
      if (!cancelled) return null;
      await emitMutationAudit(db, auth.claims, financeAudit.feeAssignmentCancelled(assignmentId), req);
      return cancelled;
    });
    if (!result) {
      return errorEnvelope("NOT_FOUND", `Assignment not found: ${assignmentId}`, 404);
    }
    return jsonResponse(envelope({
      assignment: assignmentToApi(result.assignment),
      account: studentAccountToApi(result),
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    throw error;
  }
}

export async function handleGetStudentAccount(
  req: Request,
  config: AppConfig,
  studentId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "viewFinance") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const academicYear = url.searchParams.get("academicYear") ??
    url.searchParams.get("academic_year") ?? undefined;
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, (db) =>
      getStudentAccount(db, orgId, schoolId, studentId, academicYear || undefined)
    );
    if (!result) {
      return errorEnvelope("NOT_FOUND", `Student account not found: ${studentId}`, 404);
    }
    return jsonResponse(envelope(studentAccountToApi(result)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    throw error;
  }
}
