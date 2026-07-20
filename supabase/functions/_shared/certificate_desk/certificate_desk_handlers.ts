// PRC-A Batch 2 (caps 136-148) — Certificate Request Desk HTTP handlers.
//
//   POST /certificate-requests             raise (requestStudentCertificate)
//   GET  /certificate-requests             school queue / parent's own (?status=)
//   GET  /certificate-requests/:id         detail
//   POST /certificate-requests/:id/cancel  cancel (staff only — see below)
//
// Deciding (approve/reject) is NOT here — it goes through the EXISTING
// generic F2 approval decide endpoints -> orchestrateApprovalDecision ->
// applyApprovalTypeHandler -> applyCertificateRequestDecision (see
// certificate_desk_approval_effect.ts).
//
// Cancel is intentionally STAFF-ONLY (requireSchoolOperationalScope), even
// though a parent may hold requestStudentCertificate and be "the original
// requester": the migration grants parent scope SELECT + INSERT ONLY (mirrors
// 20260885000000_gate_passes.sql's identical parent/staff shape) — a parent
// RLS session has no UPDATE grant on sis_certificate_requests at all. Gating
// in the handler before ever reaching the DB gives a clean 403 instead of a
// confusing RLS-caused "not pending" 409. A parent who wants to withdraw a
// request asks the school office to cancel it (they hold approveCertificateRequest
// or raised it themselves as staff).

import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import type { AccessTokenClaims } from "../jwt.ts";
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
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";
import { StudentNotFoundError } from "../sis/sis_students_repository.ts";
import { resolveStudentId } from "../sis/sis_student_resolver.ts";
import { submitApproval } from "../approval/approval_repository.ts";
import {
  assertCertificateRequestType,
  cancelCertificateRequest,
  CERTIFICATE_REQUEST_STATUSES,
  type CertificateRequestListFilter,
  CertificateRequestForbiddenError,
  CertificateRequestNotFoundError,
  type CertificateRequestRow,
  type CertificateRequestScope,
  CertificateRequestStateError,
  type CertificateRequestStatus,
  createCertificateRequest,
  DuplicateCertificateRequestError,
  getCertificateRequestById,
  InvalidCertificateRequestTypeError,
  linkApprovalRequest,
  listCertificateRequests,
} from "./certificate_desk_repository.ts";

const REQUEST_PERM = "requestStudentCertificate";
const APPROVE_PERM = "approveCertificateRequest";

function optionalStr(body: Record<string, unknown>, ...keys: string[]): string | undefined {
  for (const key of keys) {
    const value = body[key];
    if (typeof value === "string" && value.trim()) return value.trim();
  }
  return undefined;
}

/** School staff OR parent, both with a resolved school_id — the two scopes
 * that may ever touch the certificate desk. */
function requireCertificateDeskScope(claims: AccessTokenClaims): Response | null {
  if ((claims.scope !== "school" && claims.scope !== "parent") || !claims.school_id) {
    return errorEnvelope(
      "FORBIDDEN",
      "Certificate requests require school or parent scope",
      403,
    );
  }
  return null;
}

function requireRaisePermission(claims: AccessTokenClaims): Response | null {
  return requirePermission(claims, REQUEST_PERM) ?? requireCertificateDeskScope(claims);
}

/** Staff who may decide (approveCertificateRequest) OR raise
 * (requestStudentCertificate, which a parent also holds) may see the queue. */
function requireQueuePermission(claims: AccessTokenClaims): Response | null {
  return requireAnyPermission(claims, [APPROVE_PERM, REQUEST_PERM]) ??
    requireCertificateDeskScope(claims);
}

function certificateLabel(type: string): string {
  switch (type) {
    case "bonafide":
      return "Bonafide";
    case "study":
      return "Study";
    case "conduct":
      return "Conduct";
    case "transfer":
      return "Transfer";
    case "fee":
      return "Fee";
    default:
      return type;
  }
}

