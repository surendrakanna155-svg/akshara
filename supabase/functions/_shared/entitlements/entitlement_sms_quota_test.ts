// W4 · SaaS limits — config-driven proof + owner-decision-#1 regressions.
//
// Owner decision #1 (FINAL): STUDENT limits are enforced per plan; staff/admin
// accounts are NOT plan-capped; SMS quotas are enforced per plan; ALL limits are
// CONFIG-DRIVEN (never hardcoded). This file pins those invariants at the
// resolution layer with a fake DB (no live Postgres), the same way the other
// entitlement tests pin the pure decisions.
//
// resolveSubscription() reads the plan/subscription rows through a TenantQueryClient;
// we hand it a fake client that answers those exact queries from in-memory rows,
// so we prove the limits FLOW FROM PLAN CONFIG (change the plan number → the
// resolved limit changes) rather than from any constant baked into the code.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { resolveSubscription } from "./entitlement_service.ts";
import * as limits from "./entitlement_limits.ts";

// ── Fake DB rows (raw column shapes the repository maps) ─────────────────────
interface PlanCfg {
  studentSlabMax: number | null;
  maxSmsPerMonth: number | null;
  maxSchools?: number | null;
}

function planRow(cfg: PlanCfg): Record<string, unknown> {
  return {
    slug: "standard",
    name: "Standard",
    description: "",
    tier_rank: 1,
    student_slab_min: 0,
    student_slab_max: cfg.studentSlabMax,
    max_schools: cfg.maxSchools ?? 1,
    max_storage_bytes: null,
    max_sms_per_month: cfg.maxSmsPerMonth,
    grace_buffer_percent: 10,
    trial_length_days: null,
    trial_grace_days: null,
    base_price_paise: 0,
    is_trial: false,
    is_public: true,
    is_active: true,
  };
}

function subscriptionRow(): Record<string, unknown> {
  return {
    organization_id: "org-1",
    plan_slug: "standard",
    status: "active",
    // No per-org overrides → the PLAN's values must win. This is what proves the
    // limit is read from plan config.
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

/** A TenantQueryClient stand-in that answers resolveSubscription's queries from
 * the supplied plan config. No network, no Postgres. */
function fakeDb(cfg: PlanCfg): TenantQueryClient {
  const fake = {
    // deno-lint-ignore no-explicit-any
    queryObject(sql: string, _args: unknown[] = []): Promise<any[]> {
      if (sql.includes("FROM organization_subscriptions")) {
        return Promise.resolve([subscriptionRow()]);
      }
      if (sql.includes("FROM subscription_plans")) {
        return Promise.resolve([planRow(cfg)]);
      }
      if (sql.includes("FROM plan_entitlements")) return Promise.resolve([]);
      if (sql.includes("FROM school_configuration")) return Promise.resolve([]);
      return Promise.resolve([]);
    },
    queryCount(_sql: string, _args: unknown[] = []): Promise<number> {
      return Promise.resolve(0);
    },
  };
  return fake as unknown as TenantQueryClient;
}

// ─── STUDENT limit is config-driven (reads the plan, not a hardcoded number) ──
Deno.test("STUDENT limit is read from plan config: change the plan slab → the resolved limit changes", async () => {
  const a = await resolveSubscription(fakeDb({ studentSlabMax: 250, maxSmsPerMonth: null }), "org-1", null);
  assertEquals(a.limits.students, 250, "student limit did not track the plan's student_slab_max (250)");

  // Same code path, DIFFERENT plan number → different resolved limit. If the
  // limit were hardcoded this second case would fail.
  const b = await resolveSubscription(fakeDb({ studentSlabMax: 1200, maxSmsPerMonth: null }), "org-1", null);
  assertEquals(b.limits.students, 1200, "student limit did not track the plan's student_slab_max (1200)");
});

Deno.test("STUDENT limit: an unlimited plan (null slab) resolves to null (unlimited)", async () => {
  const sub = await resolveSubscription(fakeDb({ studentSlabMax: null, maxSmsPerMonth: null }), "org-1", null);
  assertEquals(sub.limits.students, null);
});

// ─── SMS quota is config-driven (max_sms_per_month → sub.limits.sms) ──────────
Deno.test("SMS quota is read from plan config: sub.limits.sms tracks max_sms_per_month", async () => {
  const a = await resolveSubscription(fakeDb({ studentSlabMax: 250, maxSmsPerMonth: 1000 }), "org-1", null);
  assertEquals(a.limits.sms, 1000, "SMS cap did not track the plan's max_sms_per_month (1000)");

  const b = await resolveSubscription(fakeDb({ studentSlabMax: 250, maxSmsPerMonth: 50 }), "org-1", null);
  assertEquals(b.limits.sms, 50, "SMS cap did not track the plan's max_sms_per_month (50)");
});

Deno.test("SMS quota: a plan with no SMS cap (null) resolves to null (unlimited)", async () => {
  const sub = await resolveSubscription(fakeDb({ studentSlabMax: 250, maxSmsPerMonth: null }), "org-1", null);
  assertEquals(sub.limits.sms, null);
});

// ─── Owner decision #1: staff / admin accounts are NOT plan-capped ────────────
// This is pinned STRUCTURALLY: the plan-limit model exposes caps only for
// students, schools, storage and SMS — there is deliberately NO staff / user /
// admin / teacher / employee limit anywhere in the resolved limits, so there is
// nothing a plan could ever cap staff creation against.
Deno.test("staff/admin are NOT plan-capped: resolved limits carry no staff/user/admin key", async () => {
  const sub = await resolveSubscription(fakeDb({ studentSlabMax: 250, maxSmsPerMonth: 1000 }), "org-1", null);
  const keys = Object.keys(sub.limits).sort();
  // The exact, closed set of plan limits. If someone adds a staff/user cap it
  // will land here and trip this assertion.
  assertEquals(keys, ["graceBufferPercent", "schools", "sms", "storageBytes", "students"]);
  for (const k of keys) {
    assertEquals(
      /staff|user|admin|teacher|employee/i.test(k),
      false,
      `plan limits must not include a staff/admin cap, found: ${k}`,
    );
  }
});

Deno.test("staff/admin are NOT plan-capped: the entitlements enforcement module exports no staff/user/admin limiter", () => {
  const enforcers = Object.keys(limits).filter((k) => /^enforce/i.test(k));
  // The ONLY create/usage gates that exist are students, schools and SMS.
  assertEquals(enforcers.sort(), ["enforceSchoolLimit", "enforceSmsQuota", "enforceStudentLimit"]);
  for (const name of enforcers) {
    assertEquals(
      /staff|user|admin|teacher|employee/i.test(name),
      false,
      `no staff/admin enforcement gate may exist, found: ${name}`,
    );
  }
  // And the three that DO exist are callable functions.
  assertEquals(typeof limits.enforceStudentLimit, "function");
  assertEquals(typeof limits.enforceSchoolLimit, "function");
  assertEquals(typeof limits.enforceSmsQuota, "function");
});
