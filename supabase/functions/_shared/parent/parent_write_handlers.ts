import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { createEntityWriteStore } from "../entity_write/entity_write_store.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";
import { str } from "../entity_write/module_write_handlers.ts";

/**
 * Parent-scope writes (MJ-H12 leave, MJ-C3 communication, MJ-C4 PTM). These rows
 * live in `parent_entities`, which is keyed by `student_id` and guarded by an RLS
 * policy that only admits a child actively linked to the requesting guardian
 * (`student_guardians`). We bind the standard parent_entities write store for
 * the shared table/RLS contract, but inserts/replaces go through the
 * student-scoped helpers below so the NOT NULL `student_id` (part of the PK) is
 * always supplied — without it the parent read handlers (which filter
 * `student_id = $3`) would never see the new rows.
 */
export const parentWriteStore = createEntityWriteStore("parent_entities", "Parent");

/** Single source of truth for the parent entities table (from the store binding). */
const PARENT_TABLE = parentWriteStore.tableName;

/** Parent scope is the parent's RBAC here — mirrors mobile_read_handlers.ts. */
function requireParentScope(claims: AccessTokenClaims): Response | null {
  if (claims.scope !== "parent" || !claims.school_id) {
    return errorEnvelope("FORBIDDEN", "Parent data requires parent scope", 403);
  }
  return null;
}

/**
 * Resolve which child the write targets. Prefers an explicit body field
 * (`child_id` / `studentId` / `sisStudentId`) or `?activeChildId=`; falls back
 * to the parent's first linked child. The id MUST be one of the parent's
 * `child_ids` claims, which RLS double-checks against `student_guardians`.
 */
function resolveChildId(
  claims: AccessTokenClaims,
  url: URL,
  body: Record<string, unknown>,
): string | Response {
  const requested = str(body, "child_id", "childId", "studentId", "sisStudentId") ??
    url.searchParams.get("activeChildId") ?? undefined;
  if (requested) {
    if (!claims.child_ids.includes(requested)) {
      return errorEnvelope(
        "FORBIDDEN",
        "Requested child is not linked to this parent account",
        403,
      );
    }
    return requested;
  }
  if (claims.child_ids.length === 0) {
    return errorEnvelope("FORBIDDEN", "No linked children on parent account", 403);
  }
  return claims.child_ids[0];
}

/** Insert a parent entity row carrying the (NOT NULL) student_id. */
async function insertParentEntity(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
  entityType: string,
  id: string,
  payload: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const rows = await db.queryObject<{ payload: Record<string, unknown> }>(
    `INSERT INTO ${PARENT_TABLE}
       (id, organization_id, school_id, student_id, entity_type, payload)
     VALUES ($1, $2, $3, $4, $5, $6::jsonb)
     RETURNING payload`,
    [id, organizationId, schoolId, studentId, entityType, JSON.stringify(payload)],
  );
  return rows[0]?.payload ?? payload;
}

/** Replace a parent entity row's payload (student-scoped). */
async function replaceParentEntity(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
  entityType: string,
  id: string,
  payload: Record<string, unknown>,
): Promise<Record<string, unknown> | null> {
  const rows = await db.queryObject<{ payload: Record<string, unknown> }>(
    `UPDATE ${PARENT_TABLE}
        SET payload = $6::jsonb
      WHERE organization_id = $2
        AND school_id = $3
        AND student_id = $4
        AND entity_type = $5
        AND id = $1
      RETURNING payload`,
    [id, organizationId, schoolId, studentId, entityType, JSON.stringify(payload)],
  );
  return rows[0]?.payload ?? null;
}

/** Read one parent entity row (student-scoped). */
async function findParentEntity(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
  entityType: string,
  id: string,
): Promise<Record<string, unknown> | null> {
  const rows = await db.queryObject<{ payload: Record<string, unknown> }>(
    `SELECT payload
       FROM ${PARENT_TABLE}
      WHERE organization_id = $1
        AND school_id = $2
        AND student_id = $3
        AND entity_type = $4
        AND id = $5`,
    [organizationId, schoolId, studentId, entityType, id],
  );
  return rows[0]?.payload ?? null;
}

interface ParentWriteContext {
  db: TenantQueryClient;
  organizationId: string;
  schoolId: string;
  studentId: string;
  claims: AccessTokenClaims;
  body: Record<string, unknown>;
  url: URL;
  req: Request;
}

