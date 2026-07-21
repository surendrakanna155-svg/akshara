// ICA-G3 — permission RESOLUTION regression tests (DB-free).
// Proves the org-scoped role_permissions read: a custom role resolves its grants
// exactly like a system role; a system-role membership resolves identically to
// pre-G3; and a membership NEVER picks up another org's grants — even when the
// mock deliberately returns a colliding slug, the production-side org filter in
// loadRolePermissionMap drops the foreign-org rows.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { loadRolePermissionMap, resolveSchoolMembershipPermissions } from "../permission_resolver.ts";

interface MembershipRole {
  role_slug: string;
  is_primary: boolean;
  status: string;
}
interface RolePerm {
  role_slug: string;
  permission_slug: string;
  organization_id: string | null;
}

function makeClient(seed: {
  membershipRoles: Record<string, MembershipRole[]>;
  rolePermissions: RolePerm[];
  overrides?: Record<string, { permission_slug: string; effect: string }[]>;
}) {
  function builder(table: string) {
    const eqs: Record<string, unknown> = {};
    let inClause: { col: string; vals: unknown[] } | null = null;
    // deno-lint-ignore no-explicit-any
    const b: any = {
      select() {
        return b;
      },
      eq(c: string, v: unknown) {
        eqs[c] = v;
        return b;
      },
      in(c: string, vals: unknown[]) {
        inClause = { col: c, vals };
        return b;
      },
      // PostgREST .or is a passthrough here on purpose: we want the PRODUCTION
      // JS-side org filter in loadRolePermissionMap to be the thing under test.
      or() {
        return b;
      },
      // deno-lint-ignore no-explicit-any
      then(resolve: (r: any) => void) {
        if (table === "school_membership_roles") {
          const rows = (seed.membershipRoles[eqs.school_membership_id as string] ?? [])
            .filter((r) => !eqs.status || r.status === eqs.status);
          resolve({ data: rows, error: null });
          return;
        }
        if (table === "role_permissions") {
          const rows = seed.rolePermissions.filter((r) =>
            inClause ? inClause.vals.includes(r.role_slug) : true
          );
          resolve({ data: rows, error: null });
          return;
        }
        if (table === "membership_permission_overrides") {
          resolve({ data: seed.overrides?.[eqs.school_membership_id as string] ?? [], error: null });
          return;
        }
        resolve({ data: [], error: null });
      },
    };
    return b;
  }
  return { from: (t: string) => builder(t) } as unknown as SupabaseClient;
}

const ORG_A = "a1000000-0000-4000-8000-00000000000a";
const ORG_B = "b1000000-0000-4000-8000-00000000000b";

Deno.test("G3 resolution: a custom role resolves its permissions (union like a system role)", async () => {
  const client = makeClient({
    membershipRoles: { m1: [{ role_slug: "custom_a_accountant", is_primary: true, status: "active" }] },
    rolePermissions: [
      { role_slug: "custom_a_accountant", permission_slug: "viewFinance", organization_id: ORG_A },
      { role_slug: "custom_a_accountant", permission_slug: "manageFinance", organization_id: ORG_A },
    ],
  });
  const resolved = await resolveSchoolMembershipPermissions(client, "m1", null, 1, ORG_A);
  assertEquals(resolved.permissions, ["manageFinance", "viewFinance"]);
  assertEquals(resolved.primaryRole, "custom_a_accountant");
});

Deno.test("G3 resolution: a system-role membership resolves identically (no regression)", async () => {
  const client = makeClient({
    membershipRoles: { m2: [{ role_slug: "teacher", is_primary: true, status: "active" }] },
    rolePermissions: [
      { role_slug: "teacher", permission_slug: "viewAdminHub", organization_id: null },
    ],
  });
  const resolved = await resolveSchoolMembershipPermissions(client, "m2", null, 1, ORG_A);
  assertEquals(resolved.permissions, ["viewAdminHub"]);
  assertEquals(resolved.primaryRole, "teacher");
});

Deno.test("G3 resolution: org isolation — a membership never picks up another org's grants", async () => {
  const client = makeClient({
    membershipRoles: { m3: [{ role_slug: "shared", is_primary: true, status: "active" }] },
    // A deliberately colliding slug across two orgs + a system row. Only the
    // system grant and org A's grant must survive; org B's must be dropped.
    rolePermissions: [
      { role_slug: "shared", permission_slug: "viewAdminHub", organization_id: null },
      { role_slug: "shared", permission_slug: "viewFinance", organization_id: ORG_A },
      { role_slug: "shared", permission_slug: "manageControlCenter", organization_id: ORG_B },
    ],
  });
  const resolved = await resolveSchoolMembershipPermissions(client, "m3", null, 1, ORG_A);
  assertEquals(resolved.permissions, ["viewAdminHub", "viewFinance"]);
  assertEquals(resolved.permissions.includes("manageControlCenter"), false, "org B's grant must NOT leak");
});

Deno.test("G3 resolution: loadRolePermissionMap keeps system + own-org, drops foreign-org", async () => {
  const client = makeClient({
    membershipRoles: {},
    rolePermissions: [
      { role_slug: "r", permission_slug: "sysPerm", organization_id: null },
      { role_slug: "r", permission_slug: "ownPerm", organization_id: ORG_A },
      { role_slug: "r", permission_slug: "foreignPerm", organization_id: ORG_B },
    ],
  });
  const map = await loadRolePermissionMap(client, ["r"], ORG_A);
  assertEquals((map.get("r") ?? []).sort(), ["ownPerm", "sysPerm"]);
});
