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
  });
  assertEquals(result.riskLevel, "low");
});
