import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { claimsToTenantParams } from "./tenant_db.ts";
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
