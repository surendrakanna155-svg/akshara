// PRC-A Batch 4 — storage quota route contract + enforcement dark-switch.
// A 503 (TENANT_DB_NOT_CONFIGURED) means the RBAC gate PASSED and the handler
// reached the (unconfigured-in-this-test) DB. Proves the permission layer only;
// the usage SQL / RLS are live probes.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims, AuthScope } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { handleGetStorageQuota } from "./storage_quota_handlers.ts";
import { enforceStorageQuota, storageQuotaEnforcementEnabled } from "./storage_quota_enforcement.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function claims(permissions: string[], scope: AuthScope = "organization"): AccessTokenClaims {
  return {
    sub: "a3000000-0000-4000-8000-000000000001",
    tenant_id: "a1000000-0000-4000-8000-000000000001",
    organization_id: "a1000000-0000-4000-8000-000000000001",
    school_id: scope === "organization" ? null : "a2000000-0000-4000-8000-000000000001",
    role: "management",
    role_slugs: ["management"],
    primary_role: "management",
    permissions,
    permissions_version: 1,
    scope,
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
  };
}

function req(token?: string): Request {
  return new Request("https://x/storage/quota", {
    headers: token ? { authorization: `Bearer ${token}` } : {},
  });
}

Deno.test("storage quota: GET denied without viewStorageQuota (403)", async () => {
  const token = await signAccessToken(SECRET, claims(["viewSis"]), 900);
  assertEquals((await handleGetStorageQuota(req(token), config)).status, 403);
});

Deno.test("storage quota: GET passes the RBAC gate with viewStorageQuota (503 = reached DB)", async () => {
  const token = await signAccessToken(SECRET, claims(["viewStorageQuota"]), 900);
  assertEquals((await handleGetStorageQuota(req(token), config)).status, 503);
});

Deno.test("storage quota: GET is 401 without a token", async () => {
  assertEquals((await handleGetStorageQuota(req(), config)).status, 401);
});

// ── enforcement dark-switch (deterministic, no DB) ───────────────────────────
Deno.test("enforcement is OFF by default → enforceStorageQuota is a no-op (null)", async () => {
  // No STORAGE_QUOTA_ENFORCEMENT in the env → the guard short-circuits before any
  // DB access, so passing an obviously-over size still returns null (allowed).
  assertEquals(storageQuotaEnforcementEnabled(), false);
  const res = await enforceStorageQuota(config, claims(["viewSis"]), 999_999_999_999);
  assertEquals(res, null);
});
