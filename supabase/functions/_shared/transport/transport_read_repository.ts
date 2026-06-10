import type { TenantQueryClient } from "../tenant_db.ts";
import {
  clampPageSize,
  offsetFor,
  type PaginationParams,
  type PaginationResult,
} from "../academic/academic_pagination.ts";

export const TRANSPORT_ROUTE_SCHOOL_A = "be000000-0000-4000-8000-000000000001";
export const TRANSPORT_ROUTE_SCHOOL_B = "be000000-0000-4000-8000-000000000002";

/** SQL fragment used by tenant isolation probes for transport entity visibility. */
export const TRANSPORT_ENTITIES_PROBE_SQL = `
  SELECT count(*)::text AS count
  FROM transport_entities
`;

/** SQL fragment used by API-layer tenant isolation probes (route list). */
export const TRANSPORT_ROUTES_API_PROBE_SQL = `
  SELECT count(*)::text AS count
  FROM transport_entities
  WHERE entity_type = 'route'
    AND organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
`;

/** SQL fragment used by API-layer tenant isolation probes (route detail by id). */
export const TRANSPORT_ROUTE_DETAIL_PROBE_SQL = `
  SELECT count(*)::text AS count
  FROM transport_entities
  WHERE entity_type = 'route'
    AND id = $1
`;

export class TransportSnapshotNotFoundError extends Error {
  constructor(entityType: string) {
    super(`Transport snapshot not found: ${entityType}`);
    this.name = "TransportSnapshotNotFoundError";
  }
}

export async function getSnapshot(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  entityType: string,
  snapshotId = "default",
): Promise<Record<string, unknown>> {
  const rows = await db.queryObject<{ payload: Record<string, unknown> }>(
    `SELECT payload
     FROM transport_entities
     WHERE organization_id = $1
       AND school_id = $2
       AND entity_type = $3
       AND id = $4`,
    [organizationId, schoolId, entityType, snapshotId],
  );
  const row = rows[0];
  if (!row) {
    throw new TransportSnapshotNotFoundError(entityType);
  }
  return row.payload;
}

export async function listEntities(
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
     FROM transport_entities
     WHERE organization_id = $1
       AND school_id = $2
       AND entity_type = $3`,
    [organizationId, schoolId, entityType],
  );
  const total = parseInt(countRows[0]?.total ?? "0", 10);

  const rows = await db.queryObject<{ payload: Record<string, unknown> }>(
    `SELECT payload
     FROM transport_entities
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
