import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, MAX_BULK_ITEMS, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { approvalPermissionForType } from "./approval_permissions.ts";
import { isClassTeacherForClass } from "../academic/teacher_assignments_repository.ts";
import {
  approvalAuditToApi,
  approvalRequestToApi,
  listEnvelope,
} from "./approval_mapper.ts";
import {
  ApprovalInvalidStateError,
  ApprovalNotFoundError,
  ApprovalRejectCommentRequiredError,
  ApprovalSelfApproveDeniedError,
  ApprovalSeparationOfDutiesError,
  findPendingByEntity,
  getApprovalById,
  insertAuditEntry,
  listApprovals,
  listAuditEntries,
  listPendingApprovals,
  submitApproval,
} from "./approval_repository.ts";
import { orchestrateApprovalDecision } from "./approval_orchestrator.ts";
import { isF2ApprovalType } from "./approval_types.ts";

function optionalStr(
  body: Record<string, unknown>,
  snakeKey: string,
  camelKey: string,
): string | undefined {
  if (snakeKey in body && body[snakeKey] != null) return String(body[snakeKey]);
  if (camelKey in body && body[camelKey] != null) return String(body[camelKey]);
  return undefined;
}

function mapApprovalError(error: unknown): Response | null {
  if (error instanceof ApprovalNotFoundError) {
    return errorEnvelope("NOT_FOUND", error.message, 404);
  }
  if (error instanceof ApprovalInvalidStateError) {
    return errorEnvelope("VALIDATION_ERROR", error.message, 422);
  }
  if (error instanceof ApprovalRejectCommentRequiredError) {
    return errorEnvelope("VALIDATION_ERROR", error.message, 422);
  }
  if (error instanceof ApprovalSelfApproveDeniedError) {
    return errorEnvelope("FORBIDDEN", error.message, 403);
  }
  if (error instanceof ApprovalSeparationOfDutiesError) {
    return errorEnvelope("FORBIDDEN", error.message, 403);
  }
  return null;
}

async function runTenant<T>(
  config: AppConfig,
  claims: Parameters<typeof withTenantContext>[1],
  operation: Parameters<typeof withTenantContext<T>>[2],
): Promise<T> {
  return await withTenantContext(config, claims, operation);
}

function requireSchoolScope(claims: Parameters<typeof requireSchoolOperationalScope>[0]): Response | null {
  return requireSchoolOperationalScope(claims);
}

type Claims = Parameters<typeof organizationIdFromClaims>[0];

/**
 * Per-item decision outcome. This is the SINGLE source of truth shared by the
 * single-ID endpoints and the batch endpoint, so the two paths cannot diverge.
 *   - kind "decided"   → the row transitioned (approved/rejected/cancelled).
 *   - kind "not_found" → no such approval in this tenant scope.
 *   - kind "denied"    → an authorization gate (per-type permission, class-teacher
 *                        scope, self-approve, SoD) refused this specific id.
 *   - kind "invalid"   → a per-item validation error (not pending, or reject
 *                        without a comment) refused this specific id.
 * Single handlers map denied/invalid/not_found to 403/422/404; the batch handler
 * maps them to `skipped` — the underlying decision logic is identical.
 */
export type DecideOutcome =
  | { kind: "decided"; row: Awaited<ReturnType<typeof orchestrateApprovalDecision>> }
  | { kind: "not_found" }
  | { kind: "denied"; message: string }
  | { kind: "invalid"; message: string };

/**
 * The one true per-item decision path. Runs INSIDE an already-open tenant
 * context (`db`), so single + batch reuse the exact same load → per-type
 * permission → class-teacher scope (studentLeave) → SoD/self-approve →
 * transition → domain effect → audit sequence. It never bypasses or weakens any
 * guard; a failing guard is returned as a structured outcome (never thrown) so
 * the batch can skip that id without aborting, while the single handlers turn
 * the same outcome into their existing HTTP status.
 *
 * Idempotency: the pending-state check lives in decideApproval's guarded UPDATE
 * (`... AND status = 'pending'`), surfaced here as ApprovalInvalidStateError →
 * kind "invalid" ("not pending"), so a non-pending id is never double-decided.
 */
