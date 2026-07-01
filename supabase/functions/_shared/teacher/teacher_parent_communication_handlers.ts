import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse } from "../http.ts";
import {
  createModuleWriteHandlers,
  requireStr,
  str,
  WriteNotFoundError,
} from "../entity_write/module_write_handlers.ts";
import {
  authenticateRequest,
  requirePermission,
  requireSchoolOperationalScope,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";

/**
 * MJ-H13 — teacher parent-communication + subject-concern writes.
 *
 * These persist to the existing `teacher_entities` read-model table. NOTE:
 * `teacher_entities` is keyed and RLS-scoped per teacher
 * (`teacher_id = app_current_user_id()`, NOT NULL — see migration
 * 20260702000000_teacher_entities_teacher_scope.sql). The generic
 * `createEntityWriteStore` INSERT omits `teacher_id`, so it cannot satisfy the
 * NOT NULL column or the WITH CHECK policy. We therefore use teacher-scoped SQL
 * here that always binds `teacher_id = claims.sub`; reads rely on the same RLS
 * predicate (the read store also filters only by org/school/entity_type and
 * leans on RLS for the per-teacher cut).
 *
 * Permission: `manageTeacherAssistant` — the teacher-held write permission used
 * by the Teacher Assistant module to persist teacher-authored interventions
 * (the closest existing analog to subject concerns and parent-communication
 * logs). A plain teacher holds it (migration 20260623400000_evolution_permissions
 * / 20260627110000 recovery), so this never 403s a legitimate teacher, and it is
 * a write-grade grant rather than a read one (`viewTeacherAssistant`).
 */
const TEACHER_TABLE = "teacher_entities";
const WRITE_PERMISSION = "manageTeacherAssistant";
const READ_PERMISSION = "viewTeacherAssistant";

const ENTITY_PARENT_COMM = "parent_communication_log";
const ENTITY_SUBJECT_CONCERN = "subject_concern";

const { runWrite } = createModuleWriteHandlers(WRITE_PERMISSION);

/** Insert a teacher-owned JSONB entity row (binds teacher_id to satisfy RLS). */
async function insertTeacherEntity(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  teacherId: string,
  entityType: string,
  id: string,
  payload: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const rows = await db.queryObject<{ payload: Record<string, unknown> }>(
    `INSERT INTO ${TEACHER_TABLE}
       (id, organization_id, school_id, teacher_id, entity_type, payload)
     VALUES ($1, $2, $3, $4, $5, $6::jsonb)
     RETURNING payload`,
    [id, organizationId, schoolId, teacherId, entityType, JSON.stringify(payload)],
  );
  return rows[0]?.payload ?? payload;
}

/** Read a single teacher-owned entity payload (null when absent / not owned). */
async function findTeacherEntity(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  teacherId: string,
  entityType: string,
  id: string,
): Promise<Record<string, unknown> | null> {
  const rows = await db.queryObject<{ payload: Record<string, unknown> }>(
    `SELECT payload
       FROM ${TEACHER_TABLE}
      WHERE organization_id = $1
        AND school_id = $2
        AND teacher_id = $3
        AND entity_type = $4
        AND id = $5`,
    [organizationId, schoolId, teacherId, entityType, id],
  );
  return rows[0]?.payload ?? null;
}

/** Replace a teacher-owned entity payload (null when no row was updated). */
async function replaceTeacherEntity(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  teacherId: string,
  entityType: string,
  id: string,
  payload: Record<string, unknown>,
): Promise<Record<string, unknown> | null> {
  const rows = await db.queryObject<{ payload: Record<string, unknown> }>(
    `UPDATE ${TEACHER_TABLE}
        SET payload = $6::jsonb
      WHERE organization_id = $1
        AND school_id = $2
        AND teacher_id = $3
        AND entity_type = $4
        AND id = $5
      RETURNING payload`,
    [organizationId, schoolId, teacherId, entityType, id, JSON.stringify(payload)],
  );
  return rows[0]?.payload ?? null;
}

/** List all teacher-owned entity payloads of a type. */
async function listTeacherEntities(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  teacherId: string,
  entityType: string,
): Promise<Array<Record<string, unknown>>> {
  const rows = await db.queryObject<{ payload: Record<string, unknown> }>(
    `SELECT payload
       FROM ${TEACHER_TABLE}
      WHERE organization_id = $1
        AND school_id = $2
        AND teacher_id = $3
        AND entity_type = $4
      ORDER BY id`,
    [organizationId, schoolId, teacherId, entityType],
  );
  return rows.map((row) => row.payload);
}

function stringList(body: Record<string, unknown>, key: string): string[] {
  const value = body[key];
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => String(item ?? "").trim())
    .filter((item) => item.length > 0);
}

/**
 * POST /teacher/parent-communication — log a parent-communication message. When
 * a `sourceConcernId` is supplied, the originating subject concern is marked
 * resolved in the same transaction. Returns `{ id, status }`.
 */
