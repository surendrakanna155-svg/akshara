// PRC-A Batch 3 — AI credit wallet route contract (RBAC gate + validation),
// mirroring gate_pass/gate_pass_handlers_test.ts: a 503
// (TENANT_DB_NOT_CONFIGURED) means the RBAC + validation gates PASSED and the
// handler reached the (unconfigured-in-this-test) DB — i.e. authorization let
// the request through. These tests exercise the permission + validation layer
// only; they prove NOTHING about the balance SQL or double-spend safety, which
// are live probes (see the Batch 3 live-cert suite).

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims, AuthScope } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { handleGetAiWallet, handleGrantAiCredits } from "./ai_wallet_handlers.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function claims(
  permissions: string[],
  scope: AuthScope = "organization",
): AccessTokenClaims {
  return {
    sub: "a3000000-0000-4000-8000-000000000001",
    tenant_id: "a1000000-0000-4000-8000-000000000001",
    organization_id: "a1000000-0000-4000-8000-000000000001",
    school_id: scope === "organization" ? null : "a2000000-0000-4000-8000-000000000001",
    role: "superAdmin",
    role_slugs: ["superAdmin"],
    primary_role: "superAdmin",
    permissions,
    permissions_version: 1,
    scope,
    school_group_id: null,
    student_id: null,
    child_ids: [],
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

const validGrant = { entryType: "top_up", units: 1000, reason: "invoice INV-42" };

// ── GET /ai-wallet ───────────────────────────────────────────────────────────
Deno.test("wallet: GET is denied without viewAiWallet (403)", async () => {
  const token = await signAccessToken(SECRET, claims(["viewSis"]), 900);
  const res = await handleGetAiWallet(req("GET", "/ai-wallet", token), config);
  assertEquals(res.status, 403);
});

Deno.test("wallet: GET passes the RBAC gate with viewAiWallet (503 = reached the DB)", async () => {
  const token = await signAccessToken(SECRET, claims(["viewAiWallet"]), 900);
  const res = await handleGetAiWallet(req("GET", "/ai-wallet", token), config);
  assertEquals(res.status, 503);
});

Deno.test("wallet: GET is 401 without a token", async () => {
  const res = await handleGetAiWallet(new Request("https://x/ai-wallet"), config);
  assertEquals(res.status, 401);
});

// ── POST /ai-wallet/grant ────────────────────────────────────────────────────
Deno.test("wallet: grant is denied for a caller with none of the wallet permissions (403)", async () => {
  const token = await signAccessToken(SECRET, claims(["viewSis"]), 900);
  const res = await handleGrantAiCredits(req("POST", "/ai-wallet/grant", token, validGrant), config);
  assertEquals(res.status, 403);
});

Deno.test("wallet: grant is denied for a VIEW-only holder — view is not manage (403)", async () => {
  // The whole point of the wallet: an org that can SEE its balance still cannot
  // top itself up. viewAiWallet must never satisfy the grant gate.
  const token = await signAccessToken(SECRET, claims(["viewAiWallet"]), 900);
  const res = await handleGrantAiCredits(req("POST", "/ai-wallet/grant", token, validGrant), config);
  assertEquals(res.status, 403);
});

Deno.test("wallet: grant passes the RBAC + validation gate with manageAiCredits (503)", async () => {
  const token = await signAccessToken(SECRET, claims(["manageAiCredits"]), 900);
  const res = await handleGrantAiCredits(req("POST", "/ai-wallet/grant", token, validGrant), config);
  assertEquals(res.status, 503);
});

Deno.test("wallet: grant rejects an unknown entryType (422) before the DB", async () => {
  const token = await signAccessToken(SECRET, claims(["manageAiCredits"]), 900);
  const res = await handleGrantAiCredits(
    req("POST", "/ai-wallet/grant", token, { ...validGrant, entryType: "refund" }),
    config,
  );
  assertEquals(res.status, 422);
});

Deno.test("wallet: grant rejects units = 0 (422)", async () => {
  const token = await signAccessToken(SECRET, claims(["manageAiCredits"]), 900);
  const res = await handleGrantAiCredits(
    req("POST", "/ai-wallet/grant", token, { ...validGrant, units: 0 }),
    config,
  );
  assertEquals(res.status, 422);
});

Deno.test("wallet: grant rejects a non-numeric units (422)", async () => {
  const token = await signAccessToken(SECRET, claims(["manageAiCredits"]), 900);
  const res = await handleGrantAiCredits(
    req("POST", "/ai-wallet/grant", token, { ...validGrant, units: "lots" }),
    config,
  );
  assertEquals(res.status, 422);
});

Deno.test("wallet: grant rejects a missing reason (422) — a grant must be justified", async () => {
  const token = await signAccessToken(SECRET, claims(["manageAiCredits"]), 900);
  const res = await handleGrantAiCredits(
    req("POST", "/ai-wallet/grant", token, { entryType: "top_up", units: 500 }),
    config,
  );
  assertEquals(res.status, 422);
});

Deno.test("wallet: grant accepts a negative expiry (reaches DB, 503) — sign rules are DB-enforced", async () => {
  // The handler allows any non-zero integer through to grantCredits, which (with
  // the DB CHECK) enforces the per-type sign rule. A negative expiry is valid.
  const token = await signAccessToken(SECRET, claims(["manageAiCredits"]), 900);
  const res = await handleGrantAiCredits(
    req("POST", "/ai-wallet/grant", token, { entryType: "expiry", units: -200, reason: "expired" }),
    config,
  );
  assertEquals(res.status, 503);
});
