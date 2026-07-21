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

export interface OccupancyMetrics {
  totalCapacity: number;
  allocatedSeats: number;
  unassignedStudents: number;
  utilizationPercent: number;
  source: "live";
}

/** Batch 8 slice 2: pure occupancy derivation from the raw counts — testable in
 * isolation. Utilization is allocated/capacity (0 when no fleet); unassigned is
 * the gap between the routes' declared student counts and actual seat allocations
 * (never negative). No seed literal. */
export function computeOccupancy(
  totalCapacity: number,
  allocatedSeats: number,
  routeStudents: number,
): OccupancyMetrics {
  const utilizationPercent = totalCapacity > 0
    ? Math.round((allocatedSeats / totalCapacity) * 100)
    : 0;
  const unassignedStudents = Math.max(0, routeStudents - allocatedSeats);
  return { totalCapacity, allocatedSeats, unassignedStudents, utilizationPercent, source: "live" };
}

/**
 * Batch 8 slice 2: LIVE seat-occupancy, replacing the static
 * snapshot_occupancy literal. totalCapacity = SUM of ACTIVE vehicle capacities;
 * allocatedSeats = COUNT of allocation entities; routeStudents = SUM of active
 * routes' declared studentCount. Numeric casts are regex-guarded so a malformed
 * payload can never break the aggregate.
 */
export async function getOccupancyMetrics(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<OccupancyMetrics> {
  const rows = await db.queryObject<{
    total_capacity: string;
    allocated_seats: string;
    route_students: string;
  }>(
    `SELECT
       COALESCE((SELECT SUM((payload->>'capacity')::numeric)
          FROM transport_entities
         WHERE organization_id = $1 AND school_id = $2 AND entity_type = 'vehicle'
           AND COALESCE(payload->>'status', 'active') = 'active'
           AND payload->>'capacity' ~ '^[0-9]+(\\.[0-9]+)?$'), 0)::text AS total_capacity,
       (SELECT count(*) FROM transport_entities
         WHERE organization_id = $1 AND school_id = $2 AND entity_type = 'allocation')::text AS allocated_seats,
       COALESCE((SELECT SUM((payload->>'studentCount')::numeric)
          FROM transport_entities
         WHERE organization_id = $1 AND school_id = $2 AND entity_type = 'route'
           AND COALESCE(payload->>'status', 'active') = 'active'
           AND payload->>'studentCount' ~ '^[0-9]+(\\.[0-9]+)?$'), 0)::text AS route_students`,
    [organizationId, schoolId],
  );
  return computeOccupancy(
    Number(rows[0]?.total_capacity ?? 0),
    Number(rows[0]?.allocated_seats ?? 0),
    Number(rows[0]?.route_students ?? 0),
  );
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

/**
 * All entity payloads of a given type for the tenant scope (unpaginated). Used
 * by read handlers that need the full set to cross-reference in memory
 * (e.g. demands to annotate allocations, allocations for a route roster).
 */
export async function listEntityPayloads(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  entityType: string,
): Promise<Record<string, unknown>[]> {
  const rows = await db.queryObject<{ payload: Record<string, unknown> }>(
    `SELECT payload FROM transport_entities
     WHERE organization_id = $1 AND school_id = $2 AND entity_type = $3`,
    [organizationId, schoolId, entityType],
  );
  return rows.map((r) => r.payload);
}

/**
 * The payload of a single entity by id, or null when absent (the caller decides
 * how to handle the miss).
 */
export async function getEntityPayloadById(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  entityType: string,
  id: string,
): Promise<Record<string, unknown> | null> {
  const rows = await db.queryObject<{ payload: Record<string, unknown> }>(
    `SELECT payload FROM transport_entities
     WHERE organization_id = $1 AND school_id = $2 AND entity_type = $3 AND id = $4`,
    [organizationId, schoolId, entityType, id],
  );
  return rows[0]?.payload ?? null;
}

/** A current SIS enrollment row for bulk transport allocation by class/section. */
export interface EnrollmentTargetRow {
  student_id: string;
  display_name: string | null;
  class_name: string | null;
  section_name: string | null;
}

/**
 * Current enrollments for a class (optionally a specific section) — the roster a
 * bulk transport allocation resolves when no explicit student id list is given.
 * `sectionName` null means "any section of the class".
 */
export async function listEnrollmentsForClassSection(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  className: string,
  sectionName: string | null,
): Promise<EnrollmentTargetRow[]> {
  return await db.queryObject<EnrollmentTargetRow>(
    `SELECT e.student_id, s.display_name, e.class_name, e.section_name
     FROM sis_student_enrollments e
     JOIN students s ON s.id = e.student_id
       AND s.organization_id = e.organization_id AND s.school_id = e.school_id
     WHERE e.organization_id = $1 AND e.school_id = $2 AND e.is_current = true
       AND e.class_name = $3
       AND ($4::text IS NULL OR e.section_name = $4)
     ORDER BY e.student_id`,
    [organizationId, schoolId, className, sectionName ?? null],
  );
}
