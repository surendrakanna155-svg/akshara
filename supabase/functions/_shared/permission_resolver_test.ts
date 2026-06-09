import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  aggregateRolePermissions,
  applyPermissionOverrides,
  resolvePrimaryRoleSlug,
} from "./permission_resolver.ts";

const ROLE_MAP = new Map<string, string[]>([
  ["teacher", ["viewAdminHub"]],
  ["coordinator", ["viewAdminHub", "viewSis", "manageAdmissions"]],
  ["counselor", ["viewAdminHub", "manageAdmissions"]],
]);

Deno.test("aggregateRolePermissions unions multiple roles", () => {
  const perms = aggregateRolePermissions(["teacher", "coordinator"], ROLE_MAP);
  assertEquals(perms.includes("viewAdminHub"), true);
  assertEquals(perms.includes("viewSis"), true);
  assertEquals(perms.includes("manageAdmissions"), true);
});

Deno.test("aggregateRolePermissions deduplicates shared permissions", () => {
  const perms = aggregateRolePermissions(["teacher", "coordinator"], ROLE_MAP);
  assertEquals(perms.filter((p) => p === "viewAdminHub").length, 1);
});

Deno.test("applyPermissionOverrides DENY wins over union", () => {
  const base = aggregateRolePermissions(["teacher", "coordinator"], ROLE_MAP);
  const effective = applyPermissionOverrides(base, [
    { permission_slug: "manageAdmissions", effect: "deny" },
  ]);
  assertEquals(effective.includes("manageAdmissions"), false);
  assertEquals(effective.includes("viewSis"), true);
});

Deno.test("applyPermissionOverrides grant adds permission", () => {
  const base = aggregateRolePermissions(["teacher"], ROLE_MAP);
  const effective = applyPermissionOverrides(base, [
    { permission_slug: "viewFinance", effect: "grant" },
  ]);
  assertEquals(effective.includes("viewFinance"), true);
});

Deno.test("resolvePrimaryRoleSlug prefers is_primary", () => {
  const slug = resolvePrimaryRoleSlug([
    { role_slug: "teacher", is_primary: false, status: "active" },
    { role_slug: "coordinator", is_primary: true, status: "active" },
  ], null);
  assertEquals(slug, "coordinator");
});

Deno.test("aggregateRolePermissions falls back to viewAdminHub", () => {
  const perms = aggregateRolePermissions(["unknownRole"], new Map());
  assertEquals(perms, ["viewAdminHub"]);
});
