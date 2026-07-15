// PRC-A caps 44-49 — platform-scoped DB access path tests (no live DB).
//
// Proves:
//   - `withPlatformContext` denies a non-superadmin/non-platform caller
//     BEFORE ever attempting a connection (the operation callback never
//     runs, and the env need not even be configured for the denial to fire).
//   - `withPlatformContext` throws `PlatformDbNotConfiguredError` for a
//     genuinely platform-scoped caller when `ERP_PLATFORM_DATABASE_URL` is
//     unset, so handlers can map it to the same 503 shape
//     `tenantDbNotConfiguredResponse()` produces.
//   - `isPlatformCaller` matches the codebase's existing scope+permission
//     idiom (mirrors the `ORG_SCOPES` allow-list already used in
//     `organization_builder_handlers.ts` / `director_handlers.ts`, and the
//     Platform-category permission catalog granted only to `superAdmin`).
//   - `assertEdgePlatformRole` — deploy-time role assertion, same shape as
//     `tenant_db_test.ts`'s `assertEdgeTenantRole` tests.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "./config.ts";
import type { AccessTokenClaims } from "./jwt.ts";
import {
  assertEdgePlatformRole,
  EDGE_PLATFORM_ROLE,
  isPlatformCaller,
  PlatformDbNotConfiguredError,
  PlatformScopeDeniedError,
  withPlatformContext,
} from "./platform_db.ts";

const FAKE_CONFIG = {} as AppConfig;

function superAdminClaims(over: Partial<AccessTokenClaims> = {}): AccessTokenClaims {
  return {
    sub: "u-1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: null,
    role: "superAdmin",
    role_slugs: ["superAdmin"],
    primary_role: "superAdmin",
    permissions: ["managePlatformVault"],
    permissions_version: 1,
    scope: "organization",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s-1",
    ...over,
  };
}

function clearPlatformEnv() {
  Deno.env.delete("ERP_PLATFORM_DATABASE_URL");
}

// ── isPlatformCaller ─────────────────────────────────────────────────────────

Deno.test("isPlatformCaller: true for organization scope + a Platform-category permission", () => {
  assertEquals(isPlatformCaller(superAdminClaims()), true);
});

Deno.test("isPlatformCaller: each Platform-category permission alone is sufficient (with org scope)", () => {
  for (
    const perm of [
      "managePlatformProviders",
      "viewPlatformUsage",
      "managePlatformVault",
      "managePlatformFeatures",
      "managePlatformWhatsApp",
    ]
  ) {
    assertEquals(
      isPlatformCaller(superAdminClaims({ permissions: [perm] })),
      true,
      `expected ${perm} to qualify`,
    );
  }
});

Deno.test("isPlatformCaller: false for school scope even with a Platform permission (session, not the platform owner)", () => {
  assertEquals(
    isPlatformCaller(superAdminClaims({ scope: "school", school_id: "school-1" })),
    false,
  );
});

Deno.test("isPlatformCaller: false for parent/student scope with a Platform permission", () => {
  assertEquals(isPlatformCaller(superAdminClaims({ scope: "parent" })), false);
  assertEquals(isPlatformCaller(superAdminClaims({ scope: "student" })), false);
});

Deno.test("isPlatformCaller: false for organization scope WITHOUT any Platform-category permission", () => {
  assertEquals(
    isPlatformCaller(superAdminClaims({ permissions: ["viewControlCenter"] })),
    false,
  );
});

Deno.test("isPlatformCaller: true for school_group scope + a Platform permission (parity with ORG_SCOPES elsewhere)", () => {
  assertEquals(
    isPlatformCaller(superAdminClaims({ scope: "school_group" })),
    true,
  );
});

// ── withPlatformContext — defense in depth BEFORE any connection ───────────

Deno.test("withPlatformContext denies a non-platform caller (school scope) before connecting — operation never runs, env need not be set", async () => {
  clearPlatformEnv(); // deliberately unset — proves the scope check runs first
  let called = false;
  await (async () => {
    try {
      await withPlatformContext(
        FAKE_CONFIG,
        superAdminClaims({ scope: "school", school_id: "school-1" }),
        async (_db) => {
          called = true;
          return null;
        },
      );
      throw new Error("expected withPlatformContext to throw");
    } catch (error) {
      assertEquals(error instanceof PlatformScopeDeniedError, true);
    }
  })();
  assertEquals(called, false, "operation must never run when the scope check fails");
});

Deno.test("withPlatformContext denies a caller with no Platform-category permission, even at organization scope", async () => {
  clearPlatformEnv();
  let called = false;
  try {
    await withPlatformContext(
      FAKE_CONFIG,
      superAdminClaims({ permissions: ["viewAdminHub"] }),
      async (_db) => {
        called = true;
        return null;
      },
    );
    throw new Error("expected withPlatformContext to throw");
  } catch (error) {
    assertEquals(error instanceof PlatformScopeDeniedError, true);
  }
  assertEquals(called, false);
});

Deno.test("withPlatformContext throws PlatformDbNotConfiguredError for a genuine platform caller when ERP_PLATFORM_DATABASE_URL is unset", async () => {
  clearPlatformEnv();
  let called = false;
  try {
    await withPlatformContext(FAKE_CONFIG, superAdminClaims(), async (_db) => {
      called = true;
      return null;
    });
    throw new Error("expected withPlatformContext to throw");
  } catch (error) {
    assertEquals(error instanceof PlatformDbNotConfiguredError, true);
  }
  assertEquals(called, false, "operation must never run without a configured connection");
});

// ── assertEdgePlatformRole — deploy-time assertion (mirrors tenant_db_test.ts) ──

Deno.test("assertEdgePlatformRole accepts erp_platform with NOBYPASSRLS", () => {
  assertEquals(
    assertEdgePlatformRole({ role: EDGE_PLATFORM_ROLE, bypassRls: false }),
    null,
  );
});

Deno.test("assertEdgePlatformRole rejects service_role", () => {
  const err = assertEdgePlatformRole({ role: "service_role", bypassRls: true });
  assertEquals(err !== null, true);
});

Deno.test("assertEdgePlatformRole rejects erp_tenant (wrong role for the platform path)", () => {
  const err = assertEdgePlatformRole({ role: "erp_tenant", bypassRls: false });
  assertEquals(err !== null, true);
  assertEquals(err!.includes("erp_platform"), true);
});

Deno.test("assertEdgePlatformRole rejects erp_platform that can bypass RLS", () => {
  const err = assertEdgePlatformRole({ role: EDGE_PLATFORM_ROLE, bypassRls: true });
  assertEquals(err !== null, true);
  assertEquals(err!.includes("BYPASS"), true);
});

Deno.test("assertEdgePlatformRole rejects an unknown/missing role", () => {
  assertEquals(assertEdgePlatformRole({}) !== null, true);
});
