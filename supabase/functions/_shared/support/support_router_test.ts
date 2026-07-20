import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import { routeSupport } from "./support_router.ts";

// Router-level checks (prefix match, method/id validation, auth-gating) need no
// DB: bad-path branches return before any handler runs, and a valid path with no
// bearer token returns 401 at authenticateRequest.
const CFG = {} as AppConfig;
const UUID = "11111111-1111-4111-8111-111111111111";

function req(method: string, path: string): Request {
  return new Request(`http://edge${path}`, { method });
}

Deno.test("routeSupport returns null for a non-/support path (chain continues)", async () => {
  const res = await routeSupport(req("GET", "/finance/invoices"), CFG, "GET", "/finance/invoices");
  assertEquals(res, null);
});

Deno.test("routeSupport 404s an unmatched /support path", async () => {
  const res = await routeSupport(req("GET", "/support/nope"), CFG, "GET", "/support/nope");
  assertEquals(res?.status, 404);
});

Deno.test("routeSupport 405s a wrong method on the collection", async () => {
  const res = await routeSupport(req("DELETE", "/support/incidents"), CFG, "DELETE", "/support/incidents");
  assertEquals(res?.status, 405);
});

Deno.test("routeSupport 422s a non-uuid incident id", async () => {
  const res = await routeSupport(
    req("GET", "/support/incidents/not-a-uuid"),
    CFG,
    "GET",
    "/support/incidents/not-a-uuid",
  );
  assertEquals(res?.status, 422);
});

Deno.test("routeSupport 404s an unknown sub-resource under a valid incident", async () => {
  const path = `/support/incidents/${UUID}/bogus`;
  const res = await routeSupport(req("POST", path), CFG, "POST", path);
  assertEquals(res?.status, 404);
});

Deno.test("routeSupport requires auth: create with no bearer token => 401", async () => {
  const res = await routeSupport(req("POST", "/support/incidents"), CFG, "POST", "/support/incidents");
  assertEquals(res?.status, 401);
});

Deno.test("routeSupport requires auth: list with no bearer token => 401", async () => {
  const res = await routeSupport(req("GET", "/support/incidents"), CFG, "GET", "/support/incidents");
  assertEquals(res?.status, 401);
});

Deno.test("routeSupport requires auth: analyze with no bearer token => 401", async () => {
  const path = `/support/incidents/${UUID}/analyze`;
  const res = await routeSupport(req("POST", path), CFG, "POST", path);
  assertEquals(res?.status, 401);
});
