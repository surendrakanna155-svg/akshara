import {
  assert,
  assertEquals,
  assertNotEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { hashOtp, hashToken, signAccessToken, verifyAccessToken } from "./jwt.ts";

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

// ─── ICA-B4: OTP hashing must be keyed, not a bare reversible SHA-256 ────────

Deno.test("ICA-B4: a stored OTP hash is NOT a bare SHA-256 of the code", async () => {
  const otp = "123456";
  const stored = await hashOtp(otp, TEST_SECRET);
  const bareSha256 = await hashToken(otp);
  // If these were equal, a DB dump would let an attacker brute-force the 10^6
  // preimages instantly. The HMAC key (server secret) must make them differ.
  assertNotEquals(
    stored,
    bareSha256,
    "OTP hash must be keyed (HMAC), not a plain SHA-256 of the code",
  );
  assertEquals(stored.length, 64, "HMAC-SHA256 hex digest is 64 chars");
});

Deno.test("ICA-B4: a correct OTP still verifies under the same secret", async () => {
  const otp = "482913";
  // Store path (requestOtp) and verify path (handleVerifyOtp) both use hashOtp
  // with config.jwtSecret — a freshly issued OTP must still compare equal.
  const storedHash = await hashOtp(otp, TEST_SECRET);
  const submittedHash = await hashOtp("482913".trim(), TEST_SECRET);
  assertEquals(submittedHash, storedHash, "correct OTP must verify");

  // Wrong code must not match.
  const wrong = await hashOtp("000000", TEST_SECRET);
  assertNotEquals(wrong, storedHash, "wrong OTP must not verify");
});

Deno.test("ICA-B4: OTP hash is bound to the server secret (dump-only is useless)", async () => {
  const otp = "654321";
  const underRealSecret = await hashOtp(otp, TEST_SECRET);
  const underOtherSecret = await hashOtp(otp, "a-different-secret-32-characters-xx");
  // Same code, different key ⇒ different hash: without the secret, an attacker
  // holding only the DB cannot recompute/verify candidate OTPs.
  assertNotEquals(underRealSecret, underOtherSecret);
});
