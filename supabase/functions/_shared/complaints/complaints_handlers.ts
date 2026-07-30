// PRC-A Batch 2 (caps 101-108) — Complaint / Internal Issue HTTP handlers.
//
//   POST /complaints                raise (raiseComplaint)
//   GET  /complaints                list — school queue (manage/principal) or
//                                    own-only (a bare raiseComplaint holder,
//                                    or a parent)
//   GET  /complaints/{id}           detail + full event timeline
//   POST /complaints/{id}/assign    manageComplaints
//   POST /complaints/{id}/status    manageComplaints OR the current assignee
//   POST /complaints/{id}/comment   anyone who can already see the complaint
//   POST /complaints/{id}/vendor    manageComplaints
//   POST /complaints/{id}/photo     the raiser (own complaint) or manageComplaints

import type { AccessTokenClaims } from "../jwt.ts";
import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
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
import {
  COMPLAINT_CATEGORIES,
  COMPLAINT_SEVERITIES,
  COMPLAINT_STATUSES,
  type ComplaintStatus,
  computeSlaDueAt,
  computeSlaState,
} from "./complaints_sla.ts";
import {
  assignComplaint,
  attachPhoto,
  attachVendor,
  type ComplaintEventRow,
  ComplaintError,
  type ComplaintRow,
  eventTypeForTransition,
  findVendorInScope,
  getComplaint,
  listComplaintEvents,
  listComplaints,
  markFirstResponse,
  raiseComplaint,
  recordEvent,
  transitionStatus,
  VendorNotFoundError,
} from "./complaints_repository.ts";
import {
  buildComplaintPhotoStoragePath,
  createComplaintPhotoUploadUrl,
  validateComplaintPhotoUpload,
} from "./complaints_storage.ts";

const VIEW_PERMISSIONS = ["raiseComplaint", "manageComplaints", "viewComplaintsPrincipal"];

function requireAnyComplaintsAccess(claims: AccessTokenClaims): Response | null {
  return requireAnyPermission(claims, VIEW_PERMISSIONS);
}

/** Deliberately permissive: only checks a school_id is present, NOT that the
 * scope is 'school' — a parent-scope session also carries school_id and
 * legitimately raises/lists/comments/photo-attaches on their OWN complaints.
 * Endpoints that must be staff-only (assign, status, vendor) instead use
 * `requireSchoolOperationalScope` (scope === 'school') or a permission check
 * that a parent could never hold. */
function requireSchoolSession(claims: AccessTokenClaims): Response | null {
  if (!claims.school_id) {
    return errorEnvelope("FORBIDDEN", "Complaints require a school-scoped session", 403);
  }
  return null;
}

/** manageComplaints / viewComplaintsPrincipal see the whole school queue;
 * everyone else (a bare raiseComplaint holder, or a parent) sees only their
 * own — folded into the repository's SQL WHERE, never filtered client-side. */
function complaintVisibility(claims: AccessTokenClaims): { seesAll: boolean; ownOnly: string } {
  const seesAll = claims.permissions.includes("manageComplaints") ||
    claims.permissions.includes("viewComplaintsPrincipal");
  return { seesAll, ownOnly: claims.sub };
}

function optionalStr(body: Record<string, unknown>, ...keys: string[]): string | undefined {
  for (const key of keys) {
    const value = body[key];
    if (typeof value === "string" && value.trim()) return value.trim();
  }
  return undefined;
}

async function readBody(req: Request): Promise<Record<string, unknown> | Response> {
  try {
    return (await readJson<Record<string, unknown>>(req)) ?? {};
  } catch {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }
}

function isResponse(value: unknown): value is Response {
  return value instanceof Response;
}

