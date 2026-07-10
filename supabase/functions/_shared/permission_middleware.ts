import type { AppConfig } from "./config.ts";
import { errorEnvelope } from "./http.ts";
import {
  bearerToken,
  verifyAccessToken,
  type AccessTokenClaims,
} from "./jwt.ts";
import { assertSessionValid } from "./session_validation.ts";

export type AuthResult =
  | { ok: true; claims: AccessTokenClaims }
  | { ok: false; response: Response };

/**
 * Validates the bearer JWT, then (RT-16/RT-17) re-checks the session and RBAC
 * freshness against live state so logout/revoke/demotion take effect on the
 * very next request instead of waiting out the 15-minute token TTL. This is the
 * single chokepoint every authenticated handler funnels through.
 */
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

  // RT-16 (session revocation) + RT-17 (permissions freshness): the stateless
  // signature alone is not enough — consult live session + membership state.
  const sessionDenied = await assertSessionValid(config, claims);
  if (sessionDenied) {
    return { ok: false, response: sessionDenied };
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

/**
 * OR-gate: returns `null` (grant) when the caller holds **any** of `permissions`,
 * else a 403 listing them. This is the correct primitive for "specific OR broader"
 * fallbacks — note that chaining `requirePermission(a) ?? requirePermission(b)`
 * does NOT express OR: `requirePermission` returns a truthy `Response` on denial,
 * so `??` short-circuits on the first miss and the chain collapses into an AND of
 * every slug (the QW4-INV-OR defect). Use this helper instead.
 */
export function requireAnyPermission(
  claims: AccessTokenClaims,
  permissions: string[],
): Response | null {
  if (permissions.some((p) => claims.permissions.includes(p))) {
    return null;
  }
  return errorEnvelope(
    "FORBIDDEN",
    `Permission required: one of ${permissions.join(", ")}`,
    403,
  );
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

/**
 * Parent Insights are consumed by the parent (scope "parent", restricted to
 * their own children by RLS) and by school staff (scope "school"). Both carry a
 * school_id; per-child authorization is enforced in the database, not here.
 */
export function requireParentInsightsScope(
  claims: AccessTokenClaims,
): Response | null {
  if (
    (claims.scope !== "parent" && claims.scope !== "school") ||
    !claims.school_id
  ) {
    return errorEnvelope(
      "FORBIDDEN",
      "Parent insights require parent or school scope",
      403,
    );
  }
  return null;
}

/**
 * The parent priority feed is the parent's OWN feed: it must come from a genuine
 * parent-scope session (children resolved from `claims.child_ids`), never a
 * school-staff session. Distinct from `requireParentInsightsScope`, which also
 * admits staff so they can view a child's insights.
 */
export function requireParentSelfScope(claims: AccessTokenClaims): Response | null {
  if (claims.scope !== "parent" || !claims.school_id) {
    return errorEnvelope("FORBIDDEN", "Parent feed requires parent scope", 403);
  }
  return null;
}

/**
 * The student priority feed is the student's OWN feed: a genuine student-scope
 * session with a resolved `student_id`. School staff never satisfy this.
 */
export function requireStudentSelfScope(claims: AccessTokenClaims): Response | null {
  if (claims.scope !== "student" || !claims.school_id || !claims.student_id) {
    return errorEnvelope("FORBIDDEN", "Student feed requires student scope", 403);
  }
  return null;
}

/**
 * Feed feedback (accept/dismiss/suppress) writes only the caller's OWN Persona
 * Memory row (user_id = app_current_user_id()). Any feed-eligible session —
 * school (principal/teacher/…), parent, or student — may record its own
 * feedback; per-user isolation is enforced by RLS, not by scope. A school_id is
 * still required (the row is keyed by org+school+user).
 */
export function requireFeedbackScope(claims: AccessTokenClaims): Response | null {
  const eligible = claims.scope === "school" || claims.scope === "parent" ||
    claims.scope === "student";
  if (!eligible || !claims.school_id) {
    return errorEnvelope("FORBIDDEN", "Feedback requires a school, parent, or student session", 403);
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
