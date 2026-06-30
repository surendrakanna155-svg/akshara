// QW4 · QA-B-008 — Setup Wizard ROUTE contract (DB-free).
//
// routeSetupWizard owns POST /setup-wizard/sessions (create), GET
// /setup-wizard/sessions/{uuid} (read), POST /setup-wizard/sessions/{uuid}/advance.
//
// SLUG NOTE: the spec sketch said "POST /setup-wizard/sessions ... for
// viewSchoolSetup holder", but the REAL handler gates the write on
// requirePermission("manageSchoolSetup") (setup_wizard_handlers.ts:32 create,
// :128 advance), and gates only the GET read on "viewSchoolSetup" (:83). That is
// the correct read/write split (creating/advancing a session mutates state), so we
// test against the actual slugs rather than the sketch. Each gate is chained with
// requireSchoolOperationalScope.
//
// PROVEN HERE (locally, DB-free):
//   * 503 (authorized) for a manageSchoolSetup holder creating a session.
//   * 403 for a non-holder, including a viewSchoolSetup-only holder, on POST create.
//   * 503 for a viewSchoolSetup holder on GET session (read gate).
//   * advance: 503 for a manage holder; 422 on missing `step`; 403 for view-only.
//   * 403 for an org-scope caller WITH the slug (school-operational-scope leg).
//   * 401 unauthenticated; 404 unregistered/non-UUID path.
//
// Live remainder: the persisted setup_wizard_sessions row + provisioning side
// effects are covered by the live cert (needs ERP_TENANT_DATABASE_URL).

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeSetupWizard } from "./setup_wizard_router.ts";

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
  over: Partial<AccessTokenClaims> = {},
  body?: unknown,
): Promise<Response | null> {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (permissions !== null) {
    const token = await signAccessToken(SECRET, claims(permissions, over), 900);
    headers.authorization = `Bearer ${token}`;
  }
  const req = new Request(`https://x${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  return routeSetupWizard(req, config, method, path);
}

const SESSION_ID = "55555555-5555-4555-8555-555555555555";

Deno.test("QA-B-008: POST setup-wizard sessions authorizes a manageSchoolSetup holder (503 creates)", async () => {
  const res = await call("POST", "/setup-wizard/sessions", ["manageSchoolSetup"], {}, {
    inputs: {},
  });
  assertEquals(res!.status, 503);
});

Deno.test("QA-B-008: POST setup-wizard sessions is denied for a viewSchoolSetup-only holder (403)", async () => {
  const res = await call("POST", "/setup-wizard/sessions", ["viewSchoolSetup"], {}, {
    inputs: {},
  });
  assertEquals(res!.status, 403);
  const env = await res!.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("QA-B-008: POST setup-wizard sessions is denied for an unrelated role (403)", async () => {
  const res = await call("POST", "/setup-wizard/sessions", ["viewLibrary"], {}, { inputs: {} });
  assertEquals(res!.status, 403);
});

Deno.test("QA-B-008: GET setup-wizard session authorizes a viewSchoolSetup holder (503 read gate)", async () => {
  const res = await call("GET", `/setup-wizard/sessions/${SESSION_ID}`, ["viewSchoolSetup"]);
  assertEquals(res!.status, 503);
});

Deno.test("QA-B-008: GET setup-wizard session is denied for a non-holder (403)", async () => {
  const res = await call("GET", `/setup-wizard/sessions/${SESSION_ID}`, ["viewLibrary"]);
  assertEquals(res!.status, 403);
});

Deno.test("QA-B-008: POST advance authorizes a manageSchoolSetup holder (503)", async () => {
  const res = await call("POST", `/setup-wizard/sessions/${SESSION_ID}/advance`, [
    "manageSchoolSetup",
  ], {}, { step: "academic_year" });
  assertEquals(res!.status, 503);
});

Deno.test("QA-B-008: POST advance rejects a missing step (422 before DB)", async () => {
  const res = await call("POST", `/setup-wizard/sessions/${SESSION_ID}/advance`, [
    "manageSchoolSetup",
  ], {}, {});
  assertEquals(res!.status, 422);
});

Deno.test("QA-B-008: POST advance is denied for a view-only holder (403)", async () => {
  const res = await call("POST", `/setup-wizard/sessions/${SESSION_ID}/advance`, [
    "viewSchoolSetup",
  ], {}, { step: "academic_year" });
  assertEquals(res!.status, 403);
});

Deno.test("QA-B-008: POST create denies an org-scope caller WITH the slug (school scope leg, 403)", async () => {
  const res = await call("POST", "/setup-wizard/sessions", ["manageSchoolSetup"], {
    scope: "organization",
    school_id: null,
    role: "director",
  }, { inputs: {} });
  assertEquals(res!.status, 403);
});

Deno.test("QA-B-008: setup-wizard rejects an unauthenticated caller (401)", async () => {
  const res = await call("POST", "/setup-wizard/sessions", null, {}, { inputs: {} });
  assertEquals(res!.status, 401);
});

Deno.test("QA-B-008: an unregistered setup-wizard path returns 404", async () => {
  const res = await call("GET", "/setup-wizard/unknown", ["viewSchoolSetup"]);
  assertEquals(res!.status, 404);
});
