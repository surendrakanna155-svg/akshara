import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { computeStudentSuccessPrediction } from "./student_success_service.ts";

Deno.test("computeStudentSuccessPrediction flags high dropout risk for at-risk profile", () => {
  const result = computeStudentSuccessPrediction({
    attendancePercent: 55,
    homeworkCompletionRate: 40,
    averageMarksPercent: 35,
    communicationGaps: 2,
    behaviorIncidents: 1,
    recentMarksTrend: -15,
  });
  assertEquals(result.dropoutProbability >= 50, true);
  assertEquals(result.performanceDeclineScore >= 40, true);
  assertEquals(result.riskSignals.length > 0, true);
  assertEquals(result.predictions.recommendedInterventions.length > 0, true);
});

Deno.test("computeStudentSuccessPrediction returns low risk for stable student", () => {
  const result = computeStudentSuccessPrediction({
    attendancePercent: 92,
    homeworkCompletionRate: 88,
    averageMarksPercent: 78,
    communicationGaps: 0,
    behaviorIncidents: 0,
    recentMarksTrend: 5,
  });
  assertEquals(result.dropoutProbability < 30, true);
  assertEquals(result.improvementScore >= 60, true);
  assertEquals(result.predictions.dropoutRisk.includes("Low"), true);
});

Deno.test("attendance prediction declines for low attendance students", () => {
  const result = computeStudentSuccessPrediction({
    attendancePercent: 62,
    homeworkCompletionRate: 70,
    averageMarksPercent: 65,
    communicationGaps: 0,
    behaviorIncidents: 0,
    recentMarksTrend: 0,
  });
  assertEquals(result.attendancePrediction < 70, true);
  assertEquals(
    result.riskSignals.some((s) => s.code === "attendance_decline"),
    true,
  );
});
