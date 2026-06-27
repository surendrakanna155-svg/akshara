import type { TenantQueryClient } from "../tenant_db.ts";

/**
 * Write counterpart to {@link createEntityReadStore}. Persists JSONB entity
 * rows (and snapshot documents) into a `{module}_entities` table under the
 * caller's tenant context. RLS (`FOR ALL`, school scope) is enforced by the
 * `erp_tenant` connection, so these helpers never widen tenant boundaries —
 * a row whose org/school does not match the request context is rejected by
 * the `WITH CHECK` policy.
 */
export interface EntityWriteStore {
  tableName: string;
  moduleLabel: string;
  /** Insert a new entity row; returns the persisted payload. */
  insert: (
    db: TenantQueryClient,
    organizationId: string,
    schoolId: string,
    entityType: string,
    id: string,
    payload: Record<string, unknown>,
  ) => Promise<Record<string, unknown>>;
  /** Replace an existing entity row's payload; returns the new payload or null when absent. */
  replace: (
    db: TenantQueryClient,
    organizationId: string,
    schoolId: string,
    entityType: string,
    id: string,
    payload: Record<string, unknown>,
  ) => Promise<Record<string, unknown> | null>;
  /** Read a single entity payload (null when absent). */
  find: (
    db: TenantQueryClient,
    organizationId: string,
    schoolId: string,
    entityType: string,
    id: string,
  ) => Promise<Record<string, unknown> | null>;
  /** Read all payloads of an entity type (use for small lookup sets, e.g. catalog by isbn). */
  findAll: (
    db: TenantQueryClient,
    organizationId: string,
    schoolId: string,
    entityType: string,
  ) => Promise<Array<Record<string, unknown>>>;
  /** Delete an entity row; returns true when a row was removed. */
  remove: (
    db: TenantQueryClient,
    organizationId: string,
    schoolId: string,
    entityType: string,
    id: string,
  ) => Promise<boolean>;
  /**
   * Read-modify-write a snapshot document (entity rows whose id is a fixed
   * snapshot key, default "default"). The current payload — `{}` when the row
   * does not yet exist — is passed to `mutate`; the returned object is
   * persisted in full and returned.
   */
  mutateSnapshot: (
    db: TenantQueryClient,
    organizationId: string,
    schoolId: string,
    snapshotEntityType: string,
    mutate: (current: Record<string, unknown>) => Record<string, unknown>,
    snapshotId?: string,
  ) => Promise<Record<string, unknown>>;
}

