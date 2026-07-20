// PLAT-0 (W2) — Multi-school identity: one user, MANY schools, STRICT per-school
// isolation. Owner decision #14 (FINAL).
//
// This module is the single source of truth for *which schools a user may act
// as* and for authorizing a school-context switch. It splits cleanly into:
//
//   • an IO read (`listActiveSchoolMemberships`) — the user's ACTIVE school
//     memberships in a deterministic order (oldest first, school_id tiebreak);
//   • pure decision helpers (`resolveSchoolSelection`,
//     `assertActiveSchoolMembership`, `schoolSelectionDenial`) — no IO, so the
//     authorization policy is unit-testable without a database, exactly like
//     `evaluateSessionState`.
//
// SECURITY INVARIANT (never weaken): a user may only obtain a school context for
// a school they hold an ACTIVE membership in. The selector never widens access —
// every option is one of THIS user's active memberships. Switching changes the
// session's `school_id` ONLY; every tenant read/write remains fenced by
// `app_current_school_id()` under RLS. This module authorizes *which* school a
// context may carry; RLS enforces isolation *within* whichever school it carries.
// No RLS policy is defined or broadened here.

import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

/** A single active school a user belongs to — a selector option and the unit an
 *  authorization decision is made against. */
export interface SchoolMembershipSummary {
  membershipId: string;
  schoolId: string;
  schoolName: string;
  schoolCode: string;
  organizationId: string;
  role: string;
  permissionsVersion: number;
}

/**
 * Outcome of resolving a requested (or absent) school against a user's active
 * memberships. A discriminated union so callers must handle every case:
 *   - `none`               → the user has no active school membership at all.
 *   - `forbidden`          → a school was requested that the user is NOT a
 *                            member of (the switch-into-a-non-member-school 403).
 *   - `selection_required` → ≥2 memberships and no school named — the client
 *                            must present a selector and re-call with a choice.
 *   - `resolved`           → exactly the membership the context may carry.
 */
export type SchoolSelection =
  | { kind: "none" }
  | { kind: "resolved"; membership: SchoolMembershipSummary }
  | { kind: "forbidden"; requestedSchoolId: string }
  | { kind: "selection_required"; options: SchoolMembershipSummary[] };

/**
 * Pure resolution of a school context request. This REPLACES the old silent
 * `.limit(1)` default-school pick with an explicit, membership-checked decision.
 *
 * - A requested school is honored ONLY when it is one of the user's active
 *   memberships; otherwise the request is `forbidden` (→ 403). A non-member
 *   school can never be resolved.
 * - With no requested school: one membership resolves to it; ≥2 memberships
 *   require an explicit selection (a REAL selector, not a silent pick).
 */
export function resolveSchoolSelection(
  memberships: SchoolMembershipSummary[],
  requestedSchoolId?: string | null,
): SchoolSelection {
  if (memberships.length === 0) return { kind: "none" };

  if (requestedSchoolId) {
    const match = memberships.find((m) => m.schoolId === requestedSchoolId);
    if (!match) return { kind: "forbidden", requestedSchoolId };
    return { kind: "resolved", membership: match };
  }

  if (memberships.length === 1) {
    return { kind: "resolved", membership: memberships[0] };
  }

  return { kind: "selection_required", options: memberships };
}

/**
 * The named security check for the switch path: the user must hold an ACTIVE
 * membership in `schoolId`. Pure and independent of `resolveSchoolSelection`, so
 * the switch handler asserts membership a second time (defense-in-depth) right
 * before it mints a new context — the 403 boundary cannot be lost to a future
 * refactor of the resolver.
 */
export function assertActiveSchoolMembership(
  memberships: SchoolMembershipSummary[],
  schoolId: string,
): boolean {
  return memberships.some((m) => m.schoolId === schoolId);
}

/** A denial descriptor a handler turns into an HTTP response. Pure. */
export interface SchoolSelectionDenial {
  code: string;
  message: string;
  status: number;
  /** Selector options — present only for `selection_required`. Contains no
   *  cross-tenant data: every entry is one of the caller's own memberships. */
  options?: Array<{
    schoolId: string;
    schoolName: string;
    schoolCode: string;
    organizationId: string;
  }>;
}

/**
 * Maps a non-resolved {@link SchoolSelection} to its HTTP denial, or `null` when
 * the selection resolved (the caller may proceed). Keeps the wiring in the
 * handler thin and the status/code mapping unit-tested.
 */
export function schoolSelectionDenial(
  selection: SchoolSelection,
): SchoolSelectionDenial | null {
  switch (selection.kind) {
    case "resolved":
      return null;
    case "none":
      return {
        code: "CONTEXT_FORBIDDEN",
        message: "No active school membership for this user",
        status: 403,
      };
    case "forbidden":
      return {
        code: "CONTEXT_FORBIDDEN",
        message: "You are not a member of the requested school",
        status: 403,
      };
    case "selection_required":
      return {
        code: "SCHOOL_SELECTION_REQUIRED",
        message: "Multiple school memberships — choose a school to switch into",
        status: 409,
        options: selection.options.map((o) => ({
          schoolId: o.schoolId,
          schoolName: o.schoolName,
          schoolCode: o.schoolCode,
          organizationId: o.organizationId,
        })),
      };
  }
}

/**
 * A user's ACTIVE school memberships in a DETERMINISTIC order (oldest first,
 * school_id as the tiebreak) — the ordering the previous `.limit(1)` pick relied
 * on for a stable default. This is the source of truth for BOTH the selector and
 * the switch-path authorization check. Runs on the service-role (identity plane)
 * client, like the other auth resolvers. Any read error resolves to an empty
 * list (fail-closed: no memberships → no school context).
 */
export async function listActiveSchoolMemberships(
  client: SupabaseClient,
  userId: string,
): Promise<SchoolMembershipSummary[]> {
  const { data, error } = await client
    .from("school_memberships")
    .select(
      "id,school_id,role,permissions_version,schools(id,organization_id,name,code)",
    )
    .eq("user_id", userId)
    .eq("status", "active")
    .order("created_at", { ascending: true })
    .order("school_id", { ascending: true });

  if (error || !data) return [];

  const rows = data as unknown as Array<{
    id: string;
    school_id: string;
    role: string;
    permissions_version: number;
    schools:
      | { id: string; organization_id: string; name: string; code: string }
      | null;
  }>;

  return rows
    .filter((r) => r.schools != null)
    .map((r) => ({
      membershipId: r.id,
      schoolId: r.school_id,
      schoolName: r.schools!.name,
      schoolCode: r.schools!.code,
      organizationId: r.schools!.organization_id,
      role: r.role,
      permissionsVersion: r.permissions_version,
    }));
}
