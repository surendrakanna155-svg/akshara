import type { TenantQueryClient } from "./tenant_db.ts";

// ICA-F7: thin transaction-savepoint helpers so handlers/services never issue
// raw SAVEPOINT SQL themselves. These are the DB-access layer's transaction
// primitives — used to guard a best-effort or racy write inside a larger
// tenant transaction so it can be rolled back WITHOUT poisoning the outer
// transaction. Behaviour is identical to the inline statements they replace.
//
// The savepoint NAME must be a trusted, code-level constant (a PostgreSQL
// identifier cannot be a bind parameter). Never pass user input here.

/** Open a named SAVEPOINT within the current tenant transaction. */
export async function savepoint(db: TenantQueryClient, name: string): Promise<void> {
  await db.queryObject(`SAVEPOINT ${name}`);
}

/** Release (commit) a previously-opened named SAVEPOINT. */
export async function releaseSavepoint(db: TenantQueryClient, name: string): Promise<void> {
  await db.queryObject(`RELEASE SAVEPOINT ${name}`);
}

/** Roll back to a named SAVEPOINT, undoing work since it was opened while
 * keeping the surrounding tenant transaction alive. */
export async function rollbackToSavepoint(db: TenantQueryClient, name: string): Promise<void> {
  await db.queryObject(`ROLLBACK TO SAVEPOINT ${name}`);
}
