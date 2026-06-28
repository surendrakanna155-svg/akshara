import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { requirePermission } from "../permission_middleware.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { RBAC_ROUTE_INVENTORY } from "./rbac_route_inventory.ts";

/// QW1 · QA-B-038 (per-route RBAC matrix) + QA-B-049 (anti-escalation).
/// For EVERY inventory route with a required permission, assert the holder is
/// allowed and a non-holder is denied (403); and that holding every OTHER
/// permission still does not grant the route (no privilege escalation via a
/// different/broader permission).

function claims(permissions: string[]): AccessTokenClaims {
  return {
    sub: "a3000000-0000-4000-8000-000000000001",
    tenant_id: "a1000000-0000-4000-8000-000000000001",
    organization_id: "a1000000-0000-4000-8000-000000000001",
    school_id: "a2000000-0000-4000-8000-000000000001",
    role: "schoolAdmin",
    role_slugs: ["schoolAdmin"],
    primary_role: "schoolAdmin",
    permissions,
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "test",
  };
}

const permissionedRules = RBAC_ROUTE_INVENTORY.filter(
  (r) => r.permission !== null,
);

const allPermissions = [
  ...new Set(permissionedRules.map((r) => r.permission as string)),
];

Deno.test("QA-B-038: inventory has a substantial permissioned-route surface", () => {
  // Guard against the matrix silently shrinking to nothing.
  assertEquals(permissionedRules.length >= 50, true,
    `expected >=50 permissioned routes, got ${permissionedRules.length}`);
});

Deno.test("QA-B-038: every route allows its holder and denies a non-holder", () => {
  for (const rule of permissionedRules) {
    const perm = rule.permission as string;
    const tag = `${rule.method} ${rule.path} (${perm})`;

    // Holder → allowed (no 403).
    assertEquals(
      requirePermission(claims([perm]), perm),
      null,
      `holder should access ${tag}`,
    );

    // Non-holder (no permissions) → 403.
    const denied = requirePermission(claims([]), perm);
    assertEquals(denied?.status, 403, `non-holder should be denied ${tag}`);
  }
});

Deno.test("QA-B-049: holding every OTHER permission never grants a route", () => {
  for (const rule of permissionedRules) {
    const perm = rule.permission as string;
    const others = allPermissions.filter((p) => p !== perm);
    const denied = requirePermission(claims(others), perm);
    assertEquals(
      denied?.status,
      403,
      `${rule.method} ${rule.path} must require exactly ${perm} ` +
        `(no escalation via other permissions)`,
    );
  }
});