function certificateRequestToApi(row: CertificateRequestRow): Record<string, unknown> {
  return {
    id: row.id,
    studentId: row.student_id,
    certificateType: row.certificate_type,
    purpose: row.purpose ?? "",
    status: row.status,
    requestedBy: row.requested_by,
    requestedByRole: row.requested_by_role ?? "",
    approvalRequestId: row.approval_request_id,
    issuedCertificateId: row.issued_certificate_id,
    issueNote: row.issue_note ?? "",
    decidedAt: row.decided_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

// ── POST /certificate-requests ────────────────────────────────────────────
export async function handleRaiseCertificateRequest(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireRaisePermission(auth.claims);
  if (denied) return denied;

  let body: Record<string, unknown> = {};
  try {
    body = (await readJson<Record<string, unknown>>(req)) ?? {};
  } catch {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  const rawType = optionalStr(body, "certificateType", "certificate_type", "type");
  if (!rawType) {
    return errorEnvelope("VALIDATION_ERROR", "certificateType is required", 422);
  }
  let type: string;
  try {
    type = assertCertificateRequestType(rawType);
  } catch (error) {
    if (error instanceof InvalidCertificateRequestTypeError) {
      return errorEnvelope("VALIDATION_ERROR", error.message, 422);
    }
    throw error;
  }

  const purpose = optionalStr(body, "purpose", "reason") ?? null;

  // Resolve the TARGET student. Parent identity/child-linkage is NEVER
  // trusted from the body beyond naming which linked child — the
  // child_ids claim (JWT, verified) is the source of truth, doubly enforced
  // by the parent-scope INSERT RLS policy (student_guardians).
  let targetStudentIdOrCode: string;
  if (auth.claims.scope === "parent") {
    const requested = optionalStr(body, "studentId", "student_id", "childId", "child_id");
    if (requested) {
      if (!auth.claims.child_ids.includes(requested)) {
        return errorEnvelope(
          "FORBIDDEN",
          "Requested child is not linked to this parent account",
          403,
        );
      }
      targetStudentIdOrCode = requested;
    } else if (auth.claims.child_ids.length > 0) {
      targetStudentIdOrCode = auth.claims.child_ids[0]!;
    } else {
      return errorEnvelope("FORBIDDEN", "No linked children on parent account", 403);
    }
  } else {
    const requested = optionalStr(body, "studentId", "student_id");
    if (!requested) {
      return errorEnvelope("VALIDATION_ERROR", "studentId is required", 422);
    }
    targetStudentIdOrCode = requested;
  }

  const requesterName = optionalStr(body, "requesterName", "requester_name") ??
    (auth.claims.scope === "parent" ? "Parent" : "Requester");
  // Pinned to the calling scope — never trust the body for the raiser's role.
  const requestedByRole = auth.claims.scope === "parent"
    ? "parent"
    : (auth.claims.role || auth.claims.primary_role || "staff");

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const scope: CertificateRequestScope = { organizationId: orgId, schoolId };

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const resolved = await resolveStudentId(db, orgId, schoolId, targetStudentIdOrCode);
      if (!resolved) throw new StudentNotFoundError(targetStudentIdOrCode);

      const created = await createCertificateRequest(db, scope, {
        studentId: resolved,
        certificateType: type,
        purpose,
        requestedBy: auth.claims.sub,
        requestedByRole,
      });

      const label = certificateLabel(type);
      const approval = await submitApproval(db, orgId, schoolId, {
        type: "certificateRequest",
        title: `${label} certificate request`,
        summary: purpose ? `Reason: ${purpose}` : `${label} certificate requested`,
        requesterId: auth.claims.sub,
        requesterName,
        entityType: "certificate_request",
        entityId: created.id,
        payload: { certificateType: type, studentId: resolved },
      });

      await linkApprovalRequest(db, scope, created.id, approval.id);

      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit("certificateDesk.request.raised", "certificate_request", created.id, {
          studentId: resolved,
          certificateType: type,
        }),
        req,
      );

      return { ...created, approval_request_id: approval.id };
    });
    return jsonResponse(envelope(certificateRequestToApi(result)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    if (error instanceof StudentNotFoundError) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    if (error instanceof InvalidCertificateRequestTypeError) {
      return errorEnvelope("VALIDATION_ERROR", error.message, 422);
    }
    if (error instanceof DuplicateCertificateRequestError) {
      return errorEnvelope("CONFLICT", error.message, 409);
    }
    console.error("handleRaiseCertificateRequest error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to raise certificate request", 500);
  }
}

// ── GET /certificate-requests ─────────────────────────────────────────────
export async function handleListCertificateRequests(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireQueuePermission(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const statusRaw = url.searchParams.get("status") ?? undefined;
  if (
    statusRaw &&
    !(CERTIFICATE_REQUEST_STATUSES as readonly string[]).includes(statusRaw)
  ) {
    return errorEnvelope("VALIDATION_ERROR", `Invalid status filter: ${statusRaw}`, 422);
  }
  const status = statusRaw as CertificateRequestStatus | undefined;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const scope: CertificateRequestScope = { organizationId: orgId, schoolId };

  try {
    const items = await withTenantContext(config, auth.claims, async (db) => {
      const filter: CertificateRequestListFilter = { status };
      if (auth.claims.scope === "parent") {
        filter.studentIds = auth.claims.child_ids;
      }
      const rows = await listCertificateRequests(db, scope, filter);
      return rows.map(certificateRequestToApi);
    });
    return jsonResponse(envelope({ items, count: items.length }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    console.error("handleListCertificateRequests error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to list certificate requests", 500);
  }
}

// ── GET /certificate-requests/:id ─────────────────────────────────────────
export async function handleGetCertificateRequest(
  req: Request,
  config: AppConfig,
  id: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireQueuePermission(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const scope: CertificateRequestScope = { organizationId: orgId, schoolId };

  try {
    const row = await withTenantContext(
      config,
      auth.claims,
      (db) => getCertificateRequestById(db, scope, id),
    );
    if (!row) {
      return errorEnvelope("NOT_FOUND", `Certificate request not found: ${id}`, 404);
    }
    // Belt-and-braces own-child check (RLS already enforces this at the row
    // level for a parent session) — hide existence rather than leak a 403.
    if (auth.claims.scope === "parent" && !auth.claims.child_ids.includes(row.student_id)) {
      return errorEnvelope("NOT_FOUND", `Certificate request not found: ${id}`, 404);
    }
    return jsonResponse(envelope(certificateRequestToApi(row)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    console.error("handleGetCertificateRequest error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load certificate request", 500);
  }
}

// ── POST /certificate-requests/:id/cancel ─────────────────────────────────
export async function handleCancelCertificateRequest(
  req: Request,
  config: AppConfig,
  id: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  // Staff-only (see file header): parent RLS has no UPDATE grant here.
  const denied = requireAnyPermission(auth.claims, [REQUEST_PERM, APPROVE_PERM]) ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const scope: CertificateRequestScope = { organizationId: orgId, schoolId };
  const hasApprovePerm = auth.claims.permissions.includes(APPROVE_PERM);

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const row = await getCertificateRequestById(db, scope, id);
      if (!row) throw new CertificateRequestNotFoundError(id);
      // Only the original requester, or staff holding approveCertificateRequest,
      // may cancel.
      if (!hasApprovePerm && row.requested_by !== auth.claims.sub) {
        throw new CertificateRequestForbiddenError(id);
      }
      const cancelled = await cancelCertificateRequest(db, scope, id);
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit("certificateDesk.request.cancelled", "certificate_request", id, {}),
        req,
      );
      return cancelled;
    });
    return jsonResponse(envelope(certificateRequestToApi(result)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    if (error instanceof CertificateRequestNotFoundError) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    if (error instanceof CertificateRequestForbiddenError) {
      return errorEnvelope("FORBIDDEN", error.message, 403);
    }
    if (error instanceof CertificateRequestStateError) {
      return errorEnvelope("CONFLICT", error.message, 409);
    }
    console.error("handleCancelCertificateRequest error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to cancel certificate request", 500);
  }
}
