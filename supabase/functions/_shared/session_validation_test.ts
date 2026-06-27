import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { evaluateSessionState } from "./session_validation.ts";
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
  permissions_version: 2,
  scope: "school",
  school_group_id: null,
  student_id: null,
  child_ids: [],
  session_id: "sess-1",
};

Deno.test("RT-16: live session + matching version is allowed", () => {
  const verdict = evaluateSessionState(
    baseClaims,
    { revoked_at: null },
    { permissions_version: 2 },
  );
  assertEquals(verdict.ok, true);
});

Deno.test("RT-16: missing session is rejected", () => {
  const verdict = evaluateSessionState(baseClaims, null, { permissions_version: 2 });
  assertEquals(verdict.ok, false);
  if (!verdict.ok) assertEquals(verdict.code, "SESSION_INVALID");
});

Deno.test("RT-16: revoked session is rejected", () => {
  const verdict = evaluateSessionState(
    baseClaims,
    { revoked_at: "2026-06-27T00:00:00Z" },
    { permissions_version: 2 },
  );
  assertEquals(verdict.ok, false);
  if (!verdict.ok) assertEquals(verdict.code, "SESSION_REVOKED");
});

Deno.test("RT-17: stale permissions_version is rejected (school scope)", () => {
  const verdict = evaluateSessionState(
    baseClaims,
    { revoked_at: null },
    { permissions_version: 3 }, // membership was bumped after the token was minted
  );
  assertEquals(verdict.ok, false);
  if (!verdict.ok) assertEquals(verdict.code, "PERMISSIONS_STALE");
});

Deno.test("RT-17: removed membership is rejected (school scope)", () => {
  const verdict = evaluateSessionState(baseClaims, { revoked_at: null }, null);
  assertEquals(verdict.ok, false);
  if (!verdict.ok) assertEquals(verdict.code, "MEMBERSHIP_REVOKED");
});

Deno.test("RT-17: organization scope also checks the membership version", () => {
  const orgClaims: AccessTokenClaims = {
    ...baseClaims,
    scope: "organization",
    school_id: null,
  };
  const stale = evaluateSessionState(
    orgClaims,
    { revoked_at: null },
    { permissions_version: 99 },
  );
  assertEquals(stale.ok, false);
  if (!stale.ok) assertEquals(stale.code, "PERMISSIONS_STALE");

  const fresh = evaluateSessionState(
    orgClaims,
    { revoked_at: null },
    { permissions_version: 2 },
  );
  assertEquals(fresh.ok, true);
});

Deno.test("RT-17: relationship scopes skip the version check (no membership row)", () => {
  for (const scope of ["parent", "student"] as const) {
    const relClaims: AccessTokenClaims = { ...baseClaims, scope };
    const verdict = evaluateSessionState(relClaims, { revoked_at: null }, null);
    assertEquals(verdict.ok, true, `${scope} with a live session should pass`);
  }
});