export async function handleSendParentCommunication(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const teacherId = claims.sub;

    const sisStudentId = requireStr(body, "sisStudentId", "sis_student_id");
    const reason = requireStr(body, "reason");
    const tone = requireStr(body, "tone");
    const channels = stringList(body, "channels");
    const customMessage = str(body, "customMessage", "custom_message");
    const message = customMessage ?? `Communication regarding ${reason}.`;
    const sourceConcernId = str(body, "sourceConcernId", "source_concern_id");

    const id = crypto.randomUUID();
    const log = {
      id,
      sisStudentId,
      reason,
      tone,
      channels,
      message,
      status: "sent",
      createdBy: teacherId,
      createdAt: new Date().toISOString(),
    };
    await insertTeacherEntity(
      db,
      organizationId,
      schoolId,
      teacherId,
      ENTITY_PARENT_COMM,
      id,
      log,
    );

    // Resolve the originating concern (if any) so it leaves the pending queue.
    if (sourceConcernId) {
      const concern = await findTeacherEntity(
        db,
        organizationId,
        schoolId,
        teacherId,
        ENTITY_SUBJECT_CONCERN,
        sourceConcernId,
      );
      if (concern) {
        await replaceTeacherEntity(
          db,
          organizationId,
          schoolId,
          teacherId,
          ENTITY_SUBJECT_CONCERN,
          sourceConcernId,
          { ...concern, status: "resolved", resolvedCommunicationId: id },
        );
      }
    }

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit(
        "teacher.parent_communication.sent",
        "teacher_parent_communication",
        id,
        { sisStudentId, reason, sourceConcernId: sourceConcernId ?? null },
      ),
      request,
    );

    return { payload: { id, status: "sent" }, status: 201 };
  });
}

/**
 * POST /teacher/parent-communication/concerns — flag a subject concern. Returns
 * the persisted concern entity.
 */
export async function handleFlagSubjectConcern(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const teacherId = claims.sub;

    const sisStudentId = requireStr(body, "sisStudentId", "sis_student_id");
    const category = requireStr(body, "category");
    const observation = requireStr(body, "observation");
    const subject = requireStr(body, "subject");

    const id = crypto.randomUUID();
    const concern = {
      id,
      sisStudentId,
      category,
      observation,
      subject,
      status: "pending",
      createdBy: teacherId,
      createdAt: new Date().toISOString(),
    };
    const saved = await insertTeacherEntity(
      db,
      organizationId,
      schoolId,
      teacherId,
      ENTITY_SUBJECT_CONCERN,
      id,
      concern,
    );

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit(
        "teacher.subject_concern.flagged",
        "teacher_subject_concern",
        id,
        { sisStudentId, category, subject },
      ),
      request,
    );

    return { payload: saved, status: 201 };
  });
}

/**
 * POST /teacher/parent-communication/concerns/{id}/dismiss — dismiss a pending
 * concern with an optional note. Returns the updated concern.
 */
export async function handleDismissSubjectConcern(
  req: Request,
  config: AppConfig,
  concernId: string,
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const teacherId = claims.sub;
    const note = str(body, "note");

    const concern = await findTeacherEntity(
      db,
      organizationId,
      schoolId,
      teacherId,
      ENTITY_SUBJECT_CONCERN,
      concernId,
    );
    if (!concern) {
      throw new WriteNotFoundError(`Subject concern not found: ${concernId}`);
    }

    const updated = {
      ...concern,
      status: "dismissed",
      dismissNote: note ?? null,
    };
    const saved = await replaceTeacherEntity(
      db,
      organizationId,
      schoolId,
      teacherId,
      ENTITY_SUBJECT_CONCERN,
      concernId,
      updated,
    );

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit(
        "teacher.subject_concern.dismissed",
        "teacher_subject_concern",
        concernId,
        { hasNote: note != null },
      ),
      request,
    );

    return { payload: saved ?? updated, status: 200 };
  });
}

/**
 * GET /teacher/parent-communication/concerns?classLabel= — list this teacher's
 * pending subject concerns. When `classLabel` is supplied it filters to concerns
 * carrying a matching `classLabel` (concerns without one are not class-tagged and
 * are always returned). Returns `{ items: [...] }`.
 */
export async function handleListPendingConcerns(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, READ_PERMISSION) ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const classLabel = url.searchParams.get("classLabel")?.trim() ?? "";

  try {
    const items = await withTenantContext(config, auth.claims, async (db) => {
      const rows = await listTeacherEntities(
        db,
        auth.claims.tenant_id,
        auth.claims.school_id!,
        auth.claims.sub,
        ENTITY_SUBJECT_CONCERN,
      );
      return rows.filter((row) => {
        if (String(row.status ?? "") !== "pending") return false;
        if (!classLabel) return true;
        const rowClass = String(row.classLabel ?? "").trim();
        // Untagged concerns are not class-specific → always visible.
        return rowClass.length === 0 || rowClass === classLabel;
      });
    });
    return jsonResponse(envelope({ items }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to load subject concerns", 500);
  }
}

/**
 * GET /teacher/parent-communication?sisStudentId= — list THIS teacher's logged
 * parent communications for a student (newest first). Backs the student
 * communication timeline, which previously read an in-memory store that is never
 * populated in API mode (so the timeline rendered empty in production).
 * Returns `{ items: [...] }`.
 */
export async function handleListParentCommunications(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, READ_PERMISSION) ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const sisStudentId = (url.searchParams.get("sisStudentId") ??
    url.searchParams.get("sis_student_id") ?? "").trim();

  try {
    const items = await withTenantContext(config, auth.claims, async (db) => {
      const rows = await listTeacherEntities(
        db,
        auth.claims.tenant_id,
        auth.claims.school_id!,
        auth.claims.sub,
        ENTITY_PARENT_COMM,
      );
      const filtered = sisStudentId
        ? rows.filter((row) => String(row.sisStudentId ?? "") === sisStudentId)
        : rows;
      // Newest first (createdAt is an ISO timestamp).
      return filtered.sort((a, b) =>
        String(b.createdAt ?? "").localeCompare(String(a.createdAt ?? "")));
    });
    return jsonResponse(envelope({ items }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to load parent communications", 500);
  }
}
