// ASIP — Phase 2: support-side (mirror) data access. Every query runs under a
// PLATFORM_ORG session, so the mirror RLS (app_current_tenant_id() = PLATFORM_ORG)
// scopes rows automatically — support never reads a school tenant table. The
// PLATFORM_ORG constant here MUST equal app_support_platform_org() in the
// 20260920000040 migration.

import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";

export const SUPPORT_PLATFORM_ORG = "a5100000-0000-4000-8000-000000000001";

export interface PlatformIncidentRow {
  id: string;
  source_org_id: string;
  source_school_id: string;
  public_ref: string;
  title: string;
  description: string;
  category: string;
  severity: string;
  source_status: string;
  module_key: string | null;
  screen_route: string | null;
  app_version: string | null;
  platform: string | null;
  support_status: string;
  assigned_to: string | null;
  escalated_at: string | null;
  cluster_id: string | null;
  first_seen_at: string;
  mirrored_at: string;
  updated_at: string;
}

const PI_COLS = `
  id, source_org_id, source_school_id, public_ref, title, description, category,
  severity, source_status, module_key, screen_route, app_version, platform,
  support_status, assigned_to, escalated_at, cluster_id, first_seen_at,
  mirrored_at, updated_at
`;

export interface PlatformEvidenceRow {
  id: string;
  incident_id: string;
  kind: string;
  payload: Record<string, unknown>;
  collected_at: string;
}

export interface PlatformNoteRow {
  id: string;
  incident_id: string;
  author_user_id: string;
  body: string;
  created_at: string;
}

export interface ClusterRow {
  id: string;
  cluster_key: string;
  title: string;
  category: string;
  module_key: string | null;
  status: string;
  root_cause: string;
  resolution: string;
  incident_count: number;
  created_at: string;
  updated_at: string;
}

const CL_COLS = `
  id, cluster_key, title, category, module_key, status, root_cause, resolution,
  incident_count, created_at, updated_at
`;

export interface Page<T> {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
  hasMore: boolean;
}

export async function listPlatformIncidents(
  db: TenantQueryClient,
  filter: { supportStatus?: string; clusterId?: string; page: number; pageSize: number },
): Promise<Page<PlatformIncidentRow>> {
  const limit = Math.min(Math.max(filter.pageSize, 1), 100);
  const offset = (Math.max(filter.page, 1) - 1) * limit;
  const where: string[] = ["platform_org_id = $1"];
  const args: unknown[] = [SUPPORT_PLATFORM_ORG];
  if (filter.supportStatus) {
    args.push(filter.supportStatus);
    where.push(`support_status = $${args.length}`);
  }
  if (filter.clusterId) {
    args.push(filter.clusterId);
    where.push(`cluster_id = $${args.length}::uuid`);
  }
  const whereSql = where.join(" AND ");
  const total = await db.queryCount(
    `SELECT count(*)::text AS count FROM support_platform_incident WHERE ${whereSql}`,
    args,
  );
  const items = await db.queryObject<PlatformIncidentRow>(
    `SELECT ${PI_COLS} FROM support_platform_incident WHERE ${whereSql}
      ORDER BY escalated_at DESC NULLS LAST, mirrored_at DESC
      LIMIT $${args.length + 1} OFFSET $${args.length + 2}`,
    [...args, limit, offset],
  );
  return { items, total, page: Math.max(filter.page, 1), pageSize: limit, hasMore: offset + items.length < total };
}

export async function getPlatformIncident(
  db: TenantQueryClient,
  incidentId: string,
): Promise<PlatformIncidentRow | null> {
  const rows = await db.queryObject<PlatformIncidentRow>(
    `SELECT ${PI_COLS} FROM support_platform_incident
      WHERE platform_org_id = $1 AND id = $2::uuid`,
    [SUPPORT_PLATFORM_ORG, incidentId],
  );
  return rows[0] ?? null;
}

export async function listPlatformEvidence(
  db: TenantQueryClient,
  incidentId: string,
): Promise<PlatformEvidenceRow[]> {
  return await db.queryObject<PlatformEvidenceRow>(
    `SELECT id, incident_id, kind, payload, collected_at
       FROM support_platform_evidence
      WHERE platform_org_id = $1 AND incident_id = $2::uuid
      ORDER BY kind`,
    [SUPPORT_PLATFORM_ORG, incidentId],
  );
}

export async function listPlatformNotes(
  db: TenantQueryClient,
  incidentId: string,
): Promise<PlatformNoteRow[]> {
  return await db.queryObject<PlatformNoteRow>(
    `SELECT id, incident_id, author_user_id, body, created_at
       FROM support_platform_note
      WHERE platform_org_id = $1 AND incident_id = $2::uuid
      ORDER BY created_at ASC`,
    [SUPPORT_PLATFORM_ORG, incidentId],
  );
}

export async function insertPlatformNote(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  incidentId: string,
  body: string,
): Promise<PlatformNoteRow> {
  const rows = await db.queryObject<PlatformNoteRow>(
    `INSERT INTO support_platform_note (platform_org_id, incident_id, author_user_id, body)
     VALUES ($1, $2, $3, $4)
     RETURNING id, incident_id, author_user_id, body, created_at`,
    [claims.tenant_id, incidentId, claims.sub, body],
  );
  return rows[0];
}

export async function assignPlatformIncident(
  db: TenantQueryClient,
  incidentId: string,
  assignedTo: string | null,
): Promise<PlatformIncidentRow | null> {
  const rows = await db.queryObject<PlatformIncidentRow>(
    `UPDATE support_platform_incident
        SET assigned_to = $3::uuid, updated_at = timezone('utc', now())
      WHERE platform_org_id = $1 AND id = $2::uuid
      RETURNING ${PI_COLS}`,
    [SUPPORT_PLATFORM_ORG, incidentId, assignedTo],
  );
  return rows[0] ?? null;
}

