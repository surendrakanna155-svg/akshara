// QW4 · QA-B-005 — School Calendar ROUTE contract (DB-free).
//
// routeSchoolCalendar owns GET/POST /school-calendar and DELETE
// /school-calendar/{uuid}. Read gates on requirePermission("viewSchoolCalendar");
// write (POST create, DELETE) gates on requirePermission("manageSchoolCalendar")
// (school_calendar_handlers.ts:23,27, each chained with requireSchoolOperationalScope).
//
// PROVEN HERE (locally, DB-free):
//   * 503 (authorized) for a manageSchoolCalendar holder creating an event.
//   * 403 for a VIEW-ONLY holder (viewSchoolCalendar but not manageSchoolCalendar)
//     hitting POST — the manage gate.
//   * 503 for a viewSchoolCalendar holder on GET list.
//   * DELETE path: 503 for a manage holder, 403 for view-only.
//   * 422 on POST with missing eventDate/title or a bad eventType (before DB).
//   * 401 unauthenticated; 404 unregistered/non-UUID path.
//
// Live remainder: the actual persisted event row + read-back are covered by the
// repository test + the live cert (needs ERP_TENANT_DATABASE_URL).

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeSchoolCalendar } from "./school_calendar_router.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function claims(
  permissions: string[],
  over: Partial<AccessTokenClaims> = {},
): AccessTokenClaims {
  return {
    sub: "u1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "schoolAdmin",
    role_slugs: ["schoolAdmin"],
    primary_role: "schoolAdmin",
    permissions,
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
    ...over,
  };
}

async function call(
  method: string,
  path: string,
  permissions: string[] | null,
  body?: unknown,
): Promise<Response | null> {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (permissions !== null) {
    const token = await signAccessToken(SECRET, claims(permissions), 900);
    headers.authorization = `Bearer ${token}`;
  }
  const req = new Request(`https://x${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  return routeSchoolCalendar(req, config, method, path);
}

const validEvent = { eventDate: "2026-08-15", title: "Independence Day", eventType: "holiday" };
const EVENT_ID = "33333333-3333-4333-8333-333333333333";

Deno.test("QA-B-005: POST school-calendar authorizes a manageSchoolCalendar holder (503 persists)", async () => {
  const res = await call("POST", "/school-calendar", ["manageSchoolCalendar"], validEvent);
  assertEquals(res!.status, 503);
});

Deno.test("QA-B-005: POST school-calendar is denied for a VIEW-ONLY holder (403 manage gate)", async () => {
  const res = await call("POST", "/school-calendar", ["viewSchoolCalendar"], validEvent);
  assertEquals(res!.status, 403);
  const env = await res!.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("QA-B-005: GET school-calendar authorizes a viewSchoolCalendar holder (503)", async () => {
  const res = await call("GET", "/school-calendar", ["viewSchoolCalendar"]);
  assertEquals(res!.status, 503);
});

Deno.test("QA-B-005: GET school-calendar is denied for a non-holder (403)", async () => {
  const res = await call("GET", "/school-calendar", ["viewLibrary"]);
  assertEquals(res!.status, 403);
});

Deno.test("QA-B-005: DELETE school-calendar event authorizes a manage holder (503)", async () => {
  const res = await call("DELETE", `/school-calendar/${EVENT_ID}`, ["manageSchoolCalendar"]);
  assertEquals(res!.status, 503);
});

Deno.test("QA-B-005: DELETE school-calendar event is denied for a view-only holder (403)", async () => {
  const res = await call("DELETE", `/school-calendar/${EVENT_ID}`, ["viewSchoolCalendar"]);
  assertEquals(res!.status, 403);
});

Deno.test("QA-B-005: POST school-calendar rejects missing title (422 before DB)", async () => {
  const res = await call("POST", "/school-calendar", ["manageSchoolCalendar"], {
    eventDate: "2026-08-15",
  });
  assertEquals(res!.status, 422);
});

Deno.test("QA-B-005: POST school-calendar rejects an invalid eventType (422 before DB)", async () => {
  const res = await call("POST", "/school-calendar", ["manageSchoolCalendar"], {
    eventDate: "2026-08-15",
    title: "X",
    eventType: "not-a-type",
  });
  assertEquals(res!.status, 422);
});

Deno.test("QA-B-005: POST school-calendar rejects an unauthenticated caller (401)", async () => {
  const res = await call("POST", "/school-calendar", null, validEvent);
  assertEquals(res!.status, 401);
});

Deno.test("QA-B-005: a non-UUID delete path is not claimed by the router (null)", async () => {
  const res = await call("DELETE", "/school-calendar/not-a-uuid", ["manageSchoolCalendar"]);
  assertEquals(res, null);
});
