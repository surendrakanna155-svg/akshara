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
      student_id: null,
      child_ids: [],
      session_id: "session-1",
    },
    900,
  );

  const claims = await verifyAccessToken(TEST_SECRET, token);
  assertEquals(claims?.primary_role, "coordinator");
  assertEquals(claims?.role_slugs, ["teacher", "coordinator"]);
  assertEquals(claims?.role, "coordinator");
  assertEquals(claims?.permissions_version, 2);
  assertEquals(claims?.child_ids, []);
});

Deno.test("JWT includes parent and student scope claims", async () => {
  const token = await signAccessToken(
    TEST_SECRET,
    {
      sub: "parent-1",
      tenant_id: "org-1",
      organization_id: "org-1",
      school_id: "school-1",
      role: "parent",
      role_slugs: ["parent"],
      primary_role: "parent",
      permissions: ["viewSis", "viewFinance"],
      permissions_version: 1,
      scope: "parent",
      school_group_id: null,
      student_id: null,
      child_ids: ["child-1", "child-2"],
      session_id: "session-2",
    },
    900,
  );

  const claims = await verifyAccessToken(TEST_SECRET, token);
  assertEquals(claims?.scope, "parent");
  assertEquals(claims?.child_ids, ["child-1", "child-2"]);

  const studentToken = await signAccessToken(
    TEST_SECRET,
    {
      sub: "student-user-1",
      tenant_id: "org-1",
      organization_id: "org-1",
      school_id: "school-1",
      role: "student",
      role_slugs: ["student"],
      primary_role: "student",
      permissions: ["viewSis"],
      permissions_version: 1,
      scope: "student",
      school_group_id: null,
      student_id: "student-record-1",
      child_ids: [],
      session_id: "session-3",
    },
    900,
  );

  const studentClaims = await verifyAccessToken(TEST_SECRET, studentToken);
  assertEquals(studentClaims?.scope, "student");
  assertEquals(studentClaims?.student_id, "student-record-1");
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
      student_id: null,
      child_ids: [],
      session_id: "session-1",
    },
    900,
  );

  const claims = await verifyAccessToken(TEST_SECRET, token);
  assertEquals(claims?.role_slugs, ["schoolAdmin"]);
});
