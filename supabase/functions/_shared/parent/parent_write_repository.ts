import type { TenantQueryClient } from "../tenant_db.ts";

/**
 * Repository for parent-scope writes (MJ-H12 leave, MJ-C3 communication, MJ-C4
 * PTM). Owns the SQL the parent write handlers previously inlined (handlers
 * orchestrate, repositories own SQL). Rows live in `parent_entities`, keyed by
 * `student_id` and guarded by the `parent_entities_parent_scope` RLS policy that
 * only admits a child actively linked to the requesting guardian. Every function
 * takes the caller's `db` handle so it participates in the caller's tenant
 * transaction — it opens no new connection.
 *
 * `PARENT_TABLE` mirrors `parentWriteStore.tableName` ("parent_entities"); it is
 * declared here so this module owns the table it writes to.
 */
const PARENT_TABLE = "parent_entities";

/** A `payload`-returning row shape from the parent_entities statements. */
export interface ParentEntityPayloadRow {
  payload: Record<string, unknown>;
}

/** A `student_id` + `payload` row shape (used by cross-child lookups). */
export interface ParentEntityStudentPayloadRow {
  student_id: string;
  payload: Record<string, unknown>;
}

/** Insert a parent entity row carrying the (NOT NULL) student_id. */
export async function insertParentEntityRow(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
  entityType: string,
  id: string,
  payload: Record<string, unknown>,
): Promise<ParentEntityPayloadRow[]> {
  return await db.queryObject<ParentEntityPayloadRow>(
    `INSERT INTO ${PARENT_TABLE}
       (id, organization_id, school_id, student_id, entity_type, payload)
     VALUES ($1, $2, $3, $4, $5, $6::jsonb)
     RETURNING payload`,
    [id, organizationId, schoolId, studentId, entityType, JSON.stringify(payload)],
  );
}

/** Replace a parent entity row's payload (student-scoped). */
export async function updateParentEntityRow(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
  entityType: string,
  id: string,
  payload: Record<string, unknown>,
): Promise<ParentEntityPayloadRow[]> {
  return await db.queryObject<ParentEntityPayloadRow>(
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
}

/** Read one parent entity row (student-scoped). */
export async function selectParentEntityRow(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
  entityType: string,
  id: string,
): Promise<ParentEntityPayloadRow[]> {
  return await db.queryObject<ParentEntityPayloadRow>(
    `SELECT payload
       FROM ${PARENT_TABLE}
      WHERE organization_id = $1
        AND school_id = $2
        AND student_id = $3
        AND entity_type = $4
        AND id = $5`,
    [organizationId, schoolId, studentId, entityType, id],
  );
}

/** List a single child's `communication_message` entities (ordered by id). */
export async function listCommunicationMessageEntities(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
): Promise<ParentEntityPayloadRow[]> {
  return await db.queryObject<ParentEntityPayloadRow>(
    `SELECT payload
           FROM ${PARENT_TABLE}
          WHERE organization_id = $1
            AND school_id = $2
            AND student_id = $3
            AND entity_type = 'communication_message'
          ORDER BY id`,
    [organizationId, schoolId, studentId],
  );
}

/**
 * Find one `communication_message` entity across the parent's linked children.
 * Returns the raw rows so the caller can transform `rows[0]` into its own shape.
 */
export async function findCommunicationEntityAcrossChildren(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  childIds: string[],
  communicationId: string,
): Promise<ParentEntityStudentPayloadRow[]> {
  return await db.queryObject<ParentEntityStudentPayloadRow>(
    `SELECT student_id, payload
       FROM ${PARENT_TABLE}
      WHERE organization_id = $1
        AND school_id = $2
        AND student_id = ANY($3::uuid[])
        AND entity_type = 'communication_message'
        AND id = $4`,
    [organizationId, schoolId, childIds, communicationId],
  );
}

/** List the `ptm_meeting` entities across the parent's linked children (ordered by id). */
export async function listPtmMeetingEntities(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  childIds: string[],
): Promise<ParentEntityPayloadRow[]> {
  return await db.queryObject<ParentEntityPayloadRow>(
    `SELECT payload
           FROM ${PARENT_TABLE}
          WHERE organization_id = $1
            AND school_id = $2
            AND student_id = ANY($3::uuid[])
            AND entity_type = 'ptm_meeting'
          ORDER BY id`,
    [organizationId, schoolId, childIds],
  );
}

/**
 * Find one `ptm_meeting` entity across the parent's linked children. Returns the
 * raw rows so the caller can branch on `rows[0]` and transform it.
 */
export async function findPtmMeetingAcrossChildren(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  childIds: string[],
  meetingId: string,
): Promise<ParentEntityStudentPayloadRow[]> {
  return await db.queryObject<ParentEntityStudentPayloadRow>(
    `SELECT student_id, payload
         FROM ${PARENT_TABLE}
        WHERE organization_id = $1
          AND school_id = $2
          AND student_id = ANY($3::uuid[])
          AND entity_type = 'ptm_meeting'
          AND id = $4`,
    [organizationId, schoolId, childIds, meetingId],
  );
}
