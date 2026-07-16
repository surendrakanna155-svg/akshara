// PRC-A Batch 2 — Student Health / Infirmary: router tests.
//
// Pure routing tests: path -> handler + extracted args, and the two envelope
// contracts every module router must honour (null outside the prefix, a real
// 404 for an unmatched path inside it). No auth, no DB — that is the handler
// tests' job (student_health_handlers_test.ts).

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import { matchStudentHealthRoute, routeStudentHealth } from "./student_health_router.ts";

const config = { jwtSecret: "test-jwt-secret-minimum-32-characters-long" } as AppConfig;

const STUDENT = "a4000000-0000-4000-8000-000000000001";
const ALERT_ID = "a7000000-0000-4000-8000-000000000001";
const AUTH_ID = "a6000000-0000-4000-8000-000000000001";

// ─── prefix contract ─────────────────────────────────────────────────────────

Deno.test("routeStudentHealth: returns null for a path outside its prefix (next router tries)", async () => {
  const res = await routeStudentHealth(
    new Request("https://x/sis/students"),
    config,
    "GET",
    "/sis/students",
  );
  assertEquals(res, null);
});

Deno.test("routeStudentHealth: does NOT claim the unrelated /health system-readiness prefix", async () => {
  // The module doc explicitly calls out /health as a DIFFERENT surface
  // (system readiness) that must never be shadowed by this router.
  const res = await routeStudentHealth(
    new Request("https://x/health"),
    config,
    "GET",
    "/health",
  );
  assertEquals(res, null);
});

Deno.test("routeStudentHealth: an unmatched path inside the prefix is a 404 envelope, not null", async () => {
  const res = await routeStudentHealth(
    new Request("https://x/student-health/foo/bar/baz"),
    config,
    "GET",
    "/student-health/foo/bar/baz",
  );
  assertEquals(res?.status, 404);
  const env = await res!.json();
  assertEquals(env.error.code, "NOT_FOUND");
  assertEquals(env.data, null);
});

Deno.test("routeStudentHealth: the bare prefix with nothing after it is a 404, not null", async () => {
  const res = await routeStudentHealth(
    new Request("https://x/student-health"),
    config,
    "GET",
    "/student-health",
  );
  assertEquals(res?.status, 404);
});

// ─── the single highest-consequence routing assertion in this module ────────
// care-alert (teacher surface, minimum actionable facts) vs record (full
// clinical history, health-staff/leadership only) must never cross-route.

Deno.test("router: /students/:id/care-alert matches handleGetCareAlert, NEVER handleGetStudentRecord", () => {
  const match = matchStudentHealthRoute("GET", `/student-health/students/${STUDENT}/care-alert`);
  assertEquals(match?.args, [STUDENT]);
  assertEquals(match?.handler.name, "handleGetCareAlert");
  assertEquals(
    (match?.handler.name ?? "") === "handleGetStudentRecord",
    false,
    "a teacher's care-alert request must never resolve to the clinical record handler",
  );
});

Deno.test("router: /students/:id/record matches handleGetStudentRecord, NEVER handleGetCareAlert", () => {
  const match = matchStudentHealthRoute("GET", `/student-health/students/${STUDENT}/record`);
  assertEquals(match?.args, [STUDENT]);
  assertEquals(match?.handler.name, "handleGetStudentRecord");
  assertEquals(
    (match?.handler.name ?? "") === "handleGetCareAlert",
    false,
    "a full-record request must never resolve to the teacher care-alert handler",
  );
});

Deno.test("router: care-alert and record resolve to DIFFERENT handlers for the SAME student id", () => {
  const careAlert = matchStudentHealthRoute("GET", `/student-health/students/${STUDENT}/care-alert`);
  const record = matchStudentHealthRoute("GET", `/student-health/students/${STUDENT}/record`);
  assertEquals(careAlert?.args, record?.args); // same [studentId] extraction
  assertEquals(careAlert?.handler === record?.handler, false);
});

