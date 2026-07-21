// ICA-G2 — Entitlement enforcement phased rollout (master MODE + per-org flag).
//
// These are the ON-path tests the roadmap asked for: they exercise the REAL
// production decision function `resolveEntitlementDecision` (the exact code that
// runs inside enforceEntitlement's tenant context) against a SEEDED org and a
// SEEDED plan, across every rollout mode — with no live Postgres, using the same
// fake-TenantQueryClient harness the other entitlement tests use.
//
// Proven here:
//   * master "off" (default) → enforcement runs NOWHERE (today's safe behavior).
//   * master "allowlist" + org flag TRUE + org has the entitlement → passes;
//                          + org lacks the entitlement → 402 PLAN_UPGRADE_REQUIRED;
//                          + suspended subscription → 402 SUBSCRIPTION_SUSPENDED.
//   * master "allowlist" + org flag FALSE → NOT enforced (gradual rollout works).
//   * master "all" → enforced regardless of the per-org flag.
//   * mode resolution precedence (mode env > legacy boolean > default off).

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { resolveEntitlementDecision } from "./entitlement_middleware.ts";
import {
  entitlementEnforcementEnabled,
  entitlementEnforcementMode,
  isEntitlementEnforcedForOrg,
} from "./entitlement_enforcement.ts";

const MODE_ENV = "ENTITLEMENT_ENFORCEMENT_MODE";
const LEGACY_ENV = "ENTITLEMENT_ENFORCEMENT";
const ORG = "org-1";
const MODULE = "module.transport"; // a plan-gated optional module

// ── Seeded rows (raw column shapes the repository maps) ──────────────────────
interface Seed {
  /** organizations.entitlement_enforcement_enabled for ORG. */
  orgFlag: boolean;
  /** entitlement slugs the org's plan grants (plan_entitlements). */
  planEntitlements: string[];
  /** subscription status; when null → no subscription row (Trial fallback). */
  status: string | null;
}

function planRow(): Record<string, unknown> {
  return {
    slug: "standard",
    name: "Standard",
    description: "",
    tier_rank: 1,
    student_slab_min: 0,
    student_slab_max: 500,
    max_schools: 3,
    max_storage_bytes: null,
    max_sms_per_month: null,
    grace_buffer_percent: 10,
    trial_length_days: null,
    trial_grace_days: null,
    base_price_paise: 0,
    is_trial: false,
    is_public: true,
    is_active: true,
  };
}

function subscriptionRow(status: string): Record<string, unknown> {
  return {
    organization_id: ORG,
    plan_slug: "standard",
    status,
    student_slab_max: null,
    max_schools_override: null,
    trial_ends_at: null,
    grace_ends_at: null,
    student_count_cached: 0,
    school_count_cached: 0,
    overrides: {},
    started_at: new Date().toISOString(),
  };
}

/** A TenantQueryClient stand-in that answers the org-flag lookup AND
 * resolveSubscription's queries from the seed. No network, no Postgres. */
function fakeDb(seed: Seed): TenantQueryClient {
  const fake = {
    // deno-lint-ignore no-explicit-any
    queryObject(sql: string, _args: unknown[] = []): Promise<any[]> {
      // Order matters: check the specific table tokens before the generic one.
      if (sql.includes("organization_subscriptions")) {
        return Promise.resolve(seed.status === null ? [] : [subscriptionRow(seed.status)]);
      }
      if (sql.includes("subscription_plans")) return Promise.resolve([planRow()]);
      if (sql.includes("plan_entitlements")) {
        return Promise.resolve(seed.planEntitlements.map((s) => ({ entitlement_slug: s })));
      }
      if (sql.includes("school_configuration")) return Promise.resolve([]);
      if (sql.includes("FROM organizations")) {
        return Promise.resolve([{ enabled: seed.orgFlag }]);
      }
      return Promise.resolve([]);
    },
    queryCount(_sql: string, _args: unknown[] = []): Promise<number> {
      return Promise.resolve(0);
    },
  };
  return fake as unknown as TenantQueryClient;
}

