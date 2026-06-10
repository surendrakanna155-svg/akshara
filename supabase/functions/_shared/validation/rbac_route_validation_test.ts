import { assertEquals, assertExists } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  requirePermission,
  requireSchoolOperationalScope,
} from "../permission_middleware.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import {
  RBAC_MODULE_PERMISSIONS,
  RBAC_ROUTE_INVENTORY,
  type RbacRouteRule,
} from "./rbac_route_inventory.ts";

function claimsForRule(
  rule: RbacRouteRule,
  permissions: string[],
): AccessTokenClaims {
  const schoolId = rule.scope === "organization" ? null : "a2000000-0000-4000-8000-000000000001";
  return {
    sub: "a3000000-0000-4000-8000-000000000001",
    tenant_id: "a1000000-0000-4000-8000-000000000001",
    organization_id: "a1000000-0000-4000-8000-000000000001",
    school_id: schoolId,
    role: rule.scope === "parent" ? "parent" : rule.scope === "student" ? "student" : "schoolAdmin",
    role_slugs: [rule.scope === "parent" ? "parent" : rule.scope === "student" ? "student" : "schoolAdmin"],
    primary_role: rule.scope === "parent" ? "parent" : rule.scope === "student" ? "student" : "schoolAdmin",
    permissions,
    permissions_version: 1,
    scope: rule.scope,
    school_group_id: null,
    student_id: rule.scope === "student" ? "a4000000-0000-4000-8000-000000000001" : null,
    child_ids: rule.scope === "parent" ? ["a4000000-0000-4000-8000-000000000001"] : [],
    session_id: "test",
  };
}

Deno.test("RBAC route inventory is non-empty and modules covered", () => {
  assertEquals(RBAC_ROUTE_INVENTORY.length >= 20, true);
  const modules = new Set(RBAC_ROUTE_INVENTORY.map((r) => r.module));
  for (const name of ["admissions", "finance", "sis", "audit", "parent", "teacher", "student"]) {
    assertEquals(modules.has(name), true, `missing module ${name}`);
  }
});

Deno.test("RBAC routes deny when required permission missing", () => {
  for (const rule of RBAC_ROUTE_INVENTORY) {
    if (!rule.permission) continue;
    const claims = claimsForRule(rule, []);
    const denied = requirePermission(claims, rule.permission);
    assertEquals(denied?.status, 403, `${rule.method} ${rule.path}`);
  }
});

Deno.test("RBAC school routes deny organization scope", () => {
  for (const rule of RBAC_ROUTE_INVENTORY) {
    if (rule.scope !== "school" || !rule.permission) continue;
    const claims = claimsForRule(rule, [rule.permission]);
    const orgClaims = { ...claims, scope: "organization" as const, school_id: null };
    const denied = requireSchoolOperationalScope(orgClaims);
    assertEquals(denied?.status, 403, `${rule.path}`);
  }
});

Deno.test("RBAC module permissions are unique slugs", () => {
  const set = new Set(RBAC_MODULE_PERMISSIONS);
  assertEquals(set.size, RBAC_MODULE_PERMISSIONS.length);
});

Deno.test("parent and student routes use persona scope not school permission", () => {
  const parent = RBAC_ROUTE_INVENTORY.find((r) => r.module === "parent");
  const student = RBAC_ROUTE_INVENTORY.find((r) => r.module === "student");
  assertExists(parent);
  assertExists(student);
  assertEquals(parent!.scope, "parent");
  assertEquals(student!.scope, "student");
  assertEquals(parent!.permission, null);
});
