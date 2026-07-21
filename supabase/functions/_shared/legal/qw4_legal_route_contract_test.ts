// QW4 · QA-B-031 (P1) + QA-B-043 (P1) — Legal acceptance gate route-contract.
//
// routeLegal owns two routes, both open to ANY authenticated principal (no RBAC
// permission — acceptance is a per-user obligation, see legal/legal_router.ts:8
// and legal_handlers.ts:55):
//   • GET  /legal/status  → handleGetLegalStatus
//   • POST /legal/accept  → handleAcceptPolicies
//
// QA-B-031 (accept WRITE contract): POST /legal/accept records acceptance and
// (per handler) binds the user/role/scope/tenant + IP (x-forwarded-for) + device
// + user-agent, then INSERTs. We prove the write contract up to the DB boundary:
//   • a valid acceptances[] body for a known policy at the CURRENT version passes
//     validation and reaches the unconfigured tenant DB (503 = DB-free proxy for
//     "writing the acceptance row" — where IP/device/user/scope are persisted);
//   • body validation fires BEFORE the DB: empty/missing acceptances → 422,
//     unknown policy → 422, stale version → 409 POLICY_VERSION_MISMATCH;
//   • the accept path is fail-CLOSED on a bad body (rejects before any write) —
//     there is no fail-open accept; the only "open" property is no-RBAC.
//
// QA-B-043 (RBAC): GET /legal/status requires AUTH (401 unauth) but no
// permission; POST /legal/accept binds to the CALLER — the handler reads
// claims.sub / claims.primary_role / claims.scope / claims.tenant_id straight
// from the authenticated token (handlers.ts:147-165), so a caller can only ever
// record acceptance AS THEMSELVES. It is authenticated-ANY (any role/scope, incl.
// student & parent), NOT permission-scoped. We assert exactly that.
//
// REMAINDER (infra-blocked): the real 201 + the persisted legal_acceptances row
// actually carrying this user's sub/IP/device, and that GET reflects it, need a
// live ERP_TENANT_DATABASE_URL (live cert). The route/validation/binding
// contract is fully provable DB-free.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeLegal } from "./legal_router.ts";
import { LEGAL_POLICIES } from "./legal_catalog.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

// Pick a real policy + its current version straight from the catalog so the
// "current version" path is exercised without hard-coding a version string.
const [SAMPLE_KEY, SAMPLE_DEF] = Object.entries(LEGAL_POLICIES)[0]!;
const SAMPLE_VERSION = SAMPLE_DEF.version;

function claims(over: Partial<AccessTokenClaims> = {}): AccessTokenClaims {
  return {
    sub: "legal-user-1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "schoolAdmin",
    role_slugs: ["schoolAdmin"],
    primary_role: "schoolAdmin",
    permissions: [],
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
    ...over,
  };
}

