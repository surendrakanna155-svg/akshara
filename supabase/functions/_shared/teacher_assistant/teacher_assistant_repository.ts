import type { TenantQueryClient } from "../tenant_db.ts";

/**
 * ICA-F7: repository for the Teacher Assistant intervention CRUD, moved out of
 * `teacher_assistant_handlers.ts` (handlers orchestrate, repositories own SQL).
 */

/** List the open/in-progress teacher interventions (most urgent, most recent first). */
export async function listOpenInterventions(
  db: TenantQueryClient,
): Promise<Record<string, unknown>[]> {
  return await db.queryObject<Record<string, unknown>>(
    `SELECT id, student_id AS "studentId", intervention_type AS "interventionType",
            status, priority, title, notes, follow_up_at AS "followUpAt"
     FROM teacher_interventions
     WHERE status IN ('open', 'in_progress')
     ORDER BY priority DESC, created_at DESC
     LIMIT 50`,
  );
}

export interface InsertInterventionInput {
  organizationId: string;
  schoolId: string;
  teacherUserId: string;
  studentId: string;
  interventionType: string;
  title: string;
  notes: string | null;
  priority: string;
  followUpAt: string | null;
  createdBy: string;
}

/** Insert a new teacher intervention. Returns the created row's id. */
export async function insertIntervention(
  db: TenantQueryClient,
  input: InsertInterventionInput,
): Promise<string> {
  const rows = await db.queryObject<{ id: string }>(
    `INSERT INTO teacher_interventions (
       organization_id, school_id, teacher_user_id, student_id,
       intervention_type, title, notes, priority, follow_up_at, created_by
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
     RETURNING id`,
    [
      input.organizationId,
      input.schoolId,
      input.teacherUserId,
      input.studentId,
      input.interventionType,
      input.title,
      input.notes,
      input.priority,
      input.followUpAt,
      input.createdBy,
    ],
  );
  return rows[0]!.id;
}

export interface UpdateInterventionPatch {
  status: string | null;
  notes: string | null;
  followUpAt: string | null;
}

/** Patch a teacher intervention's mutable fields (coalesced against current values). */
export async function updateIntervention(
  db: TenantQueryClient,
  interventionId: string,
  patch: UpdateInterventionPatch,
): Promise<void> {
  await db.queryObject(
    `UPDATE teacher_interventions
     SET status = coalesce($2, status),
         notes = coalesce($3, notes),
         follow_up_at = coalesce($4::timestamptz, follow_up_at),
         completed_at = CASE WHEN $2 = 'completed' THEN timezone('utc', now()) ELSE completed_at END,
         updated_at = timezone('utc', now())
     WHERE id = $1`,
    [interventionId, patch.status, patch.notes, patch.followUpAt],
  );
}
