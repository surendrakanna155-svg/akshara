// P1 (observability) — the per-request log can be narrowed to a user.
//
// PHASE-PRIOR REALITY: `logRequest` emitted method/path/status/durationMs/
// correlationId/clientIp and nothing else. That log is the ONLY durable
// per-request diagnostic this service produces, so a support ticket ("my child
// was marked absent on Tuesday") could be narrowed to a path and a minute — not
// to a person, a school or a session. `clientIp` is additionally almost always
// null, because the internal gateway sets no X-Forwarded-For.
//
// WHAT IS PROVEN HERE:
//   1. Identifiers come from the VERIFIED access token, never from the
//      client-supplied X-User-Id / X-School-Id / X-Tenant-Id headers: a forged
//      header cannot attribute a request to another user, and a header that
//      disagrees with the token is flagged rather than trusted.
//   2. An absent / expired / forged token degrades honestly (tokenState) instead
//      of silently attributing the request to whoever the headers name.
//   3. The end-to-end log line carries the actor — and still carries NO token,
//      body, query string, name, phone number or permission list.

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleRequest, resolveRequestIdentity } from "./app.ts";
import type { AppConfig } from "../_shared/config.ts";
import type { AccessTokenClaims } from "../_shared/jwt.ts";
import { signAccessToken } from "../_shared/jwt.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const OTHER_SECRET = "another-jwt-secret-minimum-32-characters-long";
const goodConfig = () => ({ jwtSecret: SECRET } as AppConfig);

const USER = "11111111-0000-4000-8000-000000000001";
const ORG = "22222222-0000-4000-8000-000000000001";
const SCHOOL = "33333333-0000-4000-8000-000000000001";
const CHILD = "44444444-0000-4000-8000-000000000001";
const IMPERSONATED = "99999999-0000-4000-8000-000000000009";

function claims(over: Partial<AccessTokenClaims> = {}): AccessTokenClaims {
  return {
    sub: USER,
    tenant_id: ORG,
    organization_id: ORG,
    school_id: SCHOOL,
    role: "parent",
    role_slugs: ["parent"],
    primary_role: "parent",
    permissions: ["viewParentExperience"],
    permissions_version: 1,
    scope: "parent",
    school_group_id: null,
    student_id: null,
    child_ids: [CHILD],
    session_id: "sess-42",
    ...over,
  };
}

function req(headers: Record<string, string>): Request {
  return new Request("https://x/attendance/corrections", { method: "GET", headers });
}

// ── verified claims are the attribution ──────────────────────────────────────

Deno.test("request log: identifiers are read from the verified token", async () => {
  const token = await signAccessToken(SECRET, claims(), 900);
  const identity = await resolveRequestIdentity(
    req({ authorization: `Bearer ${token}` }),
    SECRET,
  );

  assertEquals(identity.tokenState, "verified");
  assertEquals(identity.userId, USER);
  assertEquals(identity.sessionId, "sess-42");
  assertEquals(identity.tenantId, ORG);
  assertEquals(identity.schoolId, SCHOOL);
  assertEquals(identity.scope, "parent");
  assertEquals(identity.headerIdentityMismatch, false);
});

Deno.test("request log: a forged X-User-Id cannot attribute the request to someone else", async () => {
  const token = await signAccessToken(SECRET, claims(), 900);
  const identity = await resolveRequestIdentity(
    req({
      authorization: `Bearer ${token}`,
      "x-user-id": IMPERSONATED,
      "x-school-id": "some-other-school",
    }),
    SECRET,
  );

  // Attribution stays with the token...
  assertEquals(identity.userId, USER);
  assertEquals(identity.schoolId, SCHOOL);
  // ...the header value is kept, but only under a name that says what it is.
  assertEquals(identity.headerUserId, IMPERSONATED);
  assertEquals(identity.headerSchoolId, "some-other-school");
  assertEquals(identity.headerIdentityMismatch, true);
});

Deno.test("request log: matching headers are not flagged as a mismatch", async () => {
  const token = await signAccessToken(SECRET, claims(), 900);
  const identity = await resolveRequestIdentity(
    req({
      authorization: `Bearer ${token}`,
      "x-user-id": USER,
      "x-school-id": SCHOOL,
      "x-tenant-id": ORG,
    }),
    SECRET,
  );
  assertEquals(identity.headerIdentityMismatch, false);
});

// ── honest degradation ───────────────────────────────────────────────────────

Deno.test("request log: no token → nothing is attributed, headers survive as hints only", async () => {
  const identity = await resolveRequestIdentity(
    req({ "x-user-id": IMPERSONATED, "x-tenant-id": ORG }),
    SECRET,
  );
  assertEquals(identity.tokenState, "none");
  assertEquals(identity.userId, null);
  assertEquals(identity.tenantId, null);
  assertEquals(identity.headerUserId, IMPERSONATED);
  assertEquals(identity.headerTenantId, ORG);
  assertEquals(identity.headerIdentityMismatch, false);
});

