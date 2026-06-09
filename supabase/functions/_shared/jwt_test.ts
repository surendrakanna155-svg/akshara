import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { signAccessToken, verifyAccessToken } from "./jwt.ts";

const TEST_SECRET = "test-jwt-secret-minimum-32-characters-long";

Deno.test("JWT includes role_slugs and primary_role claims", async () => {
  const token = await signAccessToken(
    TEST_SECRET,
    {
      sub: "user-1",
      tenant_id: "org-1",
      organization_id: "org-1",
      school_id: "school-1",
      role: "coordinator",
      role_slugs: ["teacher", "coordinator"],
      primary_role: "coordinator",
      permissions: ["viewAdminHub", "manageAdmissions"],
      permissions_version: 2,
      scope: "school",
      school_group_id: null,
      session_id: "session-1",
    },
    900,
  );

  const claims = await verifyAccessToken(TEST_SECRET, token);
  assertEquals(claims?.primary_role, "coordinator");
  assertEquals(claims?.role_slugs, ["teacher", "coordinator"]);
  assertEquals(claims?.role, "coordinator");
  assertEquals(claims?.permissions_version, 2);
});

Deno.test("JWT verify backfills role_slugs from legacy role claim", async () => {
  const token = await signAccessToken(
    TEST_SECRET,
    {
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
      session_id: "session-1",
    },
    900,
  );

  const claims = await verifyAccessToken(TEST_SECRET, token);
  assertEquals(claims?.role_slugs, ["schoolAdmin"]);
});
