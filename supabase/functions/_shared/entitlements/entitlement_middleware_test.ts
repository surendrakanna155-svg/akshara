import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { requireEntitlement } from "./entitlement_middleware.ts";

const PROFESSIONAL = new Set([
  "module.admissions",
  "module.transport",
  "module.hostel",
  "feature.parent_insights",
]);

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