export async function decideOne(
  db: Parameters<typeof getApprovalById>[0],
  claims: Claims,
  orgId: string,
  schoolId: string,
  id: string,
  decision: "approved" | "rejected",
  comment: string | null,
  actorId: string,
  actorName: string,
): Promise<DecideOutcome> {
  const row = await getApprovalById(db, orgId, schoolId, id);
  if (!row) {
    return { kind: "not_found" };
  }

  // Per-type approve/reject permission — reuse the exact type→slug map.
  const perm = approvalPermissionForType(row.type);
  if (perm && requirePermission(claims, perm) !== null) {
    return { kind: "denied", message: `Permission required: ${perm}` };
  }

  // Student leave: a teacher (no management oversight) may only decide leaves for
  // their OWN class. Principals/management (viewManagement) are unscoped.
  if (row.type === "studentLeave" && !claims.permissions.includes("viewManagement")) {
    const classLabel = String(row.payload?.classLabel ?? "");
    const dash = classLabel.indexOf("-");
    const className = dash >= 0 ? classLabel.substring(0, dash) : classLabel;
    const sectionName = dash >= 0 ? classLabel.substring(dash + 1) : "";
    const allowed = await isClassTeacherForClass(
      db,
      orgId,
      schoolId,
      claims.sub,
      className,
      sectionName,
    );
    if (!allowed) {
      return {
        kind: "denied",
        message: "Only the class teacher of this class may decide this leave.",
      };
    }
  }

  try {
    const decided = await orchestrateApprovalDecision(db, orgId, schoolId, {
      approvalId: id,
      status: decision,
      actorId,
      actorName,
      comment,
    });
    return { kind: "decided", row: decided };
  } catch (error) {
    // Self-approve (inventoryPo) + SoD (examResults verifier) are enforced
    // inside decideApproval; reject-without-comment + not-pending too. Turn each
    // into a structured outcome so the batch can skip rather than abort.
    if (
      error instanceof ApprovalSelfApproveDeniedError ||
      error instanceof ApprovalSeparationOfDutiesError
    ) {
      return { kind: "denied", message: error.message };
    }
    if (
      error instanceof ApprovalRejectCommentRequiredError ||
      error instanceof ApprovalInvalidStateError ||
      error instanceof ApprovalNotFoundError
    ) {
      return { kind: "invalid", message: error.message };
    }
    throw error;
  }
}

export async function handleListApprovals(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "viewManagement") ??
    requireSchoolScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const rows = await runTenant(config, auth.claims, (db) =>
      listApprovals(db, orgId, schoolId, {
        status: url.searchParams.get("status") ?? undefined,
        type: url.searchParams.get("type") ?? undefined,
        requesterId: url.searchParams.get("requesterId") ??
          url.searchParams.get("requester_id") ?? undefined,
        entityType: url.searchParams.get("entityType") ??
          url.searchParams.get("entity_type") ?? undefined,
        entityId: url.searchParams.get("entityId") ??
          url.searchParams.get("entity_id") ?? undefined,
      })
    );
    return jsonResponse(envelope(listEnvelope(rows.map(approvalRequestToApi))));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}

export async function handleListPendingApprovals(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "viewManagement") ??
    requireSchoolScope(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const rows = await runTenant(config, auth.claims, (db) =>
      listPendingApprovals(db, orgId, schoolId)
    );
    return jsonResponse(envelope(listEnvelope(rows.map(approvalRequestToApi))));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}

export async function handleGetApproval(
  req: Request,
  config: AppConfig,
  approvalId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "viewManagement") ??
    requireSchoolScope(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await runTenant(config, auth.claims, (db) =>
      getApprovalById(db, orgId, schoolId, approvalId)
    );
    if (!row) {
      return errorEnvelope("NOT_FOUND", `Approval not found: ${approvalId}`, 404);
    }
    return jsonResponse(envelope(approvalRequestToApi(row)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}

export async function handleFindPendingByEntity(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "viewManagement") ??
    requireSchoolScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const type = url.searchParams.get("type");
  const entityType = url.searchParams.get("entityType") ??
    url.searchParams.get("entity_type");
  const entityId = url.searchParams.get("entityId") ??
    url.searchParams.get("entity_id");

  if (!type || !entityType || !entityId) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "type, entityType, and entityId query params are required",
      422,
    );
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await runTenant(config, auth.claims, (db) =>
      findPendingByEntity(db, orgId, schoolId, type, entityType, entityId)
    );
    return jsonResponse(envelope(row ? approvalRequestToApi(row) : null));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}

