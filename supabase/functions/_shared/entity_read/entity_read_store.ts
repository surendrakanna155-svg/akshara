import type { TenantQueryClient } from "../tenant_db.ts";
import {
  clampPageSize,
  offsetFor,
  type PaginationParams,
  type PaginationResult,
} from "../academic/academic_pagination.ts";

export interface EntityReadStore {
  tableName: string;
  moduleLabel: string;
  getSnapshot: (
    db: TenantQueryClient,
    organizationId: string,
    schoolId: string,
    entityType: string,
    snapshotId?: string,
  ) => Promise<Record<string, unknown>>;
  listEntities: (
    db: TenantQueryClient,
    organizationId: string,
    schoolId: string,
    entityType: string,
    pagination: PaginationParams,
  ) => Promise<PaginationResult<Record<string, unknown>>>;
  getEntity: (
    db: TenantQueryClient,
    organizationId: string,
    schoolId: string,
    entityType: string,
    entityId: string,
  ) => Promise<Record<string, unknown>>;
  SnapshotNotFoundError: new (entityType: string) => Error;
  EntityNotFoundError: new (entityType: string, id: string) => Error;
  entitiesProbeSql: string;
  listApiProbeSql: (entityType: string) => string;
  detailProbeSql: (entityType: string) => string;
}

export function createEntityReadStore(
  tableName: string,
  moduleLabel: string,
): EntityReadStore {
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
    entityType: string,
    snapshotId = "default",
  ): Promise<Record<string, unknown>> {
    const rows = await db.queryObject<{ payload: Record<string, unknown> }>(
      `SELECT payload
       FROM ${tableName}
       WHERE organization_id = $1
         AND school_id = $2
         AND entity_type = $3
         AND id = $4`,
      [organizationId, schoolId, entityType, snapshotId],
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
         AND entity_type = $3`,
      [organizationId, schoolId, entityType],
    );
    const total = parseInt(countRows[0]?.total ?? "0", 10);

    const rows = await db.queryObject<{ payload: Record<string, unknown> }>(
      `SELECT payload
       FROM ${tableName}
       WHERE organization_id = $1
         AND school_id = $2
         AND entity_type = $3
       ORDER BY id
       LIMIT $4 OFFSET $5`,
      [organizationId, schoolId, entityType, pageSize, offset],
    );

    return {
      items: rows.map((row) => row.payload),
      total,
      page,
      pageSize,
      hasMore: offset + rows.length < total,
    };
  }

  async function getEntity(
    db: TenantQueryClient,
    organizationId: string,
    schoolId: string,
    entityType: string,
    entityId: string,
  ): Promise<Record<string, unknown>> {
    const rows = await db.queryObject<{ payload: Record<string, unknown> }>(
      `SELECT payload
       FROM ${tableName}
       WHERE organization_id = $1
         AND school_id = $2
         AND entity_type = $3
         AND id = $4`,
      [organizationId, schoolId, entityType, entityId],
    );
    const row = rows[0];
    if (!row) {
      throw new EntityNotFoundError(entityType, entityId);
    }
    return row.payload;
  }

  const entitiesProbeSql = `
    SELECT count(*)::text AS count
    FROM ${tableName}
  `;

  function listApiProbeSql(entityType: string): string {
    return `
      SELECT count(*)::text AS count
      FROM ${tableName}
      WHERE entity_type = '${entityType}'
        AND organization_id = app_current_tenant_id()
        AND school_id = app_current_school_id()
    `;
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
    getEntity,
    SnapshotNotFoundError,
    EntityNotFoundError,
    entitiesProbeSql,
    listApiProbeSql,
    detailProbeSql,
  };
}
