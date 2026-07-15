import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  ASSIGNABLE_FROM,
  COMPLAINT_CATEGORIES,
  COMPLAINT_SEVERITIES,
  computeSlaDueAt,
  computeSlaState,
  DEFAULT_SLA_HOURS,
  isLegalTransition,
  LEGAL_TRANSITIONS,
  slaResponseHours,
} from "./complaints_sla.ts";

Deno.test("SLA policy table: every (category, severity) pair is mapped — no undefined cell", () => {
  for (const category of COMPLAINT_CATEGORIES) {
    for (const severity of COMPLAINT_SEVERITIES) {
      const hours = slaResponseHours(category, severity);
      assertEquals(typeof hours, "number");
      assertEquals(hours > 0, true);
    }
  }
});

Deno.test("SLA policy: safety/critical is the tightest lane", () => {
  assertEquals(slaResponseHours("safety", "critical"), 1);
});

Deno.test("SLA policy: severity strictly tightens response hours within a category", () => {
  for (const category of COMPLAINT_CATEGORIES) {
    const critical = slaResponseHours(category, "critical");
    const high = slaResponseHours(category, "high");
    const medium = slaResponseHours(category, "medium");
    const low = slaResponseHours(category, "low");
    assertEquals(critical <= high, true, `${category}: critical<=high`);
    assertEquals(high <= medium, true, `${category}: high<=medium`);
    assertEquals(medium <= low, true, `${category}: medium<=low`);
  }
});

Deno.test("SLA policy: an unknown category/severity falls back to the documented default (defensive only)", () => {
  assertEquals(slaResponseHours("bogus", "medium"), DEFAULT_SLA_HOURS);
  assertEquals(slaResponseHours("facilities", "bogus"), DEFAULT_SLA_HOURS);
});

Deno.test("computeSlaDueAt: adds the policy hours deterministically", () => {
  const created = new Date("2026-07-15T00:00:00.000Z");
  const due = computeSlaDueAt(created, "transport", "critical"); // 2h
  assertEquals(due.toISOString(), "2026-07-15T02:00:00.000Z");
});

Deno.test("computeSlaDueAt: facilities/low is a 96h (4 day) window", () => {
  const created = new Date("2026-07-15T00:00:00.000Z");
  const due = computeSlaDueAt(created, "facilities", "low");
  assertEquals(due.toISOString(), "2026-07-19T00:00:00.000Z");
});

Deno.test("computeSlaState: still open, now before due -> onTrack", () => {
  const due = "2026-07-20T00:00:00.000Z";
  const now = new Date("2026-07-15T00:00:00.000Z");
  assertEquals(computeSlaState(due, now, null), "onTrack");
});

Deno.test("computeSlaState: still open, now after due -> breached", () => {
  const due = "2026-07-10T00:00:00.000Z";
  const now = new Date("2026-07-15T00:00:00.000Z");
  assertEquals(computeSlaState(due, now, null), "breached");
});

Deno.test("computeSlaState: exactly at the due instant is still onTrack (inclusive)", () => {
  const due = "2026-07-15T00:00:00.000Z";
  const now = new Date("2026-07-15T00:00:00.000Z");
  assertEquals(computeSlaState(due, now, null), "onTrack");
});

Deno.test("computeSlaState: resolved BEFORE due -> onTrack regardless of when it's read later", () => {
  const due = "2026-07-20T00:00:00.000Z";
  const resolvedAt = "2026-07-18T00:00:00.000Z";
  const readMuchLater = new Date("2026-08-01T00:00:00.000Z");
  assertEquals(computeSlaState(due, readMuchLater, resolvedAt), "onTrack");
});

Deno.test("computeSlaState: resolved AFTER due -> breached forever, does not heal on later reads", () => {
  const due = "2026-07-10T00:00:00.000Z";
  const resolvedAt = "2026-07-12T00:00:00.000Z";
  const readMuchLater = new Date("2026-09-01T00:00:00.000Z");
  assertEquals(computeSlaState(due, readMuchLater, resolvedAt), "breached");
});

// ── Legal transition table ──────────────────────────────────────────────

const ALL_STATUSES = [
  "open",
  "assigned",
  "in_progress",
  "resolved",
  "closed",
  "reopened",
] as const;

Deno.test("isLegalTransition: every documented edge is legal", () => {
  for (const [from, targets] of Object.entries(LEGAL_TRANSITIONS)) {
    for (const to of targets) {
      assertEquals(isLegalTransition(from, to), true, `${from} -> ${to} should be legal`);
    }
  }
});

Deno.test("isLegalTransition: every non-edge pair is illegal (exhaustive over the full status set)", () => {
  let illegalChecked = 0;
  for (const from of ALL_STATUSES) {
    for (const to of ALL_STATUSES) {
      const legal = (LEGAL_TRANSITIONS[from] as readonly string[]).includes(to);
      assertEquals(isLegalTransition(from, to), legal, `${from} -> ${to}`);
      if (!legal) illegalChecked++;
    }
  }
  // Sanity: this test actually exercised illegal pairs (not vacuously true).
  assertEquals(illegalChecked > 0, true);
});

Deno.test("isLegalTransition: a self-transition is illegal everywhere", () => {
  for (const status of ALL_STATUSES) {
    assertEquals(isLegalTransition(status, status), false, `${status} -> ${status}`);
  }
});

Deno.test("isLegalTransition: an unknown 'from' status is illegal (never throws)", () => {
  assertEquals(isLegalTransition("bogus", "open"), false);
});

Deno.test("ASSIGNABLE_FROM matches exactly the edges that produce 'assigned'", () => {
  assertEquals([...ASSIGNABLE_FROM].sort(), ["open", "reopened"]);
  for (const status of ASSIGNABLE_FROM) {
    assertEquals(isLegalTransition(status, "assigned"), true);
  }
});

Deno.test("category/severity arrays match the DB CHECK constraints", () => {
  assertEquals(
    [...COMPLAINT_CATEGORIES].sort(),
    ["academics", "facilities", "finance", "hostel", "other", "safety", "staff", "transport"],
  );
  assertEquals([...COMPLAINT_SEVERITIES].sort(), ["critical", "high", "low", "medium"]);
});

Deno.test("computeSlaDueAt never throws for any category/severity pair", () => {
  const created = new Date();
  for (const category of COMPLAINT_CATEGORIES) {
    for (const severity of COMPLAINT_SEVERITIES) {
      computeSlaDueAt(created, category, severity);
    }
  }
});
