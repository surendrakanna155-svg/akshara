// OFFICE / ADMIN student-attendance reads — ROUTE + RBAC + SHAPE contract (DB-free).
//
// Covers ATT-1 (register), ATT-2 (monthly), ATT-4 (pending), ATT-D1 (consecutive
// absence), ATT-D2 (short attendance). All are READ-only and gate on viewSis +
// school scope. Proven without a live Postgres:
//   1. PATH-MATCH: each route resolves to a handler (not 404); an unregistered
//      path under the prefix 404s; a path outside the prefix returns null.
//   2. RBAC: 401 unauthenticated; 403 without viewSis; 503 (authorized, DB-free)
//      with viewSis + a valid query — i.e. it reached the tenant DB seam.
//   3. SHAPE hard-blocks server-side BEFORE any DB work (422): missing/invalid
//      classLabel, date, month, days, threshold.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { matchAttendanceRoute, routeAttendance } from "./attendance_router.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function claims(perms: string[]): AccessTokenClaims {
  return {
    sub: "u1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "office",
    role_slugs: ["office"],
    primary_role: "office",
    permissions: perms,
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
  };
}

// Calls the route with the FULL query string preserved on the Request URL.
async function callFull(
  method: string,
  fullPath: string,
  perms: string[],
): Promise<Response | null> {
  const token = await signAccessToken(SECRET, claims(perms), 900);
  const req = new Request(`https://x${fullPath}`, {
    method,
    headers: { authorization: `Bearer ${token}` },
  });
  const path = fullPath.split("?")[0]!;
  return routeAttendance(req, config, method, path);
}

const OFFICE_ROUTES = [
  "/attendance/register?classLabel=8-A&date=2026-07-01",
  "/attendance/register/monthly?classLabel=8-A&month=2026-07",
  "/attendance/pending?date=2026-07-01",
  "/attendance/alerts/consecutive-absence?days=3",
  "/attendance/alerts/short-attendance?threshold=75",
] as const;

Deno.test("office-attendance: the 5 read routes path-match handlers (not 404)", () => {
  for (const full of OFFICE_ROUTES) {
    const path = full.split("?")[0]!;
    const match = matchAttendanceRoute("GET", path);
    assertEquals(match !== null, true, `${path} should resolve to a handler`);
  }
});

Deno.test("office-attendance: unregistered path under prefix returns null (central dispatcher 404s); outside prefix is null", async () => {
  const under = await callFull("GET", "/attendance/nope", ["viewSis"]);
  assertEquals(under, null);
  const outside = await routeAttendance(
    new Request("https://x/staff-attendance/check", { method: "POST" }),
    config,
    "POST",
    "/staff-attendance/check",
  );
  assertEquals(outside, null);
});

Deno.test("office-attendance: unauthenticated is 401", async () => {
  for (const full of OFFICE_ROUTES) {
    const req = new Request(`https://x${full}`, { method: "GET" });
    const path = full.split("?")[0]!;
    const res = await routeAttendance(req, config, "GET", path);
    // Note: routeAttendance matches on the path only; the query string travels
    // on the Request URL, which the handler reads.
    assertEquals(res?.status, 401, `${full} unauthenticated should 401`);
  }
});

Deno.test("office-attendance: 403 without viewSis", async () => {
  for (const full of OFFICE_ROUTES) {
    const res = await callFull("GET", full, []);
    assertEquals(res?.status, 403, `${full} without viewSis should 403`);
    assertEquals((await res!.json()).error.code, "FORBIDDEN");
  }
});

Deno.test("office-attendance: 503 (authorized, DB-free) with viewSis + valid query", async () => {
  for (const full of OFFICE_ROUTES) {
    const res = await callFull("GET", full, ["viewSis"]);
    assertEquals(res?.status, 503, `${full} authorized DB-free should 503`);
  }
});

Deno.test("office-attendance: SHAPE 422 before DB — register needs classLabel + valid date", async () => {
  const noClass = await callFull("GET", "/attendance/register?date=2026-07-01", ["viewSis"]);
  assertEquals(noClass?.status, 422);
  assertEquals((await noClass!.json()).error.code, "ATTENDANCE_VALIDATION");

  const badDate = await callFull(
    "GET",
    "/attendance/register?classLabel=8-A&date=07-2026",
    ["viewSis"],
  );
  assertEquals(badDate?.status, 422);
});

Deno.test("office-attendance: SHAPE 422 — monthly needs classLabel + YYYY-MM month", async () => {
  const noMonth = await callFull("GET", "/attendance/register/monthly?classLabel=8-A", ["viewSis"]);
  assertEquals(noMonth?.status, 422);

  const badMonth = await callFull(
    "GET",
    "/attendance/register/monthly?classLabel=8-A&month=2026-7",
    ["viewSis"],
  );
  assertEquals(badMonth?.status, 422);
});

Deno.test("office-attendance: SHAPE 422 — pending needs a valid date", async () => {
  const bad = await callFull("GET", "/attendance/pending?date=nope", ["viewSis"]);
  assertEquals(bad?.status, 422);
});

Deno.test("office-attendance: SHAPE 422 — consecutive-absence days out of range", async () => {
  const zero = await callFull("GET", "/attendance/alerts/consecutive-absence?days=0", ["viewSis"]);
  assertEquals(zero?.status, 422);
  const huge = await callFull("GET", "/attendance/alerts/consecutive-absence?days=999", ["viewSis"]);
  assertEquals(huge?.status, 422);
});

Deno.test("office-attendance: SHAPE 422 — short-attendance threshold out of range", async () => {
  const zero = await callFull("GET", "/attendance/alerts/short-attendance?threshold=0", ["viewSis"]);
  assertEquals(zero?.status, 422);
  const over = await callFull("GET", "/attendance/alerts/short-attendance?threshold=101", ["viewSis"]);
  assertEquals(over?.status, 422);
});

Deno.test("office-attendance: short-attendance defaults threshold to 75 (authorized → 503, not 422)", async () => {
  const res = await callFull("GET", "/attendance/alerts/short-attendance", ["viewSis"]);
  assertEquals(res?.status, 503);
});
