// PRA-P0-01 (S2) — Identity revocation primitive (Workstream ILR).
//
// `session_validation.ts` has, since RT-16/RT-17, rejected any request whose
// school membership is no longer `status='active'` (see
// session_validation.ts:112-119). But NOTHING in the codebase ever wrote a
// membership to a non-active status — the sole writer hardcodes `'active'` — so
// the gate was dormant: an offboarded staff member kept full access until their
// 15-minute token expired, and a refresh silently re-minted it.
//
// This module is the missing writer. `revokeUserAccess` performs the three-part
// revocation atomically-in-intent:
//   1. flip the school membership to `status='revoked'` (activates the gate);
//   2. mark the user's live sessions for that school revoked;
//   3. revoke the refresh tokens tied to those sessions (no silent re-mint).
//
// It runs through the service-role client (the identity plane — same client the
// auth session-sweep handlers use), so it does not depend on any erp_tenant
// grant. Every write is explicitly scoped to (user, school), so it can never
// touch another tenant's rows.
//
// Blast-radius note (per PRA §11 / Fix Strategy line 110): this is the first
// code to ever write a non-'active' membership status, i.e. it activates the
// session_validation membership check in production. That is safe because the
// only prior writer hardcodes 'active' (all existing rows pass the gate). A
// one-time audit for legacy NULL/non-'active' rows before the live cut-over is
// tracked in the S2 execution log (requires the VPS DB; deferred to the live
// lane).

import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

export interface RevokeUserAccessInput {
  /** Tenant the revocation is happening within (audit / scoping context). */
  organizationId: string;
  /** School whose membership + sessions are revoked. Required — revocation is
   *  always school-scoped so a multi-school staff member keeps access elsewhere. */
  schoolId: string;
  /** The user losing access (the linked login identity of the departing staff). */
  userId: string;
  /** Free-text reason recorded by the caller in its own audit event. */
  reason?: string;
}

export interface RevokeUserAccessResult {
  membershipsRevoked: number;
  sessionsRevoked: number;
  refreshTokensRevoked: number;
}

/**
 * Revoke a user's access to a single school: flip the membership to 'revoked',
 * kill live sessions scoped to that school, and revoke their refresh tokens.
 * Idempotent — a second call reports zero because the guards (`is revoked_at
 * null` / `neq status 'revoked'`) match nothing the second time.
 */
export async function revokeUserAccess(
  client: SupabaseClient,
  input: RevokeUserAccessInput,
): Promise<RevokeUserAccessResult> {
  const { schoolId, userId } = input;
  const now = new Date().toISOString();

  // 1) Kill live sessions for this user in this school. `context_school_id`
  //    scopes it so a session the user holds at another school is untouched.
  const { data: revokedSessions, error: sessionErr } = await client
    .from("sessions")
    .update({ revoked_at: now })
    .eq("user_id", userId)
    .eq("context_school_id", schoolId)
    .is("revoked_at", null)
    .select("id");
  if (sessionErr) throw new Error(`session revoke failed: ${sessionErr.message}`);
  const sessionIds = (revokedSessions ?? []).map((s) => (s as { id: string }).id);

  // 2) Revoke the refresh tokens tied to exactly those sessions, so the killed
  //    sessions cannot be silently re-minted via /auth/refresh.
  let refreshTokensRevoked = 0;
  if (sessionIds.length > 0) {
    const { data: revokedRt, error: rtErr } = await client
      .from("refresh_tokens")
      .update({ revoked_at: now })
      .in("session_id", sessionIds)
      .is("revoked_at", null)
      .select("id");
    if (rtErr) throw new Error(`refresh-token revoke failed: ${rtErr.message}`);
    refreshTokensRevoked = (revokedRt ?? []).length;
  }

  // 3) Flip the membership to 'revoked' — the write that finally activates the
  //    session_validation membership gate. `neq status 'revoked'` keeps it
  //    idempotent (a re-run flips nothing) and scoped to (user, school).
  const { data: revokedMemberships, error: mErr } = await client
    .from("school_memberships")
    .update({ status: "revoked" })
    .eq("user_id", userId)
    .eq("school_id", schoolId)
    .neq("status", "revoked")
    .select("id");
  if (mErr) throw new Error(`membership revoke failed: ${mErr.message}`);

  return {
    membershipsRevoked: (revokedMemberships ?? []).length,
    sessionsRevoked: sessionIds.length,
    refreshTokensRevoked,
  };
}
