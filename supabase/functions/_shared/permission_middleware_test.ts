import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  requireAnyPermission,
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

// QW4-INV-OR — the OR-gate primitive that replaced the broken
// `requirePermission(a) ?? requirePermission(b)` chains (which collapsed into an AND).
Deno.test("requireAnyPermission grants when the caller holds the specific slug", () => {
  assertEquals(requireAnyPermission(baseClaims, ["viewAdmissions", "manageGrowthPlatform"]), null);
});

Deno.test("requireAnyPermission grants when the caller holds the broader fallback slug", () => {
  // baseClaims holds manageAdmissions but NOT manageGrowthPlatform — the OR fallback
  // (the exact case the old `??` chain wrongly denied) must now grant.
  assertEquals(requireAnyPermission(baseClaims, ["manageGrowthPlatform", "manageAdmissions"]), null);
});

Deno.test("requireAnyPermission denies when the caller holds NONE of the slugs", () => {
  const response = requireAnyPermission(baseClaims, ["manageGrowthPlatform", "viewFinance"]);
  assertEquals(response?.status, 403);
});

Deno.test("requireAnyPermission lists the accepted slugs in the 403 message", async () => {
  const response = requireAnyPermission(baseClaims, ["approveRefunds", "manageFinance"]);
  const body = await response!.json();
  assertEquals(body.error.message, "Permission required: one of approveRefunds, manageFinance");
});
