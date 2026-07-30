// ICA-C3 (P1, perf) — listAttendanceSessions is bounded.
//
// The list used to run `SELECT s.*, count(ar.id) … LEFT JOIN attendance_records
// … GROUP BY s.id ORDER BY s.session_date DESC` with NO LIMIT and NO date
// filter — a full-table scan over the entire session history. It now paginates
// (page/pageSize, hard-capped at 100 via the shared clampPageSize) and applies a
// trailing date window (default 90 days, override up to 366), and returns a
// PaginationResult. These tests use the module's fake-db pattern to prove:
//   (1) a request with no options returns a bounded page with the date default;
//   (2) page/pageSize are respected and pageSize is capped at 100;
//   (3) record_count is carried through correctly for the returned sessions.
// Route/RBAC/validation for the handler are covered further down (DB-free).

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import {
  DEFAULT_SESSIONS_PAGE_SIZE,
  DEFAULT_SESSIONS_WINDOW_DAYS,
  listAttendanceSessions,
  MAX_SESSIONS_WINDOW_DAYS,
} from "./attendance_sessions_repository.ts";
import { matchAttendanceRoute, routeAttendance } from "./attendance_router.ts";

const ORG = "org-1";
const SCHOOL = "school-1";

interface Capture {
  sql: string;
  args: unknown[];
}

// The page query is matched on the LEFT JOIN (record_count SELECT); the COUNT
// query is matched on its `AS total` projection. Everything else falls through
// to an empty result.
function mockDb(
  page: unknown[],
  total: number,
  captures: Capture[] = [],
): TenantQueryClient {
  return {
    queryObject: async <T>(sql: string, args: unknown[] = []) => {
      captures.push({ sql, args });
      if (sql.includes("AS total")) {
        return [{ total: String(total) }] as unknown as T[];
      }
      if (sql.includes("LEFT JOIN attendance_records")) {
        return page as T[];
      }
      return [] as T[];
    },
  } as unknown as TenantQueryClient;
}

function sessionRow(overrides: Record<string, unknown> = {}) {
  return {
    id: "sess-1",
    organization_id: ORG,
    school_id: SCHOOL,
    class_label: "8-A",
    session_date: "2026-07-20",
    taken_by: "teacher-1",
    status: "submitted",
    created_at: "2026-07-20T09:00:00Z",
    updated_at: "2026-07-20T09:05:00Z",
    record_count: 30,
    ...overrides,
  };
}

// (1) No options → bounded page with the date default applied.
Deno.test("listAttendanceSessions: no options → default page, default window, LIMIT applied", async () => {
  const captures: Capture[] = [];
  const db = mockDb([sessionRow()], 1, captures);

  const result = await listAttendanceSessions(db, ORG, SCHOOL);

  assertEquals(result.page, 1);
  assertEquals(result.pageSize, DEFAULT_SESSIONS_PAGE_SIZE);
  assertEquals(result.total, 1);
  assertEquals(result.items.length, 1);
  assertEquals(result.hasMore, false);

  // The page query is bounded: it carries a LIMIT + OFFSET and the date window.
  const pageQuery = captures.find((c) =>
    c.sql.includes("LEFT JOIN attendance_records")
  )!;
  assertEquals(pageQuery.sql.includes("LIMIT $4 OFFSET $5"), true);
  assertEquals(pageQuery.sql.includes("s.session_date >= (CURRENT_DATE - $3::int)"), true);
  // args = [org, school, windowDays, pageSize, offset]
  assertEquals(pageQuery.args[2], DEFAULT_SESSIONS_WINDOW_DAYS);
  assertEquals(pageQuery.args[3], DEFAULT_SESSIONS_PAGE_SIZE);
  assertEquals(pageQuery.args[4], 0);

  // The COUNT is bounded to the same window (never the whole table).
  const countQuery = captures.find((c) => c.sql.includes("AS total"))!;
  assertEquals(countQuery.sql.includes("s.session_date >= (CURRENT_DATE - $3::int)"), true);
  assertEquals(countQuery.args[2], DEFAULT_SESSIONS_WINDOW_DAYS);
});

// (2a) pageSize is capped at the hard 100 cap even when a larger value is asked.
Deno.test("listAttendanceSessions: pageSize is hard-capped at 100", async () => {
  const captures: Capture[] = [];
  const db = mockDb([], 0, captures);

  const result = await listAttendanceSessions(db, ORG, SCHOOL, {
    page: 1,
    pageSize: 500,
  });

  assertEquals(result.pageSize, 100);
  const pageQuery = captures.find((c) =>
    c.sql.includes("LEFT JOIN attendance_records")
  )!;
  assertEquals(pageQuery.args[3], 100); // clamped LIMIT
});

