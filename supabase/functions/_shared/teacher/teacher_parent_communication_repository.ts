import type { TenantQueryClient } from "../tenant_db.ts";

/**
 * ICA-F7: repository for MJ-H13 teacher parent-communication + subject-concern
 * writes, moved out of `teacher_parent_communication_handlers.ts` (handlers
 * orchestrate, repositories own SQL).
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
 */
const TEACHER_TABLE = "teacher_entities";

/** Insert a teacher-owned JSONB entity row (binds teacher_id to satisfy RLS). */
export async function insertTeacherEntity(
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
export async function findTeacherEntity(
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
export async function replaceTeacherEntity(
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
export async function listTeacherEntities(
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
