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

    try {
      const result = await withTenantContext(config, auth.claims, (db) =>
        operation({ db, organizationId, schoolId, claims: auth.claims, body, req })
      );
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

/** Body field readers tolerant of camelCase / snake_case from either client. */
export function str(
  body: Record<string, unknown>,
  ...keys: string[]
): string | undefined {
  for (const key of keys) {
    if (key in body && body[key] != null) {
      const value = String(body[key]).trim();
      if (value.length > 0) return value;
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

export function intOr(
  body: Record<string, unknown>,
  fallback: number,
  ...keys: string[]
): number {
  for (const key of keys) {
    if (key in body && body[key] != null) {
      const num = parseInt(String(body[key]), 10);
      if (Number.isFinite(num)) return num;
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
