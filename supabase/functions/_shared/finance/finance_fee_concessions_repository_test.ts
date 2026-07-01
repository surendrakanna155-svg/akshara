import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { asUuidOrNull, parseAmountMinor } from "./finance_fee_concessions_repository.ts";

Deno.test("parseAmountMinor: extracts minor units from free-text amounts", () => {
  assertEquals(parseAmountMinor("2500"), 250000);
  assertEquals(parseAmountMinor("₹2,500"), 250000);
  assertEquals(parseAmountMinor("1500.50"), 150050);
  assertEquals(parseAmountMinor(""), null);
  assertEquals(parseAmountMinor("waiver"), null);
});

Deno.test("asUuidOrNull: keeps a real UUID, drops demo/non-UUID identifiers", () => {
  const uuid = "d1000000-0000-4000-8000-000000000002";
  assertEquals(asUuidOrNull(uuid), uuid);
  assertEquals(asUuidOrNull("finance_demo"), null);
  assertEquals(asUuidOrNull(""), null);
  assertEquals(asUuidOrNull(null), null);
});
