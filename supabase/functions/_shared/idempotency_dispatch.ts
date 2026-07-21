import type { AppConfig } from "./config.ts";
import { envelope, errorEnvelope, jsonResponse } from "./http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  schoolIdFromClaims,
} from "./permission_middleware.ts";
import { withTenantContext } from "./tenant_db.ts";
import type { AccessTokenClaims } from "./jwt.ts";

const MUTATING_METHODS = new Set(["POST", "PUT", "PATCH", "DELETE"]);

/**
 * Requests the universal wrapper has already claimed an idempotency row for, so
 * a route that *also* runs its own `runWithIdempotency` (the
 * `createModuleWriteHandlers` factory) defers to the wrapper instead of trying
 * to claim the same `(org, key)` again (which would 409 the first request).
 */
const _claimedRequests = new WeakSet<Request>();

export function idempotencyAlreadyClaimed(req: Request): boolean {
  return _claimedRequests.has(req);
}

export function idempotencyKeyOf(req: Request): string | null {
  return req.headers.get("Idempotency-Key") ??
    req.headers.get("idempotency-key");
}

/**
 * ICA-A4: how long an in-flight (NULL-payload) claim may sit before a retry is
 * allowed to re-claim it. The wrapper's `claim()` → `dispatch()` → `store()` run
 * in THREE separate transactions (the dispatch is an opaque module router that
 * opens its OWN transactions, so a single shared transaction — the pattern
 * `module_write_handlers.runWithIdempotency` uses — is infeasible here). A
 * process crash, or a `store()` failure, between the write COMMIT and `store()`
 * would otherwise leave a NULL-payload row that 409s every retry FOREVER. A
 * retry whose claim is older than this window re-claims the abandoned slot and
 * re-dispatches; the route's own money-safe backstop (natural-key dedup) keeps
 * that re-dispatch exactly-once. The window sits comfortably above the maximum
 * single edge-function execution so a genuinely in-flight concurrent duplicate
 * is never stolen (which would double-dispatch a non-backstopped route).
 */
export const IN_FLIGHT_CLAIM_TTL_MS = 5 * 60 * 1000; // 5 minutes

/** Result of attempting to claim `(org, key)`. */
export interface ClaimResult {
  /** True when this caller won the claim (fresh, or re-claimed a stale slot) and must run the write. */
  claimed: boolean;
  /** When the claim was already taken: the stored status (null if in-flight). */
  priorStatus: number | null;
  /** When the claim was already taken: the stored envelope (null if in-flight). */
  priorPayload: Record<string, unknown> | null;
  /**
   * ICA-D1: the stored `(method, path)` for this key differs from the incoming
   * request — the same Idempotency-Key is being reused across two different
   * endpoints. The wrapper must reject rather than replay the other endpoint's
   * response (or 409 spuriously). Never set together with `claimed`.
   */
  mismatch?: boolean;
}

/**
 * Persistence for store-and-replay idempotency. The default implementation is
 * backed by the `request_idempotency` table inside a tenant transaction; tests
 * inject an in-memory fake.
 */
export interface IdempotencyStore {
  claim(method: string, path: string): Promise<ClaimResult>;
  store(status: number, payload: unknown): Promise<void>;
  release(): Promise<void>;
}

/** Resolved tenant scope for a request (org + school + claims). */
export interface IdempotencyScope {
  organizationId: string;
  schoolId: string;
  claims: AccessTokenClaims;
}

export interface IdempotencyDeps {
  /** Resolve the tenant scope, or null to skip wrapping (pass straight through). */
  resolveScope?: (
    req: Request,
    config: AppConfig,
  ) => Promise<IdempotencyScope | null>;
  /** Build the store for a resolved scope + key. */
  makeStore?: (
    config: AppConfig,
    scope: IdempotencyScope,
    key: string,
  ) => IdempotencyStore;
}

