// QW4 · QA-B-009 — teacher_assistant ROUTE/RBAC contract (DB-free).
//
// `routeTeacherAssistant` reads gate on viewTeacherAssistant (+ school scope),
// writes on manageTeacherAssistant (+ school scope). Proven WITHOUT a live
// Postgres (503/TENANT_DB_NOT_CONFIGURED = gate PASSED, handler reached the
// unconfigured tenant DB = "authorized"):
//   - GET /teacher-assistant/insights: teacher (viewTeacherAssistant) → 503;
//     a parent (no slug, non-school scope) → 403.
//   - POST /teacher-assistant/interventions: manageTeacherAssistant → 503;
//     a viewer-only token → 403; missing fields → 422 before the DB.
//   - PATCH .../interventions/{uuid}: manageTeacherAssistant → 503; viewer → 403.
// Live remainder (infra): the real insights aggregation, the persisted
// intervention row, and per-school RLS isolation are covered by the live cert.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeTeacherAssistant } from "./teacher_assistant_router.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function claims(permissions: string[], over: Partial<AccessTokenClaims> = {}): AccessTokenClaims {
  return {
    sub: "u1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "teacher",
    role_slugs: ["teacher"],
    primary_role: "teacher",
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

const parentOver: Partial<AccessTokenClaims> = {
  role: "parent",
  role_slugs: ["parent"],
  primary_role: "parent",
  scope: "parent",
  child_ids: ["stu-1"],
};

async function call(
  method: string,
  path: string,
  perms: string[],
  body?: unknown,
  over?: Partial<AccessTokenClaims>,
): Promise<Response | null> {
  const token = await signAccessToken(SECRET, claims(perms, over), 900);
  const req = new Request(`https://x${path}`, {
    method,
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
  return routeTeacherAssistant(req, config, method, path);
}

const UUID = "11111111-1111-4111-8111-111111111111";
const validIntervention = { studentId: "stu-1", interventionType: "academic", title: "Extra help" };

Deno.test("QA-B-009: insights pass the gate for a teacher with viewTeacherAssistant (503)", async () => {
  const res = await call("GET", "/teacher-assistant/insights", ["viewTeacherAssistant"]);
  assertEquals(res?.status, 503);
});

Deno.test("QA-B-009: insights are denied for a parent (403 FORBIDDEN)", async () => {
  const res = await call("GET", "/teacher-assistant/insights", ["viewParentInsights"], undefined, parentOver);
  assertEquals(res?.status, 403);
  const env = await res!.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("QA-B-009: insights are denied for a school user lacking the slug (403)", async () => {
  const res = await call("GET", "/teacher-assistant/insights", ["viewSis"]);
  assertEquals(res?.status, 403);
});

Deno.test("QA-B-009: create intervention passes the gate with manageTeacherAssistant (503)", async () => {
  const res = await call("POST", "/teacher-assistant/interventions", ["manageTeacherAssistant"], validIntervention);
  assertEquals(res?.status, 503);
});

Deno.test("QA-B-009: create intervention is denied for a viewer-only token (403)", async () => {
  const res = await call("POST", "/teacher-assistant/interventions", ["viewTeacherAssistant"], validIntervention);
  assertEquals(res?.status, 403);
});

Deno.test("QA-B-009: create intervention is denied for a parent (403)", async () => {
  const res = await call("POST", "/teacher-assistant/interventions", ["viewParentInsights"], validIntervention, parentOver);
  assertEquals(res?.status, 403);
});

Deno.test("QA-B-009: create intervention rejects missing fields (422) before the DB", async () => {
  const res = await call("POST", "/teacher-assistant/interventions", ["manageTeacherAssistant"], { title: "x" });
  assertEquals(res?.status, 422);
});

Deno.test("QA-B-009: update intervention passes the gate with manageTeacherAssistant (503)", async () => {
  const res = await call("PATCH", `/teacher-assistant/interventions/${UUID}`, ["manageTeacherAssistant"], {
    status: "completed",
  });
  assertEquals(res?.status, 503);
});

Deno.test("QA-B-009: update intervention is denied for a viewer-only token (403)", async () => {
  const res = await call("PATCH", `/teacher-assistant/interventions/${UUID}`, ["viewTeacherAssistant"], {
    status: "completed",
  });
  assertEquals(res?.status, 403);
});

Deno.test("QA-B-009: unauthenticated insights are rejected (401)", async () => {
  const req = new Request("https://x/teacher-assistant/insights", { method: "GET" });
  const res = await routeTeacherAssistant(req, config, "GET", "/teacher-assistant/insights");
  assertEquals(res?.status, 401);
});

Deno.test("QA-B-009: router returns null for a path outside its prefix", async () => {
  const res = await call("GET", "/finance/refunds", ["viewTeacherAssistant"]);
  assertEquals(res, null);
});

Deno.test("QA-B-009: unregistered path under the prefix returns null (central dispatcher 404s)", async () => {
  const res = await call("GET", "/teacher-assistant/nope", ["viewTeacherAssistant"]);
  assertEquals(res, null);
});
