// QW4 · QA-B-030, QA-B-048 — Academic Timetable ROUTE contract + RBAC (DB-free).
//
// Proven without a live Postgres (QW1 pattern): the timetable routes match
// routeTimetable, an unregistered /academic/timetables path 404s, and the three
// mutating POSTs (generate, validate, periods/move) are denied for a non-holder
// (403) yet, with manageAcademicTimetable + a valid body, pass through to the
// unconfigured tenant DB (503). Reads gate on viewAcademicTimetable; publish on
// publishAcademicTimetable. The actual generated grids / conflict detection are
// the live-cert remainder (timetable_engine_test.ts proves the algorithm).

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeTimetable } from "./timetable_router.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function claims(perms: string[], over: Partial<AccessTokenClaims> = {}): AccessTokenClaims {
  return {
    sub: "u1", tenant_id: "org-1", organization_id: "org-1", school_id: "school-1",
    role: "academicAdmin", role_slugs: ["academicAdmin"], primary_role: "academicAdmin",
    permissions: perms, permissions_version: 1, scope: "school",
    school_group_id: null, student_id: null, child_ids: [], session_id: "s1", ...over,
  };
}

async function raw(
  method: string, pathWithQuery: string, perms: string[], body?: unknown,
): Promise<Response | null> {
  const token = await signAccessToken(SECRET, claims(perms), 900);
  const init: RequestInit = {
    method,
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
  };
  if (body !== undefined) init.body = JSON.stringify(body);
  // The central dispatcher (routePath) strips the query string before path
  // matching, so the router always receives a query-free path. Mirror that here.
  const path = pathWithQuery.split("?")[0];
  return await routeTimetable(new Request(`https://x${pathWithQuery}`, init), config, method, path);
}

async function call(
  method: string, path: string, perms: string[], body?: unknown,
): Promise<Response> {
  const res = await raw(method, path, perms, body);
  if (res === null) throw new Error(`routeTimetable returned null for ${method} ${path}`);
  return res;
}

Deno.test("QA-B-030: the 7 timetable routes match the router", async () => {
  const v = ["viewAcademicTimetable"];
  const m = ["manageAcademicTimetable"];
  // GET reads (need ?academicYearId for summary/workload/conflicts → 503 once gated).
  assertEquals((await call("GET", "/academic/timetables/summary?academicYearId=ay-1", v)).status, 503);
  assertEquals((await call("GET", "/academic/timetables/workload?academicYearId=ay-1", v)).status, 503);
  assertEquals((await call("GET", "/academic/timetables/conflicts?academicYearId=ay-1", v)).status, 503);
  // GET list (academicYearId optional) → 503.
  assertEquals((await call("GET", "/academic/timetables", v)).status, 503);
  // POST mutations with valid bodies → 503 (gate + validation passed).
  assertEquals((await call("POST", "/academic/timetables/generate", m, { academicYearId: "ay-1" })).status, 503);
  assertEquals((await call("POST", "/academic/timetables/validate", m, { timetableId: "tt-1" })).status, 503);
  assertEquals((await call("POST", "/academic/timetables/periods/move", m, {
    periodId: "p-1", targetDayOfWeek: 2, targetPeriodNumber: 3,
  })).status, 503);
});

Deno.test("QA-B-030: an unregistered timetable path returns 404 NOT_FOUND", async () => {
  const res = await call("GET", "/academic/timetables/nope/extra", ["viewAcademicTimetable"]);
  assertEquals(res.status, 404);
  const env = await res.json();
  assertEquals(env.error.code, "NOT_FOUND");
});

Deno.test("QA-B-030: a non-timetable path returns null (no match)", async () => {
  assertEquals(await raw("GET", "/analytics/dashboard", ["viewAcademicTimetable"]), null);
});

