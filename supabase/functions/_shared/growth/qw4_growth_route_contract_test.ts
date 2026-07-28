// QW4 · QA-B-010 — growth (RAW routeGrowth) ROUTE/RBAC contract (DB-free).
//
// This tests the RAW `routeGrowth` permission contract. The module.marketing 402
// entitlement gate is applied by the index-level withEntitlement wrapper (covered
// by QA-B-065), NOT by routeGrowth — so it never appears here.
//
// Proven WITHOUT a live Postgres (503/TENANT_DB_NOT_CONFIGURED = gate PASSED,
// handler reached the unconfigured tenant DB = "authorized"):
//   - POST /growth/campaigns: OR-fixed write gate — manageGrowthPlatform OR the
//     broader manageAdmissions independently authorize (503); a non-holder → 403;
//     missing fields → 422 before the DB.
//   - GET /growth/dashboard + /growth/funnel: OR-fixed read gate — viewGrowthPlatform
//     OR viewAdmissions authorize (503).
//   - GET /growth/campaigns/history: read history. NOTE this handler still gates on
//     the single slug viewGrowthPlatform (NOT OR-fixed) — viewAdmissions is denied
//     here. See FINDINGS (P2 list-read OR asymmetry).
// Live remainder (infra): real persisted campaign/inquiry rows + per-school RLS
// isolation are covered by the live cert.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeGrowth } from "./growth_router.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function claims(permissions: string[], over: Partial<AccessTokenClaims> = {}): AccessTokenClaims {
  return {
    sub: "u1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "admissionsManager",
    role_slugs: ["admissionsManager"],
    primary_role: "admissionsManager",
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
  perms: string[],
  body?: unknown,
): Promise<Response | null> {
  const token = await signAccessToken(SECRET, claims(perms), 900);
  const req = new Request(`https://x${path}`, {
    method,
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
  return routeGrowth(req, config, method, path);
}

const validCampaign = { name: "Open House", channel: "whatsapp" };

Deno.test("QA-B-010: create campaign is denied for a non-holder (403 FORBIDDEN)", async () => {
  const res = await call("POST", "/growth/campaigns", ["viewSis"], validCampaign);
  assertEquals(res?.status, 403);
  const env = await res!.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("QA-B-010: create campaign passes the gate with manageGrowthPlatform (503)", async () => {
  const res = await call("POST", "/growth/campaigns", ["manageGrowthPlatform"], validCampaign);
  assertEquals(res?.status, 503);
});

Deno.test("QA-B-010: OR-fix — broader manageAdmissions also authorizes the write (503)", async () => {
  const res = await call("POST", "/growth/campaigns", ["manageAdmissions"], validCampaign);
  assertEquals(res?.status, 503);
});

Deno.test("QA-B-010: create campaign rejects missing channel (422) before the DB", async () => {
  const res = await call("POST", "/growth/campaigns", ["manageGrowthPlatform"], { name: "x" });
  assertEquals(res?.status, 422);
});

Deno.test("QA-B-010: create campaign denies a holder of only the READ slug (403)", async () => {
  const res = await call("POST", "/growth/campaigns", ["viewGrowthPlatform"], validCampaign);
  assertEquals(res?.status, 403);
});

Deno.test("QA-B-010: dashboard passes the gate with viewGrowthPlatform (503)", async () => {
  const res = await call("GET", "/growth/dashboard", ["viewGrowthPlatform"]);
  assertEquals(res?.status, 503);
});

Deno.test("QA-B-010: OR-fix — broader viewAdmissions also authorizes the dashboard read (503)", async () => {
  const res = await call("GET", "/growth/dashboard", ["viewAdmissions"]);
  assertEquals(res?.status, 503);
});

Deno.test("QA-B-010: funnel OR-fix — viewAdmissions authorizes the funnel read (503)", async () => {
  const res = await call("GET", "/growth/funnel", ["viewAdmissions"]);
  assertEquals(res?.status, 503);
});

Deno.test("QA-B-010: campaign history passes the gate with viewGrowthPlatform (503)", async () => {
  const res = await call("GET", "/growth/campaigns/history", ["viewGrowthPlatform"]);
  assertEquals(res?.status, 503);
});

Deno.test("QA-B-010: campaign history is denied for a non-holder (403 FORBIDDEN)", async () => {
  const res = await call("GET", "/growth/campaigns/history", ["viewSis"]);
  assertEquals(res?.status, 403);
});

Deno.test("QA-B-010: campaign history list-read is NOT OR-fixed — viewAdmissions is denied (403)", async () => {
  // Documents the P2 asymmetry: the list/history reads gate on the single slug
  // viewGrowthPlatform, unlike dashboard/funnel which accept viewAdmissions too.
  const res = await call("GET", "/growth/campaigns/history", ["viewAdmissions"]);
  assertEquals(res?.status, 403);
});

Deno.test("QA-B-010: unauthenticated create is rejected (401)", async () => {
  const req = new Request("https://x/growth/campaigns", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(validCampaign),
  });
  const res = await routeGrowth(req, config, "POST", "/growth/campaigns");
  assertEquals(res?.status, 401);
});

Deno.test("QA-B-010: router returns null for a path outside its prefix", async () => {
  const res = await call("GET", "/finance/refunds", ["viewGrowthPlatform"]);
  assertEquals(res, null);
});

Deno.test("QA-B-010: unregistered path under the prefix returns null (central dispatcher 404s)", async () => {
  const res = await call("GET", "/growth/nope", ["viewGrowthPlatform"]);
  assertEquals(res, null);
});
