import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { assertEdgeTenantRole, claimsToTenantParams } from "./tenant_db.ts";
import type { AccessTokenClaims } from "./jwt.ts";

const baseClaims: AccessTokenClaims = {
  sub: "user-1",
  tenant_id: "org-1",
  organization_id: "org-1",
  school_id: "school-1",
  role: "schoolAdmin",
  role_slugs: ["schoolAdmin"],
  primary_role: "schoolAdmin",
  permissions: ["viewAdminHub"],
  permissions_version: 1,
  scope: "school",
  school_group_id: null,
  student_id: null,
  child_ids: [],
  session_id: "session-1",
};

Deno.test("claimsToTenantParams maps school scope", () => {
  const params = claimsToTenantParams(baseClaims);
  assertEquals(params.tenantId, "org-1");
  assertEquals(params.scope, "school");
  assertEquals(params.schoolId, "school-1");
  assertEquals(params.parentUserId, null);
});

Deno.test("claimsToTenantParams sets parentUserId for parent scope", () => {
  const params = claimsToTenantParams({
    ...baseClaims,
    scope: "parent",
    role: "parent",
    primary_role: "parent",
    child_ids: ["child-1"],
  });
  assertEquals(params.parentUserId, "user-1");
  assertEquals(params.scope, "parent");
});

Deno.test("claimsToTenantParams maps student scope", () => {
  const params = claimsToTenantParams({
    ...baseClaims,
    scope: "student",
    student_id: "student-record-1",
    role: "student",
    primary_role: "student",
  });
  assertEquals(params.studentId, "student-record-1");
  assertEquals(params.scope, "student");
});

// P0-INFRA-6 / DB-2 — deploy-time edge role assertion.
Deno.test("assertEdgeTenantRole accepts erp_tenant with NOBYPASSRLS", () => {
  assertEquals(assertEdgeTenantRole({ role: "erp_tenant", bypassRls: false }), null);
});

Deno.test("assertEdgeTenantRole rejects service_role", () => {
  const err = assertEdgeTenantRole({ role: "service_role", bypassRls: true });
  assertEquals(err !== null, true);
  assertEquals(err!.includes("service_role") || err!.includes("erp_tenant"), true);
});

Deno.test("assertEdgeTenantRole rejects erp_tenant that can bypass RLS", () => {
  const err = assertEdgeTenantRole({ role: "erp_tenant", bypassRls: true });
  assertEquals(err !== null, true);
  assertEquals(err!.includes("BYPASS"), true);
});

Deno.test("assertEdgeTenantRole rejects an unknown/missing role", () => {
  assertEquals(assertEdgeTenantRole({}) !== null, true);
});
