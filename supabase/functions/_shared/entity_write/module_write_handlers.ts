import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { idempotencyAlreadyClaimed } from "../idempotency_dispatch.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import type { AccessTokenClaims } from "../jwt.ts";

/** Raised by a write handler to return a specific HTTP status to the client. */
export class WriteValidationError extends Error {
  constructor(message: string, readonly status = 422, readonly code = "VALIDATION_ERROR") {
    super(message);
    this.name = "WriteValidationError";
  }
}

export class WriteNotFoundError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "WriteNotFoundError";
  }
}

export interface WriteContext {
  db: TenantQueryClient;
  organizationId: string;
  schoolId: string;
  claims: AccessTokenClaims;
  body: Record<string, unknown>;
  req: Request;
}

export interface WriteResult {
  payload: Record<string, unknown>;
  status?: number;
}

/**
 * RT-07: store-and-replay idempotency for generic entity writes.
 *
 * The first request with a given key claims a `request_idempotency` row
 * (`INSERT … ON CONFLICT DO NOTHING`), runs `operation`, and stores the inner
 * payload + status. A concurrent or repeated request with the same key is
 * serialized by the `(organization_id, idempotency_key)` unique index — it
 * finds the claim already taken and replays the stored response instead of
 * writing again. All of this runs inside the caller's single tenant
 * transaction, so the claim and the write commit or roll back together.
 */
async function runWithIdempotency(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  idempotencyKey: string,
  req: Request,
  operation: () => Promise<WriteResult>,
): Promise<WriteResult> {
  const url = new URL(req.url);
  const claimed = await db.queryObject<{ id: string }>(
    `INSERT INTO request_idempotency
       (organization_id, school_id, idempotency_key, method, path)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (organization_id, idempotency_key) DO NOTHING
     RETURNING id`,
    [organizationId, schoolId, idempotencyKey, req.method, url.pathname],
  );

  if (claimed.length === 0) {
    // Key already used — replay the stored response.
    const prior = await db.queryObject<{ status_code: number | null; response_payload: Record<string, unknown> | null }>(
      `SELECT status_code, response_payload FROM request_idempotency
       WHERE organization_id = $1 AND idempotency_key = $2`,
      [organizationId, idempotencyKey],
    );
    const row = prior[0];
    if (row && row.response_payload != null) {
      return { payload: row.response_payload, status: row.status_code ?? 201 };
    }
    // The claim exists but no response was stored — a same-key request is still
    // in flight (or its tx rolled back). Surface a clean conflict rather than
    // risk a duplicate write.
    throw new WriteValidationError(
      "A request with this Idempotency-Key is already being processed",
      409,
      "IDEMPOTENCY_CONFLICT",
    );
  }

  const result = await operation();
  await db.queryObject(
    `UPDATE request_idempotency
       SET status_code = $3, response_payload = $4::jsonb, completed_at = timezone('utc', now())
     WHERE organization_id = $1 AND idempotency_key = $2`,
    [organizationId, idempotencyKey, result.status ?? 201, JSON.stringify(result.payload)],
  );
  return result;
}

/**
 * Factory for module write handlers. Mirrors {@link createModuleReadHandlers}
 * but enforces a `manage*` permission and runs the operation inside a single
 * tenant transaction (so the entity write + its audit row commit or roll back
 * together). The per-write logic — body validation, persistence, audit — is
 * supplied as `operation`.
 */
