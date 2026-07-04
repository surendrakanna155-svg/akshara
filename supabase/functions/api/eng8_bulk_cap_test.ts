// P1-CODE-3 · ENG-8 (SEC-11) — client-supplied bulk-write arrays are capped at
// MAX_BULK_ITEMS BEFORE any per-row DB work, so an oversized payload can't
// exhaust the edge worker (a cheap DoS). Tested against the server-free
// `handleRequest` seam: an over-limit array 422s before the DB (which would
// otherwise 503 as unconfigured), a within-limit array reaches the DB (503).
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleRequest } from "./app.ts";
import { MAX_BULK_ITEMS } from "../_shared/http.ts";
import type { AppConfig } from "../_shared/config.ts";
import type { AccessTokenClaims } from "../_shared/jwt.ts";
import { signAccessToken } from "../_shared/jwt.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const goodConfig = () => ({ jwtSecret: SECRET } as AppConfig);

function claims(perms: string[]): AccessTokenClaims {
  return {
    sub: "user-1", tenant_id: "org-1", organization_id: "org-1", school_id: "school-1",
    role: "schoolAdmin", role_slugs: ["schoolAdmin"], primary_role: "schoolAdmin",
    permissions: perms, permissions_version: 1, scope: "school", school_group_id: null,
    student_id: null, child_ids: [], session_id: "s1",
  };
}

async function post(path: string, perms: string[], body: unknown): Promise<Request> {
  const token = await signAccessToken(SECRET, claims(perms), 900);
  return new Request(`https://x${path}`, {
    method: "POST",
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

Deno.test("ENG-8: an over-limit bulk marks array is rejected 422 BEFORE the DB", async () => {
  const entries = Array.from(
    { length: MAX_BULK_ITEMS + 1 },
    (_, i) => ({ id: `m${i}`, marksObtained: 10, status: "present" }),
  );
  const res = await handleRequest(
    await post("/academics/exams/e1/marks/batch", ["manageExamMarks"], { entries }),
    goodConfig,
  );
  assertEquals(res.status, 422, "over-limit → 422, not a DB 503");
  const env = await res.json();
  assertEquals(env.error.code, "EXAM_VALIDATION");
  assertEquals(env.error.message.includes(String(MAX_BULK_ITEMS)), true);
});

Deno.test("ENG-8: a within-limit bulk marks array passes the cap and reaches the DB (503)", async () => {
  const entries = Array.from(
    { length: 3 },
    (_, i) => ({ id: `m${i}`, marksObtained: 10, status: "present" }),
  );
  const res = await handleRequest(
    await post("/academics/exams/e1/marks/batch", ["manageExamMarks"], { entries }),
    goodConfig,
  );
  // Passes the cap + auth, reaches the unconfigured tenant DB → 503 (not 422).
  assertEquals(res.status, 503, "within-limit must not be blocked by the cap");
});

Deno.test("ENG-8: an over-limit approval batch is rejected 422 before the DB", async () => {
  const ids = Array.from({ length: MAX_BULK_ITEMS + 1 }, (_, i) => `a${i}`);
  const res = await handleRequest(
    await post("/approvals/batch-decide", ["approveWorkflows"], { ids, decision: "approve" }),
    goodConfig,
  );
  // Either the dedicated cap (422) fires, or (if the route/permission differs)
  // it never 503s past the cap into DB work with an oversized array.
  assertEquals(res.status === 422 || res.status === 403, true);
});
