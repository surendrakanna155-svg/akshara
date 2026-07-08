import type { TenantQueryClient } from "../tenant_db.ts";
import type {
  ApprovalAuditAction,
  ApprovalAuditRow,
  ApprovalRequestRow,
  ApprovalStatus,
} from "./approval_types.ts";

export class ApprovalNotFoundError extends Error {
  constructor(public readonly approvalId: string) {
    super(`Approval request not found: ${approvalId}`);
    this.name = "ApprovalNotFoundError";
  }
}

export class ApprovalInvalidStateError extends Error {
  constructor(
    public readonly approvalId: string,
    public readonly currentStatus: string,
    public readonly action: string,
  ) {
    super(`Cannot ${action} approval ${approvalId} (status=${currentStatus})`);
    this.name = "ApprovalInvalidStateError";
  }
}

export class ApprovalRejectCommentRequiredError extends Error {
  constructor(public readonly approvalId: string) {
    super(`Reject comment required for approval ${approvalId}`);
    this.name = "ApprovalRejectCommentRequiredError";
  }
}

export class ApprovalSelfApproveDeniedError extends Error {
  constructor(public readonly approvalId: string) {
    super(`Purchase order creator cannot approve their own request: ${approvalId}`);
    this.name = "ApprovalSelfApproveDeniedError";
  }
}

/**
 * Separation of duties: whoever VERIFIED an exam's results (coordinator) may not
 * also APPROVE/publish them. Keeps the verify and approve steps in different hands.
 */
export class ApprovalSeparationOfDutiesError extends Error {
  constructor(public readonly approvalId: string) {
    super(
      `Exam results verifier cannot also approve/publish them: ${approvalId}`,
    );
    this.name = "ApprovalSeparationOfDutiesError";
  }
}

export interface SubmitApprovalInput {
  type: string;
  title: string;
  summary: string;
  requesterId: string;
  requesterName: string;
  entityType: string;
  entityId: string;
  payload?: Record<string, unknown>;
}

export interface DecideApprovalInput {
  approvalId: string;
  status: ApprovalStatus;
  actorId: string;
  actorName: string;
  comment?: string | null;
}

export interface ApprovalListFilter {
  status?: string;
  type?: string;
  requesterId?: string;
  entityType?: string;
  entityId?: string;
}

function parsePayload(raw: unknown): Record<string, unknown> {
  if (raw && typeof raw === "object" && !Array.isArray(raw)) {
    return raw as Record<string, unknown>;
  }
  return {};
}

function parseMetadata(raw: unknown): Record<string, unknown> {
  return parsePayload(raw);
}

