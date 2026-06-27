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

/** Result of attempting to claim `(org, key)`. */
export interface ClaimResult {
  /** True when this caller won the claim and must run the write. */
  claimed: boolean;
  /** When the claim was already taken: the stored status (null if in-flight). */
  priorStatus: number | null;
  /** When the claim was already taken: the stored envelope (null if in-flight). */
  priorPayload: Record<string, unknown> | null;
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
 *      (the client treats this as "already applied");
 *   4. a non-2xx response **releases** the claim so a transient failure stays
 *      retryable (the key is never poisoned).
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
  if (!claim.claimed) {
    if (claim.priorPayload != null) {
      return jsonResponse(claim.priorPayload, { status: claim.priorStatus ?? 201 });
    }
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
    await store.store(response.status, payload);
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
        const prior = await db.queryObject<
          { status_code: number | null; response_payload: Record<string, unknown> | null }
        >(
          `SELECT status_code, response_payload FROM request_idempotency
           WHERE organization_id = $1 AND idempotency_key = $2`,
          [organizationId, key],
        );
        const row = prior[0];
        return {
          claimed: false,
          priorStatus: row?.status_code ?? null,
          priorPayload: row?.response_payload ?? null,
        };
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
