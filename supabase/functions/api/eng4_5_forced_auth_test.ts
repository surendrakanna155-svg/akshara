// P1-CODE-3 · ENG-4 (route-registry lint) + ENG-5 (forced-auth choke).
//
// The invariant: EVERY mounted module route sits behind the single auth/RBAC
// gate — there is no orphan or unguarded route that returns data without a
// valid session. This test drives the real `handleRequest` seam with NO
// Authorization header across a representative route from each major module
// group and asserts each is rejected with 401 (never 200/2xx, never a 5xx that
// would imply the handler ran business logic before checking auth).
//
// A route that 404s here would be a registry gap (ENG-4); a route that returns
// 200/503 would be an auth-bypass (ENG-5) — both are failures.
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleRequest } from "./app.ts";
import type { AppConfig } from "../_shared/config.ts";
import type { AccessTokenClaims } from "../_shared/jwt.ts";
import { signAccessToken } from "../_shared/jwt.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const goodConfig = () => ({ jwtSecret: SECRET } as AppConfig);

// A validly-signed session (no permissions) — enough to PASS the ICA-F1 central auth
// gate so a request reaches dispatch (the 404 fallback / handler), without granting any
// RBAC. Used to probe post-authentication behaviour.
function authedReq(method: string, path: string): Promise<Request> {
  const claims: AccessTokenClaims = {
    sub: "user-1", tenant_id: "org-1", organization_id: "org-1", school_id: "school-1",
    role: "schoolAdmin", role_slugs: ["schoolAdmin"], primary_role: "schoolAdmin",
    permissions: [], permissions_version: 1, scope: "school", school_group_id: null,
    student_id: null, child_ids: [], session_id: "s1",
  };
  return signAccessToken(SECRET, claims, 900).then((token) =>
    new Request(`https://x${path}`, {
      method,
      headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
      body: method === "GET" ? undefined : JSON.stringify({}),
    })
  );
}

// Representative (method, path) per module group — verified to path-match a real
// handler. No Authorization header is sent.
const ROUTES: ReadonlyArray<readonly [string, string]> = [
  ["POST", "/finance/collections"],
  ["GET", "/finance/dashboard"],
  ["POST", "/academics/exams/e1/marks/batch"],
  ["POST", "/approvals/batch-decide"],
  ["POST", "/hr/leave/batch-decide"],
  ["GET", "/hr/dashboard"],
  ["GET", "/inventory/dashboard"],
  ["POST", "/inventory/intelligence/lifecycle/events"],
  ["GET", "/memories/events"],
  ["POST", "/memories/events"],
  ["PUT", "/school-config"],
  ["POST", "/admissions/leads/bulk"],
];

for (const [method, path] of ROUTES) {
  Deno.test(`ENG-5: ${method} ${path} rejects an unauthenticated request (401)`, async () => {
    const req = new Request(`https://x${path}`, {
      method,
      headers: { "content-type": "application/json" },
      body: method === "GET" ? undefined : JSON.stringify({}),
    });
    const res = await handleRequest(req, goodConfig);
    assertEquals(
      res.status,
      401,
      `${method} ${path} must be gated by auth (got ${res.status})`,
    );
  });
}

// ENG-4: a genuinely unregistered route still falls through to the 404 registry
// fallback (proving the module table has a catch-all, not a silent 200). ICA-F1: the
// central auth gate now runs BEFORE dispatch, so this probe is AUTHENTICATED to reach
// the 404 (an unauthenticated probe is intercepted by the gate — asserted below).
Deno.test("ENG-4: an unregistered module route falls through to 404 NOT_FOUND", async () => {
  const res = await handleRequest(
    await authedReq("POST", "/definitely/not/a/route"),
    goodConfig,
  );
  assertEquals(res.status, 404);
  assertEquals((await res.json()).error.code, "NOT_FOUND");
});

// ── ICA-F1: central auth chokepoint — no module route is unauthenticated by omission ──

// Auth-first: an UNAUTHENTICATED request is rejected at the central gate BEFORE dispatch,
// so even an unknown route returns 401 (not 404) — unauthenticated callers cannot
// enumerate which routes exist. (Authenticated, the same route 404s — see ENG-4 above.)
Deno.test("ICA-F1: an unauthenticated request to ANY module path is 401 at the central gate", async () => {
  for (const [method, path] of [["POST", "/definitely/not/a/route"], ["GET", "/finance/dashboard"]] as const) {
    const res = await handleRequest(
      new Request(`https://x${path}`, { method, headers: { "content-type": "application/json" }, body: method === "GET" ? undefined : "{}" }),
      goodConfig,
    );
    assertEquals(res.status, 401, `${method} ${path} must be gated (got ${res.status})`);
  }
});

// The public allowlist (signature-authed webhooks) is NOT gated: an unauthenticated POST
// reaches the webhook handler's OWN signature check, never the central gate. Both handlers
// reject a bad/absent signature, but with their own message — the delivery webhook even
// returns 401 "Invalid webhook signature", so status alone can't tell "handler ran" from
// "gate blocked". The precise guarantee: the response is NOT the gate's "Missing bearer
// token" 401 — i.e. the request got PAST the central gate to the handler (a valid signature
// would be processed, not rejected for lack of a JWT).
Deno.test("ICA-F1: public webhook routes bypass the central auth gate (reach their signature check)", async () => {
  for (const path of ["/webhooks/razorpay", "/communications/delivery/webhook"]) {
    const res = await handleRequest(
      new Request(`https://x${path}`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ event: "x" }),
      }),
      goodConfig,
    );
    const message = (await res.json())?.error?.message ?? "";
    assertEquals(message !== "Missing bearer token", true,
      `${path} must bypass the central auth gate — it was blocked by "Missing bearer token" (${res.status})`);
  }
});
