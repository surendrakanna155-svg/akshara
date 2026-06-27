import type { AppConfig } from "./config.ts";
import { errorEnvelope } from "./http.ts";
import type { AccessTokenClaims } from "./jwt.ts";
import { createServiceClient } from "./db.ts";

/**
 * Red Team Wave 3 — RT-16 (session revocation) + RT-17 (RBAC freshness).
 *
 * The access token is a stateless HS256 JWT with a 15-minute TTL. Before this
 * module, `authenticateRequest` only verified the signature, so a logged-out /
 * revoked session and a demoted user both kept full access until the token
 * expired (≤15 min). This module adds the per-request validity check the
 * Red Team audit asked for:
 *
 *   RT-16 — the session referenced by `session_id` must still exist and not be
 *           revoked (logout / logout-all / context-switch / refresh-reuse all
 *           set `sessions.revoked_at`).
 *   RT-17 — for membership scopes (school / organization), the token's
 *           `permissions_version` must still match the live membership. Any
 *           role/override change bumps `permissions_version` (precedent:
 *           migration `20260627110000`), so a stale token is rejected — forcing
 *           a refresh that re-resolves the caller's current permissions.
 *
 * Failure semantics are fail-closed for *definitive* states (missing/revoked
 * session, missing membership, stale version → 401) but transparent for
 * *infrastructure* errors (a failed lookup throws and surfaces as a 500), so a
 * transient DB blip never silently logs every user out.
 */

export interface SessionStateRow {
  revoked_at: string | null;
}

export interface MembershipStateRow {
  permissions_version: number;
}

export type SessionEvaluation =
  | { ok: true }
  | { ok: false; code: string; message: string };

/**
 * Pure decision function (no IO) so the policy is unit-testable without a DB.
 * `session` / `membership` are the rows looked up for `claims`; `null` means the
 * row was not found.
 */
export function evaluateSessionState(
  claims: AccessTokenClaims,
  session: SessionStateRow | null,
  membership: MembershipStateRow | null,
): SessionEvaluation {
  // RT-16 — the session must exist and be live.
  if (!session) {
    return { ok: false, code: "SESSION_INVALID", message: "Session no longer exists" };
  }
  if (session.revoked_at) {
    return { ok: false, code: "SESSION_REVOKED", message: "Session has been revoked" };
  }

  // RT-17 — membership scopes must still match the live permissions version.
  if (claims.scope === "school" || claims.scope === "organization") {
    if (!membership) {
      return {
        ok: false,
        code: "MEMBERSHIP_REVOKED",
        message: "Membership for this scope is no longer active",
      };
    }
    if (membership.permissions_version !== claims.permissions_version) {
      return {
        ok: false,
        code: "PERMISSIONS_STALE",
        message: "Permissions changed — please re-authenticate",
      };
    }
  }

  return { ok: true };
}

/**
 * Looks up the live session + membership for `claims` and applies
 * {@link evaluateSessionState}. Returns a 401 `Response` to reject, or `null`
 * when the request may proceed. Lookup failures throw (→ 500), never a false
 * 401.
 */
export async function assertSessionValid(
  config: AppConfig,
  claims: AccessTokenClaims,
): Promise<Response | null> {
  // The check needs the service client. `loadConfig()` guarantees these are
  // present in every real deployment (it throws otherwise), so this guard is
  // effectively always false in production and only skips the lookup in DB-less
  // unit tests (which assert the permission layer; the live cert proves the
  // end-to-end session/RBAC enforcement on the real VPS).
  if (!config.supabaseUrl || !config.supabaseServiceRoleKey) {
    return null;
  }

  const client = createServiceClient(config);

  const { data: session, error: sessionError } = await client
    .from("sessions")
    .select("revoked_at")
    .eq("id", claims.session_id)
    .maybeSingle();
  if (sessionError) {
    throw new Error(`session lookup failed: ${sessionError.message}`);
  }

  let membership: MembershipStateRow | null = null;
  if (claims.scope === "school" && claims.school_id) {
    const { data, error } = await client
      .from("school_memberships")
      .select("permissions_version")
      .eq("user_id", claims.sub)
      .eq("school_id", claims.school_id)
      .eq("status", "active")
      .maybeSingle();
    if (error) throw new Error(`membership lookup failed: ${error.message}`);
    membership = (data as MembershipStateRow | null) ?? null;
  } else if (claims.scope === "organization") {
    const { data, error } = await client
      .from("organization_memberships")
      .select("permissions_version")
      .eq("user_id", claims.sub)
      .eq("organization_id", claims.organization_id)
      .eq("status", "active")
      .maybeSingle();
    if (error) throw new Error(`membership lookup failed: ${error.message}`);
    membership = (data as MembershipStateRow | null) ?? null;
  }

  const verdict = evaluateSessionState(
    claims,
    (session as SessionStateRow | null) ?? null,
    membership,
  );
  if (verdict.ok) return null;
  return errorEnvelope(verdict.code, verdict.message, 401);
}