Deno.test("request log: a token signed with the wrong key is `invalid`, not an actor", async () => {
  const token = await signAccessToken(OTHER_SECRET, claims(), 900);
  const identity = await resolveRequestIdentity(
    req({ authorization: `Bearer ${token}`, "x-user-id": IMPERSONATED }),
    SECRET,
  );
  assertEquals(identity.tokenState, "invalid");
  assertEquals(identity.userId, null);
  assertEquals(identity.headerUserId, IMPERSONATED);
});

Deno.test("request log: an EXPIRED token is `invalid` — the diagnostic is the state itself", async () => {
  const token = await signAccessToken(SECRET, claims(), -60);
  const identity = await resolveRequestIdentity(
    req({ authorization: `Bearer ${token}` }),
    SECRET,
  );
  assertEquals(identity.tokenState, "invalid");
  assertEquals(identity.userId, null);
});

Deno.test("request log: with no secret (config error) the token is `unverifiable`, never assumed good", async () => {
  const token = await signAccessToken(SECRET, claims(), 900);
  const identity = await resolveRequestIdentity(
    req({ authorization: `Bearer ${token}`, "x-school-id": SCHOOL }),
    null,
  );
  assertEquals(identity.tokenState, "unverifiable");
  assertEquals(identity.userId, null);
  assertEquals(identity.headerSchoolId, SCHOOL);
});

Deno.test("request log: blank header values are treated as absent", async () => {
  const identity = await resolveRequestIdentity(req({ "x-user-id": "   " }), SECRET);
  assertEquals(identity.headerUserId, null);
});

// ── end-to-end log line ──────────────────────────────────────────────────────

/** Runs `handleRequest` and returns the emitted `type:"request"` log line. */
async function captureRequestLog(
  request: Request,
): Promise<{ line: Record<string, unknown>; raw: string; status: number }> {
  const raw: string[] = [];
  const original = console.log;
  console.log = (...args: unknown[]) => {
    raw.push(String(args[0]));
  };
  let status = 0;
  try {
    status = (await handleRequest(request, goodConfig, () => {})).status;
  } finally {
    console.log = original;
  }
  const match = raw.find((l) => l.includes('"type":"request"'));
  assert(match, `no request log line emitted; got: ${raw.join(" | ")}`);
  return { line: JSON.parse(match), raw: match, status };
}

Deno.test("request log: the emitted line carries the verified actor, school and session", async () => {
  const token = await signAccessToken(SECRET, claims({ scope: "school" }), 900);
  const { line, status } = await captureRequestLog(
    new Request("https://x/attendance/corrections/att_corr_1/status", {
      method: "PATCH",
      headers: {
        authorization: `Bearer ${token}`,
        "content-type": "application/json",
        "x-correlation-id": "corr-9",
      },
      body: JSON.stringify({ status: "approved" }),
    }),
  );

  // 403: the parent-ish token lacks approveAttendanceCorrection. What matters
  // is that the LOG LINE for it names who was denied.
  assertEquals(status, 403);
  assertEquals(line.type, "request");
  assertEquals(line.method, "PATCH");
  assertEquals(line.path, "/attendance/corrections/att_corr_1/status");
  assertEquals(line.correlationId, "corr-9");
  assertEquals(line.userId, USER);
  assertEquals(line.schoolId, SCHOOL);
  assertEquals(line.tenantId, ORG);
  assertEquals(line.sessionId, "sess-42");
  assertEquals(line.tokenState, "verified");
  // Documented reality: no X-Forwarded-For from the internal gateway.
  assertEquals(line.clientIp, null);
});

Deno.test("request log: the line leaks no token, body, query string or personal data", async () => {
  const token = await signAccessToken(SECRET, claims(), 900);
  const { line, raw } = await captureRequestLog(
    new Request("https://x/attendance/corrections?studentName=Asha%20Kumari", {
      method: "POST",
      headers: {
        authorization: `Bearer ${token}`,
        "content-type": "application/json",
        "user-agent": "Niksha/1.0",
      },
      body: JSON.stringify({ studentName: "Asha Kumari", reason: "was at the clinic" }),
    }),
  );

  assertEquals(raw.includes(token), false, "the bearer token must never be logged");
  assertEquals(raw.includes("Asha Kumari"), false, "no names — from body or query string");
  assertEquals(raw.includes("was at the clinic"), false, "no free text from the body");
  assertEquals(raw.includes("studentName"), false, "no query string is logged");
  // The path is logged WITHOUT its query string.
  assertEquals(line.path, "/attendance/corrections");
  // Claims that identify the CHILD or grant-level detail stay out of the log.
  assertEquals(raw.includes(CHILD), false, "child ids must not be logged");
  assertEquals("permissions" in line, false);
  assertEquals("childIds" in line, false);
  assertEquals("studentId" in line, false);
  assertEquals("role" in line, false);
});

Deno.test("request log: an unauthenticated request still logs, marked as such", async () => {
  const { line, status } = await captureRequestLog(
    new Request("https://x/health", { method: "GET", headers: { "x-user-id": USER } }),
  );
  assertEquals(status, 200);
  assertEquals(line.tokenState, "none");
  assertEquals(line.userId, null);
  // The only narrowing key an anonymous request has — explicitly untrusted.
  assertEquals(line.headerUserId, USER);
});