export async function getApprovalById(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  approvalId: string,
): Promise<ApprovalRequestRow | null> {
  const rows = await db.queryObject<ApprovalRequestRow>(
    `SELECT * FROM approval_requests
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [approvalId, organizationId, schoolId],
  );
  const row = rows[0];
  if (!row) return null;
  return { ...row, payload: parsePayload(row.payload) };
}

export async function findPendingByEntity(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  type: string,
  entityType: string,
  entityId: string,
): Promise<ApprovalRequestRow | null> {
  const rows = await db.queryObject<ApprovalRequestRow>(
    `SELECT * FROM approval_requests
     WHERE organization_id = $1 AND school_id = $2
       AND type = $3 AND entity_type = $4 AND entity_id = $5
       AND status = 'pending'
     LIMIT 1`,
    [organizationId, schoolId, type, entityType, entityId],
  );
  const row = rows[0];
  if (!row) return null;
  return { ...row, payload: parsePayload(row.payload) };
}

export async function findApprovedByEntity(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  type: string,
  entityType: string,
  entityId: string,
): Promise<ApprovalRequestRow | null> {
  const rows = await db.queryObject<ApprovalRequestRow>(
    `SELECT * FROM approval_requests
     WHERE organization_id = $1 AND school_id = $2
       AND type = $3 AND entity_type = $4 AND entity_id = $5
       AND status = 'approved'
     ORDER BY decided_at DESC NULLS LAST, updated_at DESC
     LIMIT 1`,
    [organizationId, schoolId, type, entityType, entityId],
  );
  const row = rows[0];
  if (!row) return null;
  return { ...row, payload: parsePayload(row.payload) };
}

export async function listApprovals(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  filter: ApprovalListFilter = {},
): Promise<ApprovalRequestRow[]> {
  const clauses = [
    "organization_id = $1",
    "school_id = $2",
  ];
  const args: unknown[] = [organizationId, schoolId];
  let idx = 3;

  if (filter.status) {
    clauses.push(`status = $${idx++}`);
    args.push(filter.status);
  }
  if (filter.type) {
    clauses.push(`type = $${idx++}`);
    args.push(filter.type);
  }
  if (filter.requesterId) {
    clauses.push(`requester_id = $${idx++}`);
    args.push(filter.requesterId);
  }
  if (filter.entityType) {
    clauses.push(`entity_type = $${idx++}`);
    args.push(filter.entityType);
  }
  if (filter.entityId) {
    clauses.push(`entity_id = $${idx++}`);
    args.push(filter.entityId);
  }

  const rows = await db.queryObject<ApprovalRequestRow>(
    `SELECT * FROM approval_requests
     WHERE ${clauses.join(" AND ")}
     ORDER BY created_at DESC`,
    args,
  );
  return rows.map((row) => ({ ...row, payload: parsePayload(row.payload) }));
}

export async function listPendingApprovals(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<ApprovalRequestRow[]> {
  return await listApprovals(db, organizationId, schoolId, { status: "pending" });
}

export async function insertAuditEntry(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  approvalRequestId: string,
  action: ApprovalAuditAction,
  actorId: string,
  actorName: string,
  comment: string | null = null,
  metadata: Record<string, unknown> = {},
): Promise<ApprovalAuditRow> {
  const rows = await db.queryObject<ApprovalAuditRow>(
    `INSERT INTO approval_audit_entries (
       organization_id, school_id, approval_request_id,
       action, actor_id, actor_name, comment, metadata
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8::jsonb)
     RETURNING *`,
    [
      organizationId,
      schoolId,
      approvalRequestId,
      action,
      actorId,
      actorName,
      comment,
      JSON.stringify(metadata),
    ],
  );
  const row = rows[0]!;
  return { ...row, metadata: parseMetadata(row.metadata) };
}

export async function listAuditEntries(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  approvalRequestId?: string,
): Promise<ApprovalAuditRow[]> {
  if (approvalRequestId) {
    const rows = await db.queryObject<ApprovalAuditRow>(
      `SELECT * FROM approval_audit_entries
       WHERE organization_id = $1 AND school_id = $2
         AND approval_request_id = $3
       ORDER BY occurred_at ASC`,
      [organizationId, schoolId, approvalRequestId],
    );
    return rows.map((row) => ({ ...row, metadata: parseMetadata(row.metadata) }));
  }

  const rows = await db.queryObject<ApprovalAuditRow>(
    `SELECT * FROM approval_audit_entries
     WHERE organization_id = $1 AND school_id = $2
     ORDER BY occurred_at DESC`,
    [organizationId, schoolId],
  );
  return rows.map((row) => ({ ...row, metadata: parseMetadata(row.metadata) }));
}

export async function submitApproval(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: SubmitApprovalInput,
): Promise<ApprovalRequestRow> {
  const existing = await findPendingByEntity(
    db,
    organizationId,
    schoolId,
    input.type,
    input.entityType,
    input.entityId,
  );
  if (existing) return existing;

  const rows = await db.queryObject<ApprovalRequestRow>(
    `INSERT INTO approval_requests (
       organization_id, school_id, type, status, title, summary,
       requester_id, requester_name, entity_type, entity_id, payload
     ) VALUES ($1, $2, $3, 'pending', $4, $5, $6, $7, $8, $9, $10::jsonb)
     RETURNING *`,
    [
      organizationId,
      schoolId,
      input.type,
      input.title,
      input.summary,
      input.requesterId,
      input.requesterName,
      input.entityType,
      input.entityId,
      JSON.stringify(input.payload ?? {}),
    ],
  );
  const created = rows[0]!;
  const request = { ...created, payload: parsePayload(created.payload) };

  await insertAuditEntry(
    db,
    organizationId,
    schoolId,
    request.id,
    "submitted",
    input.requesterId,
    input.requesterName,
  );

  return request;
}

function assertPending(row: ApprovalRequestRow, action: string): void {
  if (row.status !== "pending") {
    throw new ApprovalInvalidStateError(row.id, row.status, action);
  }
}

/**
 * SoD: approval types where the requester may NOT approve their own request — a
 * second person must decide. These all gate money/value:
 *  - `inventoryPo`     — a purchase-order value commitment
 *  - `feeConcession`   — FIN-D4 two-person maker-checker; WAIVES money
 *  - `refund`          — pays money OUT
 *  - `feeStructure`    — sets the fee amounts students are billed
 * Rejection by the same person is allowed (only approvals are guarded). The
 * check applies identically to the single- and batch-decide paths (both route
 * through {@link decideApproval}).
 */
const SELF_APPROVE_DENIED_TYPES = new Set<string>([
  "inventoryPo",
  "feeConcession",
  "refund",
  "feeStructure",
]);

/**
 * The SINGLE, server-owned source of the self-approve-denied rule. The Approval
 * Center reads a per-item `sodBlocked` flag derived from THIS predicate (see
 * {@link approvalRequestToApi}) so the client never re-implements — and cannot
 * drift from — the maker-checker type set. Enforcement still lives in
 * {@link decideApproval}; the flag is only the UI hint reflecting it.
 */
export function isSelfApproveDeniedType(type: string): boolean {
  return SELF_APPROVE_DENIED_TYPES.has(type);
}

export async function decideApproval(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: DecideApprovalInput,
): Promise<ApprovalRequestRow> {
  const current = await getApprovalById(db, organizationId, schoolId, input.approvalId);
  if (!current) {
    throw new ApprovalNotFoundError(input.approvalId);
  }
  assertPending(current, input.status);

  if (input.status === "rejected" && !(input.comment?.trim())) {
    throw new ApprovalRejectCommentRequiredError(input.approvalId);
  }

  // SoD self-approve denial for value/money-gating approvals — the requester
  // may not approve their OWN request (see SELF_APPROVE_DENIED_TYPES). Reject by
  // the same person stays allowed.
  if (
    input.status === "approved" &&
    SELF_APPROVE_DENIED_TYPES.has(current.type) &&
    current.requester_id === input.actorId
  ) {
    throw new ApprovalSelfApproveDeniedError(input.approvalId);
  }

  // Separation of duties for exam results: the coordinator who verified the
  // session may not also approve/publish it. entity_id is the exam_session id.
  if (input.status === "approved" && current.type === "examResults") {
    const verifierRows = await db.queryObject<{ coordinator_verified_by: string | null }>(
      `SELECT coordinator_verified_by FROM exam_sessions
       WHERE organization_id = $1 AND school_id = $2 AND id = $3`,
      [organizationId, schoolId, current.entity_id],
    );
    const verifier = verifierRows[0]?.coordinator_verified_by ?? null;
    if (verifier && verifier === input.actorId) {
      throw new ApprovalSeparationOfDutiesError(input.approvalId);
    }
  }

  const rows = await db.queryObject<ApprovalRequestRow>(
    `UPDATE approval_requests
     SET status = $1,
         decided_at = timezone('utc', now()),
         decided_by_id = $2,
         decided_by_name = $3,
         decision_comment = $4,
         updated_at = timezone('utc', now())
     WHERE id = $5 AND organization_id = $6 AND school_id = $7 AND status = 'pending'
     RETURNING *`,
    [
      input.status,
      input.actorId,
      input.actorName,
      input.comment?.trim() ?? null,
      input.approvalId,
      organizationId,
      schoolId,
    ],
  );
  const updated = rows[0];
  if (!updated) {
    throw new ApprovalInvalidStateError(input.approvalId, current.status, input.status);
  }

  const request = { ...updated, payload: parsePayload(updated.payload) };

  const auditAction: ApprovalAuditAction = input.status === "approved"
    ? "approved"
    : input.status === "rejected"
    ? "rejected"
    : "cancelled";

  await insertAuditEntry(
    db,
    organizationId,
    schoolId,
    request.id,
    auditAction,
    input.actorId,
    input.actorName,
    input.comment?.trim() ?? null,
  );

  return request;
}

export async function insertDomainEffect(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  approvalRequestId: string,
  domainType: string,
  entityType: string,
  entityId: string,
  effectAction: "approved" | "rejected",
  effectPayload: Record<string, unknown> = {},
): Promise<void> {
  await db.queryObject(
    `INSERT INTO approval_domain_effects (
       organization_id, school_id, approval_request_id,
       domain_type, entity_type, entity_id, effect_action, effect_payload
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8::jsonb)`,
    [
      organizationId,
      schoolId,
      approvalRequestId,
      domainType,
      entityType,
      entityId,
      effectAction,
      JSON.stringify(effectPayload),
    ],
  );
}
