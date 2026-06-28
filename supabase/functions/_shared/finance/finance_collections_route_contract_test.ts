// QW1 · QA-B-014 — POST /finance/collections collect-fee ROUTE contract.
//
// The repository-level persist + receipt behaviour is already proven in
// finance_collections_repository_test.ts ("createCollection creates collection
// and receipt", "...updates invoice and account balances"). What was missing —
// and is closed here — is the ROUTE handler contract: the write is denied for a
// non-finance role (403 FORBIDDEN), passes the gate for a finance role, and
// rejects malformed input (422) — all before the DB layer (no live Postgres).
//
// As in pilot_rbac_gate_test.ts, a 503 (TENANT_DB_NOT_CONFIGURED) means the
// permission gate PASSED and the handler proceeded to the (unconfigured) DB —
// i.e. the manageFinance check let the request through. The end-to-end 200 +
// persisted rows are covered by the repository test + the live cert.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { handleCreateCollection } from "./finance_collections_handlers.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function claims(permissions: string[]): AccessTokenClaims {
  return {
    sub: "user-1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "financeAdmin",
    role_slugs: ["financeAdmin"],
    primary_role: "financeAdmin",
    permissions,
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
  };
}

function post(token: string, body: unknown): Request {
  return new Request("https://x/finance/collections", {
    method: "POST",
    headers: {
      authorization: `Bearer ${token}`,
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });
}

const validBody = {
  invoice_id: "inv-1",
  amount_collected: 5000,
  payment_method: "cash",
};

Deno.test("QA-B-014: collect-fee is denied for a non-finance role (403 FORBIDDEN)", async () => {
  // inventoryManager-style token: holds viewInventory, NOT manageFinance.
  const token = await signAccessToken(SECRET, claims(["viewInventory"]), 900);
  const res = await handleCreateCollection(post(token, validBody), config);
  assertEquals(res.status, 403);
  const env = await res.json();
  assertEquals(env.error.code, "FORBIDDEN");
  assertEquals(env.data, null);
});

Deno.test("QA-B-014: collect-fee passes the gate WITH manageFinance (reaches DB layer)", async () => {
  const token = await signAccessToken(SECRET, claims(["manageFinance"]), 900);
  const res = await handleCreateCollection(post(token, validBody), config);
  // Gate + validation passed → reached the (unconfigured) tenant DB.
  assertEquals(res.status, 503);
});

Deno.test("QA-B-014: collect-fee rejects a missing invoice (422) before the DB", async () => {
  const token = await signAccessToken(SECRET, claims(["manageFinance"]), 900);
  const res = await handleCreateCollection(
    post(token, { amount_collected: 5000, payment_method: "cash" }),
    config,
  );
  assertEquals(res.status, 422);
});

Deno.test("QA-B-014: collect-fee rejects a non-positive amount (422) before the DB", async () => {
  const token = await signAccessToken(SECRET, claims(["manageFinance"]), 900);
  const res = await handleCreateCollection(
    post(token, { invoice_id: "inv-1", amount_collected: 0, payment_method: "cash" }),
    config,
  );
  assertEquals(res.status, 422);
});

Deno.test("QA-B-014: collect-fee rejects an unauthenticated caller (401)", async () => {
  const res = await handleCreateCollection(
    new Request("https://x/finance/collections", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(validBody),
    }),
    config,
  );
  assertEquals(res.status, 401);
});