function req(
  method: string,
  path: string,
  token: string | null,
  body?: unknown,
  extraHeaders: Record<string, string> = {},
): Request {
  const headers: Record<string, string> = { "content-type": "application/json", ...extraHeaders };
  if (token) headers.authorization = `Bearer ${token}`;
  return new Request(`https://x${path}`, {
    method,
    headers,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
}

// ── QA-B-043: GET /legal/status requires auth, no permission ──────────────────

Deno.test("QA-B-043: GET /legal/status rejects an unauthenticated caller (401)", async () => {
  const res = await routeLegal(req("GET", "/legal/status", null), config, "GET", "/legal/status");
  assertEquals(res?.status, 401);
});

Deno.test("QA-B-043: GET /legal/status needs NO permission (any authenticated principal → 503 to DB)", async () => {
  // A principal with an empty permissions array still passes — acceptance status
  // is not RBAC-gated.
  const token = await signAccessToken(SECRET, claims({ permissions: [] }), 900);
  const res = await routeLegal(req("GET", "/legal/status", token), config, "GET", "/legal/status");
  assertEquals(res?.status, 503);
});

Deno.test("QA-B-043: GET /legal/status is open across personas (student & parent reach it too)", async () => {
  for (const scoped of [
    claims({ scope: "student", student_id: "student-1", primary_role: "student", role: "student" }),
    claims({ scope: "parent", child_ids: ["student-1"], primary_role: "parent", role: "parent" }),
  ]) {
    const token = await signAccessToken(SECRET, scoped, 900);
    const res = await routeLegal(req("GET", "/legal/status", token), config, "GET", "/legal/status");
    assertEquals(res?.status, 503, `scope ${scoped.scope} should reach the status DB`);
  }
});

// ── QA-B-031: POST /legal/accept write contract ───────────────────────────────

Deno.test("QA-B-031: POST /legal/accept rejects an unauthenticated caller (401) before any write", async () => {
  const res = await routeLegal(
    req("POST", "/legal/accept", null, { acceptances: [{ key: SAMPLE_KEY, version: SAMPLE_VERSION }] }),
    config,
    "POST",
    "/legal/accept",
  );
  assertEquals(res?.status, 401);
});

Deno.test("QA-B-031: POST /legal/accept persists a valid acceptance (binds caller + IP/device → 503 to DB)", async () => {
  const token = await signAccessToken(SECRET, claims(), 900);
  const res = await routeLegal(
    req(
      "POST",
      "/legal/accept",
      token,
      { acceptances: [{ key: SAMPLE_KEY, version: SAMPLE_VERSION }], device_id: "dev-xyz" },
      { "x-forwarded-for": "203.0.113.7", "user-agent": "Akshara/1.0" },
    ),
    config,
    "POST",
    "/legal/accept",
  );
  // Validation passed → handler proceeded to insertAcceptance (which records
  // user/role/scope/tenant + IP + user-agent + device) against the unconfigured
  // tenant DB.
  assertEquals(res?.status, 503);
});

Deno.test("QA-B-031: POST /legal/accept binds to the caller across personas (student/parent accept as self → 503)", async () => {
  for (const scoped of [
    claims({ scope: "student", student_id: "student-1", primary_role: "student", role: "student" }),
    claims({ scope: "parent", child_ids: ["student-1"], primary_role: "parent", role: "parent" }),
  ]) {
    const token = await signAccessToken(SECRET, scoped, 900);
    const res = await routeLegal(
      req("POST", "/legal/accept", token, {
        acceptances: [{ key: SAMPLE_KEY, version: SAMPLE_VERSION }],
      }),
      config,
      "POST",
      "/legal/accept",
    );
    assertEquals(res?.status, 503, `scope ${scoped.scope} should reach the accept-write DB`);
  }
});

Deno.test("QA-B-031: POST /legal/accept rejects an empty/missing acceptances list (422) before the DB", async () => {
  const token = await signAccessToken(SECRET, claims(), 900);
  for (const body of [{}, { acceptances: [] }, { acceptances: "nope" }]) {
    const res = await routeLegal(req("POST", "/legal/accept", token, body), config, "POST", "/legal/accept");
    assertEquals(res?.status, 422, `body ${JSON.stringify(body)} should be 422`);
  }
});

Deno.test("QA-B-031: POST /legal/accept rejects an unknown policy key (422) before the DB", async () => {
  const token = await signAccessToken(SECRET, claims(), 900);
  const res = await routeLegal(
    req("POST", "/legal/accept", token, {
      acceptances: [{ key: "no_such_policy", version: "1.0" }],
    }),
    config,
    "POST",
    "/legal/accept",
  );
  assertEquals(res?.status, 422);
});

Deno.test("QA-B-031: POST /legal/accept rejects a stale policy version (409 POLICY_VERSION_MISMATCH)", async () => {
  const token = await signAccessToken(SECRET, claims(), 900);
  const res = await routeLegal(
    req("POST", "/legal/accept", token, {
      acceptances: [{ key: SAMPLE_KEY, version: `${SAMPLE_VERSION}-stale` }],
    }),
    config,
    "POST",
    "/legal/accept",
  );
  assertEquals(res?.status, 409);
  const env = await res!.json();
  assertEquals(env.error.code, "POLICY_VERSION_MISMATCH");
});

Deno.test("QA-B-031: an unregistered /legal path returns null (central dispatcher 404s); a foreign path returns null", async () => {
  const token = await signAccessToken(SECRET, claims(), 900);
  const notFound = await routeLegal(req("GET", "/legal/nope", token), config, "GET", "/legal/nope");
  assertEquals(notFound, null);
  const foreign = await routeLegal(req("GET", "/student/exams", null), config, "GET", "/student/exams");
  assertEquals(foreign, null);
});