export async function escalatePlatformIncident(
  db: TenantQueryClient,
  incidentId: string,
): Promise<PlatformIncidentRow | null> {
  const rows = await db.queryObject<PlatformIncidentRow>(
    `UPDATE support_platform_incident
        SET escalated_at = COALESCE(escalated_at, timezone('utc', now())),
            support_status = 'awaiting_engineering',
            updated_at = timezone('utc', now())
      WHERE platform_org_id = $1 AND id = $2::uuid
      RETURNING ${PI_COLS}`,
    [SUPPORT_PLATFORM_ORG, incidentId],
  );
  return rows[0] ?? null;
}

/** Guarded support_status transition (writes only when current = fromStatus). */
export async function setPlatformSupportStatus(
  db: TenantQueryClient,
  incidentId: string,
  fromStatus: string,
  toStatus: string,
): Promise<PlatformIncidentRow | null> {
  const rows = await db.queryObject<PlatformIncidentRow>(
    `UPDATE support_platform_incident
        SET support_status = $4, updated_at = timezone('utc', now())
      WHERE platform_org_id = $1 AND id = $2::uuid AND support_status = $3
      RETURNING ${PI_COLS}`,
    [SUPPORT_PLATFORM_ORG, incidentId, fromStatus, toStatus],
  );
  return rows[0] ?? null;
}

export async function upsertCluster(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  clusterKey: string,
  title: string,
  category: string,
  moduleKey: string | null,
): Promise<ClusterRow> {
  const rows = await db.queryObject<ClusterRow>(
    `INSERT INTO support_cluster (platform_org_id, cluster_key, title, category, module_key)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (platform_org_id, cluster_key) DO UPDATE SET
       updated_at = timezone('utc', now())
     RETURNING ${CL_COLS}`,
    [claims.tenant_id, clusterKey, title, category, moduleKey],
  );
  return rows[0];
}

/** Link an incident to a cluster and recompute the cluster's member count. */
export async function linkIncidentToCluster(
  db: TenantQueryClient,
  incidentId: string,
  clusterId: string,
): Promise<void> {
  await db.queryObject(
    `UPDATE support_platform_incident
        SET cluster_id = $3::uuid, updated_at = timezone('utc', now())
      WHERE platform_org_id = $1 AND id = $2::uuid`,
    [SUPPORT_PLATFORM_ORG, incidentId, clusterId],
  );
  await db.queryObject(
    `UPDATE support_cluster
        SET incident_count = (
              SELECT count(*) FROM support_platform_incident
               WHERE platform_org_id = $1 AND cluster_id = $2::uuid),
            updated_at = timezone('utc', now())
      WHERE platform_org_id = $1 AND id = $2::uuid`,
    [SUPPORT_PLATFORM_ORG, clusterId],
  );
}

export async function listClusters(
  db: TenantQueryClient,
  filter: { status?: string; page: number; pageSize: number },
): Promise<Page<ClusterRow>> {
  const limit = Math.min(Math.max(filter.pageSize, 1), 100);
  const offset = (Math.max(filter.page, 1) - 1) * limit;
  const where: string[] = ["platform_org_id = $1"];
  const args: unknown[] = [SUPPORT_PLATFORM_ORG];
  if (filter.status) {
    args.push(filter.status);
    where.push(`status = $${args.length}`);
  }
  const whereSql = where.join(" AND ");
  const total = await db.queryCount(
    `SELECT count(*)::text AS count FROM support_cluster WHERE ${whereSql}`,
    args,
  );
  const items = await db.queryObject<ClusterRow>(
    `SELECT ${CL_COLS} FROM support_cluster WHERE ${whereSql}
      ORDER BY incident_count DESC, updated_at DESC
      LIMIT $${args.length + 1} OFFSET $${args.length + 2}`,
    [...args, limit, offset],
  );
  return { items, total, page: Math.max(filter.page, 1), pageSize: limit, hasMore: offset + items.length < total };
}

export async function getCluster(
  db: TenantQueryClient,
  clusterId: string,
): Promise<ClusterRow | null> {
  const rows = await db.queryObject<ClusterRow>(
    `SELECT ${CL_COLS} FROM support_cluster WHERE platform_org_id = $1 AND id = $2::uuid`,
    [SUPPORT_PLATFORM_ORG, clusterId],
  );
  return rows[0] ?? null;
}

export async function listClusterIncidentIds(
  db: TenantQueryClient,
  clusterId: string,
): Promise<string[]> {
  const rows = await db.queryObject<{ id: string }>(
    `SELECT id FROM support_platform_incident
      WHERE platform_org_id = $1 AND cluster_id = $2::uuid`,
    [SUPPORT_PLATFORM_ORG, clusterId],
  );
  return rows.map((r) => r.id);
}

export async function setClusterResolution(
  db: TenantQueryClient,
  clusterId: string,
  status: string,
  rootCause: string,
  resolution: string,
): Promise<ClusterRow | null> {
  const rows = await db.queryObject<ClusterRow>(
    `UPDATE support_cluster
        SET status = $3, root_cause = $4, resolution = $5,
            updated_at = timezone('utc', now())
      WHERE platform_org_id = $1 AND id = $2::uuid
      RETURNING ${CL_COLS}`,
    [SUPPORT_PLATFORM_ORG, clusterId, status, rootCause, resolution],
  );
  return rows[0] ?? null;
}