Deno.test("QA-B-030: POST generate is denied for a non-holder (403 FORBIDDEN)", async () => {
  const res = await call("POST", "/academic/timetables/generate", ["viewAcademicTimetable"], {
    academicYearId: "ay-1",
  });
  assertEquals(res.status, 403);
  const env = await res.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("QA-B-030: POST generate rejects a missing academicYearId (422) before the DB", async () => {
  const res = await call("POST", "/academic/timetables/generate", ["manageAcademicTimetable"], {});
  assertEquals(res.status, 422);
});

Deno.test("QA-B-030: POST periods/move rejects a missing periodId (422) before the DB", async () => {
  const res = await call("POST", "/academic/timetables/periods/move", ["manageAcademicTimetable"], {
    targetDayOfWeek: 2, targetPeriodNumber: 3,
  });
  assertEquals(res.status, 422);
});

// ─── QA-B-048 — timetable manage RBAC ───────────────────────────────────────────
Deno.test("QA-B-048: generate, validate, and move all require manageAcademicTimetable (403 otherwise)", async () => {
  // The view permission must NOT unlock the mutations.
  const v = ["viewAcademicTimetable"];
  const cases: Array<[string, unknown]> = [
    ["/academic/timetables/generate", { academicYearId: "ay-1" }],
    ["/academic/timetables/validate", { timetableId: "tt-1" }],
    ["/academic/timetables/periods/move", { periodId: "p-1", targetDayOfWeek: 2, targetPeriodNumber: 3 }],
  ];
  for (const [path, body] of cases) {
    const res = await call("POST", path, v, body);
    assertEquals(res.status, 403, `${path} should 403 with only viewAcademicTimetable`);
    const env = await res.json();
    assertEquals(env.error.code, "FORBIDDEN");
  }
});

Deno.test("QA-B-048: manageAcademicTimetable authorizes all three mutations (reaches DB → 503)", async () => {
  const m = ["manageAcademicTimetable"];
  const cases: Array<[string, unknown]> = [
    ["/academic/timetables/generate", { academicYearId: "ay-1" }],
    ["/academic/timetables/validate", { timetableId: "tt-1" }],
    ["/academic/timetables/periods/move", { periodId: "p-1", targetDayOfWeek: 2, targetPeriodNumber: 3 }],
  ];
  for (const [path, body] of cases) {
    const res = await call("POST", path, m, body);
    assertEquals(res.status, 503, `${path} should reach DB with manageAcademicTimetable`);
  }
});

Deno.test("QA-B-048: an unauthenticated caller is rejected (401) on a timetable route", async () => {
  const res = await routeTimetable(
    new Request("https://x/academic/timetables", { method: "GET" }),
    config, "GET", "/academic/timetables",
  );
  assertEquals(res?.status, 401);
});

// ─── Gap #8 — persisted substitution routes (contract + RBAC) ──────────────────
const SUB = ["manageTimetableSubstitution"];
const VIEW = ["viewAcademicTimetable"];
const SUB_UUID = "d0500000-0000-4000-8000-0000000000aa";

Deno.test("GAP8: the 4 substitution routes match the router and reach the DB (503) when authorized", async () => {
  // POST create (manageTimetableSubstitution) with a valid body → gate+validation pass → 503.
  assertEquals(
    (await call("POST", "/academic/timetables/substitutions", SUB, {
      periodId: "d0500000-0000-4000-8000-000000000001",
      subDate: "2026-07-06",
      substituteTeacherId: "b0000000-0000-4000-8000-000000000001",
    })).status,
    503,
  );
  // GET list + candidates (viewAcademicTimetable, ?date required) → 503.
  assertEquals(
    (await call("GET", "/academic/timetables/substitutions?date=2026-07-06", VIEW)).status,
    503,
  );
  assertEquals(
    (await call("GET", "/academic/timetables/substitutions/candidates?date=2026-07-06", VIEW)).status,
    503,
  );
  // DELETE by id (manageTimetableSubstitution) → 503.
  assertEquals(
    (await call("DELETE", `/academic/timetables/substitutions/${SUB_UUID}`, SUB)).status,
    503,
  );
});

Deno.test("GAP8: create + delete substitution require manageTimetableSubstitution (403 for view-only)", async () => {
  const create = await call("POST", "/academic/timetables/substitutions", VIEW, {
    periodId: "d0500000-0000-4000-8000-000000000001",
    subDate: "2026-07-06",
    substituteTeacherId: "b0000000-0000-4000-8000-000000000001",
  });
  assertEquals(create.status, 403);
  assertEquals((await create.json()).error.code, "FORBIDDEN");

  const del = await call("DELETE", `/academic/timetables/substitutions/${SUB_UUID}`, VIEW);
  assertEquals(del.status, 403);
  assertEquals((await del.json()).error.code, "FORBIDDEN");
});

Deno.test("GAP8: substitution reads require viewAcademicTimetable (403 without it)", async () => {
  const noPerms: string[] = [];
  assertEquals(
    (await call("GET", "/academic/timetables/substitutions?date=2026-07-06", noPerms)).status,
    403,
  );
  assertEquals(
    (await call("GET", "/academic/timetables/substitutions/candidates?date=2026-07-06", noPerms)).status,
    403,
  );
});

Deno.test("GAP8: create rejects a missing field (422) before the DB", async () => {
  const res = await call("POST", "/academic/timetables/substitutions", SUB, {
    subDate: "2026-07-06",
  });
  assertEquals(res.status, 422);
});

Deno.test("GAP8: list/candidates require a ?date param (422) before the DB", async () => {
  assertEquals((await call("GET", "/academic/timetables/substitutions", VIEW)).status, 422);
  assertEquals(
    (await call("GET", "/academic/timetables/substitutions/candidates", VIEW)).status,
    422,
  );
});

Deno.test("GAP8: substitutions/candidates matches BEFORE the /:id delete route", async () => {
  // 'candidates' must resolve to the candidates handler (a GET), never be
  // swallowed by the DELETE /:id matcher. A GET to it with view perms → 503.
  const res = await call("GET", "/academic/timetables/substitutions/candidates?date=2026-07-06", VIEW);
  assertEquals(res.status, 503);
});