/** Shared envelope: auth → parent scope → resolve child → tenant tx. */
async function runParentWrite(
  req: Request,
  config: AppConfig,
  errorLabel: string,
  operation: (ctx: ParentWriteContext) => Promise<{ payload: unknown; status?: number }>,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireParentScope(auth.claims);
  if (denied) return denied;

  const body = (await readJson<Record<string, unknown>>(req)) ?? {};
  const url = new URL(req.url);
  const childResult = resolveChildId(auth.claims, url, body);
  if (childResult instanceof Response) return childResult;

  const organizationId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await withTenantContext(config, auth.claims, (db) =>
      operation({
        db,
        organizationId,
        schoolId,
        studentId: childResult,
        claims: auth.claims,
        body,
        url,
        req,
      })
    );
    return jsonResponse(envelope(result.payload), { status: result.status ?? 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    if (error instanceof ParentWriteNotFoundError) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    console.error(`[parent write] ${errorLabel}:`, error);
    return errorEnvelope("INTERNAL_ERROR", errorLabel, 500);
  }
}

function nowIso(): string {
  return new Date().toISOString();
}

/** Thrown by a parent write to surface a 404 through {@link runParentWrite}. */
class ParentWriteNotFoundError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ParentWriteNotFoundError";
  }
}

// NOTE: POST /parent/leave is intentionally NOT handled here. It is served by
// routePilotOperations (handleParentLeaveSubmit), which persists the canonical
// `mobile_leave_requests` row the school/HR approval + intelligence side reads.
// MJ-H12's fix lives on the READ side: GET /parent/leave now overlays those real
// rows (parent_handlers.handleLeave → mobile_read_handlers.handleLeaveRequests)
// so a parent sees the leave they just submitted.

// ─── MJ-C3 — parent communication inbox ──────────────────────────────────────

/**
 * Inbox row shape mirrored to parent_mapper.toCommunicationInboxItem so the
 * existing DTO parser binds it. Real backing = `communication_message` parent
 * entities; when none exist we return an empty (but valid) list — never people.
 */
function toInboxItem(row: Record<string, unknown>): Record<string, unknown> {
  return {
    id: String(row.id ?? ""),
    sisStudentId: row.sisStudentId ?? row.studentId ?? "",
    studentName: row.studentName ?? "",
    senderName: row.senderName ?? "",
    reasonLabel: row.reasonLabel ?? "",
    originalMessage: row.originalMessage ?? "",
    translatedMessage: row.translatedMessage ?? row.originalMessage ?? "",
    targetLanguage: row.targetLanguage ?? "en",
    channels: Array.isArray(row.channels) ? row.channels : ["inApp"],
    sentAt: row.sentAt ?? row.createdAt ?? "",
    sentAtLabel: row.sentAtLabel ?? "",
    deliveryStatus: row.deliveryStatus ?? "delivered",
    isUnread: row.isUnread ?? true,
    ...(row.readAt ? { readAt: row.readAt } : {}),
    ...(row.acknowledgedAt ? { acknowledgedAt: row.acknowledgedAt } : {}),
  };
}

