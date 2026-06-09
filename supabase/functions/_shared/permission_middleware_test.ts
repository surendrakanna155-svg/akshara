import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  requirePermission,
  requireSchoolOperationalScope,
} from "./permission_middleware.ts";
import type { AccessTokenClaims } from "./jwt.ts";

const baseClaims: AccessTokenClaims = {
  sub: "user-1",
  tenant_id: "org-1",
  organization_id: "org-1",
  school_id: "school-1",
  role: "schoolAdmin",
  role_slugs: ["schoolAdmin"],
  primary_role: "schoolAdmin",
  permissions: ["viewAdmissions", "manageAdmissions"],
  permissions_version: 1,
  scope: "school",
  school_group_id: null,
  student_id: null,
  child_ids: [],
  session_id: "sess-1",
};

Deno.test("requirePermission allows when slug present", () => {
  assertEquals(requirePermission(baseClaims, "viewAdmissions"), null);
});

Deno.test("requirePermission denies missing slug", () => {
  const response = requirePermission(baseClaims, "approveAdmissions");
  assertEquals(response?.status, 403);
});

Deno.test("requireSchoolOperationalScope denies organization scope", () => {
  const orgClaims = { ...baseClaims, scope: "organization" as const, school_id: null };
  const response = requireSchoolOperationalScope(orgClaims);
  assertEquals(response?.status, 403);
});
