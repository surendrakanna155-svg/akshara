// PRA-P1-05 (S2) — write path for `membership_permission_overrides`.
//
// The override table has, since RBAC foundation, been READ by permission
// resolution (permission_resolver.ts:114-117 applies grant/deny overrides on top
// of role permissions) but NOTHING ever wrote it — a per-user exception grant
// was impossible, so `officeStaff` (and every role) could only be all-or-nothing.
// This is the missing writer. It runs on the service-role client (the table has
// no RLS policy and no erp_tenant grant — tenant isolation is enforced in the
// handler, which only ever resolves a membership within the caller's own
// school). A companion trigger (migration 20260900000011) bumps the membership's
// permissions_version on every write here, so an override takes effect on the
// user's next request instead of waiting out the token TTL.

import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

export type OverrideEffect = "grant" | "deny";

export class UnknownPermissionError extends Error {
  constructor(slug: string) {
    super(`Unknown permission: ${slug}`);
    this.name = "UnknownPermissionError";
  }
}

/** True when `slug` exists in the permission catalogue (FK target). */
export async function permissionExists(
  client: SupabaseClient,
  slug: string,
): Promise<boolean> {
  const { data, error } = await client
    .from("permission_definitions")
    .select("slug")
    .eq("slug", slug)
    .maybeSingle();
  if (error) throw new Error(`permission lookup failed: ${error.message}`);
  return !!data;
}

/**
 * Resolve the school-membership id for (userId, schoolId). Returns null when the
 * user has no membership in that school — the caller uses this to keep overrides
 * strictly within their own school (tenant isolation).
 */
export async function resolveSchoolMembershipId(
  client: SupabaseClient,
  userId: string,
  schoolId: string,
): Promise<string | null> {
  const { data, error } = await client
    .from("school_memberships")
    .select("id")
    .eq("user_id", userId)
    .eq("school_id", schoolId)
    .maybeSingle();
  if (error) throw new Error(`membership lookup failed: ${error.message}`);
  return (data as { id: string } | null)?.id ?? null;
}

/**
 * Set (idempotent replace) a grant/deny override for a permission on a school
 * membership. Delete-then-insert because the table's uniqueness is a PARTIAL
 * index (`WHERE school_membership_id IS NOT NULL`), which PostgREST cannot target
 * with `onConflict`. Validates the permission slug first so the caller gets a
 * clean 422 rather than a raw FK violation.
 */
export async function setMembershipOverride(
  client: SupabaseClient,
  input: {
    schoolMembershipId: string;
    permissionSlug: string;
    effect: OverrideEffect;
    reason?: string | null;
  },
): Promise<void> {
  if (!(await permissionExists(client, input.permissionSlug))) {
    throw new UnknownPermissionError(input.permissionSlug);
  }

  const del = await client
    .from("membership_permission_overrides")
    .delete()
    .eq("school_membership_id", input.schoolMembershipId)
    .eq("permission_slug", input.permissionSlug);
  if (del.error) throw new Error(`override clear failed: ${del.error.message}`);

  const ins = await client.from("membership_permission_overrides").insert({
    school_membership_id: input.schoolMembershipId,
    permission_slug: input.permissionSlug,
    effect: input.effect,
    reason: input.reason ?? null,
  });
  if (ins.error) throw new Error(`override insert failed: ${ins.error.message}`);
}

/** Remove an override; returns the number of rows removed (0 = none existed). */
export async function removeMembershipOverride(
  client: SupabaseClient,
  input: { schoolMembershipId: string; permissionSlug: string },
): Promise<number> {
  const { data, error } = await client
    .from("membership_permission_overrides")
    .delete()
    .eq("school_membership_id", input.schoolMembershipId)
    .eq("permission_slug", input.permissionSlug)
    .select("id");
  if (error) throw new Error(`override remove failed: ${error.message}`);
  return (data ?? []).length;
}
