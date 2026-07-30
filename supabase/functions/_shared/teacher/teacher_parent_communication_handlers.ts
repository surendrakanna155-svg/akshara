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
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";
import { guardianUserIdsForStudents } from "../communication/guardian_recipients.ts";
import { enqueueDelivery } from "../communication/communication_repository.ts";
import { processDeliveryQueue } from "../communication/notification_service.ts";
import {
  findTeacherEntity,
  insertTeacherEntity,
  listTeacherEntities,
  replaceTeacherEntity,
} from "./teacher_parent_communication_repository.ts";

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
const WRITE_PERMISSION = "manageTeacherAssistant";
const READ_PERMISSION = "viewTeacherAssistant";

const ENTITY_PARENT_COMM = "parent_communication_log";
const ENTITY_SUBJECT_CONCERN = "subject_concern";

const { runWrite } = createModuleWriteHandlers(WRITE_PERMISSION);

function stringList(body: Record<string, unknown>, key: string): string[] {
  const value = body[key];
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => String(item ?? "").trim())
    .filter((item) => item.length > 0);
}

/**
 * PRA-P0-16: normalize the teacher-requested channel labels to the delivery
 * channels the notification queue actually supports (`push`/`sms`/`email` — the
 * `notification_deliveries.channel` CHECK). Any app/in-app/notification label
 * maps to `push`; empty selection defaults to `push` (the always-available
 * in-app channel). De-duplicated, order-stable.
 */
export function deliveryChannels(requested: string[]): string[] {
  const mapped = requested.map((c) => {
    const key = c.trim().toLowerCase();
    if (key === "sms") return "sms";
    if (key === "email") return "email";
    // "app", "push", "notification", "in_app", … → the push/in-app channel.
    return "push";
  });
  const deduped = Array.from(new Set(mapped));
  return deduped.length > 0 ? deduped : ["push"];
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

    // PRA-P0-16: this previously stamped a hardcoded status:"sent" and enqueued
    // NOTHING — the parent never received anything. Resolve the student's ACTIVE
    // guardian(s) and enqueue a REAL delivery per requested channel, then set the
    // status HONESTLY from what was actually queued.
    const title = `Message about ${reason}`;
    const targetChannels = deliveryChannels(channels);
    const guardianIds = await guardianUserIdsForStudents(
      db,
      organizationId,
      schoolId,
      [sisStudentId],
    );
    let enqueued = 0;
    for (const recipientUserId of guardianIds) {
      for (const channel of targetChannels) {
        await enqueueDelivery(db, {
          organizationId,
          schoolId,
          recipientUserId,
          channel,
          category: "announcement",
          renderedSubject: title,
          renderedBody: message,
        });
        enqueued += 1;
      }
    }
    // Drain out of the request the same way sendDirectMessage does, so the push
    // actually goes out. A guardian-less student yields an honest "no_recipients"
    // rather than a fabricated "sent".
    if (enqueued > 0) {
      await processDeliveryQueue(db, organizationId, claims, request);
    }
    const status = guardianIds.length === 0 ? "no_recipients" : "queued";

    const id = crypto.randomUUID();
    const log = {
      id,
      sisStudentId,
      reason,
      tone,
      channels,
      deliveredChannels: targetChannels,
      recipientCount: guardianIds.length,
      message,
      status,
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
        {
          sisStudentId,
          reason,
          sourceConcernId: sourceConcernId ?? null,
          status,
          recipientCount: guardianIds.length,
          channels: targetChannels,
        },
      ),
      request,
    );

    return {
      payload: { id, status, recipientCount: guardianIds.length },
      status: 201,
    };
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
