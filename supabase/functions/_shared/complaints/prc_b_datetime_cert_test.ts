// PRC-B — Product Correctness certification: Date & Time (3.2) + temporal integrity.
// Exercises the REAL exported date functions across leap-year / month-end / invalid
// / century boundaries and the "SLA never heals over time" temporal property.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { isStrictIsoDate } from "../transport/transport_write_handlers.ts";
import { computeSlaDueAt, computeSlaState } from "./complaints_sla.ts";

// ─── PRC-B-DT-01..08,19: strict calendar-date validation ──────────────────────

Deno.test("PRC-B-DT-01: February 28 is a valid date", () => {
  assertEquals(isStrictIsoDate("2026-02-28"), true);
});

Deno.test("PRC-B-DT-02/03: February 29 is valid in a leap year, rejected in a non-leap year", () => {
  assertEquals(isStrictIsoDate("2028-02-29"), true); // 2028 leap
  assertEquals(isStrictIsoDate("2027-02-29"), false); // 2027 non-leap → Mar 1, rejected
});

Deno.test("PRC-B-DT-04/05: leap-century vs non-leap-century February 29", () => {
  assertEquals(isStrictIsoDate("2000-02-29"), true); // 2000 divisible by 400 → leap
  assertEquals(isStrictIsoDate("1900-02-29"), false); // 1900 divisible by 100 not 400 → not leap
});

Deno.test("PRC-B-DT-07: a 30-day month rejects day 31, accepts day 30", () => {
  assertEquals(isStrictIsoDate("2026-04-31"), false); // April has 30 days
  assertEquals(isStrictIsoDate("2026-04-30"), true);
});

Deno.test("PRC-B-DT-08/09: 31-day month + year-end boundary are valid", () => {
  assertEquals(isStrictIsoDate("2026-12-31"), true);
  assertEquals(isStrictIsoDate("2026-01-31"), true);
});

Deno.test("PRC-B-DT-19: impossible / malformed dates are rejected", () => {
  for (const bad of ["2026-02-30", "2026-13-01", "2026-00-10", "2026-04-00", "not-a-date", "2026-1-1", "20260101", ""]) {
    assertEquals(isStrictIsoDate(bad), false, `expected ${bad} to be rejected`);
  }
});

// ─── PRC-B-DT temporal integrity: SLA state does not silently heal over time ───

Deno.test("PRC-B-DT (temporal): computeSlaDueAt is deterministic (created + policy hours)", () => {
  const created = new Date(Date.UTC(2026, 6, 1, 9, 0, 0));
  const due = computeSlaDueAt(created, "unknown", "unknown"); // → DEFAULT 72h
  assertEquals(due.getTime() - created.getTime(), 72 * 60 * 60 * 1000);
});

Deno.test("PRC-B-DT (temporal): a complaint RESOLVED late stays 'breached' forever, even read long after", () => {
  const due = new Date(Date.UTC(2026, 6, 4, 9, 0, 0));
  const resolvedLate = new Date(Date.UTC(2026, 6, 5, 9, 0, 0)); // 1 day late
  // Read now, and read a year later — both must say 'breached' (judged vs resolution, not read time).
  assertEquals(computeSlaState(due, new Date(Date.UTC(2026, 6, 6)), resolvedLate), "breached");
  assertEquals(computeSlaState(due, new Date(Date.UTC(2027, 6, 6)), resolvedLate), "breached");
});

Deno.test("PRC-B-DT (temporal): a complaint resolved on time is 'onTrack' regardless of when it is read", () => {
  const due = new Date(Date.UTC(2026, 6, 4, 9, 0, 0));
  const resolvedOnTime = new Date(Date.UTC(2026, 6, 3, 9, 0, 0));
  assertEquals(computeSlaState(due, new Date(Date.UTC(2030, 0, 1)), resolvedOnTime), "onTrack");
});

Deno.test("PRC-B-DT-32/33 (boundary): an open item flips to 'breached' exactly at the due instant", () => {
  const due = new Date(Date.UTC(2026, 6, 4, 9, 0, 0));
  // exactly at due → onTrack (inclusive); one ms after → breached.
  assertEquals(computeSlaState(due, new Date(due.getTime()), null), "onTrack");
  assertEquals(computeSlaState(due, new Date(due.getTime() + 1), null), "breached");
  assert(true);
});