export async function handleSubmitApproval(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireSchoolScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  const type = optionalStr(body, "type", "type");
  const title = optionalStr(body, "title", "title");
  const summary = optionalStr(body, "summary", "summary");
  const requesterId = optionalStr(body, "requester_id", "requesterId");
  const requesterName = optionalStr(body, "requester_name", "requesterName");
  const entityType = optionalStr(body, "entity_type", "entityType");
  const entityId = optionalStr(body, "entity_id", "entityId");

  if (!type || !title || !summary || !requesterId || !requesterName || !entityType || !entityId) {
    return errorEnvelope("VALIDATION_ERROR", "Missing required approval fields", 422);
  }

  if (!isF2ApprovalType(type)) {
    return errorEnvelope("VALIDATION_ERROR", `Unsupported approval type: ${type}`, 422);
  }

  const payload = (body.payload && typeof body.payload === "object" && !Array.isArray(body.payload))
    ? body.payload as Record<string, unknown>
    : {};

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await runTenant(config, auth.claims, (db) =>
      submitApproval(db, orgId, schoolId, {
        type,
        title,
        summary,
        requesterId,
        requesterName,
        entityType,
        entityId,
        payload,
      })
    );
    return jsonResponse(envelope(approvalRequestToApi(row)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    const mapped = mapApprovalError(error);
    if (mapped) return mapped;
    throw error;
  }
}

async function handleDecision(
  req: Request,
  config: AppConfig,
  approvalId: string,
  status: "approved" | "rejected" | "cancelled",
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireSchoolScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req) ?? {};
  const actorId = optionalStr(body, "actor_id", "actorId") ?? auth.claims.sub;
  const actorName = optionalStr(body, "actor_name", "actorName") ?? "Approver";
  const comment = optionalStr(body, "comment", "comment") ?? null;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  // Cancel keeps its OWN authorization (approval authority OR being the
  // requester) — it is not part of the batch surface and gates differently from
  // approve/reject. RT-20: it still loads the row and authorizes every decision.
  if (status === "cancelled") {
    const row = await runTenant(config, auth.claims, (db) =>
      getApprovalById(db, orgId, schoolId, approvalId)
    );
    if (!row) {
      return errorEnvelope("NOT_FOUND", `Approval not found: ${approvalId}`, 404);
    }
    const perm = approvalPermissionForType(row.type);
    const hasApproveAuthority =
      (perm ? requirePermission(auth.claims, perm) === null : false) ||
      requirePermission(auth.claims, "manageManagement") === null;
    const isRequester = row.requester_id === auth.claims.sub;
    if (!hasApproveAuthority && !isRequester) {
      return errorEnvelope(
        "FORBIDDEN",
        "Cancelling this approval requires approval authority or being the requester.",
        403,
      );
    }

    try {
      const decided = await runTenant(config, auth.claims, (db) =>
        orchestrateApprovalDecision(db, orgId, schoolId, {
          approvalId,
          status,
          actorId,
          actorName,
          comment,
        })
      );
      return jsonResponse(envelope(approvalRequestToApi(decided)));
    } catch (error) {
      if (error instanceof TenantDbNotConfiguredError) {
        return tenantDbNotConfiguredResponse();
      }
      const mapped = mapApprovalError(error);
      if (mapped) return mapped;
      throw error;
    }
  }

  // Approve / reject route through the SHARED decideOne so single + batch can't
  // diverge. The per-item outcome is mapped back to this endpoint's HTTP status.
  try {
    const outcome = await runTenant(config, auth.claims, (db) =>
      decideOne(db, auth.claims, orgId, schoolId, approvalId, status, comment, actorId, actorName)
    );
    switch (outcome.kind) {
      case "decided":
        return jsonResponse(envelope(approvalRequestToApi(outcome.row)));
      case "not_found":
        return errorEnvelope("NOT_FOUND", `Approval not found: ${approvalId}`, 404);
      case "denied":
        return errorEnvelope("FORBIDDEN", outcome.message, 403);
      case "invalid":
        return errorEnvelope("VALIDATION_ERROR", outcome.message, 422);
    }
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    const mapped = mapApprovalError(error);
    if (mapped) return mapped;
    throw error;
  }
}

export async function handleApproveApproval(
  req: Request,
  config: AppConfig,
  approvalId: string,
): Promise<Response> {
  return await handleDecision(req, config, approvalId, "approved");
}

export async function handleRejectApproval(
  req: Request,
  config: AppConfig,
  approvalId: string,
): Promise<Response> {
  return await handleDecision(req, config, approvalId, "rejected");
}

export async function handleCancelApproval(
  req: Request,
  config: AppConfig,
  approvalId: string,
): Promise<Response> {
  return await handleDecision(req, config, approvalId, "cancelled");
}

/**
 * PRI-1 — batch approve/reject on the Approval Center (multi-select decisions).
 *
 * Body: { ids: string[], decision: 'approve'|'reject', comment?: string }.
 * `reject` REQUIRES a non-empty comment (mirrors the single-reject 422).
 *
 * The route is gated on `viewManagement` for REACHABILITY only. The ACTUAL
 * decision authority for each id is the SAME per-item, type-specific check the
 * single endpoints run (approve permission + class-teacher scope + self-approve
 * + SoD) — so a caller lacking a given type's approve permission gets THAT id
 * skipped('forbidden'), not a blanket 403. Every id runs through the shared
 * `decideOne`, so batch and single cannot diverge.
 *
 * Partial result: { decided: [{id, status}], skipped: [{id, reason}] }.
 *   - missing id            → skipped('not found')
 *   - forbidden id          → skipped('forbidden: <reason>')
 *   - non-pending id        → skipped('not pending')  (idempotent; never
 *                             double-decided — the guarded UPDATE only fires on
 *                             a pending row)
 * A bad/forbidden/non-pending id NEVER aborts the batch. All ids run inside ONE
 * tenant transaction, and each decided id gets its own audit row (decideOne →
 * orchestrateApprovalDecision → decideApproval → insertAuditEntry).
 */
