import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { resolveLoginScopeOrder } from "./auth_context.ts";
import {
  aggregateRolePermissions,
  applyPermissionOverrides,
} from "./permission_resolver.ts";

Deno.test("resolveLoginScopeOrder defaults school-first for v6.0 compat", () => {
  assertEquals(resolveLoginScopeOrder(), [
    "school",
    "organization",
    "parent",
    "student",
  ]);
});

Deno.test("resolveLoginScopeOrder honors explicit scope", () => {
  assertEquals(resolveLoginScopeOrder("organization"), ["organization"]);
  assertEquals(resolveLoginScopeOrder("parent"), ["parent"]);
});

Deno.test("parent role permissions union includes viewSis and viewFinance", () => {
  const map = new Map<string, string[]>([
    ["parent", ["viewFinance", "viewSis"]],
  ]);
  const perms = aggregateRolePermissions(["parent"], map);
  assertEquals(perms.includes("viewSis"), true);
  assertEquals(perms.includes("viewFinance"), true);
});

Deno.test("DENY override removes parent fee visibility", () => {
  const perms = applyPermissionOverrides(
    ["viewFinance", "viewSis"],
    [{ permission_slug: "viewFinance", effect: "deny" }],
  );
  assertEquals(perms.includes("viewFinance"), false);
  assertEquals(perms.includes("viewSis"), true);
});
