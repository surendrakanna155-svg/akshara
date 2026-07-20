// PRC-A caps 44-49 — pins the vault handler wiring in
// `platform_providers_handlers.ts`: `handleListPlatformProviders` /
// `handleUpsertPlatformProvider` / `handleRotateVaultSecret` /
// `handleCheckVaultHealth` must run on `withPlatformContext` (the new
// `erp_platform` path), not `withTenantContext`. Same DB-free idiom as
// `qw4_control_center_route_contract_test.ts` (route-contract proof via
// `signAccessToken` + a config with no `supabaseUrl`, so
// `assertSessionValid` short-circuits and no live DB is needed): the
// distinguishing signal is the error CODE in the 503 body —
// `PLATFORM_DB_NOT_CONFIGURED` (platform path) vs `TENANT_DB_NOT_CONFIGURED`
// (tenant path) — which only changes if the handler body actually calls a
// different helper, so it is not satisfiable by coincidence.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import {
  handleCheckVaultHealth,
  handleGetPlatformUsage,
  handleListFeatureEnablements,
  handleListPlatformProviders,
  handleRotateVaultSecret,
  handleSetFeatureEnablement,
  handleUpsertPlatformProvider,
} from "./platform_providers_handlers.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
// No supabaseUrl/supabaseServiceRoleKey — assertSessionValid short-circuits
// to "proceed" (see session_validation.ts), and no ERP_*_DATABASE_URL — both
// withTenantContext and withPlatformContext throw their respective
// not-configured error, which is exactly the signal this file pins.
const config = { jwtSecret: SECRET } as AppConfig;

function claims(perms: string[], over: Partial<AccessTokenClaims> = {}): AccessTokenClaims {
  return {
    sub: "u1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: null,
    role: "superAdmin",
    role_slugs: ["superAdmin"],
    primary_role: "superAdmin",
    permissions: perms,
    permissions_version: 1,
    scope: "organization",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
    ...over,
  };
}

