// W4 Staff Duty — router + RBAC contract (DB-free): 401 unauthenticated, 403
// without the right HR permission, 403 for a non-school scope even WITH the slug,
// and 503 (authorized, DB-off) with it. Writes need manageHr; reads accept
// viewHr OR manageHr. Validation (422) fires before any DB work.

import { assertEquals } from "jsr:@std/assert@1";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { matchStaffDutyRoute, routeStaffDuty } from "./staff_duty_router.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function claims(
  perms: string[],
  scope: "school" | "parent" | "student" = "school",
): AccessTokenClaims {
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
  // Production passes the routed PATHNAME (query is read from req.url by the
  // handler), so strip any query string before routing — mirroring routePath().
  const pathname = path.split("?")[0]!;
  return routeStaffDuty(req, config, method, pathname);
}

const SUB = "/hr/staff-duties/substitutions";
const INV = "/hr/staff-duties/invigilations";
const NT = "/hr/staff-duties/non-teaching";
const ROLLUP = "/hr/staff-duties/rollup";

const validSub = { absentTeacherId: "t-a", substituteTeacherId: "t-b", dutyDate: "2026-07-20" };
const validInv = { staffId: "s-1", dutyDate: "2026-07-20" };
const validNt = { staffId: "s-1", dutyType: "ground_duty", startDate: "2026-07-20" };

// ─── prefix / matching ──────────────────────────────────────────────────────

Deno.test("routeStaffDuty: returns null for a non-staff-duty path (parent dispatcher continues)", async () => {
  assertEquals(await call("GET", "/hr/payroll/run", ["viewHr"]), null);
});

Deno.test("routeStaffDuty: an unknown /hr/staff-duties path → null (central dispatcher 404s)", async () => {
  const res = await call("GET", "/hr/staff-duties/nope", ["viewHr"]);
  assertEquals(res, null);
});

Deno.test("matchStaffDutyRoute: every declared route resolves to a handler", () => {
  for (const [method, path] of [
    ["POST", SUB], ["GET", SUB],
    ["POST", INV], ["GET", INV],
    ["POST", NT], ["GET", NT],
    ["GET", ROLLUP],
  ] as const) {
    if (matchStaffDutyRoute(method, path) === null) {
      throw new Error(`no handler for ${method} ${path}`);
    }
  }
  // A write verb on the read-only rollup does not match.
  assertEquals(matchStaffDutyRoute("POST", ROLLUP), null);
});

// ─── writes need manageHr ───────────────────────────────────────────────────

Deno.test("create substitution: 401 unauthenticated", async () => {
  assertEquals((await call("POST", SUB, null, validSub))?.status, 401);
});

Deno.test("create substitution: 403 without manageHr (viewHr alone is not enough to write)", async () => {
  assertEquals((await call("POST", SUB, ["viewHr"], validSub))?.status, 403);
});

Deno.test("create substitution: 403 for a parent scope even WITH manageHr", async () => {
  assertEquals((await call("POST", SUB, ["manageHr"], validSub, "parent"))?.status, 403);
});

Deno.test("create substitution: authorized (manageHr) reaches the DB layer → 503 when DB-off", async () => {
  assertEquals((await call("POST", SUB, ["manageHr"], validSub))?.status, 503);
});

Deno.test("create invigilation: manageHr required (viewHr 403s, manageHr → 503)", async () => {
  assertEquals((await call("POST", INV, ["viewHr"], validInv))?.status, 403);
  assertEquals((await call("POST", INV, ["manageHr"], validInv))?.status, 503);
});

Deno.test("create non-teaching duty: manageHr required (viewHr 403s, manageHr → 503)", async () => {
  assertEquals((await call("POST", NT, ["viewHr"], validNt))?.status, 403);
  assertEquals((await call("POST", NT, ["manageHr"], validNt))?.status, 503);
});

// ─── reads accept viewHr OR manageHr ────────────────────────────────────────

Deno.test("list substitutions: viewHr is sufficient to read (→ 503 DB-off), no-perm 403", async () => {
  assertEquals((await call("GET", `${SUB}?staffId=s-1`, []))?.status, 403);
  assertEquals((await call("GET", `${SUB}?staffId=s-1`, ["viewHr"]))?.status, 503);
  assertEquals((await call("GET", `${SUB}?staffId=s-1`, ["manageHr"]))?.status, 503);
});

Deno.test("rollup: viewHr OR manageHr reads it (→ 503 DB-off); parent scope 403s", async () => {
  assertEquals((await call("GET", ROLLUP, ["viewHr"]))?.status, 503);
  assertEquals((await call("GET", ROLLUP, ["manageHr"]))?.status, 503);
  assertEquals((await call("GET", ROLLUP, ["viewHr"], undefined, "parent"))?.status, 403);
});

// ─── validation fires before any DB work ────────────────────────────────────

Deno.test("create substitution: missing dutyDate → 422 BEFORE the DB (authorized)", async () => {
  const res = await call("POST", SUB, ["manageHr"], { absentTeacherId: "a", substituteTeacherId: "b" });
  assertEquals(res?.status, 422);
  assertEquals((await res!.json()).error.code, "STAFF_DUTY_DATE_REQUIRED");
});

Deno.test("create non-teaching duty: endDate before startDate → 422 range error", async () => {
  const res = await call("POST", NT, ["manageHr"], {
    staffId: "s-1", dutyType: "event", startDate: "2026-07-20", endDate: "2026-07-19",
  });
  assertEquals(res?.status, 422);
  assertEquals((await res!.json()).error.code, "STAFF_DUTY_RANGE_INVALID");
});

Deno.test("list: neither ?staffId= nor ?date= → 422 filter required", async () => {
  const res = await call("GET", INV, ["viewHr"]);
  assertEquals(res?.status, 422);
  assertEquals((await res!.json()).error.code, "STAFF_DUTY_FILTER_REQUIRED");
});