/** GET /parent/communication/inbox — list real communication_message entities. */
export async function handleCommunicationInbox(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireParentScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const childResult = resolveChildId(auth.claims, url, {});
  if (childResult instanceof Response) return childResult;

  const organizationId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const items = await withTenantContext(config, auth.claims, async (db) => {
      const rows = await db.queryObject<{ payload: Record<string, unknown> }>(
        `SELECT payload
           FROM ${PARENT_TABLE}
          WHERE organization_id = $1
            AND school_id = $2
            AND student_id = $3
            AND entity_type = 'communication_message'
          ORDER BY id`,
        [organizationId, schoolId, childResult],
      );
      return rows.map((row) => toInboxItem(row.payload));
    });
    // Empty-but-valid: { items: [] } so the DTO parser yields an empty inbox.
    return jsonResponse(envelope({ items }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    console.error("parent communication inbox error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load parent communication inbox", 500);
  }
}

/** GET /parent/communication/:id — single communication message. */
export async function handleCommunicationMessage(
  req: Request,
  config: AppConfig,
  communicationId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireParentScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const childResult = resolveChildId(auth.claims, url, {});
  if (childResult instanceof Response) return childResult;

  const organizationId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const found = await withTenantContext(config, auth.claims, async (db) =>
      await findParentEntity(
        db,
        organizationId,
        schoolId,
        childResult,
        "communication_message",
        communicationId,
      )
    );
    if (!found) {
      return errorEnvelope("NOT_FOUND", `Communication not found: ${communicationId}`, 404);
    }
    return jsonResponse(envelope(toInboxItem(found)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    console.error("parent communication message error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load parent communication message", 500);
  }
}

// ─── GAP-P1-8 — parent communication read/acknowledge ────────────────────────
// The client posts to /parent/communication/:id/read and /acknowledge with no
// body (see parent_communication_inbox_provider.dart), so the target child is
// not named on the request. We resolve it by searching across ALL of the
// parent's linked children (own-child scope: bounded to `claims.child_ids`,
// and doubly enforced by the parent_entities_parent_scope RLS policy, which
// only admits rows for children actively linked via student_guardians).

/** Find a communication_message entity across the parent's linked children. */
async function findOwnCommunicationEntity(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  childIds: string[],
  communicationId: string,
): Promise<{ studentId: string; payload: Record<string, unknown> } | null> {
  if (childIds.length === 0) return null;
  const rows = await db.queryObject<{ student_id: string; payload: Record<string, unknown> }>(
    `SELECT student_id, payload
       FROM ${PARENT_TABLE}
      WHERE organization_id = $1
        AND school_id = $2
        AND student_id = ANY($3::uuid[])
        AND entity_type = 'communication_message'
        AND id = $4`,
    [organizationId, schoolId, childIds, communicationId],
  );
  const row = rows[0];
  return row ? { studentId: row.student_id, payload: row.payload } : null;
}

/**
 * POST /parent/communication/:id/read — persists read state so the item
 * leaves the parent action inbox (`parentActiveChildActionsProvider` filters
 * on `isUnread`). Idempotent: re-marking an already-acknowledged message as
 * read never downgrades its `deliveryStatus` back from "acknowledged", and the
 * mutation audit only fires on the first (unread -> read) transition.
 */
export async function handleMarkCommunicationRead(
  req: Request,
  config: AppConfig,
  communicationId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireParentScope(auth.claims);
  if (denied) return denied;

  const organizationId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const found = await findOwnCommunicationEntity(
        db,
        organizationId,
        schoolId,
        auth.claims.child_ids,
        communicationId,
      );
      if (!found) return null;

      const wasUnread = found.payload.isUnread !== false;
      const alreadyAcknowledged = found.payload.deliveryStatus === "acknowledged";
      const next = {
        ...found.payload,
        isUnread: false,
        deliveryStatus: alreadyAcknowledged ? "acknowledged" : "read",
        readAt: found.payload.readAt ?? nowIso(),
      };
      const saved = await replaceParentEntity(
        db,
        organizationId,
        schoolId,
        found.studentId,
        "communication_message",
        communicationId,
        next,
      );
      if (wasUnread) {
        await emitMutationAudit(
          db,
          auth.claims,
          moduleEntityAudit("parent.communication.read", "parent_communication_message", communicationId),
          req,
        );
      }
      return toInboxItem(saved ?? next);
    });
    if (!result) {
      return errorEnvelope("NOT_FOUND", `Communication not found: ${communicationId}`, 404);
    }
    return jsonResponse(envelope(result));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    console.error("parent communication read error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to mark communication read", 500);
  }
}

/**
 * POST /parent/communication/:id/acknowledge — persists the parent's consent
 * acknowledgement (own-child scoped, same lookup as read above). Always sets
 * the terminal `deliveryStatus`/`isUnread`, and backfills `readAt` too if the
 * parent acknowledged without an intervening explicit read.
 */
export async function handleAcknowledgeCommunication(
  req: Request,
  config: AppConfig,
  communicationId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireParentScope(auth.claims);
  if (denied) return denied;

  const organizationId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const found = await findOwnCommunicationEntity(
        db,
        organizationId,
        schoolId,
        auth.claims.child_ids,
        communicationId,
      );
      if (!found) return null;

      const now = nowIso();
      const next = {
        ...found.payload,
        isUnread: false,
        deliveryStatus: "acknowledged",
        readAt: found.payload.readAt ?? now,
        acknowledgedAt: now,
      };
      const saved = await replaceParentEntity(
        db,
        organizationId,
        schoolId,
        found.studentId,
        "communication_message",
        communicationId,
        next,
      );
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit("parent.communication.acknowledge", "parent_communication_message", communicationId),
        req,
      );
      return toInboxItem(saved ?? next);
    });
    if (!result) {
      return errorEnvelope("NOT_FOUND", `Communication not found: ${communicationId}`, 404);
    }
    return jsonResponse(envelope(result));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    console.error("parent communication acknowledge error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to acknowledge communication", 500);
  }
}