async function req(
  method: string,
  url: string,
  perms: string[],
  over: Partial<AccessTokenClaims> = {},
  body?: unknown,
): Promise<Request> {
  const token = await signAccessToken(SECRET, claims(perms, over), 900);
  return new Request(url, {
    method,
    headers: {
      authorization: `Bearer ${token}`,
      "content-type": "application/json",
    },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
}

async function errorCode(res: Response): Promise<string> {
  const env = await res.json();
  return env.error?.code;
}

// ── The 4 rewired vault handlers now hit the PLATFORM path ─────────────────

Deno.test("handleListPlatformProviders runs on withPlatformContext (503 PLATFORM_DB_NOT_CONFIGURED, not tenant)", async () => {
  const res = await handleListPlatformProviders(
    await req("GET", "https://x/control-center/providers", ["managePlatformProviders"]),
    config,
  );
  assertEquals(res.status, 503);
  assertEquals(await errorCode(res), "PLATFORM_DB_NOT_CONFIGURED");
});

Deno.test("handleUpsertPlatformProvider runs on withPlatformContext (503 PLATFORM_DB_NOT_CONFIGURED)", async () => {
  const res = await handleUpsertPlatformProvider(
    await req(
      "POST",
      "https://x/control-center/providers",
      ["managePlatformProviders"],
      {},
      { providerCategory: "sms", providerName: "twilio" },
    ),
    config,
  );
  assertEquals(res.status, 503);
  assertEquals(await errorCode(res), "PLATFORM_DB_NOT_CONFIGURED");
});

Deno.test("handleRotateVaultSecret runs on withPlatformContext (503 PLATFORM_DB_NOT_CONFIGURED)", async () => {
  const res = await handleRotateVaultSecret(
    await req(
      "POST",
      "https://x/control-center/vault/rotate",
      ["managePlatformVault"],
      {},
      { secretId: "s1", newCredential: "sk-new" },
    ),
    config,
  );
  assertEquals(res.status, 503);
  assertEquals(await errorCode(res), "PLATFORM_DB_NOT_CONFIGURED");
});

Deno.test("handleCheckVaultHealth runs on withPlatformContext (503 PLATFORM_DB_NOT_CONFIGURED)", async () => {
  const res = await handleCheckVaultHealth(
    await req("GET", "https://x/control-center/vault/health?secretId=s1", ["managePlatformVault"]),
    config,
  );
  assertEquals(res.status, 503);
  assertEquals(await errorCode(res), "PLATFORM_DB_NOT_CONFIGURED");
});

// ── App-layer defense in depth: withPlatformContext's OWN scope check ──────
// (in ADDITION to the route-level requirePermission gate, which these three
// intentionally still satisfy — proving the SECOND, independent check.)

Deno.test("handleRotateVaultSecret denies (403) a school-scope token even though it holds managePlatformVault", async () => {
  const res = await handleRotateVaultSecret(
    await req(
      "POST",
      "https://x/control-center/vault/rotate",
      ["managePlatformVault"],
      { scope: "school", school_id: "school-1" },
      { secretId: "s1", newCredential: "sk-new" },
    ),
    config,
  );
  assertEquals(res.status, 403);
  assertEquals(await errorCode(res), "FORBIDDEN");
});

Deno.test("handleCheckVaultHealth denies (403) a parent-scope token even though it holds managePlatformVault", async () => {
  const res = await handleCheckVaultHealth(
    await req(
      "GET",
      "https://x/control-center/vault/health?secretId=s1",
      ["managePlatformVault"],
      { scope: "parent", school_id: "school-1" },
    ),
    config,
  );
  assertEquals(res.status, 403);
  assertEquals(await errorCode(res), "FORBIDDEN");
});

Deno.test("handleListPlatformProviders denies (403) a school-scope token even though it holds managePlatformProviders", async () => {
  const res = await handleListPlatformProviders(
    await req(
      "GET",
      "https://x/control-center/providers",
      ["managePlatformProviders"],
      { scope: "school", school_id: "school-1" },
    ),
    config,
  );
  assertEquals(res.status, 403);
  assertEquals(await errorCode(res), "FORBIDDEN");
});

// ── Unchanged handlers stay on the tenant path (regression guard) ──────────
// handleGetPlatformUsage / handleListFeatureEnablements /
// handleSetFeatureEnablement read/write platform_usage_events /
// platform_feature_enablements, not the vault tables — deliberately left on
// withTenantContext (see the header note in platform_providers_handlers.ts).

Deno.test("handleGetPlatformUsage is UNCHANGED — still withTenantContext (503 TENANT_DB_NOT_CONFIGURED)", async () => {
  const res = await handleGetPlatformUsage(
    await req("GET", "https://x/control-center/usage", ["viewPlatformUsage"]),
    config,
  );
  assertEquals(res.status, 503);
  assertEquals(await errorCode(res), "TENANT_DB_NOT_CONFIGURED");
});

Deno.test("handleListFeatureEnablements is UNCHANGED — still withTenantContext (503 TENANT_DB_NOT_CONFIGURED)", async () => {
  const res = await handleListFeatureEnablements(
    await req("GET", "https://x/control-center/features", ["managePlatformFeatures"]),
    config,
  );
  assertEquals(res.status, 503);
  assertEquals(await errorCode(res), "TENANT_DB_NOT_CONFIGURED");
});

Deno.test("handleSetFeatureEnablement is UNCHANGED — still withTenantContext (503 TENANT_DB_NOT_CONFIGURED)", async () => {
  const res = await handleSetFeatureEnablement(
    await req(
      "POST",
      "https://x/control-center/features",
      ["managePlatformFeatures"],
      {},
      { schoolId: "school-1", featureKey: "x", enabled: true },
    ),
    config,
  );
  assertEquals(res.status, 503);
  assertEquals(await errorCode(res), "TENANT_DB_NOT_CONFIGURED");
});