export function createModuleWriteHandlers(managePermission: string) {
  function requireWrite(claims: AccessTokenClaims): Response | null {
    return requirePermission(claims, managePermission) ??
      requireSchoolOperationalScope(claims);
  }

  async function runWrite(
    req: Request,
    config: AppConfig,
    operation: (ctx: WriteContext) => Promise<WriteResult>,
  ): Promise<Response> {
    const auth = await authenticateRequest(req, config);
    if (!auth.ok) return auth.response;

    const denied = requireWrite(auth.claims);
    if (denied) return denied;

    const body = (await readJson<Record<string, unknown>>(req)) ?? {};
    const organizationId = organizationIdFromClaims(auth.claims);
    const schoolId = schoolIdFromClaims(auth.claims);

    // RT-07: honour the (already CORS-advertised) Idempotency-Key on generic
    // entity writes. When present, the operation + its store/replay run in the
    // same tenant transaction so a double-tapped POST writes once and replays.
    // When the universal dispatch wrapper has ALREADY claimed this request's key
    // (Data Reliability Platform §8.1), we defer to it and just run the
    // operation — claiming the same (org, key) here would 409 the first request.
    const idempotencyKey = idempotencyAlreadyClaimed(req)
      ? null
      : (req.headers.get("Idempotency-Key") ??
        req.headers.get("idempotency-key"));

    try {
      const result = await withTenantContext(config, auth.claims, async (db) => {
        if (idempotencyKey) {
          return await runWithIdempotency(
            db,
            organizationId,
            schoolId,
            idempotencyKey,
            req,
            () => operation({ db, organizationId, schoolId, claims: auth.claims, body, req }),
          );
        }
        return await operation({ db, organizationId, schoolId, claims: auth.claims, body, req });
      });
      return jsonResponse(envelope(result.payload), { status: result.status ?? 201 });
    } catch (error) {
      if (error instanceof TenantDbNotConfiguredError) {
        return tenantDbNotConfiguredResponse(error);
      }
      if (error instanceof WriteValidationError) {
        return errorEnvelope(error.code, error.message, error.status);
      }
      if (error instanceof WriteNotFoundError) {
        return errorEnvelope("NOT_FOUND", error.message, 404);
      }
      console.error(`[${managePermission}] write error:`, error);
      return errorEnvelope("INTERNAL_ERROR", "Write operation failed", 500);
    }
  }

  return { runWrite, requireWrite };
}

/**
 * RT-32 — a generous default upper bound for any single text field read from a
 * request body. The DB columns are unbounded `TEXT`, so without this a client
 * could submit a multi-megabyte string per field (DB bloat / UI overflow /
 * large-payload DoS). 20 000 chars is far above any legitimate single field
 * (names, codes, addresses, notes) while rejecting abuse.
 */
export const MAX_FIELD_LEN = 20000;

/** Body field readers tolerant of camelCase / snake_case from either client. */
export function str(
  body: Record<string, unknown>,
  ...keys: string[]
): string | undefined {
  for (const key of keys) {
    if (key in body && body[key] != null) {
      const value = String(body[key]).trim();
      if (value.length === 0) continue;
      // RT-32: reject over-long input rather than persisting it unbounded.
      if (value.length > MAX_FIELD_LEN) {
        throw new WriteValidationError(
          `${key} exceeds the maximum length of ${MAX_FIELD_LEN} characters`,
        );
      }
      return value;
    }
  }
  return undefined;
}

export function requireStr(
  body: Record<string, unknown>,
  field: string,
  ...keys: string[]
): string {
  const value = str(body, field, ...keys);
  if (value === undefined) {
    throw new WriteValidationError(`${field} is required`);
  }
  return value;
}

/**
 * RT-33 — a generous magnitude bound for any integer read from a request body.
 * Previously `intOr` accepted any finite int, so an absurd/overflowing value
 * could be persisted where no column CHECK existed. 1e12 covers every legitimate
 * count and money amount (₹1000 crore even in paise) while rejecting abuse.
 * Sign-specific bounds (e.g. marks `0 ≤ x ≤ max`) remain enforced by DB CHECKs
 * at the relevant tables (RT-08).
 */
export const MAX_INT_MAGNITUDE = 1_000_000_000_000;

export function intOr(
  body: Record<string, unknown>,
  fallback: number,
  ...keys: string[]
): number {
  for (const key of keys) {
    if (key in body && body[key] != null) {
      const num = parseInt(String(body[key]), 10);
      if (Number.isFinite(num)) {
        if (Math.abs(num) > MAX_INT_MAGNITUDE) {
          throw new WriteValidationError(
            `${key} is out of the allowed numeric range`,
          );
        }
        return num;
      }
    }
  }
  return fallback;
}

export function boolOr(
  body: Record<string, unknown>,
  fallback: boolean,
  ...keys: string[]
): boolean {
  for (const key of keys) {
    if (key in body && body[key] != null) {
      const value = body[key];
      if (typeof value === "boolean") return value;
      const text = String(value).toLowerCase();
      if (text === "true") return true;
      if (text === "false") return false;
    }
  }
  return fallback;
}