function complaintToApi(row: ComplaintRow, now: Date) {
  return {
    id: row.id,
    category: row.category,
    title: row.title,
    description: row.description,
    severity: row.severity,
    status: row.status,
    raisedBy: row.raised_by,
    raisedByRole: row.raised_by_role,
    relatedStudentId: row.related_student_id,
    assignedTo: row.assigned_to,
    assignedAt: row.assigned_at,
    assignedBy: row.assigned_by,
    slaDueAt: row.sla_due_at,
    slaState: computeSlaState(row.sla_due_at, now, row.resolved_at),
    firstResponseAt: row.first_response_at,
    resolvedAt: row.resolved_at,
    resolvedBy: row.resolved_by,
    resolutionNote: row.resolution_note,
    reopenedCount: row.reopened_count,
    vendorId: row.vendor_id,
    repairCost: row.repair_cost != null ? Number(row.repair_cost) : null,
    photoPath: row.photo_path,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function eventToApi(row: ComplaintEventRow) {
  return {
    id: row.id,
    complaintId: row.complaint_id,
    eventType: row.event_type,
    actorId: row.actor_id,
    actorName: row.actor_name,
    note: row.note,
    metadata: row.metadata,
    occurredAt: row.occurred_at,
  };
}

function complaintErrorResponse(e: ComplaintError): Response {
  return errorEnvelope(`COMPLAINT_${e.code}`, e.message, e.status);
}

// ── POST /complaints ────────────────────────────────────────────────────
export async function handleRaiseComplaint(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "raiseComplaint") ?? requireSchoolSession(auth.claims);
  if (denied) return denied;

  const body = await readBody(req);
  if (isResponse(body)) return body;

  const category = optionalStr(body, "category") ?? "";
  if (!(COMPLAINT_CATEGORIES as readonly string[]).includes(category)) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      `category must be one of ${COMPLAINT_CATEGORIES.join(", ")}`,
      422,
    );
  }
  const title = optionalStr(body, "title") ?? "";
  if (title.length < 3) {
    return errorEnvelope("VALIDATION_ERROR", "title (>=3 chars) is required", 422);
  }
  const description = optionalStr(body, "description") ?? "";
  const severity = optionalStr(body, "severity") ?? "medium";
  if (!(COMPLAINT_SEVERITIES as readonly string[]).includes(severity)) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      `severity must be one of ${COMPLAINT_SEVERITIES.join(", ")}`,
      422,
    );
  }
  const relatedStudentId = optionalStr(body, "relatedStudentId", "related_student_id") ?? null;
  const photoPath = optionalStr(body, "photoPath", "photo_path") ?? null;
  const actorName = optionalStr(body, "actorName", "raisedByName") ?? "";

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const raisedBy = auth.claims.sub;
  const raisedByRole = auth.claims.primary_role || auth.claims.scope;
  const now = new Date();
  const slaDueAt = computeSlaDueAt(now, category, severity);

  try {
    const created = await withTenantContext(config, auth.claims, async (db) => {
      const scope = { organizationId: orgId, schoolId };
      const row = await raiseComplaint(db, scope, {
        category,
        title,
        description,
        severity,
        raisedBy,
        raisedByRole,
        relatedStudentId,
        photoPath,
        slaDueAt,
      });
      await recordEvent(db, scope, {
        complaintId: row.id,
        eventType: "raised",
        actorId: raisedBy,
        actorName,
        metadata: { category, severity },
      });
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit("complaints.complaint.raised", "complaint", row.id, {
          category,
          severity,
        }),
        req,
      );
      return row;
    });
    return jsonResponse(envelope(complaintToApi(created, now)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

// ── GET /complaints ─────────────────────────────────────────────────────
export async function handleListComplaints(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireAnyComplaintsAccess(auth.claims) ?? requireSchoolSession(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const status = url.searchParams.get("status") ?? undefined;
  const category = url.searchParams.get("category") ?? undefined;
  const assignedTo = url.searchParams.get("assignedTo") ?? undefined;
  const severity = url.searchParams.get("severity") ?? undefined;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const { seesAll, ownOnly } = complaintVisibility(auth.claims);

  try {
    const rows = await withTenantContext(config, auth.claims, (db) =>
      listComplaints(db, { organizationId: orgId, schoolId }, {
        status,
        category,
        severity,
        assignedTo,
        raisedBy: seesAll ? undefined : ownOnly,
      }));
    const now = new Date();
    return jsonResponse(envelope({ items: rows.map((r) => complaintToApi(r, now)), count: rows.length }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

// ── GET /complaints/{id} ────────────────────────────────────────────────
export async function handleGetComplaint(
  req: Request,
  config: AppConfig,
  id: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireAnyComplaintsAccess(auth.claims) ?? requireSchoolSession(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const { seesAll, ownOnly } = complaintVisibility(auth.claims);

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const scope = { organizationId: orgId, schoolId };
      const complaint = await getComplaint(db, scope, id, seesAll ? undefined : ownOnly);
      const events = await listComplaintEvents(db, scope, id);
      return { complaint, events };
    });
    const now = new Date();
    return jsonResponse(envelope({
      ...complaintToApi(result.complaint, now),
      events: result.events.map(eventToApi),
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    if (error instanceof ComplaintError) return complaintErrorResponse(error);
    throw error;
  }
}

// ── POST /complaints/{id}/assign ────────────────────────────────────────
export async function handleAssignComplaint(
  req: Request,
  config: AppConfig,
  id: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageComplaints") ?? requireSchoolSession(auth.claims);
  if (denied) return denied;

  const body = await readBody(req);
  if (isResponse(body)) return body;
  const assignedTo = optionalStr(body, "assignedTo", "assigned_to");
  if (!assignedTo) {
    return errorEnvelope("VALIDATION_ERROR", "assignedTo is required", 422);
  }
  const actorName = optionalStr(body, "actorName") ?? "";

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const assignedBy = auth.claims.sub;

  try {
    const updated = await withTenantContext(config, auth.claims, async (db) => {
      const scope = { organizationId: orgId, schoolId };
      const row = await assignComplaint(db, scope, id, { assignedTo, assignedBy });
      await recordEvent(db, scope, {
        complaintId: id,
        eventType: "assigned",
        actorId: assignedBy,
        actorName,
        metadata: { assignedTo },
      });
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit("complaints.complaint.assigned", "complaint", id, { assignedTo }),
        req,
      );
      return row;
    });
    return jsonResponse(envelope(complaintToApi(updated, new Date())));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    if (error instanceof ComplaintError) return complaintErrorResponse(error);
    throw error;
  }
}

// ── POST /complaints/{id}/status ────────────────────────────────────────
export async function handleTransitionComplaintStatus(
  req: Request,
  config: AppConfig,
  id: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  // Stricter than requireSchoolSession: only a genuine school-scope (staff)
  // session may transition a complaint — a parent can never hold
  // manageComplaints nor be an assignee, so parent-scope sessions are
  // rejected HERE rather than reaching the DB layer only to be refused by
  // the assignee-or-manage check inside the transaction.
  const denied = requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readBody(req);
  if (isResponse(body)) return body;
  const to = optionalStr(body, "status", "to");
  if (!to || !(COMPLAINT_STATUSES as readonly string[]).includes(to)) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      `status must be one of ${COMPLAINT_STATUSES.join(", ")}`,
      422,
    );
  }
  const resolutionNote = optionalStr(body, "resolutionNote", "resolution_note") ?? null;
  const actorName = optionalStr(body, "actorName") ?? "";

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const actorId = auth.claims.sub;

  try {
    const updated = await withTenantContext(config, auth.claims, async (db) => {
      const scope = { organizationId: orgId, schoolId };
      const current = await getComplaint(db, scope, id);
      const canManage = auth.claims.permissions.includes("manageComplaints");
      const isAssignee = current.assigned_to === actorId;
      if (!canManage && !isAssignee) {
        throw new ComplaintError(
          "FORBIDDEN",
          "Only manageComplaints or the current assignee may transition this complaint",
          403,
        );
      }
      const row = await transitionStatus(db, scope, id, {
        to: to as ComplaintStatus,
        expectedFrom: current.status,
        resolutionNote,
        actorId,
      });
      await recordEvent(db, scope, {
        complaintId: id,
        eventType: eventTypeForTransition(to as ComplaintStatus),
        actorId,
        actorName,
        note: resolutionNote,
        metadata: { from: current.status, to },
      });
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit("complaints.complaint.status_changed", "complaint", id, {
          from: current.status,
          to,
        }),
        req,
      );
      return row;
    });
    return jsonResponse(envelope(complaintToApi(updated, new Date())));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    if (error instanceof ComplaintError) return complaintErrorResponse(error);
    throw error;
  }
}

// ── POST /complaints/{id}/comment ───────────────────────────────────────
export async function handleAddComplaintComment(
  req: Request,
  config: AppConfig,
  id: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireAnyComplaintsAccess(auth.claims) ?? requireSchoolSession(auth.claims);
  if (denied) return denied;

  const body = await readBody(req);
  if (isResponse(body)) return body;
  const note = optionalStr(body, "note", "comment");
  if (!note) {
    return errorEnvelope("VALIDATION_ERROR", "note is required", 422);
  }
  const actorName = optionalStr(body, "actorName") ?? "";

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const { seesAll, ownOnly } = complaintVisibility(auth.claims);
  const actorId = auth.claims.sub;

  try {
    const event = await withTenantContext(config, auth.claims, async (db) => {
      const scope = { organizationId: orgId, schoolId };
      // Throws ComplaintNotFoundError when the caller cannot see this
      // complaint (a raiser-only caller may only comment on their own).
      const complaint = await getComplaint(db, scope, id, seesAll ? undefined : ownOnly);
      const created = await recordEvent(db, scope, {
        complaintId: id,
        eventType: "commented",
        actorId,
        actorName,
        note,
      });
      // First STAFF (school-scope) response marks the SLA first-response
      // clock — a parent's own comment never counts as "the school responded".
      if (auth.claims.scope === "school" && complaint.first_response_at == null) {
        await markFirstResponse(db, scope, id);
      }
      return created;
    });
    return jsonResponse(envelope(eventToApi(event)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    if (error instanceof ComplaintError) return complaintErrorResponse(error);
    throw error;
  }
}

// ── POST /complaints/{id}/vendor ────────────────────────────────────────
export async function handleAttachComplaintVendor(
  req: Request,
  config: AppConfig,
  id: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageComplaints") ?? requireSchoolSession(auth.claims);
  if (denied) return denied;

  const body = await readBody(req);
  if (isResponse(body)) return body;
  const vendorId = optionalStr(body, "vendorId", "vendor_id");
  if (!vendorId) {
    return errorEnvelope("VALIDATION_ERROR", "vendorId is required", 422);
  }
  const repairCostRaw = body.repairCost ?? body.repair_cost;
  let repairCost: number | null = null;
  if (repairCostRaw != null) {
    const n = Number(repairCostRaw);
    if (!Number.isFinite(n) || n < 0) {
      return errorEnvelope("VALIDATION_ERROR", "repairCost must be a non-negative number", 422);
    }
    repairCost = n;
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const actorId = auth.claims.sub;

  try {
    const updated = await withTenantContext(config, auth.claims, async (db) => {
      const scope = { organizationId: orgId, schoolId };
      const vendor = await findVendorInScope(db, scope, vendorId);
      if (!vendor) throw new VendorNotFoundError(vendorId);
      const row = await attachVendor(db, scope, id, { vendorId, repairCost });
      // No dedicated 'vendor_attached' event_type in the CHECK constraint —
      // folded into 'commented' with structured metadata (an honest choice
      // within the fixed enum rather than widening the constraint).
      await recordEvent(db, scope, {
        complaintId: id,
        eventType: "commented",
        actorId,
        note: `Vendor attached: ${vendor.display_name}${repairCost != null ? ` (repair cost ${repairCost})` : ""}`,
        metadata: { vendorId, vendorName: vendor.display_name, repairCost },
      });
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit("complaints.complaint.vendor_attached", "complaint", id, {
          vendorId,
          repairCost,
        }),
        req,
      );
      return row;
    });
    return jsonResponse(envelope(complaintToApi(updated, new Date())));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    if (error instanceof ComplaintError) return complaintErrorResponse(error);
    throw error;
  }
}

// ── POST /complaints/{id}/photo ─────────────────────────────────────────
// Declare -> presigned PUT URL -> client uploads -> photo_path recorded here
// (optimistic, same as the admissions-documents precedent: the row is
// updated at declare time, not after a separate confirm round-trip).
export async function handleAttachComplaintPhoto(
  req: Request,
  config: AppConfig,
  id: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireAnyComplaintsAccess(auth.claims) ?? requireSchoolSession(auth.claims);
  if (denied) return denied;

  const body = await readBody(req);
  if (isResponse(body)) return body;
  const filename = optionalStr(body, "filename", "fileName");
  if (!filename) {
    return errorEnvelope("VALIDATION_ERROR", "filename is required", 422);
  }
  const contentType = optionalStr(body, "contentType", "content_type");
  const sizeBytesRaw = body.sizeBytes ?? body.size_bytes;
  const sizeBytes = sizeBytesRaw != null ? Number(sizeBytesRaw) : undefined;
  const validationError = validateComplaintPhotoUpload(filename, { contentType, sizeBytes });
  if (validationError) {
    return errorEnvelope("VALIDATION_ERROR", validationError, 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const { seesAll, ownOnly } = complaintVisibility(auth.claims);

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const scope = { organizationId: orgId, schoolId };
      // Only the raiser (own complaint) or a manage/principal holder may attach.
      await getComplaint(db, scope, id, seesAll ? undefined : ownOnly);
      const storagePath = buildComplaintPhotoStoragePath(orgId, schoolId, id, filename);
      const upload = await createComplaintPhotoUploadUrl(config, storagePath);
      const row = await attachPhoto(db, scope, id, storagePath);
      return { upload, row };
    });
    return jsonResponse(envelope({
      ...complaintToApi(result.row, new Date()),
      upload: result.upload,
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    if (error instanceof ComplaintError) return complaintErrorResponse(error);
    throw error;
  }
}
