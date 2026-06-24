import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  CAPABILITY_ENTITLEMENTS,
  planAllowedEntitlements,
  planAllows,
  resolveEffectiveCapabilities,
  schoolConfigEnabled,
} from "./entitlement_resolver.ts";

// Seed entitlement sets mirroring plan_entitlements (migration 20260717000000).
const CORE = [
  "module.admissions",
  "module.finance",
  "module.sis",
  "module.management",
  "module.attendance",
  "module.exams",
];
const OPS = [
  "module.transport",
  "module.hostel",
  "module.library",
  "module.inventory",
  "module.alumni",
  "module.hr_payroll",
  "module.multi_branch",
];
const TRIAL = CORE;
const STANDARD = CORE;
const PROFESSIONAL = [...CORE, ...OPS, "feature.parent_insights"];
const ENTERPRISE = [
  ...PROFESSIONAL,
  "module.trust_org",
  "feature.ai_predictions",
];

// All 8 flags ON, mirroring a school that toggled everything on.
const ALL_ON: Record<string, boolean> = {
  transport: true,
  hostel: true,
  library: true,
  inventory: true,
  alumni: true,
  hrPayroll: true,
  multiBranch: true,
  trustOrganization: true,
};

// ─── Trial ──────────────────────────────────────────────────────────────────
Deno.test("Trial: core only — every optional capability is plan-locked", () => {
  const caps = resolveEffectiveCapabilities({
    planEntitlements: TRIAL,
    schoolCapabilities: ALL_ON,
  });
  // None of the 8 optional flags are in Trial's plan, so all resolve false even
  // though the school switched them all on.
  for (const flag of Object.keys(CAPABILITY_ENTITLEMENTS)) {
    assertEquals(caps[flag], false, `${flag} must be plan-locked on Trial`);
  }
});

// ─── Standard ─────────────────────────────────────────────────────────────────
Deno.test("Standard: core only — ops modules plan-locked", () => {
  const caps = resolveEffectiveCapabilities({
    planEntitlements: STANDARD,
    schoolCapabilities: ALL_ON,
  });
  assertEquals(caps.transport, false);
  assertEquals(caps.hostel, false);
  assertEquals(caps.multiBranch, false);
  assertEquals(caps.trustOrganization, false);
  // Core modules are never in the capability map, so they are not gated here.
  assertEquals(planAllows("module.finance", STANDARD), true);
});

// ─── Professional ────────────────────────────────────────────────────────────
Deno.test("Professional: ops + multiBranch on, trust still locked", () => {
  const caps = resolveEffectiveCapabilities({
    planEntitlements: PROFESSIONAL,
    schoolCapabilities: ALL_ON,
  });
  assertEquals(caps.transport, true);
  assertEquals(caps.hostel, true);
  assertEquals(caps.library, true);
  assertEquals(caps.inventory, true);
  assertEquals(caps.alumni, true);
  assertEquals(caps.hrPayroll, true);
  assertEquals(caps.multiBranch, true);
  // trust_org is Enterprise-only.
  assertEquals(caps.trustOrganization, false);
  assertEquals(planAllows("feature.parent_insights", PROFESSIONAL), true);
  assertEquals(planAllows("feature.ai_predictions", PROFESSIONAL), false);
});

// ─── Enterprise ──────────────────────────────────────────────────────────────
Deno.test("Enterprise: all 8 capabilities on; AI predictions included", () => {
  const caps = resolveEffectiveCapabilities({
    planEntitlements: ENTERPRISE,
    schoolCapabilities: ALL_ON,
  });
  for (const flag of Object.keys(CAPABILITY_ENTITLEMENTS)) {
    assertEquals(caps[flag], true, `${flag} must be available on Enterprise`);
  }
  // AI predictions is Enterprise-included (not an addon), per locked config.
  assertEquals(planAllows("feature.ai_predictions", ENTERPRISE), true);
});

// ─── School-level disable override (narrow within plan) ──────────────────────
Deno.test("School disable: plan allows transport but school switched it off", () => {
  const caps = resolveEffectiveCapabilities({
    planEntitlements: PROFESSIONAL,
    schoolCapabilities: { ...ALL_ON, transport: false },
  });
  // School narrows within its plan — transport off despite the plan allowing it.
  assertEquals(caps.transport, false);
  // Other Professional capabilities stay on.
  assertEquals(caps.hostel, true);
});

Deno.test("School can never exceed plan: enabling a flag the plan lacks stays false", () => {
  const caps = resolveEffectiveCapabilities({
    planEntitlements: STANDARD,
    schoolCapabilities: { ...ALL_ON, transport: true },
  });
  assertEquals(caps.transport, false);
});

// ─── Missing subscription → Trial fallback ───────────────────────────────────
// The service substitutes Trial's entitlements when no subscription row exists;
// here we prove the resolver yields the locked-down Trial result for that set.
Deno.test("Missing subscription → Trial entitlements lock all optional modules", () => {
  const caps = resolveEffectiveCapabilities({
    planEntitlements: TRIAL, // service supplies Trial's entitlements on no-row
    schoolCapabilities: ALL_ON,
  });
  for (const flag of Object.keys(CAPABILITY_ENTITLEMENTS)) {
    assertEquals(caps[flag], false);
  }
});

// ─── Enterprise per-deal overrides ───────────────────────────────────────────
Deno.test("Override grant adds a slug beyond the plan", () => {
  const allowed = planAllowedEntitlements(PROFESSIONAL, {
    grant: ["feature.ai_predictions"],
  });
  assertEquals(allowed.has("feature.ai_predictions"), true);
});

Deno.test("Override revoke removes a slug the plan grants", () => {
  const allowed = planAllowedEntitlements(ENTERPRISE, {
    revoke: ["module.trust_org"],
  });
  assertEquals(allowed.has("module.trust_org"), false);
});

// ─── Default-capability behaviour (no school_configuration row) ───────────────
Deno.test("No school config row: defaults apply (ops on, multiBranch/trust off)", () => {
  assertEquals(schoolConfigEnabled("transport", null), true);
  assertEquals(schoolConfigEnabled("multiBranch", null), false);
  assertEquals(schoolConfigEnabled("trustOrganization", undefined), false);
});

Deno.test("Professional with no school config: ops resolve on via defaults", () => {
  const caps = resolveEffectiveCapabilities({
    planEntitlements: PROFESSIONAL,
    schoolCapabilities: null,
  });
  assertEquals(caps.transport, true); // plan allows + default on
  assertEquals(caps.multiBranch, false); // plan allows but default off
});
