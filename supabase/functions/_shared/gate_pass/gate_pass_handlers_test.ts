// PRC-A Batch 2 — Gate Pass route contract (RBAC gate + validation), mirroring
// finance/finance_fee_reductions_route_contract_test.ts: a 503
// (TENANT_DB_NOT_CONFIGURED) means the RBAC/validation gate PASSED and the
// handler reached the (unconfigured-in-this-test) DB — i.e. authorization let
// the request through. `assertSessionValid` short-circuits (returns null)
// when `supabaseUrl`/`supabaseServiceRoleKey` are absent from config, so these
// tests exercise the permission layer without touching any real database.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims, AuthScope } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import {
  handleCancelGatePass,
  handleCreateGatePass,
  handleGetGatePass,
  handleListGatePasses,
  handleVerifyGatePass,
} from "./gate_pass_handlers.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;
const GATE_PASS_ID = "gp000000-0000-4000-8000-000000000001";
const STUDENT_ID = "a4000000-0000-4000-8000-000000000001";

function claims(
  permissions: string[],
  scope: AuthScope = "school",
): AccessTokenClaims {
  return {
    sub: "user-1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: scope === "parent" ? "parent" : "officeStaff",
    role_slugs: [scope === "parent" ? "parent" : "officeStaff"],
    primary_role: scope === "parent" ? "parent" : "officeStaff",
    permissions,
    permissions_version: 1,
    scope,
    school_group_id: null,
    student_id: null,
    child_ids: scope === "parent" ? [STUDENT_ID] : [],
    session_id: "s1",
  };
}

function req(method: string, path: string, token: string, body?: unknown): Request {
  return new Request(`https://x${path}`, {
    method,
    headers: {
      authorization: `Bearer ${token}`,
      ...(body !== undefined ? { "content-type": "application/json" } : {}),
    },
    ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
  });
}

const validCreateBody = {
  studentId: STUDENT_ID,
  passType: "early_pickup",
  reason: "dentist appointment",
  scheduledAt: "2026-07-15T14:00:00.000Z",
  pickupPersonName: "Ravi Rao",
  pickupPersonRelation: "father",
  pickupPersonPhone: "9999999999",
};

// ── POST /gate-passes (raise) ────────────────────────────────────────────────