/** Run `fn` with the master mode set (and the legacy flag cleared), restoring env. */
async function withMode(mode: string, fn: () => Promise<void> | void): Promise<void> {
  const prevMode = Deno.env.get(MODE_ENV);
  const prevLegacy = Deno.env.get(LEGACY_ENV);
  Deno.env.set(MODE_ENV, mode);
  Deno.env.delete(LEGACY_ENV);
  try {
    await fn();
  } finally {
    if (prevMode === undefined) Deno.env.delete(MODE_ENV);
    else Deno.env.set(MODE_ENV, prevMode);
    if (prevLegacy === undefined) Deno.env.delete(LEGACY_ENV);
    else Deno.env.set(LEGACY_ENV, prevLegacy);
  }
}

function clearEnv(): void {
  Deno.env.delete(MODE_ENV);
  Deno.env.delete(LEGACY_ENV);
}

// ─── Mode resolution precedence ──────────────────────────────────────────────

Deno.test("mode: default (nothing set) is 'off' → machinery disabled", () => {
  clearEnv();
  try {
    assertEquals(entitlementEnforcementMode(), "off");
    assertEquals(entitlementEnforcementEnabled(), false);
  } finally {
    clearEnv();
  }
});

Deno.test("mode: ENTITLEMENT_ENFORCEMENT_MODE=allowlist|all is honored; enabled=true", async () => {
  await withMode("allowlist", () => {
    assertEquals(entitlementEnforcementMode(), "allowlist");
    assertEquals(entitlementEnforcementEnabled(), true);
  });
  await withMode("all", () => {
    assertEquals(entitlementEnforcementMode(), "all");
    assertEquals(entitlementEnforcementEnabled(), true);
  });
});

Deno.test("mode: legacy ENTITLEMENT_ENFORCEMENT=true (no mode) maps to 'all' (backward compat)", () => {
  clearEnv();
  Deno.env.set(LEGACY_ENV, "true");
  try {
    assertEquals(entitlementEnforcementMode(), "all");
    assertEquals(entitlementEnforcementEnabled(), true);
  } finally {
    clearEnv();
  }
});

Deno.test("mode: an explicit MODE wins over the legacy flag (mode=off beats legacy true)", () => {
  clearEnv();
  Deno.env.set(MODE_ENV, "off");
  Deno.env.set(LEGACY_ENV, "true");
  try {
    assertEquals(entitlementEnforcementMode(), "off");
    assertEquals(entitlementEnforcementEnabled(), false);
  } finally {
    clearEnv();
  }
});

Deno.test("mode: an unrecognized MODE value falls back (to legacy, else off)", () => {
  clearEnv();
  Deno.env.set(MODE_ENV, "banana");
  try {
    assertEquals(entitlementEnforcementMode(), "off");
  } finally {
    clearEnv();
  }
  Deno.env.set(MODE_ENV, "banana");
  Deno.env.set(LEGACY_ENV, "true");
  try {
    assertEquals(entitlementEnforcementMode(), "all");
  } finally {
    clearEnv();
  }
});

// ─── isEntitlementEnforcedForOrg (the single per-org resolver) ────────────────

Deno.test("isEntitlementEnforcedForOrg: off → false regardless of the org flag", async () => {
  await withMode("off", async () => {
    assertEquals(await isEntitlementEnforcedForOrg(ORG, fakeDb({ orgFlag: true, planEntitlements: [], status: "active" })), false);
  });
});

Deno.test("isEntitlementEnforcedForOrg: all → true regardless of the org flag (no DB read needed)", async () => {
  await withMode("all", async () => {
    assertEquals(await isEntitlementEnforcedForOrg(ORG, fakeDb({ orgFlag: false, planEntitlements: [], status: "active" })), true);
  });
});

Deno.test("isEntitlementEnforcedForOrg: allowlist → tracks the per-org flag", async () => {
  await withMode("allowlist", async () => {
    assertEquals(await isEntitlementEnforcedForOrg(ORG, fakeDb({ orgFlag: true, planEntitlements: [], status: "active" })), true);
    assertEquals(await isEntitlementEnforcedForOrg(ORG, fakeDb({ orgFlag: false, planEntitlements: [], status: "active" })), false);
  });
});

// ─── ON-path decision (resolveEntitlementDecision — the real production code) ──

