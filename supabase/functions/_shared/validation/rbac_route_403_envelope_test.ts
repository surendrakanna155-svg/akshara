// QW1 · QA-B-066 — per-route 403 FORBIDDEN envelope validation.
//
// rbac_full_matrix_test.ts (QA-B-038/049) proves every permissioned route
// DENIES a non-holder with status 403 and never escalates. This complements it
// by asserting the deny branch returns a well-formed FORBIDDEN *envelope* on
// EVERY protected route — the contract clients depend on to render an
// access-denied state — not merely the HTTP status. Fully in-memory (no DB).

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { requirePermission } from "../permission_middleware.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { RBAC_ROUTE_INVENTORY } from "./rbac_route_inventory.ts";

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

Deno.test("QA-B-066: every protected route's deny branch returns a FORBIDDEN envelope", async () => {
  for (const rule of permissionedRules) {
    const perm = rule.permission as string;
    const tag = `${rule.method} ${rule.path} (${perm})`;

    const denied = requirePermission(claims([]), perm);
    if (denied === null) {
      throw new Error(`expected a 403 response for ${tag}, got null`);
    }

    assertEquals(denied.status, 403, `status must be 403 for ${tag}`);

    const body = await denied.clone().json();
    assertEquals(body.data, null, `data must be null for ${tag}`);
    assertEquals(body.error?.code, "FORBIDDEN", `error.code must be FORBIDDEN for ${tag}`);
    // The message names the exact permission the caller is missing.
    assertEquals(
      typeof body.error?.message === "string" && body.error.message.includes(perm),
      true,
      `message must name the required permission for ${tag}`,
    );
  }
});

Deno.test("QA-B-066: the holder's request is NOT denied (no false 403)", () => {
  for (const rule of permissionedRules) {
    const perm = rule.permission as string;
    assertEquals(
      requirePermission(claims([perm]), perm),
      null,
      `holder must not be denied ${rule.method} ${rule.path} (${perm})`,
    );
  }
});
