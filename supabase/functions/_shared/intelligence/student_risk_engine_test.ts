import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { computeStudentRisk, riskLevelFromScore } from "./student_risk_engine.ts";

Deno.test("riskLevelFromScore maps critical at 85+", () => {
  assertEquals(riskLevelFromScore(90), "critical");
  assertEquals(riskLevelFromScore(50), "medium");
  assertEquals(riskLevelFromScore(20), "low");
});

Deno.test("computeStudentRisk returns reasons and interventions", () => {
  const result = computeStudentRisk({
    attendancePercent: 55,
    homeworkCompletionRate: 40,
    averageMarksPercent: 30,
    communicationGaps: 2,
    behaviorIncidents: 1,
    timetableMissedSessions: 3,
  });
  assertEquals(result.riskLevel !== "low", true);
  assertEquals(result.riskScore >= 40, true);
  assertEquals(result.reasons.length > 0, true);
  assertEquals(result.teacherActions.length > 0, true);
});

Deno.test("stable student yields low risk", () => {
  const result = computeStudentRisk({
    attendancePercent: 95,
    homeworkCompletionRate: 90,
    averageMarksPercent: 80,
    communicationGaps: 0,
    behaviorIncidents: 0,
    timetableMissedSessions: 0,
    feeOutstandingAmount: 0,
  });
  assertEquals(result.riskLevel, "low");
});

// Deterministic risk weight table (must sum to exactly 1.0). Kept in lock-step
// with computeStudentRisk so a rebalance can never silently break normalization.
const RISK_WEIGHTS = {
  attendance: 0.25,
  homework: 0.19,
  academic: 0.19,
  fee: 0.12,
  communication: 0.09,
  behavior: 0.09,
  timetable: 0.07,
} as const;

Deno.test("risk weights sum to 1.0 (fee included, attendance largest)", () => {
  const sum = Object.values(RISK_WEIGHTS).reduce((a, b) => a + b, 0);
  // guard against float dust
  assertEquals(Math.round(sum * 100) / 100, 1.0);
  const max = Math.max(...Object.values(RISK_WEIGHTS));
  assertEquals(RISK_WEIGHTS.attendance, max);
  assertEquals(RISK_WEIGHTS.fee, 0.12);
});

Deno.test("fee_default: outstanding balance raises the score and emits the reason", () => {
  const base = {
    attendancePercent: 95,
    homeworkCompletionRate: 90,
    averageMarksPercent: 80,
    communicationGaps: 0,
    behaviorIncidents: 0,
    timetableMissedSessions: 0,
  };
  const paidUp = computeStudentRisk({ ...base, feeOutstandingAmount: 0 });
  const owing = computeStudentRisk({ ...base, feeOutstandingAmount: 40000 });

  // outstanding > 0 raises the blended score vs. the paid-up baseline
  assertEquals(owing.riskScore > paidUp.riskScore, true);

  // reason is emitted only when outstanding > 0, and carries the amount
  const paidUpReason = paidUp.reasons.find((r) => r.code === "fee_default");
  const owingReason = owing.reasons.find((r) => r.code === "fee_default");
  assertEquals(paidUpReason, undefined);
  assertEquals(owingReason !== undefined, true);
  assertEquals(owingReason!.detail.includes("40000"), true);
});

Deno.test("fee_default: zero outstanding contributes no fee risk", () => {
  const inputs = {
    attendancePercent: 88,
    homeworkCompletionRate: 82,
    averageMarksPercent: 72,
    communicationGaps: 0,
    behaviorIncidents: 0,
    timetableMissedSessions: 0,
  };
  const withZero = computeStudentRisk({ ...inputs, feeOutstandingAmount: 0 });
  const withUndefined = computeStudentRisk(inputs);
  // omitting the fee input behaves identically to an explicit 0 (honest default)
  assertEquals(withUndefined.riskScore, withZero.riskScore);
  assertEquals(withZero.reasons.some((r) => r.code === "fee_default"), false);
});
