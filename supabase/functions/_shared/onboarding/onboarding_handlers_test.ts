import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { requireOnboardingView } from "./onboarding_handlers.ts";

function schoolClaims(permissions: string[]): AccessTokenClaims {
  return {
    sub: "a3000000-0000-4000-8000-000000000001",
    tenant_id: "a1000000-0000-4000-8000-000000000001",
    organization_id: "a1000000-0000-4000-8000-000000000001",
    school_id: "a2000000-0000-4000-8000-000000000001",
    role: "principal",
    role_slugs: ["principal"],
    primary_role: "principal",
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    permissions,
    session_id: "sess",
  };
}

Deno.test("viewOnboarding alone grants read access without manageOnboarding", () => {
  const denied = requireOnboardingView(schoolClaims(["viewOnboarding"]));
  assertEquals(denied, null);
});

Deno.test("manageOnboarding grants read access", () => {
  const denied = requireOnboardingView(schoolClaims(["manageOnboarding"]));
  assertEquals(denied, null);
});

Deno.test("missing onboarding permissions is denied", () => {
  const denied = requireOnboardingView(schoolClaims(["viewSis"]));
  assertEquals(denied?.status, 403);
});
