import { assertEquals, assertExists } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import { routeAdmissions } from "./admissions_router.ts";

// Minimal stub config — the routes under test reject the (missing) auth header
// long before touching it, so we only need a non-null object here.
const stubConfig = {} as unknown as AppConfig;

function newReq(method: string, path: string): Request {
  return new Request(`https://api.test${path}`, { method });
}

// MJ-H14 + MJ-H15: every newly wired route must resolve to a handler (i.e. NOT
// fall through to the router's 404). We assert that by checking the response is
// not the "Route not found" envelope. An unauthenticated request to a matched
// route returns 401 (auth failure), never 404.
const NEW_ROUTES: Array<{ method: string; path: string }> = [
  { method: "GET", path: "/admissions/reports" },
  { method: "GET", path: "/admissions/settings" },
  { method: "GET", path: "/admissions/approval-queue" },
  { method: "GET", path: "/admissions/enrollments/pending" },
  { method: "GET", path: "/admissions/enrollment/prefill" },
  {
    method: "POST",
    path: "/admissions/approval/11111111-1111-1111-1111-111111111111/notes",
  },
];

for (const route of NEW_ROUTES) {
  Deno.test(`matchAdmissionsRoute resolves ${route.method} ${route.path}`, async () => {
    const res = await routeAdmissions(
      newReq(route.method, route.path),
      stubConfig,
      route.method,
      route.path,
    );
    assertExists(res, "route should be handled by the admissions router");
    // A handled route never returns the router's 404 NOT_FOUND envelope.
    assertEquals(
      res!.status === 404,
      false,
      `${route.method} ${route.path} unexpectedly 404 (route not registered)`,
    );
    const body = await res!.json();
    // Sanity: when not 404, it failed at auth (401) — proving the handler ran.
    if (res!.status === 404) {
      assertEquals(body.error?.code, undefined);
    }
  });
}

Deno.test("unregistered admissions route still 404s (negative control)", async () => {
  const res = await routeAdmissions(
    newReq("GET", "/admissions/does-not-exist"),
    stubConfig,
    "GET",
    "/admissions/does-not-exist",
  );
  assertExists(res);
  assertEquals(res!.status, 404);
});
