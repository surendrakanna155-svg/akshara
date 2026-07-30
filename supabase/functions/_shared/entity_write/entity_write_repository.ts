import type { TenantQueryClient } from "../tenant_db.ts";

/**
 * Repository for RT-07 store-and-replay request idempotency. Owns the SQL the
 * generic entity-write path previously inlined in `runWithIdempotency`
 * (handlers orchestrate, repositories own SQL).
 *
 * Every function takes the caller's `db` handle, so the claim, the replay read,
 * and the response store all run inside the SAME tenant transaction as the write
 * they guard — they commit or roll back together. These helpers open no new
 * connection and change no transaction boundary.
 */

/** A claimed `request_idempotency` row id (empty array when the key was already taken). */
export interface IdempotencyClaimRow {
  id: string;
}

/** The stored response of a prior request with the same idempotency key. */
export interface IdempotencyReplayRow {
  status_code: number | null;
  response_payload: Record<string, unknown> | null;
}

/**
 * Claim the idempotency key: `INSERT … ON CONFLICT DO NOTHING RETURNING id`.
 * Returns the inserted row(s); an empty array means the
 * `(organization_id, idempotency_key)` unique index already holds a claim (a
 * concurrent or repeated request), so the caller must replay instead of writing.
 */
export async function claimIdempotencyKey(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  idempotencyKey: string,
  method: string,
  path: string,
): Promise<IdempotencyClaimRow[]> {
  return await db.queryObject<IdempotencyClaimRow>(
    `INSERT INTO request_idempotency
       (organization_id, school_id, idempotency_key, method, path)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (organization_id, idempotency_key) DO NOTHING
     RETURNING id`,
    [organizationId, schoolId, idempotencyKey, method, path],
  );
}

/**
 * Read the stored response for a previously claimed idempotency key. Returns the
 * raw rows so the caller can branch on whether a response was stored yet.
 */
export async function getIdempotencyReplay(
  db: TenantQueryClient,
  organizationId: string,
  idempotencyKey: string,
): Promise<IdempotencyReplayRow[]> {
  return await db.queryObject<IdempotencyReplayRow>(
    `SELECT status_code, response_payload FROM request_idempotency
       WHERE organization_id = $1 AND idempotency_key = $2`,
    [organizationId, idempotencyKey],
  );
}

/** Persist the operation's response against the claimed idempotency key. */
export async function storeIdempotencyResponse(
  db: TenantQueryClient,
  organizationId: string,
  idempotencyKey: string,
  statusCode: number,
  payload: Record<string, unknown>,
): Promise<void> {
  await db.queryObject(
    `UPDATE request_idempotency
       SET status_code = $3, response_payload = $4::jsonb, completed_at = timezone('utc', now())
     WHERE organization_id = $1 AND idempotency_key = $2`,
    [organizationId, idempotencyKey, statusCode, JSON.stringify(payload)],
  );
}