export function createEntityWriteStore(
  tableName: string,
  moduleLabel: string,
): EntityWriteStore {
  async function insert(
    db: TenantQueryClient,
    organizationId: string,
    schoolId: string,
    entityType: string,
    id: string,
    payload: Record<string, unknown>,
  ): Promise<Record<string, unknown>> {
    const rows = await db.queryObject<{ payload: Record<string, unknown> }>(
      `INSERT INTO ${tableName} (id, organization_id, school_id, entity_type, payload)
       VALUES ($1, $2, $3, $4, $5::jsonb)
       RETURNING payload`,
      [id, organizationId, schoolId, entityType, JSON.stringify(payload)],
    );
    return rows[0]?.payload ?? payload;
  }

  async function replace(
    db: TenantQueryClient,
    organizationId: string,
    schoolId: string,
    entityType: string,
    id: string,
    payload: Record<string, unknown>,
  ): Promise<Record<string, unknown> | null> {
    const rows = await db.queryObject<{ payload: Record<string, unknown> }>(
      `UPDATE ${tableName}
       SET payload = $5::jsonb
       WHERE organization_id = $2
         AND school_id = $3
         AND entity_type = $4
         AND id = $1
       RETURNING payload`,
      [id, organizationId, schoolId, entityType, JSON.stringify(payload)],
    );
    return rows[0]?.payload ?? null;
  }

  async function find(
    db: TenantQueryClient,
    organizationId: string,
    schoolId: string,
    entityType: string,
    id: string,
  ): Promise<Record<string, unknown> | null> {
    const rows = await db.queryObject<{ payload: Record<string, unknown> }>(
      `SELECT payload
       FROM ${tableName}
       WHERE organization_id = $1
         AND school_id = $2
         AND entity_type = $3
         AND id = $4`,
      [organizationId, schoolId, entityType, id],
    );
    return rows[0]?.payload ?? null;
  }

  async function findAll(
    db: TenantQueryClient,
    organizationId: string,
    schoolId: string,
    entityType: string,
  ): Promise<Array<Record<string, unknown>>> {
    const rows = await db.queryObject<{ payload: Record<string, unknown> }>(
      `SELECT payload
       FROM ${tableName}
       WHERE organization_id = $1
         AND school_id = $2
         AND entity_type = $3
       ORDER BY id`,
      [organizationId, schoolId, entityType],
    );
    return rows.map((row) => row.payload);
  }

  async function remove(
    db: TenantQueryClient,
    organizationId: string,
    schoolId: string,
    entityType: string,
    id: string,
  ): Promise<boolean> {
    const rows = await db.queryObject<{ id: string }>(
      `DELETE FROM ${tableName}
       WHERE organization_id = $1
         AND school_id = $2
         AND entity_type = $3
         AND id = $4
       RETURNING id`,
      [organizationId, schoolId, entityType, id],
    );
    return rows.length > 0;
  }

  /**
   * RT-06: lock the snapshot row (`SELECT … FOR UPDATE`) before reading it, so
   * concurrent read-modify-write mutators on the same snapshot are serialized
   * instead of last-writer-wins (which silently dropped leave requests /
   * approvals / settings). Callers run inside `withTenantContext`'s single
   * transaction, so the row lock is held until commit. Returns the locked
   * payload, or null if the row does not yet exist.
   */
  async function lockSnapshot(
    db: TenantQueryClient,
    organizationId: string,
    schoolId: string,
    entityType: string,
    id: string,
  ): Promise<Record<string, unknown> | null> {
    const rows = await db.queryObject<{ payload: Record<string, unknown> }>(
      `SELECT payload
       FROM ${tableName}
       WHERE organization_id = $1
         AND school_id = $2
         AND entity_type = $3
         AND id = $4
       FOR UPDATE`,
      [organizationId, schoolId, entityType, id],
    );
    return rows[0]?.payload ?? null;
  }

  async function mutateSnapshot(
    db: TenantQueryClient,
    organizationId: string,
    schoolId: string,
    snapshotEntityType: string,
    mutate: (current: Record<string, unknown>) => Record<string, unknown>,
    snapshotId = "default",
  ): Promise<Record<string, unknown>> {
    const existing = await lockSnapshot(
      db,
      organizationId,
      schoolId,
      snapshotEntityType,
      snapshotId,
    );
    if (existing === null) {
      // First write for this snapshot. Two concurrent first-writers both see
      // null here; the loser's INSERT raises a primary-key conflict — recover by
      // locking the now-present row and applying our mutation on top of it (no
      // lost update). The winner returns directly.
      try {
        return await insert(
          db,
          organizationId,
          schoolId,
          snapshotEntityType,
          snapshotId,
          mutate({}),
        );
      } catch (error) {
        if (!String(error).includes("duplicate key")) throw error;
        const current = await lockSnapshot(
          db,
          organizationId,
          schoolId,
          snapshotEntityType,
          snapshotId,
        );
        const replaced = await replace(
          db,
          organizationId,
          schoolId,
          snapshotEntityType,
          snapshotId,
          mutate(current ?? {}),
        );
        return replaced ?? mutate(current ?? {});
      }
    }
    const next = mutate(existing);
    const replaced = await replace(
      db,
      organizationId,
      schoolId,
      snapshotEntityType,
      snapshotId,
      next,
    );
    return replaced ?? next;
  }

  return {
    tableName,
    moduleLabel,
    insert,
    replace,
    find,
    findAll,
    remove,
    mutateSnapshot,
  };
}
