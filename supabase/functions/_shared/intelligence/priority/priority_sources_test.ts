// Adaptive AI — P3-AI-2 / W2.0a: priority-item generator tests (pure, DB-free).

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  atRiskStudentItems,
  attendanceItems,
  collectRawItems,
  feeCollectionItems,
  riskMetricItems,
  type RiskSnapshotInput,
  timetableItems,
} from "./priority_sources.ts";

const dashboard = (over: Partial<{
  attendanceRiskScore: number;
  feeCollectionRisk: number;
  timetableHealthScore: number;
}> = {}) => ({
  attendanceRiskScore: 0,
  feeCollectionRisk: 0,
  timetableHealthScore: 100,
  ...over,
});

Deno.test("riskMetricItems: drops low, classifies level, tags finance risks", () => {
  const items = riskMetricItems([
    { key: "fee_collection", label: "Fee collection", score: 80, level: "high", detail: "d" },
    { key: "attendance", label: "Attendance", score: 60, level: "medium", detail: "d" },
    { key: "trivia", label: "Trivia", score: 10, level: "low", detail: "d" },
  ]);
  assertEquals(items.length, 2); // low dropped
  const fee = items.find((i) => i.itemKey === "analytics-risk:fee-collection")!;
  assertEquals(fee.factors.impactClass, "serious"); // high → serious
  assert(fee.personas.includes("finance"));
  assertEquals(fee.entityTags, ["school:fees"]);
  const att = items.find((i) => i.itemKey === "analytics-risk:attendance")!;
  assertEquals(att.factors.impactClass, "elevated"); // medium → elevated
  assert(!att.personas.includes("finance"));
  assertEquals(att.entityTags, ["school:analytics"]);
});

Deno.test("riskMetricItems: aggregate risks are director-visible (no PII)", () => {
  const [item] = riskMetricItems([
    { key: "x", label: "X", score: 60, level: "medium", detail: "d" },
  ]);
  assert(item.personas.includes("director"));
});

const snap = (over: Partial<RiskSnapshotInput> = {}): RiskSnapshotInput => ({
  studentId: "s1",
  className: "6",
  sectionName: "B",
  riskScore: 80,
  riskLevel: "high",
  ...over,
});

Deno.test("atRiskStudentItems: only critical/high, real entity tags, cohort title", () => {
  const items = atRiskStudentItems([
    snap({ studentId: "s1", riskLevel: "critical", riskScore: 95 }),
    snap({ studentId: "s2", riskLevel: "high", riskScore: 80 }),
    snap({ studentId: "s3", riskLevel: "medium", riskScore: 55 }),
    snap({ studentId: "s4", riskLevel: "low", riskScore: 20 }),
  ]);
  assertEquals(items.length, 2);
  assertEquals(items[0].itemKey, "risk:student:s1"); // highest score first
  assert(items[0].entityTags.includes("student:s1:risk"));
  assertEquals(items[0].factors.impactClass, "critical");
  assert(items[0].title.includes("6-B"));
});

Deno.test("atRiskStudentItems: per-student rows are NEVER director-visible (privacy by construction)", () => {
  const items = atRiskStudentItems([snap()]);
  for (const it of items) {
    assert(!it.personas.includes("director"), "student item must not target director");
  }
  assertEquals(items[0].personas.sort(), ["admin", "principal"]);
});

Deno.test("atRiskStudentItems: caps the list, keeping the most severe", () => {
  const many = Array.from({ length: 25 }, (_, i) =>
    snap({ studentId: `s${i}`, riskScore: i, riskLevel: "high" }));
  const items = atRiskStudentItems(many, { limit: 10 });
  assertEquals(items.length, 10);
  assertEquals(items[0].itemKey, "risk:student:s24"); // highest score kept
});

Deno.test("feeCollectionItems: threshold + band + director-safe", () => {
  assertEquals(feeCollectionItems(dashboard({ feeCollectionRisk: 40 })).length, 0);
  const [warn] = feeCollectionItems(dashboard({ feeCollectionRisk: 60 }));
  assertEquals(warn.type, "follow_up");
  assertEquals(warn.factors.impactClass, "elevated");
  const [severe] = feeCollectionItems(dashboard({ feeCollectionRisk: 90 }));
  assertEquals(severe.factors.impactClass, "serious");
  assert(severe.personas.includes("director"));
  assert(severe.personas.includes("finance"));
});

Deno.test("timetableItems + attendanceItems respect their thresholds", () => {
  assertEquals(timetableItems(dashboard({ timetableHealthScore: 80 })).length, 0);
  assertEquals(timetableItems(dashboard({ timetableHealthScore: 55 })).length, 1);
  assertEquals(attendanceItems(dashboard({ attendanceRiskScore: 20 })).length, 0);
  assertEquals(attendanceItems(dashboard({ attendanceRiskScore: 80 }))[0].factors.impactClass, "serious");
});

Deno.test("collectRawItems: each source contributes only when its input is present", () => {
  const analyticsOnly = collectRawItems({
    analytics: {
      dashboard: dashboard({ feeCollectionRisk: 90, timetableHealthScore: 50 }),
      risks: [{ key: "x", label: "X", score: 60, level: "high", detail: "d" }],
    },
  });
  assert(analyticsOnly.length > 0);
  assert(!analyticsOnly.some((i) => i.source === "student_risk"));

  const riskOnly = collectRawItems({ riskSnapshots: [snap()] });
  assertEquals(riskOnly.every((i) => i.source === "student_risk"), true);

  assertEquals(collectRawItems({}).length, 0);
});