/**
 * Universal store-and-replay idempotency around the whole module dispatch
 * (design §8.1 — "wrap the moduleRouters dispatch so every mutating route runs
 * through runWithIdempotency keyed by the Idempotency-Key + org").
 *
 * Crucially it is **inert** for any request that does not carry an
 * `Idempotency-Key`: existing traffic is byte-for-byte unchanged. When a key IS
 * present on a mutating request:
 *   1. the first call claims `(organization_id, idempotency_key)` and runs the
 *      dispatch once;
 *   2. a retry — e.g. a write queued offline and replayed on reconnect — finds
 *      the completed claim and **replays the stored 2xx envelope** instead of
 *      writing again, guaranteeing **exactly-once** (no duplicate row / receipt /
 *      charge);
 *   3. a concurrent in-flight duplicate gets a clean `409 IDEMPOTENCY_CONFLICT`
 *      (the client treats this as "already applied"); ICA-A4: this 409 is now
 *      always **transient** — a claim abandoned by a crash between the write
 *      COMMIT and `store()` is re-claimable after `IN_FLIGHT_CLAIM_TTL_MS`, so a
 *      retry re-dispatches through the route's money-safe backstop instead of
 *      being poisoned into a permanent 409;
 *   4. a non-2xx response **releases** the claim so a transient failure stays
 *      retryable (the key is never poisoned);
 *   5. ICA-D1: the same key reused on a **different** method/path is rejected
 *      with `422 IDEMPOTENCY_KEY_REUSED` rather than replaying the wrong
 *      endpoint's response.
 *
 * Reuses the existing `request_idempotency` table (migration 20260814000000).
 */
export async function dispatchWithIdempotency(
  req: Request,
  config: AppConfig,
  dispatch: () => Promise<Response>,
  deps: IdempotencyDeps = {},
): Promise<Response> {
  const key = idempotencyKeyOf(req);
  if (!key || !MUTATING_METHODS.has(req.method.toUpperCase())) {
    return dispatch();
  }

  const resolveScope = deps.resolveScope ?? _defaultResolveScope;
  const scope = await resolveScope(req, config);
  if (scope === null) {
    // Unauthenticated, or not school-scoped → let the route answer for itself.
    return dispatch();
  }

  const makeStore = deps.makeStore ?? _defaultMakeStore;
  const store = makeStore(config, scope, key);

  // 1) Claim, or replay a completed prior response.
  const claim = await store.claim(req.method, new URL(req.url).pathname);

  // ICA-D1: a key already used for a DIFFERENT endpoint must never replay the
  // other endpoint's response (nor 409 spuriously) — reject with a clear 422.
  if (claim.mismatch) {
    return errorEnvelope(
      "IDEMPOTENCY_KEY_REUSED",
      "Idempotency-Key was already used for a different request (method/path mismatch)",
      422,
    );
  }

  if (!claim.claimed) {
    if (claim.priorPayload != null) {
      return jsonResponse(claim.priorPayload, { status: claim.priorStatus ?? 201 });
    }
    // In-flight (NULL-payload) row that is NOT yet stale: a genuine concurrent
    // duplicate is still processing. Return a clean, TRANSIENT 409. ICA-A4: this
    // is no longer permanent — a claim abandoned by a crash between the write
    // COMMIT and store() becomes re-claimable in claim() after
    // IN_FLIGHT_CLAIM_TTL_MS, so a later retry re-dispatches through the route's
    // own money-safe backstop rather than being poisoned into a forever-409.
    return errorEnvelope(
      "IDEMPOTENCY_CONFLICT",
      "A request with this Idempotency-Key is already being processed",
      409,
    );
  }

  // 2) We own the claim — run the write exactly once.
  _claimedRequests.add(req);
  let response: Response;
  try {
    response = await dispatch();
  } catch (error) {
    await _safeRelease(store);
    throw error;
  } finally {
    _claimedRequests.delete(req);
  }

  if (response.status >= 200 && response.status < 300) {
    let payload: unknown;
    try {
      payload = JSON.parse(await response.clone().text());
    } catch {
      payload = envelope(null);
    }
    // ICA-A4: the write has ALREADY committed in its own transaction. A failure
    // to persist the replay payload must NEVER turn a succeeded write into a 500
    // (which would tell the client a committed payment failed). Swallow it and
    // return the real response; the resulting stale NULL-payload row self-heals
    // via the IN_FLIGHT_CLAIM_TTL_MS re-claim path on any later retry.
    try {
      await store.store(response.status, payload);
    } catch (_) {
      // Best-effort persistence — see above. The write result is authoritative.
    }
    return response;
  }

  // Non-2xx → release the claim so the client can safely retry later.
  await _safeRelease(store);
  return response;
}

async function _safeRelease(store: IdempotencyStore): Promise<void> {
  try {
    await store.release();
  } catch (_) {
    // Best-effort; a left-over claim only ever yields a clean 409 on retry.
  }
}

