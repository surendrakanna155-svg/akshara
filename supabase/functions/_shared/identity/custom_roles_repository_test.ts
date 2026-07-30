// ICA-G3 — tenant custom-role write-path contract tests (DB-free).
// An in-memory fake supabase client models role_definitions, role_permissions and
// permission_definitions (including the org-sync trigger + PK/FK error codes) so
// we can prove: create+attach, system-role immutability, org isolation, per-org
// slug collision, and permission validation — all in code, no live DB.

import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  createCustomRole,
  customRoleSlug,
  deleteCustomRole,
  listCustomRoles,
  RoleInUseError,
  RoleNotFoundError,
  RoleSlugConflictError,
  SystemRoleImmutableError,
  UnknownPermissionError,
  updateCustomRole,
} from "./custom_roles_repository.ts";

interface RoleDef {
  slug: string;
  display_name: string;
  scope?: string;
  is_system: boolean;
  organization_id: string | null;
  [k: string]: unknown;
}
interface RolePerm {
  role_slug: string;
  permission_slug: string;
  organization_id: string | null;
  [k: string]: unknown;
}

function makeClient(seed: {
  permissions: string[];
  roleDefinitions?: RoleDef[];
  rolePermissions?: RolePerm[];
  inUse?: string[]; // slugs that raise an FK violation on delete
}) {
  const roleDefs: RoleDef[] = [...(seed.roleDefinitions ?? [])];
  const rolePerms: RolePerm[] = [...(seed.rolePermissions ?? [])];
  const perms = new Set(seed.permissions);
  const inUse = new Set(seed.inUse ?? []);

  function builder(table: string) {
    const eqs: Record<string, unknown> = {};
    let inClause: { col: string; vals: unknown[] } | null = null;
    let mode: "select" | "update" | "delete" | null = null;
    let updateVals: Record<string, unknown> | null = null;

    const matches = (row: Record<string, unknown>): boolean => {
      for (const [k, v] of Object.entries(eqs)) if (row[k] !== v) return false;
      if (inClause && !inClause.vals.includes(row[inClause.col])) return false;
      return true;
    };

    // deno-lint-ignore no-explicit-any
    const b: any = {
      select() {
        if (mode === null) mode = "select";
        return b;
      },
      eq(c: string, v: unknown) {
        eqs[c] = v;
        return b;
      },
      is(c: string, v: unknown) {
        eqs[c] = v;
        return b;
      },
      in(c: string, vals: unknown[]) {
        inClause = { col: c, vals };
        return b;
      },
      update(vals: Record<string, unknown>) {
        mode = "update";
        updateVals = vals;
        return b;
      },
      delete() {
        mode = "delete";
        return b;
      },
      // deno-lint-ignore no-explicit-any
      insert(rows: any) {
        const arr = Array.isArray(rows) ? rows : [rows];
        if (table === "role_definitions") {
          for (const r of arr) {
            if (roleDefs.some((x) => x.slug === r.slug)) {
              return Promise.resolve({ error: { code: "23505", message: "duplicate slug" } });
            }
            roleDefs.push({ ...r });
          }
        } else if (table === "role_permissions") {
          for (const r of arr) {
            // Simulate the org-sync trigger: organization_id is derived from the role.
            const role = roleDefs.find((x) => x.slug === r.role_slug);
            rolePerms.push({ ...r, organization_id: role ? role.organization_id : null });
          }
        }
        return Promise.resolve({ error: null });
      },
      maybeSingle() {
        if (table === "role_definitions") {
          const row = roleDefs.find(matches) ?? null;
          return Promise.resolve({ data: row, error: null });
        }
        return Promise.resolve({ data: null, error: null });
      },
      // deno-lint-ignore no-explicit-any
      then(resolve: (r: any) => void) {
        if (mode === "delete" && table === "role_definitions") {
          const targets = roleDefs.filter(matches);
          if (targets.some((t) => inUse.has(t.slug))) {
            resolve({ error: { code: "23503", message: "fk violation" } });
            return;
          }
          for (let i = roleDefs.length - 1; i >= 0; i--) if (matches(roleDefs[i])) roleDefs.splice(i, 1);
          resolve({ error: null });
          return;
        }
        if (mode === "delete" && table === "role_permissions") {
          for (let i = rolePerms.length - 1; i >= 0; i--) if (matches(rolePerms[i])) rolePerms.splice(i, 1);
          resolve({ error: null });
          return;
        }
        if (mode === "update" && table === "role_definitions") {
          for (const r of roleDefs) if (matches(r)) Object.assign(r, updateVals);
          resolve({ error: null });
          return;
        }
        if (mode === "select" && table === "permission_definitions") {
          const rows = [...perms]
            .filter((s) => (inClause ? inClause.vals.includes(s) : true))
            .map((slug) => ({ slug }));
          resolve({ data: rows, error: null });
          return;
        }
        if (mode === "select" && table === "role_definitions") {
          resolve({
            data: roleDefs.filter(matches).map((r) => ({ slug: r.slug, display_name: r.display_name })),
            error: null,
          });
          return;
        }
        if (mode === "select" && table === "role_permissions") {
          resolve({
            data: rolePerms.filter(matches).map((r) => ({
              role_slug: r.role_slug,
              permission_slug: r.permission_slug,
            })),
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
  return { client, roleDefs, rolePerms };
}

const ORG_A = "a1000000-0000-4000-8000-00000000000a";
const ORG_B = "b1000000-0000-4000-8000-00000000000b";

function systemSeed(): RoleDef[] {
  return [
    { slug: "schoolAdmin", display_name: "School Admin", is_system: true, organization_id: null },
    { slug: "teacher", display_name: "Teacher", is_system: true, organization_id: null },
  ];
}

Deno.test("G3: create custom role writes an org-scoped, non-system role + its grants", async () => {
  const { client, roleDefs, rolePerms } = makeClient({
    permissions: ["viewFinance", "manageFinance"],
    roleDefinitions: systemSeed(),
  });

  const { slug } = await createCustomRole(client, {
    organizationId: ORG_A,
    displayName: "Senior Accountant",
    permissionSlugs: ["viewFinance", "manageFinance"],
  });

  assertEquals(slug, customRoleSlug(ORG_A, "Senior Accountant"));
  const created = roleDefs.find((r) => r.slug === slug)!;
  assertEquals(created.is_system, false);
  assertEquals(created.organization_id, ORG_A);
  const grants = rolePerms.filter((p) => p.role_slug === slug).map((p) => p.permission_slug).sort();
  assertEquals(grants, ["manageFinance", "viewFinance"]);
  // org-sync trigger simulation tags the grants with the owning org.
  assertEquals(rolePerms.filter((p) => p.role_slug === slug).every((p) => p.organization_id === ORG_A), true);
});

Deno.test("G3: create rejects an unknown permission (no role written)", async () => {
  const { client, roleDefs } = makeClient({ permissions: ["viewFinance"] });
  await assertRejects(
    () =>
      createCustomRole(client, {
        organizationId: ORG_A,
        displayName: "Bad Role",
        permissionSlugs: ["viewFinance", "notARealPermission"],
      }),
    UnknownPermissionError,
  );
  assertEquals(roleDefs.length, 0, "no role definition written for an invalid permission set");
});

Deno.test("G3: a tenant CANNOT update a system role (immutable)", async () => {
  const { client } = makeClient({ permissions: ["viewFinance"], roleDefinitions: systemSeed() });
  await assertRejects(
    () => updateCustomRole(client, { organizationId: ORG_A, slug: "schoolAdmin", displayName: "Hacked" }),
    SystemRoleImmutableError,
  );
});

Deno.test("G3: a tenant CANNOT delete a system role (immutable)", async () => {
  const { client, roleDefs } = makeClient({ permissions: [], roleDefinitions: systemSeed() });
  await assertRejects(
    () => deleteCustomRole(client, { organizationId: ORG_A, slug: "teacher" }),
    SystemRoleImmutableError,
  );
  assertEquals(roleDefs.some((r) => r.slug === "teacher"), true, "system role still present");
});

Deno.test("G3: org isolation — org A cannot modify or delete org B's custom role", async () => {
  const bSlug = customRoleSlug(ORG_B, "Warden");
  const seed = [
    ...systemSeed(),
    { slug: bSlug, display_name: "Warden", is_system: false, organization_id: ORG_B },
  ];
  const { client } = makeClient({ permissions: ["viewHostel"], roleDefinitions: seed });

  await assertRejects(
    () => updateCustomRole(client, { organizationId: ORG_A, slug: bSlug, displayName: "Steal" }),
    RoleNotFoundError,
  );
  await assertRejects(
    () => deleteCustomRole(client, { organizationId: ORG_A, slug: bSlug }),
    RoleNotFoundError,
  );
});

Deno.test("G3: org isolation — list returns only the caller org's custom roles", async () => {
  const aSlug = customRoleSlug(ORG_A, "Front Desk");
  const bSlug = customRoleSlug(ORG_B, "Warden");
  const seed = [
    ...systemSeed(),
    { slug: aSlug, display_name: "Front Desk", is_system: false, organization_id: ORG_A },
    { slug: bSlug, display_name: "Warden", is_system: false, organization_id: ORG_B },
  ];
  const { client } = makeClient({
    permissions: ["viewSis"],
    roleDefinitions: seed,
    rolePermissions: [{ role_slug: aSlug, permission_slug: "viewSis", organization_id: ORG_A }],
  });

  const roles = await listCustomRoles(client, ORG_A);
  assertEquals(roles.map((r) => r.slug), [aSlug], "only org A's custom role is listed (no system, no org B)");
  assertEquals(roles[0].permissions, ["viewSis"]);
});

Deno.test("G3: a custom slug cannot collide with an existing role (per-org unique)", async () => {
  const dupSlug = customRoleSlug(ORG_A, "Coordinator Plus");
  const seed = [
    ...systemSeed(),
    { slug: dupSlug, display_name: "Coordinator Plus", is_system: false, organization_id: ORG_A },
  ];
  const { client } = makeClient({ permissions: ["viewSis"], roleDefinitions: seed });
  await assertRejects(
    () =>
      createCustomRole(client, {
        organizationId: ORG_A,
        displayName: "Coordinator Plus",
        permissionSlugs: ["viewSis"],
      }),
    RoleSlugConflictError,
  );
});

Deno.test("G3: a custom slug can NEVER equal a system slug (shadow-proof by construction)", () => {
  for (const sys of ["schoolAdmin", "principal", "superAdmin", "teacher", "parent"]) {
    // No org+name combination produces a bare camelCase system slug.
    assertEquals(customRoleSlug(ORG_A, sys).startsWith("custom_"), true);
    assertEquals(customRoleSlug(ORG_A, sys) === sys, false);
  }
});

Deno.test("G3: update replaces the permission set of a tenant's own role", async () => {
  const slug = customRoleSlug(ORG_A, "Exam Cell");
  const seed = [
    ...systemSeed(),
    { slug, display_name: "Exam Cell", is_system: false, organization_id: ORG_A },
  ];
  const { client, rolePerms } = makeClient({
    permissions: ["viewSis", "manageSis", "viewManagement"],
    roleDefinitions: seed,
    rolePermissions: [{ role_slug: slug, permission_slug: "viewSis", organization_id: ORG_A }],
  });

  await updateCustomRole(client, {
    organizationId: ORG_A,
    slug,
    permissionSlugs: ["manageSis", "viewManagement"],
  });

  const grants = rolePerms.filter((p) => p.role_slug === slug).map((p) => p.permission_slug).sort();
  assertEquals(grants, ["manageSis", "viewManagement"], "old grant cleared, new set attached");
});

Deno.test("G3: delete of an in-use custom role surfaces RoleInUseError", async () => {
  const slug = customRoleSlug(ORG_A, "Busy Role");
  const seed = [
    ...systemSeed(),
    { slug, display_name: "Busy Role", is_system: false, organization_id: ORG_A },
  ];
  const { client } = makeClient({ permissions: [], roleDefinitions: seed, inUse: [slug] });
  await assertRejects(
    () => deleteCustomRole(client, { organizationId: ORG_A, slug }),
    RoleInUseError,
  );
});
