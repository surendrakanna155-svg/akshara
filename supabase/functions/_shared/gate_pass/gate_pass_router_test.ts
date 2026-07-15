import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { matchGatePassRoute, routeGatePass } from "./gate_pass_router.ts";
import type { AppConfig } from "../config.ts";

const config = { jwtSecret: "test-jwt-secret-minimum-32-characters-long" } as AppConfig;
const ID = "gp000000-0000-4000-8000-000000000001";

Deno.test("router: GET /gate-passes -> handleListGatePasses", () => {
  const match = matchGatePassRoute("GET", "/gate-passes");
  assertEquals(match?.args, []);
  assertEquals(match?.handler.name, "handleListGatePasses");
});

Deno.test("router: POST /gate-passes -> handleCreateGatePass", () => {
  const match = matchGatePassRoute("POST", "/gate-passes");
  assertEquals(match?.args, []);
  assertEquals(match?.handler.name, "handleCreateGatePass");
});

Deno.test("router: GET /gate-passes/:id -> handleGetGatePass", () => {
  const match = matchGatePassRoute("GET", `/gate-passes/${ID}`);
  assertEquals(match?.args, [ID]);
  assertEquals(match?.handler.name, "handleGetGatePass");
});

Deno.test("router: POST /gate-passes/:id/verify -> handleVerifyGatePass (does not collide with detail)", () => {
  const match = matchGatePassRoute("POST", `/gate-passes/${ID}/verify`);
  assertEquals(match?.args, [ID]);
  assertEquals(match?.handler.name, "handleVerifyGatePass");
});

Deno.test("router: POST /gate-passes/:id/cancel -> handleCancelGatePass", () => {
  const match = matchGatePassRoute("POST", `/gate-passes/${ID}/cancel`);
  assertEquals(match?.args, [ID]);
  assertEquals(match?.handler.name, "handleCancelGatePass");
});

Deno.test("router: a GET on /verify (wrong verb) does not resolve", () => {
  const match = matchGatePassRoute("GET", `/gate-passes/${ID}/verify`);
  assertEquals(match, null);
});

Deno.test("routeGatePass: returns null for a foreign prefix (lets the next router try)", async () => {
  const res = await routeGatePass(new Request("https://x/sis/students"), config, "GET", "/sis/students");
  assertEquals(res, null);
});

Deno.test("routeGatePass: an unmatched path inside the prefix is a 404 envelope, not null", async () => {
  const res = await routeGatePass(
    new Request("https://x/gate-passes/foo/bar/baz"),
    config,
    "GET",
    "/gate-passes/foo/bar/baz",
  );
  assertEquals(res?.status, 404);
  const env = await res!.json();
  assertEquals(env.error.code, "NOT_FOUND");
});
