import type { TenantQueryClient } from "../tenant_db.ts";

/**
 * Repository for the Control Center write path. Owns the SQL the write handlers
 * previously inlined (handlers orchestrate, repositories own SQL). Control Center
 * is PLATFORM/ORG scope: records live in the org-scoped `control_center_entities`
 * table (no `school_id` column), so every statement here is keyed by
 * `organization_id` only. Each function takes the caller's `db` handle so it runs
 * inside the caller's tenant transaction — it opens no new connection.
 */
const TABLE = "control_center_entities";

/** A `payload`-returning row shape from the Control Center statements. */
export interface ControlCenterPayloadRow {
  payload: Record<string, unknown>;
}

/**
 * Insert a row into the org-scoped control_center_entities table. Returns the
 * persisted payload row(s) — the same shape the handler's inline query produced.
 */
export async function insertControlCenterEntity(
  db: TenantQueryClient,
  organizationId: string,
  entityType: string,
  id: string,
  payload: Record<string, unknown>,
): Promise<ControlCenterPayloadRow[]> {
  return await db.queryObject<ControlCenterPayloadRow>(
    `INSERT INTO ${TABLE} (id, organization_id, entity_type, payload)
     VALUES ($1, $2, $3, $4::jsonb)
     RETURNING payload`,
    [id, organizationId, entityType, JSON.stringify(payload)],
  );
}

/**
 * Read the org's `snapshot_crm` document row(s). Returns the raw rows (empty when
 * absent) so the caller can both read `rows[0]?.payload` and branch on
 * `rows.length === 0`.
 */
export async function selectCrmSnapshot(
  db: TenantQueryClient,
  organizationId: string,
): Promise<ControlCenterPayloadRow[]> {
  return await db.queryObject<ControlCenterPayloadRow>(
    `SELECT payload FROM ${TABLE}
     WHERE organization_id = $1 AND entity_type = 'snapshot_crm' AND id = 'default'`,
    [organizationId],
  );
}

/**
 * Overwrite the org's `snapshot_crm` document payload. Returns the new payload
 * row(s) — the same shape the handler's inline query produced.
 */
export async function updateCrmSnapshot(
  db: TenantQueryClient,
  organizationId: string,
  payload: Record<string, unknown>,
): Promise<ControlCenterPayloadRow[]> {
  return await db.queryObject<ControlCenterPayloadRow>(
    `UPDATE ${TABLE} SET payload = $2::jsonb
     WHERE organization_id = $1 AND entity_type = 'snapshot_crm' AND id = 'default'
     RETURNING payload`,
    [organizationId, JSON.stringify(payload)],
  );
}