// ─── every documented route matches to its handler, for the right method ────

Deno.test("router: POST /student-health/incidents -> handleCreateIncident", () => {
  const match = matchStudentHealthRoute("POST", "/student-health/incidents");
  assertEquals(match?.args, []);
  assertEquals(match?.handler.name, "handleCreateIncident");
});

Deno.test("router: GET /student-health/incidents -> handleListIncidents", () => {
  const match = matchStudentHealthRoute("GET", "/student-health/incidents");
  assertEquals(match?.args, []);
  assertEquals(match?.handler.name, "handleListIncidents");
});

Deno.test("router: a wrong method (DELETE) on /student-health/incidents does not resolve", () => {
  const match = matchStudentHealthRoute("DELETE", "/student-health/incidents");
  assertEquals(match, null);
});

Deno.test("router: POST /student-health/care-alerts -> handleCreateCareAlert", () => {
  const match = matchStudentHealthRoute("POST", "/student-health/care-alerts");
  assertEquals(match?.args, []);
  assertEquals(match?.handler.name, "handleCreateCareAlert");
});

Deno.test("router: a wrong method (GET) on /student-health/care-alerts does not resolve", () => {
  const match = matchStudentHealthRoute("GET", "/student-health/care-alerts");
  assertEquals(match, null);
});

Deno.test("router: PATCH /student-health/care-alerts/:id -> handleUpdateCareAlert, id extracted", () => {
  const match = matchStudentHealthRoute("PATCH", `/student-health/care-alerts/${ALERT_ID}`);
  assertEquals(match?.args, [ALERT_ID]);
  assertEquals(match?.handler.name, "handleUpdateCareAlert");
});

Deno.test("router: a wrong method (GET) on /student-health/care-alerts/:id does not resolve", () => {
  const match = matchStudentHealthRoute("GET", `/student-health/care-alerts/${ALERT_ID}`);
  assertEquals(match, null);
});

Deno.test("router: POST /student-health/authorizations -> handleCreateAuthorization", () => {
  const match = matchStudentHealthRoute("POST", "/student-health/authorizations");
  assertEquals(match?.args, []);
  assertEquals(match?.handler.name, "handleCreateAuthorization");
});

Deno.test("router: a wrong method (GET) on /student-health/authorizations does not resolve", () => {
  const match = matchStudentHealthRoute("GET", "/student-health/authorizations");
  assertEquals(match, null);
});

Deno.test("router: POST /student-health/authorizations/:id/revoke -> handleRevokeAuthorization, id extracted", () => {
  const match = matchStudentHealthRoute("POST", `/student-health/authorizations/${AUTH_ID}/revoke`);
  assertEquals(match?.args, [AUTH_ID]);
  assertEquals(match?.handler.name, "handleRevokeAuthorization");
});

Deno.test("router: a wrong method (GET) on /authorizations/:id/revoke does not resolve", () => {
  const match = matchStudentHealthRoute("GET", `/student-health/authorizations/${AUTH_ID}/revoke`);
  assertEquals(match, null);
});

Deno.test("router: POST /student-health/authorizations/:id/administer -> handleAdministerMedication, id extracted", () => {
  const match = matchStudentHealthRoute("POST", `/student-health/authorizations/${AUTH_ID}/administer`);
  assertEquals(match?.args, [AUTH_ID]);
  assertEquals(match?.handler.name, "handleAdministerMedication");
});

Deno.test("router: a wrong method (GET) on /authorizations/:id/administer does not resolve", () => {
  const match = matchStudentHealthRoute("GET", `/student-health/authorizations/${AUTH_ID}/administer`);
  assertEquals(match, null);
});