export async function handleBatchDecideApprovals(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  // Reachability gate only — per-item type-specific authority still governs each
  // decision below (see decideOne).
  const denied = requirePermission(auth.claims, "viewManagement") ??
    requireSchoolScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  const rawIds = body.ids;
  if (!Array.isArray(rawIds) || rawIds.length === 0) {
    return errorEnvelope("VALIDATION_ERROR", "ids must be a non-empty array", 422);
  }
  // ENG-8 (SEC-11): cap the bulk array before any per-row DB work.
  if (rawIds.length > MAX_BULK_ITEMS) {
    return errorEnvelope("VALIDATION_ERROR", `Maximum ${MAX_BULK_ITEMS} ids per request`, 422);
  }
  const ids = rawIds.map((v) => String(v));

  const decisionRaw = optionalStr(body, "decision", "decision");
  if (decisionRaw !== "approve" && decisionRaw !== "reject") {
    return errorEnvelope("VALIDATION_ERROR", "decision must be 'approve' or 'reject'", 422);
  }
  const status: "approved" | "rejected" = decisionRaw === "approve" ? "approved" : "rejected";

  const comment = optionalStr(body, "comment", "comment") ?? null;
  // Mirror the single-reject 422: reject requires a non-empty comment. Fail the
  // WHOLE batch up front (the single endpoint 422s on the same condition) rather
  // than skip every id — a missing reject comment is a request-shape error.
  if (status === "rejected" && !comment?.trim()) {
    return errorEnvelope("VALIDATION_ERROR", "Reject comment required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const actorId = auth.claims.sub;
  const actorName = "Approver";

  const decided: Array<{ id: string; status: string }> = [];
  const skipped: Array<{ id: string; reason: string }> = [];
  // De-dupe ids so a repeated id can't be decided twice within one batch.
  const seen = new Set<string>();

  try {
    await runTenant(config, auth.claims, async (db) => {
      for (const id of ids) {
        if (seen.has(id)) {
          skipped.push({ id, reason: "duplicate" });
          continue;
        }
        seen.add(id);

        const outcome = await decideOne(
          db,
          auth.claims,
          orgId,
          schoolId,
          id,
          status,
          comment,
          actorId,
          actorName,
        );
        switch (outcome.kind) {
          case "decided":
            decided.push({ id, status: outcome.row.status });
            break;
          case "not_found":
            skipped.push({ id, reason: "not found" });
            break;
          case "denied":
            skipped.push({ id, reason: `forbidden: ${outcome.message}` });
            break;
          case "invalid":
            skipped.push({ id, reason: "not pending" });
            break;
        }
      }
    });
    return jsonResponse(envelope({ decided, skipped }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}

export async function handleListApprovalAudit(
  req: Request,
  config: AppConfig,
  approvalId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "viewManagement") ??
    requireSchoolScope(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const rows = await runTenant(config, auth.claims, (db) =>
      listAuditEntries(db, orgId, schoolId, approvalId)
    );
    return jsonResponse(envelope(listEnvelope(rows.map(approvalAuditToApi))));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}

export async function handleRecordApprovalAudit(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  // RT-22 — this is a WRITE (it inserts an approval audit entry), so it must
  // require a manage-tier slug. It was gated by the read slug `viewManagement`,
  // letting a view-only management user forge audit-trail entries.
  const denied = requirePermission(auth.claims, "manageManagement") ??
    requireSchoolScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  const approvalRequestId = optionalStr(body, "approval_request_id", "approvalRequestId");
  const action = optionalStr(body, "action", "action");
  const actorId = optionalStr(body, "actor_id", "actorId");
  const actorName = optionalStr(body, "actor_name", "actorName");

  if (!approvalRequestId || !action || !actorId || !actorName) {
    return errorEnvelope("VALIDATION_ERROR", "Missing audit entry fields", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await runTenant(config, auth.claims, (db) =>
      insertAuditEntry(
        db,
        orgId,
        schoolId,
        approvalRequestId,
        action as "submitted" | "approved" | "rejected" | "cancelled",
        actorId,
        actorName,
        optionalStr(body, "comment", "comment") ?? null,
      )
    );
    return jsonResponse(envelope(approvalAuditToApi(row)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}
