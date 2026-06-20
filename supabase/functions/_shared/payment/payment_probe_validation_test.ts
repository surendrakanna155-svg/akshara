import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

const PROBES_PATH = new URL("../tenant_isolation_probes.ts", import.meta.url);
const probesSource = await Deno.readTextFile(PROBES_PATH);

const PAYMENT_PROBES = [
  "parent_a_cannot_see_school_b_payment_intent",
  "parent_a_sees_own_payment_intent",
  "school_a_cannot_see_school_b_payment_intent",
  "school_a_sees_own_payment_intent",
  "organization_denied_payment_intent_probe",
  "student_denied_payment_intent_probe",
  "school_a_sees_own_payment_webhook_probe",
  "school_a_cannot_see_school_b_payment_webhook",
] as const;

Deno.test("Payment v7.0 isolation probes are registered", () => {
  for (const probe of PAYMENT_PROBES) {
    assert(
      probesSource.includes(`name: "${probe}"`),
      `missing probe: ${probe}`,
    );
  }
});

Deno.test("Payment probe fixtures are defined", () => {
  assert(probesSource.includes("PAYMENT_INTENT_PROBE_SCHOOL_A"));
  assert(probesSource.includes("PAYMENT_INTENT_PROBE_SCHOOL_B"));
  assert(probesSource.includes("PAYMENT_INTENT_PROBE_DETAIL_SQL"));
  assert(probesSource.includes("PAYMENT_WEBHOOK_PROBE_SCHOOL_A"));
  assert(probesSource.includes("PAYMENT_WEBHOOK_PROBE_DETAIL_SQL"));
});

Deno.test("Payment router paths exist", async () => {
  const routerSource = await Deno.readTextFile(
    new URL("./payment_router.ts", import.meta.url),
  );
  assert(routerSource.includes("/payments/intents/initiate"));
  assert(routerSource.includes("/payments/intents/confirm"));
  assert(routerSource.includes("/webhooks/razorpay"));
});

function extractProbeNames(source: string): string[] {
  const names: string[] = [];
  const pattern = /name:\s*"([^"]+)"/g;
  for (const match of source.matchAll(pattern)) {
    names.push(match[1]!);
  }
  return names;
}

Deno.test("tenant isolation probe count includes v7.6 probes (220)", () => {
  const names = extractProbeNames(probesSource);
  assertEquals(names.length, 220, `probes: ${names.join(", ")}`);
});