// (2b) page/pageSize are respected and drive the OFFSET; hasMore reflects total.
Deno.test("listAttendanceSessions: page + pageSize respected → correct OFFSET and hasMore", async () => {
  const captures: Capture[] = [];
  // page 3, pageSize 20 → offset 40; total 100 → still more after this page.
  const db = mockDb([sessionRow(), sessionRow({ id: "sess-2" })], 100, captures);

  const result = await listAttendanceSessions(db, ORG, SCHOOL, {
    page: 3,
    pageSize: 20,
  });

  assertEquals(result.page, 3);
  assertEquals(result.pageSize, 20);
  assertEquals(result.total, 100);
  assertEquals(result.hasMore, true); // 40 + 2 < 100

  const pageQuery = captures.find((c) =>
    c.sql.includes("LEFT JOIN attendance_records")
  )!;
  assertEquals(pageQuery.args[3], 20); // LIMIT
  assertEquals(pageQuery.args[4], 40); // OFFSET = (3-1)*20
});

// (2c) windowDays override is clamped to the 366 max.
Deno.test("listAttendanceSessions: windowDays override is clamped to the max", async () => {
  const captures: Capture[] = [];
  const db = mockDb([], 0, captures);

  await listAttendanceSessions(db, ORG, SCHOOL, { windowDays: 99999 });

  const pageQuery = captures.find((c) =>
    c.sql.includes("LEFT JOIN attendance_records")
  )!;
  assertEquals(pageQuery.args[2], MAX_SESSIONS_WINDOW_DAYS);
});

// (3) record_count is carried through correctly for the returned sessions.
Deno.test("listAttendanceSessions: record_count is preserved per returned session", async () => {
  const db = mockDb(
    [
      sessionRow({ id: "sess-a", record_count: 42 }),
      sessionRow({ id: "sess-b", record_count: 0 }),
    ],
    2,
  );

  const result = await listAttendanceSessions(db, ORG, SCHOOL);

  assertEquals(result.items.map((r) => r.id), ["sess-a", "sess-b"]);
  assertEquals(result.items.map((r) => r.record_count), [42, 0]);
});

// --- Handler: route + RBAC + validation (DB-free) ----------------------------

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function claims(perms: string[]): AccessTokenClaims {
  return {
    sub: "u1",
    tenant_id: ORG,
    organization_id: ORG,
    school_id: SCHOOL,
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

Deno.test("sessions route: GET /attendance/sessions path-matches a handler", () => {
  const match = matchAttendanceRoute("GET", "/attendance/sessions");
  assertEquals(match !== null, true);
});

Deno.test("sessions route: unauthenticated is 401", async () => {
  const req = new Request("https://x/attendance/sessions", { method: "GET" });
  const res = await routeAttendance(req, config, "GET", "/attendance/sessions");
  assertEquals(res?.status, 401);
});

Deno.test("sessions route: 403 without viewSis", async () => {
  const res = await callFull("GET", "/attendance/sessions", []);
  assertEquals(res?.status, 403);
  assertEquals((await res!.json()).error.code, "FORBIDDEN");
});

Deno.test("sessions route: default params reach the DB seam (503 DB-free, not 422)", async () => {
  const res = await callFull("GET", "/attendance/sessions", ["viewSis"]);
  assertEquals(res?.status, 503);
});

Deno.test("sessions route: an oversized pageSize is clamped, not rejected (503, not 422)", async () => {
  const res = await callFull(
    "GET",
    "/attendance/sessions?page=2&pageSize=9999",
    ["viewSis"],
  );
  assertEquals(res?.status, 503);
});

Deno.test("sessions route: out-of-range windowDays is a 422 before any DB work", async () => {
  const zero = await callFull(
    "GET",
    "/attendance/sessions?windowDays=0",
    ["viewSis"],
  );
  assertEquals(zero?.status, 422);
  assertEquals((await zero!.json()).error.code, "ATTENDANCE_VALIDATION");

  const over = await callFull(
    "GET",
    `/attendance/sessions?windowDays=${MAX_SESSIONS_WINDOW_DAYS + 1}`,
    ["viewSis"],
  );
  assertEquals(over?.status, 422);
});

Deno.test("sessions route: a valid windowDays reaches the DB seam (503 DB-free)", async () => {
  const res = await callFull(
    "GET",
    "/attendance/sessions?windowDays=30",
    ["viewSis"],
  );
  assertEquals(res?.status, 503);
});
