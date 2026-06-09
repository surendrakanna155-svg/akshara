import type { AppConfig } from "./config.ts";
import { errorEnvelope } from "./http.ts";
import {
  bearerToken,
  verifyAccessToken,
  type AccessTokenClaims,
} from "./jwt.ts";

export type AuthResult =
  | { ok: true; claims: AccessTokenClaims }
  | { ok: false; response: Response };

/** Validates bearer JWT. Auth plumbing only — no tenant data access. */
export async function authenticateRequest(
  req: Request,
  config: AppConfig,
): Promise<AuthResult> {
  const token = bearerToken(req);
  if (!token) {
    return {
      ok: false,
      response: errorEnvelope("UNAUTHORIZED", "Missing bearer token", 401),
    };
  }

  const claims = await verifyAccessToken(config.jwtSecret, token);
  if (!claims) {
    return {
      ok: false,
      response: errorEnvelope("UNAUTHORIZED", "Invalid access token", 401),
    };
  }

  return { ok: true, claims };
}

/** Returns a 403 response when the permission slug is absent from the JWT. */
export function requirePermission(
  claims: AccessTokenClaims,
  permission: string,
): Response | null {
  if (!claims.permissions.includes(permission)) {
    return errorEnvelope(
      "FORBIDDEN",
      `Permission required: ${permission}`,
      403,
    );
  }
  return null;
}

/** Admissions operational tables require an active school scope with school_id. */
export function requireSchoolOperationalScope(
  claims: AccessTokenClaims,
): Response | null {
  if (claims.scope !== "school" || !claims.school_id) {
    return errorEnvelope(
      "FORBIDDEN",
      "Admissions operational data requires school scope",
      403,
    );
  }
  return null;
}

export function organizationIdFromClaims(claims: AccessTokenClaims): string {
  return claims.tenant_id;
}

export function schoolIdFromClaims(claims: AccessTokenClaims): string {
  if (!claims.school_id) {
    throw new Error("school_id missing from JWT claims");
  }
  return claims.school_id;
}
