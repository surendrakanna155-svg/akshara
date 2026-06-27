import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { gateModuleAccess, requireEntitlement } from "./entitlement_middleware.ts";

const PROFESSIONAL = new Set([
  "module.admissions",
  "module.transport",
  "module.hostel",
  "feature.parent_insights",
]);

// All optional capabilities enabled by the school.
const ALL_ON = {
  transport: true,
  hostel: true,
  library: true,
  inventory: true,
  alumni: true,
  hrPayroll: true,
  multiBranch: true,
  trustOrganization: true,
};

Deno.test("requireEntitlement returns null when the plan allows the slug", () => {
  assertEquals(requireEntitlement(PROFESSIONAL, "module.transport"), null);
});

Deno.test("requireEntitlement returns 402 PLAN_UPGRADE_REQUIRED when not allowed", async () => {
  const res = requireEntitlement(PROFESSIONAL, "module.trust_org");
  assertEquals(res?.status, 402);
  const body = await res!.json();
  assertEquals(body.error.code, "PLAN_UPGRADE_REQUIRED");
});

Deno.test("requireEntitlement accepts an array as well as a Set", () => {
  assertEquals(requireEntitlement(["module.alumni"], "module.alumni"), null);
  assertEquals(requireEntitlement(["module.alumni"], "module.hostel")?.status, 402);
});

Deno.test("Trial (no optional modules) 402s on a paid module", () => {
  const trial = new Set(["module.admissions", "module.finance"]);
  assertEquals(requireEntitlement(trial, "module.transport")?.status, 402);
});

// ─── G3 — school-disabled enforcement (gateModuleAccess) ─────────────────────

Deno.test("gateModuleAccess allows a plan-allowed, school-enabled module", () => {
  assertEquals(gateModuleAccess(PROFESSIONAL, ALL_ON, "module.transport"), null);
});

Deno.test("gateModuleAccess returns 402 when the plan does not allow the module", () => {
  const res = gateModuleAccess(PROFESSIONAL, ALL_ON, "module.trust_org");
  assertEquals(res?.status, 402);
});

Deno.test("gateModuleAccess returns 403 MODULE_DISABLED when the school turned it off", async () => {
  const schoolOffTransport = { ...ALL_ON, transport: false };
  const res = gateModuleAccess(PROFESSIONAL, schoolOffTransport, "module.transport");
  assertEquals(res?.status, 403);
  const body = await res!.json();
  assertEquals(body.error.code, "MODULE_DISABLED");
});

Deno.test("gateModuleAccess: plan-locked beats school-disabled (402 wins)", () => {
  // Not in plan AND school-off → caller sees the plan ceiling first.
  const res = gateModuleAccess(PROFESSIONAL, { ...ALL_ON, library: false }, "module.library");
  assertEquals(res?.status, 402);
});

Deno.test("gateModuleAccess: a non-capability slug is unaffected by capabilities", () => {
  assertEquals(
    gateModuleAccess(PROFESSIONAL, { ...ALL_ON, transport: false }, "module.admissions"),
    null,
  );
});
