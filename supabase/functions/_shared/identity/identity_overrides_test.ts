// PRA-P1-05 (S2) — membership-override write path contract tests (DB-free).
// An in-memory fake supabase client models permission_definitions,
// school_memberships and membership_permission_overrides so we can prove the
// permission validation, the delete-then-insert replace, and the remove count.

import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  permissionExists,
  removeMembershipOverride,
  resolveSchoolMembershipId,
  setMembershipOverride,
  UnknownPermissionError,
} from "./membership_overrides_repository.ts";

interface OverrideRow {
  id: string;
  school_membership_id: string;
  permission_slug: string;
  effect?: string;
}

function fakeClient(opts: {
  permissions: string[];
  memberships: Record<string, string>; // "userId:schoolId" -> membershipId
  overrides?: OverrideRow[];
}) {
  const overrides: OverrideRow[] = opts.overrides ? [...opts.overrides] : [];
  let seq = 0;

  function builder(table: string) {
    const filters: Record<string, unknown> = {};
    let mode: "select" | "delete" | null = null;
    let selectAfterDelete = false;
    // deno-lint-ignore no-explicit-any
    const b: any = {
      select() {
        if (mode === "delete") selectAfterDelete = true;
        else mode = "select";
        return b;
      },
      eq(c: string, v: unknown) {
        filters[c] = v;
        return b;
      },
      delete() {
        mode = "delete";
        return b;
      },
      // deno-lint-ignore no-explicit-any
      insert(row: any) {
        if (table === "membership_permission_overrides") {
          overrides.push({ id: `o-${++seq}`, ...row });
        }
        return Promise.resolve({ error: null });
      },
      maybeSingle() {
        if (table === "permission_definitions") {
          const ok = opts.permissions.includes(filters.slug as string);
          return Promise.resolve({ data: ok ? { slug: filters.slug } : null, error: null });
        }
        if (table === "school_memberships") {
          const id = opts.memberships[`${filters.user_id}:${filters.school_id}`];
          return Promise.resolve({ data: id ? { id } : null, error: null });
        }
        return Promise.resolve({ data: null, error: null });
      },
      // deno-lint-ignore no-explicit-any
      then(resolve: (r: any) => void) {
        if (mode === "delete" && table === "membership_permission_overrides") {
          const before = overrides.length;
          for (let i = overrides.length - 1; i >= 0; i--) {
            if (
              overrides[i].school_membership_id === filters.school_membership_id &&
              overrides[i].permission_slug === filters.permission_slug
            ) overrides.splice(i, 1);
          }
          const removed = before - overrides.length;
          resolve({
            data: selectAfterDelete
              ? Array.from({ length: removed }, (_, k) => ({ id: `d-${k}` }))
              : null,
            error: null,
          });
          return;
        }
        resolve({ data: null, error: null });
      },
    };
    return b;
  }

  const client = { from: (t: string) => builder(t) } as unknown as SupabaseClient;
  return { client, overrides };
}

Deno.test("PRA-P1-05: permissionExists reflects the catalogue", async () => {
  const { client } = fakeClient({ permissions: ["viewFinance"], memberships: {} });
  assertEquals(await permissionExists(client, "viewFinance"), true);
  assertEquals(await permissionExists(client, "notARealPermission"), false);
});

Deno.test("PRA-P1-05: resolveSchoolMembershipId scopes to (user, school)", async () => {
  const { client } = fakeClient({
    permissions: [],
    memberships: { "u1:s1": "m-1" },
  });
  assertEquals(await resolveSchoolMembershipId(client, "u1", "s1"), "m-1");
  assertEquals(await resolveSchoolMembershipId(client, "u1", "s2"), null);
});

Deno.test("PRA-P1-05: setMembershipOverride rejects an unknown permission", async () => {
  const { client, overrides } = fakeClient({ permissions: ["viewFinance"], memberships: {} });
  await assertRejects(
    () =>
      setMembershipOverride(client, {
        schoolMembershipId: "m-1",
        permissionSlug: "bogusPerm",
        effect: "grant",
      }),
    UnknownPermissionError,
  );
  assertEquals(overrides.length, 0, "no row written for an invalid permission");
});

Deno.test("PRA-P1-05: setMembershipOverride replaces (delete-then-insert, single row)", async () => {
  const { client, overrides } = fakeClient({
    permissions: ["viewFinance"],
    memberships: {},
    overrides: [{ id: "old", school_membership_id: "m-1", permission_slug: "viewFinance", effect: "deny" }],
  });
  await setMembershipOverride(client, {
    schoolMembershipId: "m-1",
    permissionSlug: "viewFinance",
    effect: "grant",
    reason: "acting head clerk",
  });
  const rows = overrides.filter((o) =>
    o.school_membership_id === "m-1" && o.permission_slug === "viewFinance"
  );
  assertEquals(rows.length, 1, "old override replaced, not duplicated");
  assertEquals(rows[0].effect, "grant");
});

Deno.test("PRA-P1-05: removeMembershipOverride returns the removed count", async () => {
  const { client } = fakeClient({
    permissions: [],
    memberships: {},
    overrides: [{ id: "x", school_membership_id: "m-1", permission_slug: "viewFinance" }],
  });
  assertEquals(
    await removeMembershipOverride(client, { schoolMembershipId: "m-1", permissionSlug: "viewFinance" }),
    1,
  );
  assertEquals(
    await removeMembershipOverride(client, { schoolMembershipId: "m-1", permissionSlug: "viewFinance" }),
    0,
  );
});