Deno.test("OFF (default): no enforcement anywhere — even an org lacking the module passes", async () => {
  await withMode("off", async () => {
    const db = fakeDb({ orgFlag: true, planEntitlements: [], status: "active" });
    const res = await resolveEntitlementDecision(db, ORG, null, MODULE);
    assertEquals(res, null, "OFF mode must not enforce (current safe behavior)");
  });
});

Deno.test("ALLOWLIST + flag TRUE + org HAS the entitlement → passes (null)", async () => {
  await withMode("allowlist", async () => {
    const db = fakeDb({ orgFlag: true, planEntitlements: [MODULE], status: "active" });
    assertEquals(await resolveEntitlementDecision(db, ORG, null, MODULE), null);
  });
});

Deno.test("ALLOWLIST + flag TRUE + org LACKS the entitlement → 402 PLAN_UPGRADE_REQUIRED", async () => {
  await withMode("allowlist", async () => {
    const db = fakeDb({ orgFlag: true, planEntitlements: [], status: "active" });
    const res = await resolveEntitlementDecision(db, ORG, null, MODULE);
    assertEquals(res?.status, 402);
    assertEquals((await res!.json()).error.code, "PLAN_UPGRADE_REQUIRED");
  });
});

Deno.test("ALLOWLIST + flag TRUE + SUSPENDED subscription → 402 SUBSCRIPTION_SUSPENDED (blocks even an allowed module)", async () => {
  await withMode("allowlist", async () => {
    // Plan fully grants the module, but the subscription is suspended → blocked.
    const db = fakeDb({ orgFlag: true, planEntitlements: [MODULE], status: "suspended" });
    const res = await resolveEntitlementDecision(db, ORG, null, MODULE);
    assertEquals(res?.status, 402);
    assertEquals((await res!.json()).error.code, "SUBSCRIPTION_SUSPENDED");
  });
});

Deno.test("ALLOWLIST + flag FALSE → NOT enforced for that org (gradual rollout) — lacking module still passes", async () => {
  await withMode("allowlist", async () => {
    const db = fakeDb({ orgFlag: false, planEntitlements: [], status: "active" });
    assertEquals(await resolveEntitlementDecision(db, ORG, null, MODULE), null);
  });
});

Deno.test("ALLOWLIST + flag FALSE + SUSPENDED → still NOT enforced (the org isn't in the rollout yet)", async () => {
  await withMode("allowlist", async () => {
    const db = fakeDb({ orgFlag: false, planEntitlements: [MODULE], status: "suspended" });
    assertEquals(await resolveEntitlementDecision(db, ORG, null, MODULE), null);
  });
});

Deno.test("ALL: enforced regardless of the per-org flag — org (flag FALSE) lacking module → 402", async () => {
  await withMode("all", async () => {
    const db = fakeDb({ orgFlag: false, planEntitlements: [], status: "active" });
    const res = await resolveEntitlementDecision(db, ORG, null, MODULE);
    assertEquals(res?.status, 402);
    assertEquals((await res!.json()).error.code, "PLAN_UPGRADE_REQUIRED");
  });
});

Deno.test("ALL: an org (flag FALSE) that HAS the module still passes (enforcement != denial)", async () => {
  await withMode("all", async () => {
    const db = fakeDb({ orgFlag: false, planEntitlements: [MODULE], status: "active" });
    assertEquals(await resolveEntitlementDecision(db, ORG, null, MODULE), null);
  });
});

// ── ON-path with NO plan assigned: the Trial fallback 402s paid modules ───────
// (the exact danger the pre-flip audit detect_orgs_missing_entitlement_plan()
//  exists to prevent — enabling an org that has no real plan.)
Deno.test("ALLOWLIST + flag TRUE + NO subscription row → Trial fallback → 402 on the paid module", async () => {
  await withMode("allowlist", async () => {
    const db = fakeDb({ orgFlag: true, planEntitlements: [], status: null });
    const res = await resolveEntitlementDecision(db, ORG, null, MODULE);
    assertEquals(res?.status, 402);
    assertEquals((await res!.json()).error.code, "PLAN_UPGRADE_REQUIRED");
  });
});
