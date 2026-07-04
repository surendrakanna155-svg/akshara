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

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const goodConfig = () => ({ jwtSecret: SECRET } as AppConfig);

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
// fallback (proving the module table has a catch-all, not a silent 200).
Deno.test("ENG-4: an unregistered module route falls through to 404 NOT_FOUND", async () => {
  const res = await handleRequest(
    new Request("https://x/definitely/not/a/route", { method: "POST" }),
    goodConfig,
  );
  assertEquals(res.status, 404);
  assertEquals((await res.json()).error.code, "NOT_FOUND");
});