Deno.test("router: revoke and administer resolve to DIFFERENT handlers for the SAME authorization id", () => {
  const revoke = matchStudentHealthRoute("POST", `/student-health/authorizations/${AUTH_ID}/revoke`);
  const administer = matchStudentHealthRoute("POST", `/student-health/authorizations/${AUTH_ID}/administer`);
  assertEquals(revoke?.args, administer?.args); // same [authorizationId] extraction
  assertEquals(revoke?.handler === administer?.handler, false);
});

Deno.test("router: a wrong method (PATCH) on /student-health/students/:id/record does not resolve", () => {
  const match = matchStudentHealthRoute("PATCH", `/student-health/students/${STUDENT}/record`);
  assertEquals(match, null);
});

Deno.test("router: a wrong method (POST) on /student-health/students/:id/care-alert does not resolve", () => {
  const match = matchStudentHealthRoute("POST", `/student-health/students/${STUDENT}/care-alert`);
  assertEquals(match, null);
});

Deno.test("router: GET /student-health/access-log -> handleListAccessLog", () => {
  const match = matchStudentHealthRoute("GET", "/student-health/access-log");
  assertEquals(match?.args, []);
  assertEquals(match?.handler.name, "handleListAccessLog");
});

Deno.test("router: a wrong method (POST) on /student-health/access-log does not resolve", () => {
  const match = matchStudentHealthRoute("POST", "/student-health/access-log");
  assertEquals(match, null);
});

// ─── path-param extraction edge cases ────────────────────────────────────────

Deno.test("router: path params are extracted verbatim, whatever shape the segment is (validation is the handler's job)", () => {
  // The router itself is UUID-agnostic — `[^/]+` matches any non-slash
  // segment; format validation happens downstream in the handler (UUID_RE).
  const match = matchStudentHealthRoute("GET", "/student-health/students/not-a-uuid/care-alert");
  assertEquals(match?.args, ["not-a-uuid"]);
  assertEquals(match?.handler.name, "handleGetCareAlert");
});

Deno.test("router: an extra trailing segment after :id/care-alert does not resolve (no partial match)", () => {
  const match = matchStudentHealthRoute("GET", `/student-health/students/${STUDENT}/care-alert/extra`);
  assertEquals(match, null);
});

Deno.test("router: an extra trailing segment after :id/record does not resolve (no partial match)", () => {
  const match = matchStudentHealthRoute("GET", `/student-health/students/${STUDENT}/record/extra`);
  assertEquals(match, null);
});

Deno.test("router: a bare /student-health/students/:id with no suffix does not resolve", () => {
  const match = matchStudentHealthRoute("GET", `/student-health/students/${STUDENT}`);
  assertEquals(match, null);
});

Deno.test("router: /care-alerts/:id rejects an id containing a slash (id must be a single segment)", () => {
  // A malformed id like "a/b" cannot be produced by a real path segment, but
  // prove the regex does not accidentally swallow a slash into the capture.
  const match = matchStudentHealthRoute("PATCH", "/student-health/care-alerts/a/b");
  assertEquals(match, null);
});

// ─── routeStudentHealth end-to-end dispatch (routing, not auth/DB) ──────────

Deno.test("routeStudentHealth: dispatches GET .../care-alert through to handleGetCareAlert (401, no bearer — proves it reached the handler)", async () => {
  const res = await routeStudentHealth(
    new Request(`https://x/student-health/students/${STUDENT}/care-alert`),
    config,
    "GET",
    `/student-health/students/${STUDENT}/care-alert`,
  );
  // No auth header: the dispatched handler's own auth gate fires (401), which
  // proves routing landed on A handler (a routing bug would 404 instead).
  assertEquals(res?.status, 401);
});

Deno.test("routeStudentHealth: dispatches GET .../record through to handleGetStudentRecord (401, no bearer)", async () => {
  const res = await routeStudentHealth(
    new Request(`https://x/student-health/students/${STUDENT}/record`),
    config,
    "GET",
    `/student-health/students/${STUDENT}/record`,
  );
  assertEquals(res?.status, 401);
});