// ─── MJ-C4 — parent meetings / PTM ───────────────────────────────────────────

/** Default empty arrays so the Flutter PTM mapper never NPEs on a fresh meeting. */
function toMeeting(row: Record<string, unknown>): Record<string, unknown> {
  return {
    id: String(row.id ?? ""),
    studentId: row.studentId ?? row.sisStudentId ?? "",
    studentName: row.studentName ?? "",
    parentName: row.parentName ?? "",
    teacherName: row.teacherName ?? "",
    meetingAt: row.meetingAt ?? "",
    notes: row.notes ?? "",
    ...(row.aiSummary != null ? { aiSummary: row.aiSummary } : {}),
    actionItems: Array.isArray(row.actionItems) ? row.actionItems : [],
    followUps: Array.isArray(row.followUps) ? row.followUps : [],
    ...(row.rsvp != null ? { rsvp: row.rsvp } : {}),
    ...(row.lastUpdatedAt ? { lastUpdatedAt: row.lastUpdatedAt } : {}),
  };
}

/** GET /parent/meetings — list ptm_meeting entities for the parent's children. */
export async function handleListMeetings(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireParentScope(auth.claims);
  if (denied) return denied;

  const organizationId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const childIds = auth.claims.child_ids;

  try {
    if (childIds.length === 0) {
      return jsonResponse(envelope({ items: [] }));
    }
    const items = await withTenantContext(config, auth.claims, async (db) => {
      const rows = await db.queryObject<{ payload: Record<string, unknown> }>(
        `SELECT payload
           FROM ${PARENT_TABLE}
          WHERE organization_id = $1
            AND school_id = $2
            AND student_id = ANY($3::uuid[])
            AND entity_type = 'ptm_meeting'
          ORDER BY id`,
        [organizationId, schoolId, childIds],
      );
      return rows.map((row) => toMeeting(row.payload));
    });
    return jsonResponse(envelope({ items }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    console.error("parent meetings list error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load parent meetings", 500);
  }
}

/** POST /parent/meetings/:id/rsvp — record the parent's RSVP on a meeting. */
export async function handleMeetingRsvp(
  req: Request,
  config: AppConfig,
  meetingId: string,
): Promise<Response> {
  return await runParentWrite(req, config, "Failed to record meeting RSVP", async (ctx) => {
    const { db, organizationId, schoolId, claims, body, req: request } = ctx;
    const rawResponse = str(body, "response") ?? "accept";
    const response = rawResponse === "decline" ? "decline" : "accept";
    const note = str(body, "note");

    // The meeting belongs to one of the parent's children; find it across them.
    const found = await db.queryObject<
      { student_id: string; payload: Record<string, unknown> }
    >(
      `SELECT student_id, payload
         FROM ${PARENT_TABLE}
        WHERE organization_id = $1
          AND school_id = $2
          AND student_id = ANY($3::uuid[])
          AND entity_type = 'ptm_meeting'
          AND id = $4`,
      [organizationId, schoolId, claims.child_ids, meetingId],
    );
    const row = found[0];
    if (!row) {
      throw new ParentWriteNotFoundError(`Meeting not found: ${meetingId}`);
    }

    const next = {
      ...row.payload,
      rsvp: {
        response,
        ...(note ? { note } : {}),
        respondedBy: claims.sub,
        respondedAt: nowIso(),
      },
      lastUpdatedAt: nowIso(),
    };
    const saved = await replaceParentEntity(
      db,
      organizationId,
      schoolId,
      row.student_id,
      "ptm_meeting",
      meetingId,
      next,
    );

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("parent.ptm.rsvp", "parent_ptm_meeting", meetingId, {
        response,
      }),
      request,
    );
    return { payload: toMeeting(saved ?? next), status: 200 };
  });
}
