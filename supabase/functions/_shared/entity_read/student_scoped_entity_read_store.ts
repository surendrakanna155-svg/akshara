import type { TenantQueryClient } from "../tenant_db.ts";
import {
  clampPageSize,
  keysetPageOf,
  type KeysetParams,
  type KeysetResult,
  offsetFor,
  type PaginationParams,
  type PaginationResult,
} from "../academic/academic_pagination.ts";

export interface StudentScopedEntityReadStore {
  tableName: string;
  moduleLabel: string;
  getSnapshot: (
    db: TenantQueryClient,
    organizationId: string,
    schoolId: string,
    studentId: string,
    entityType: string,
    snapshotId?: string,
  ) => Promise<Record<string, unknown>>;
  listEntities: (
    db: TenantQueryClient,
    organizationId: string,
    schoolId: string,
    studentId: string,
    entityType: string,
    pagination: PaginationParams,
  ) => Promise<PaginationResult<Record<string, unknown>>>;
  // ICA-C7: keyset (cursor) alternative to listEntities — O(pageSize) at any depth.
  listEntitiesKeyset: (
    db: TenantQueryClient,
    organizationId: string,
    schoolId: string,
    studentId: string,
    entityType: string,
    params: KeysetParams,
  ) => Promise<KeysetResult<Record<string, unknown>>>;
  getEntity: (
    db: TenantQueryClient,
    organizationId: string,
    schoolId: string,
    studentId: string,
    entityType: string,
    entityId: string,
  ) => Promise<Record<string, unknown>>;
  SnapshotNotFoundError: new (entityType: string) => Error;
  EntityNotFoundError: new (entityType: string, id: string) => Error;
  detailProbeSql: (entityType: string) => string;
}

export function createStudentScopedEntityReadStore(
  tableName: string,
  moduleLabel: string,
): StudentScopedEntityReadStore {
  class SnapshotNotFoundError extends Error {
    constructor(entityType: string) {
      super(`${moduleLabel} snapshot not found: ${entityType}`);
      this.name = `${moduleLabel}SnapshotNotFoundError`;
    }
  }

  class EntityNotFoundError extends Error {
    constructor(entityType: string, id: string) {
      super(`${moduleLabel} ${entityType} not found: ${id}`);
      this.name = `${moduleLabel}EntityNotFoundError`;
    }
  }

  async function getSnapshot(
    db: TenantQueryClient,
    organizationId: string,
    schoolId: string,
    studentId: string,
    entityType: string,
    snapshotId = "default",
  ): Promise<Record<string, unknown>> {
    const rows = await db.queryObject<{ payload: Record<string, unknown> }>(
      `SELECT payload
       FROM ${tableName}
       WHERE organization_id = $1
         AND school_id = $2
         AND student_id = $3
         AND entity_type = $4
         AND id = $5`,
      [organizationId, schoolId, studentId, entityType, snapshotId],
    );
    const row = rows[0];
    if (!row) {
      throw new SnapshotNotFoundError(entityType);
    }
    return row.payload;
  }

  async function listEntities(
    db: TenantQueryClient,
    organizationId: string,
    schoolId: string,
    studentId: string,
    entityType: string,
    pagination: PaginationParams,
  ): Promise<PaginationResult<Record<string, unknown>>> {
    const pageSize = clampPageSize(pagination.pageSize);
    const page = Math.max(1, pagination.page);
    const offset = offsetFor(page, pageSize);

    const countRows = await db.queryObject<{ total: string }>(
      `SELECT count(*)::text AS total
       FROM ${tableName}
       WHERE organization_id = $1
         AND school_id = $2
         AND student_id = $3
         AND entity_type = $4`,
      [organizationId, schoolId, studentId, entityType],
    );
    const total = parseInt(countRows[0]?.total ?? "0", 10);

    const rows = await db.queryObject<{ payload: Record<string, unknown> }>(
      `SELECT payload
       FROM ${tableName}
       WHERE organization_id = $1
         AND school_id = $2
         AND student_id = $3
         AND entity_type = $4
       ORDER BY id
       LIMIT $5 OFFSET $6`,
      [organizationId, schoolId, studentId, entityType, pageSize, offset],
    );

    return {
      items: rows.map((row) => row.payload),
      total,
      page,
      pageSize,
      hasMore: offset + rows.length < total,
    };
  }

  // ICA-C7: keyset pagination on the `id` order (no COUNT, no OFFSET scan).
  async function listEntitiesKeyset(
    db: TenantQueryClient,
    organizationId: string,
    schoolId: string,
    studentId: string,
    entityType: string,
    params: KeysetParams,
  ): Promise<KeysetResult<Record<string, unknown>>> {
    const pageSize = clampPageSize(params.pageSize);
    const cursor = params.cursor ?? null;

    const rows = await db.queryObject<{ id: string; payload: Record<string, unknown> }>(
      `SELECT id, payload
       FROM ${tableName}
       WHERE organization_id = $1
         AND school_id = $2
         AND student_id = $3
         AND entity_type = $4
         AND ($5::text IS NULL OR id > $5)
       ORDER BY id
       LIMIT $6`,
      [organizationId, schoolId, studentId, entityType, cursor, pageSize + 1],
    );

    const { rows: pageRows, nextCursor, hasMore } = keysetPageOf(rows, pageSize, (r) => r.id);
    return {
      items: pageRows.map((row) => row.payload),
      pageSize,
      nextCursor,
      hasMore,
    };
  }

  async function getEntity(
    db: TenantQueryClient,
    organizationId: string,
    schoolId: string,
    studentId: string,
    entityType: string,
    entityId: string,
  ): Promise<Record<string, unknown>> {
    const rows = await db.queryObject<{ payload: Record<string, unknown> }>(
      `SELECT payload
       FROM ${tableName}
       WHERE organization_id = $1
         AND school_id = $2
         AND student_id = $3
         AND entity_type = $4
         AND id = $5`,
      [organizationId, schoolId, studentId, entityType, entityId],
    );
    const row = rows[0];
    if (!row) {
      throw new EntityNotFoundError(entityType, entityId);
    }
    return row.payload;
  }

  function detailProbeSql(entityType: string): string {
    return `
      SELECT count(*)::text AS count
      FROM ${tableName}
      WHERE entity_type = '${entityType}'
        AND id = $1
    `;
  }

  return {
    tableName,
    moduleLabel,
    getSnapshot,
    listEntities,
    listEntitiesKeyset,
    getEntity,
    SnapshotNotFoundError,
    EntityNotFoundError,
    detailProbeSql,
  };
}
