// SCE-1 slice 3 — waiver handler RBAC contract (DB-free): 401 unauthenticated,
// 403 without the right permission (maker=manageSis, checker=approveClearance
// Waiver), and 503 (authorized, DB-off) with it. Parents/students never reach
// any of them. The SoD (maker != checker) is proven at the repository layer
// (clearance_waiver_repository_test.ts); this proves the gate split.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeSis } from "../sis/sis_router.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function claims(perms: string[], scope: "school" | "parent" | "student" = "school"): AccessTokenClaims {
  return {
    sub: "u1", tenant_id: "org-1", organization_id: "org-1", school_id: "school-1",
    role: "schoolAdmin", role_slugs: ["schoolAdmin"], primary_role: "schoolAdmin",
    permissions: perms, permissions_version: 1, scope, school_group_id: null,
    student_id: null, child_ids: [], session_id: "s1",
  };
}

async function call(
  method: string,
  path: string,
  perms: string[] | null,
  body?: unknown,
  scope: "school" | "parent" | "student" = "school",
): Promise<Response | null> {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (perms !== null) {
    headers.authorization = `Bearer ${await signAccessToken(SECRET, claims(perms, scope), 900)}`;
  }
  const req = new Request(`https://x${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  return routeSis(req, config, method, path);
}

const STU = "/sis/students/a4000000-0000-4000-8000-000000000001/clearance/waivers";
const validRaise = { reason: "waive a small remaining balance" };

Deno.test("waiver raise: 401 unauthenticated", async () => {
  const res = await call("POST", STU, null, validRaise);
  assertEquals(res?.status, 401);
});

Deno.test("waiver raise: 403 without manageSis (maker permission)", async () => {
  const res = await call("POST", STU, ["viewSis"], validRaise);
  assertEquals(res?.status, 403);
});

Deno.test("waiver raise: 403 for a parent/student scope even with the slug", async () => {
  const res = await call("POST", STU, ["manageSis"], validRaise, "parent");
  assertEquals(res?.status, 403);
});

Deno.test("waiver raise: authorized (manageSis) reaches the DB layer → 503 when DB-off", async () => {
  const res = await call("POST", STU, ["manageSis"], validRaise);
  assertEquals(res?.status, 503);
});

Deno.test("waiver raise: a too-short reason 422s BEFORE any DB work", async () => {
  const res = await call("POST", STU, ["manageSis"], { reason: "x" });
  assertEquals(res?.status, 422);
  assertEquals((await res!.json()).error.code, "CLEARANCE_WAIVER_REASON_REQUIRED");
});

Deno.test("waiver queue: the checker permission is REQUIRED (manageSis alone 403s)", async () => {
  const denied = await call("GET", "/sis/clearance/waivers", ["manageSis"]);
  assertEquals(denied?.status, 403);
  const allowed = await call("GET", "/sis/clearance/waivers", ["approveClearanceWaiver"]);
  assertEquals(allowed?.status, 503);
});

Deno.test("waiver decide: needs approveClearanceWaiver (checker); manageSis alone 403s", async () => {
  const path = "/sis/clearance/waivers/w-1/decide";
  const denied = await call("POST", path, ["manageSis"], { approve: true });
  assertEquals(denied?.status, 403);
  const allowed = await call("POST", path, ["approveClearanceWaiver"], { approve: true });
  assertEquals(allowed?.status, 503);
});

Deno.test("waiver revoke: needs approveClearanceWaiver (checker); manageSis alone 403s", async () => {
  const path = "/sis/clearance/waivers/w-1/revoke";
  const denied = await call("POST", path, ["manageSis"], {});
  assertEquals(denied?.status, 403);
  const allowed = await call("POST", path, ["approveClearanceWaiver"], {});
  assertEquals(allowed?.status, 503);
});