async function _defaultResolveScope(
  req: Request,
  config: AppConfig,
): Promise<IdempotencyScope | null> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return null;
  const organizationId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  if (!organizationId || !schoolId) return null;
  return { organizationId, schoolId, claims: auth.claims };
}

function _defaultMakeStore(
  config: AppConfig,
  scope: IdempotencyScope,
  key: string,
): IdempotencyStore {
  const { organizationId, schoolId, claims } = scope;
  return {
    async claim(method: string, path: string): Promise<ClaimResult> {
      return await withTenantContext(config, claims, async (db) => {
        const claimed = await db.queryObject<{ id: string }>(
          `INSERT INTO request_idempotency
             (organization_id, school_id, idempotency_key, method, path)
           VALUES ($1, $2, $3, $4, $5)
           ON CONFLICT (organization_id, idempotency_key) DO NOTHING
           RETURNING id`,
          [organizationId, schoolId, key, method, path],
        );
        if (claimed.length > 0) {
          return { claimed: true, priorStatus: null, priorPayload: null };
        }

        // Conflict — inspect the existing row (method/path for ICA-D1, and
        // whether an in-flight NULL-payload row is stale enough to re-claim for
        // ICA-A4). `now()` is transaction-start time, so the `stale` flag here
        // and the CAS predicate on the UPDATE below evaluate identically.
        const prior = await db.queryObject<{
          status_code: number | null;
          response_payload: Record<string, unknown> | null;
          method: string;
          path: string;
          stale: boolean;
        }>(
          `SELECT status_code, response_payload, method, path,
                  (response_payload IS NULL
                    AND created_at < timezone('utc', now())
                      - (($3::text) || ' milliseconds')::interval) AS stale
             FROM request_idempotency
            WHERE organization_id = $1 AND idempotency_key = $2`,
          [organizationId, key, String(IN_FLIGHT_CLAIM_TTL_MS)],
        );
        const row = prior[0];

        // ICA-D1: this key was first used for a DIFFERENT endpoint. Reject —
        // never replay the other endpoint's response.
        if (row && (row.method !== method || row.path !== path)) {
          return {
            claimed: false,
            priorStatus: null,
            priorPayload: null,
            mismatch: true,
          };
        }

        // Completed prior response → replay it.
        if (row && row.response_payload != null) {
          return {
            claimed: false,
            priorStatus: row.status_code ?? null,
            priorPayload: row.response_payload,
          };
        }

        // ICA-A4: an in-flight NULL-payload row older than IN_FLIGHT_CLAIM_TTL_MS
        // was abandoned (a crash, or a failed store(), between the write COMMIT
        // and store()). Atomically re-claim it. The CAS predicate (still NULL,
        // still stale) means exactly one concurrent retry wins the row lock; any
        // loser re-reads a refreshed created_at and falls through to the
        // in-flight 409. Re-claiming re-dispatches the write — the route's own
        // money-safe backstop keeps that exactly-once.
        if (row && row.stale) {
          const reclaimed = await db.queryObject<{ id: string }>(
            `UPDATE request_idempotency
                SET created_at = timezone('utc', now())
              WHERE organization_id = $1 AND idempotency_key = $2
                AND response_payload IS NULL
                AND created_at < timezone('utc', now())
                  - (($3::text) || ' milliseconds')::interval
            RETURNING id`,
            [organizationId, key, String(IN_FLIGHT_CLAIM_TTL_MS)],
          );
          if (reclaimed.length > 0) {
            return { claimed: true, priorStatus: null, priorPayload: null };
          }
        }

        // Genuinely in-flight (NULL payload, not stale) → transient conflict.
        return { claimed: false, priorStatus: null, priorPayload: null };
      });
    },
    async store(status: number, payload: unknown): Promise<void> {
      await withTenantContext(config, claims, async (db) => {
        await db.queryObject(
          `UPDATE request_idempotency
             SET status_code = $3, response_payload = $4::jsonb,
                 completed_at = timezone('utc', now())
           WHERE organization_id = $1 AND idempotency_key = $2`,
          [organizationId, key, status, JSON.stringify(payload)],
        );
      });
    },
    async release(): Promise<void> {
      await withTenantContext(config, claims, async (db) => {
        await db.queryObject(
          `DELETE FROM request_idempotency
           WHERE organization_id = $1 AND idempotency_key = $2
             AND response_payload IS NULL`,
          [organizationId, key],
        );
      });
    },
  };
}