Deno.test("route: create is denied without requestGatePass (403)", async () => {
  const token = await signAccessToken(SECRET, claims(["viewSis"]), 900);
  const res = await handleCreateGatePass(await req("POST", "/gate-passes", token, validCreateBody), config);
  assertEquals(res.status, 403);
  const env = await res.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("route: create passes the RBAC gate for school staff with requestGatePass (503 = reached the DB)", async () => {
  const token = await signAccessToken(SECRET, claims(["requestGatePass"], "school"), 900);
  const res = await handleCreateGatePass(await req("POST", "/gate-passes", token, validCreateBody), config);
  assertEquals(res.status, 503);
});

Deno.test("route: create passes the RBAC gate for a parent with requestGatePass (503)", async () => {
  const token = await signAccessToken(SECRET, claims(["requestGatePass"], "parent"), 900);
  const res = await handleCreateGatePass(await req("POST", "/gate-passes", token, validCreateBody), config);
  assertEquals(res.status, 503);
});

Deno.test("route: create rejects a missing studentId (422) before the DB", async () => {
  const token = await signAccessToken(SECRET, claims(["requestGatePass"]), 900);
  const { studentId: _drop, ...noStudent } = validCreateBody;
  const res = await handleCreateGatePass(await req("POST", "/gate-passes", token, noStudent), config);
  assertEquals(res.status, 422);
});

Deno.test("route: create rejects an invalid passType (422)", async () => {
  const token = await signAccessToken(SECRET, claims(["requestGatePass"]), 900);
  const res = await handleCreateGatePass(
    await req("POST", "/gate-passes", token, { ...validCreateBody, passType: "vacation" }),
    config,
  );
  assertEquals(res.status, 422);
});

Deno.test("route: create rejects an unparseable scheduledAt (422)", async () => {
  const token = await signAccessToken(SECRET, claims(["requestGatePass"]), 900);
  const res = await handleCreateGatePass(
    await req("POST", "/gate-passes", token, { ...validCreateBody, scheduledAt: "not-a-date" }),
    config,
  );
  assertEquals(res.status, 422);
});

Deno.test("route: create rejects an unauthenticated caller (401)", async () => {
  const res = await handleCreateGatePass(
    new Request("https://x/gate-passes", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(validCreateBody),
    }),
    config,
  );
  assertEquals(res.status, 401);
});

// ── GET /gate-passes (queue) ──────────────────────────────────────────────────

Deno.test("route: list is denied for a caller with none of the gate-pass permissions (403)", async () => {
  const token = await signAccessToken(SECRET, claims(["viewSis"]), 900);
  const res = await handleListGatePasses(await req("GET", "/gate-passes", token), config);
  assertEquals(res.status, 403);
});

Deno.test("route: list passes the gate with approveGatePass (503)", async () => {
  const token = await signAccessToken(SECRET, claims(["approveGatePass"]), 900);
  const res = await handleListGatePasses(await req("GET", "/gate-passes", token), config);
  assertEquals(res.status, 503);
});

Deno.test("route: list passes the gate with verifyGatePass (503)", async () => {
  const token = await signAccessToken(SECRET, claims(["verifyGatePass"]), 900);
  const res = await handleListGatePasses(await req("GET", "/gate-passes", token), config);
  assertEquals(res.status, 503);
});

Deno.test("route: list passes the gate for a parent with requestGatePass (503)", async () => {
  const token = await signAccessToken(SECRET, claims(["requestGatePass"], "parent"), 900);
  const res = await handleListGatePasses(await req("GET", "/gate-passes", token), config);
  assertEquals(res.status, 503);
});

// ── GET /gate-passes/:id (detail) ─────────────────────────────────────────────

Deno.test("route: detail is denied without any gate-pass permission (403)", async () => {
  const token = await signAccessToken(SECRET, claims([]), 900);
  const res = await handleGetGatePass(await req("GET", `/gate-passes/${GATE_PASS_ID}`, token), config, GATE_PASS_ID);
  assertEquals(res.status, 403);
});

Deno.test("route: detail passes the gate with requestGatePass (503)", async () => {
  const token = await signAccessToken(SECRET, claims(["requestGatePass"]), 900);
  const res = await handleGetGatePass(await req("GET", `/gate-passes/${GATE_PASS_ID}`, token), config, GATE_PASS_ID);
  assertEquals(res.status, 503);
});

// ── POST /gate-passes/:id/verify (the gate check) ─────────────────────────────

Deno.test("route: verify is denied without verifyGatePass (403)", async () => {
  const token = await signAccessToken(SECRET, claims(["approveGatePass"]), 900);
  const res = await handleVerifyGatePass(
    await req("POST", `/gate-passes/${GATE_PASS_ID}/verify`, token, { otp: "123456" }),
    config,
    GATE_PASS_ID,
  );
  assertEquals(res.status, 403);
});

Deno.test("route: verify is denied for a parent-scope caller even if somehow permissioned (school scope required)", async () => {
  const token = await signAccessToken(SECRET, claims(["verifyGatePass"], "parent"), 900);
  const res = await handleVerifyGatePass(
    await req("POST", `/gate-passes/${GATE_PASS_ID}/verify`, token, { otp: "123456" }),
    config,
    GATE_PASS_ID,
  );
  assertEquals(res.status, 403);
});

Deno.test("route: verify rejects a missing credential (422) before the DB", async () => {
  const token = await signAccessToken(SECRET, claims(["verifyGatePass"]), 900);
  const res = await handleVerifyGatePass(
    await req("POST", `/gate-passes/${GATE_PASS_ID}/verify`, token, {}),
    config,
    GATE_PASS_ID,
  );
  assertEquals(res.status, 422);
});

Deno.test("route: verify passes the gate with verifyGatePass + a credential (503)", async () => {
  const token = await signAccessToken(SECRET, claims(["verifyGatePass"]), 900);
  const res = await handleVerifyGatePass(
    await req("POST", `/gate-passes/${GATE_PASS_ID}/verify`, token, { otp: "123456" }),
    config,
    GATE_PASS_ID,
  );
  assertEquals(res.status, 503);
});

// ── POST /gate-passes/:id/cancel ──────────────────────────────────────────────

Deno.test("route: cancel is denied without requestGatePass or approveGatePass (403)", async () => {
  const token = await signAccessToken(SECRET, claims(["viewSis"]), 900);
  const res = await handleCancelGatePass(
    await req("POST", `/gate-passes/${GATE_PASS_ID}/cancel`, token),
    config,
    GATE_PASS_ID,
  );
  assertEquals(res.status, 403);
});

Deno.test("route: cancel is denied for a parent scope (RLS only grants UPDATE to school scope — see migration)", async () => {
  const token = await signAccessToken(SECRET, claims(["requestGatePass"], "parent"), 900);
  const res = await handleCancelGatePass(
    await req("POST", `/gate-passes/${GATE_PASS_ID}/cancel`, token),
    config,
    GATE_PASS_ID,
  );
  assertEquals(res.status, 403);
});

Deno.test("route: cancel passes the gate for school-scoped staff with requestGatePass (503)", async () => {
  const token = await signAccessToken(SECRET, claims(["requestGatePass"], "school"), 900);
  const res = await handleCancelGatePass(
    await req("POST", `/gate-passes/${GATE_PASS_ID}/cancel`, token),
    config,
    GATE_PASS_ID,
  );
  assertEquals(res.status, 503);
});

Deno.test("route: cancel passes the gate for school-scoped staff with approveGatePass (503)", async () => {
  const token = await signAccessToken(SECRET, claims(["approveGatePass"], "school"), 900);
  const res = await handleCancelGatePass(
    await req("POST", `/gate-passes/${GATE_PASS_ID}/cancel`, token),
    config,
    GATE_PASS_ID,
  );
  assertEquals(res.status, 503);
});
