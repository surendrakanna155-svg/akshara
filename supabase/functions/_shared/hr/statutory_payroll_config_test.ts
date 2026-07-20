// PRA-P1-35 — statutory config PARSE guards (pure). The admin supplies the rates;
// these guards reject malformed / dangerous config (a percent entered as a whole
// number, a negative rate, a bad month) so the engine only ever sees clean DATA.

import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import {
  parseComponentConfig,
  parsePtSlab,
} from "./statutory_payroll_handlers.ts";

// ── parseComponentConfig ───────────────────────────────────────────────────────

Deno.test("parseComponentConfig: a valid PF rule parses (rates are fractions)", () => {
  const cfg = parseComponentConfig({
    component: "pf",
    employeeRate: 0.12,
    employerRate: 0.12,
    wageBase: "basic",
    baseCap: 15000,
  });
  assertEquals(cfg.component, "pf");
  assertEquals(cfg.employeeRate, 0.12);
  assertEquals(cfg.wageBase, "basic");
  assertEquals(cfg.baseCap, 15000);
  assertEquals(cfg.eligibilityCeiling, null);
  assertEquals(cfg.active, true);
});

Deno.test("parseComponentConfig: a valid ESI rule with eligibility ceiling + round-up", () => {
  const cfg = parseComponentConfig({
    component: "esi",
    employeeRate: 0.0075,
    employerRate: 0.0325,
    eligibilityCeiling: 21000,
    rounding: "up",
  });
  assertEquals(cfg.eligibilityCeiling, 21000);
  assertEquals(cfg.rounding, "up");
});

Deno.test("parseComponentConfig: defaults are deploy-safe (rates 0, gross base, nearest)", () => {
  const cfg = parseComponentConfig({ component: "tds" });
  assertEquals(cfg.employeeRate, 0);
  assertEquals(cfg.employerRate, 0);
  assertEquals(cfg.wageBase, "gross");
  assertEquals(cfg.rounding, "nearest");
});

Deno.test("parseComponentConfig: state 'ALL' normalises to central ('')", () => {
  assertEquals(parseComponentConfig({ component: "pf", state: "ALL" }).state, "");
  assertEquals(parseComponentConfig({ component: "pt", state: "KA" }).state, "KA");
});

Deno.test("parseComponentConfig: rejects an unknown component", () => {
  assertThrows(() => parseComponentConfig({ component: "gratuity" }));
});

Deno.test("parseComponentConfig: rejects a rate > 1 (a percent entered as a whole number)", () => {
  assertThrows(() => parseComponentConfig({ component: "pf", employeeRate: 12 }));
});

Deno.test("parseComponentConfig: rejects a negative rate / cap", () => {
  assertThrows(() => parseComponentConfig({ component: "pf", employeeRate: -0.1 }));
  assertThrows(() => parseComponentConfig({ component: "pf", baseCap: -1 }));
});

Deno.test("parseComponentConfig: rejects a bad wageBase / rounding", () => {
  assertThrows(() => parseComponentConfig({ component: "pf", wageBase: "net" }));
  assertThrows(() => parseComponentConfig({ component: "pf", rounding: "banker" }));
});

// ── parsePtSlab ────────────────────────────────────────────────────────────────

Deno.test("parsePtSlab: a valid slab parses", () => {
  const slab = parsePtSlab({ state: "KA", lowerBound: 15000, amount: 200 });
  assertEquals(slab.state, "KA");
  assertEquals(slab.lowerBound, 15000);
  assertEquals(slab.upperBound, null);
  assertEquals(slab.amount, 200);
  assertEquals(slab.month, null);
});

Deno.test("parsePtSlab: a special-month slab parses", () => {
  assertEquals(parsePtSlab({ state: "KA", lowerBound: 15000, amount: 300, month: 2 }).month, 2);
});

Deno.test("parsePtSlab: requires a state", () => {
  assertThrows(() => parsePtSlab({ lowerBound: 15000, amount: 200 }));
});

Deno.test("parsePtSlab: rejects upperBound < lowerBound", () => {
  assertThrows(() => parsePtSlab({ state: "KA", lowerBound: 15000, upperBound: 10000, amount: 200 }));
});

Deno.test("parsePtSlab: rejects an out-of-range month", () => {
  assertThrows(() => parsePtSlab({ state: "KA", lowerBound: 15000, amount: 300, month: 13 }));
  assertThrows(() => parsePtSlab({ state: "KA", lowerBound: 15000, amount: 300, month: 0 }));
});
