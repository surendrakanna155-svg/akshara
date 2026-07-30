import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  computeAndStoreStudentSuccessSnapshots,
  computeStudentSuccessPrediction,
} from "./student_success_service.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";

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

// ── SAFEGUARDING (ICA-H4) regression cases ──────────────────────────────────

Deno.test("ICA-H4: unmonitored (no attendance data) is NOT low-concern / improving by default", () => {
  // loadStudentSignals feeds gap-0 placeholders (100) for the missing dimensions;
  // the unmonitored flag says the dominant attendance signal is absent, so the
  // optimistic outputs are untrustworthy.
  const result = computeStudentSuccessPrediction({
    attendancePercent: 100, // placeholder for missing attendance
    homeworkCompletionRate: 100, // placeholder for missing homework
    averageMarksPercent: 70,
    communicationGaps: 0,
    behaviorIncidents: 0,
    recentMarksTrend: 5,
    attendanceHasData: false,
    homeworkHasData: false,
    dataCompleteness: "none",
    unmonitored: true,
  });
  // never low-concern by default: dropout floored onto the watchlist band
  assertEquals(result.dropoutProbability >= 40, true);
  assertEquals(result.predictions.dropoutRisk.includes("Low"), false);
  // never "improving": improvement capped below the improving (>= 70) bucket
  assertEquals(result.improvementScore <= 45, true);
  // explicit provenance + caveat surfaced
  assertEquals(result.predictions.unmonitored, true);
  assertEquals(result.predictions.dataCompleteness, "none");
  assertEquals(result.predictions.monitoringCaveat !== null, true);
  assertEquals(result.riskSignals[0].code, "no_monitoring_data");
  // and it never falls through to the "on track" message
  assertEquals(
    result.predictions.recommendedInterventions.some((i) => i.includes("on track")),
    false,
  );
});

Deno.test("ICA-H4: a student with REAL low signals is still high-concern (fix does not weaken it)", () => {
  const result = computeStudentSuccessPrediction({
    attendancePercent: 55,
    homeworkCompletionRate: 40,
    averageMarksPercent: 35,
    communicationGaps: 2,
    behaviorIncidents: 1,
    recentMarksTrend: -15,
    attendanceHasData: true,
    homeworkHasData: true,
    dataCompleteness: "full",
    unmonitored: false,
  });
  assertEquals(result.dropoutProbability >= 50, true);
  assertEquals(result.predictions.unmonitored, false);
  assertEquals(result.riskSignals.some((s) => s.code === "no_monitoring_data"), false);
});

Deno.test("ICA-H4: partial data (homework missing) uses only present dimensions, not a fabricated constant", () => {
  // attendance present and healthy; homework simply not tracked yet → fed as the
  // gap-0 placeholder (100), NOT a fabricated 85. The student keeps an honest,
  // un-floored posture but carries a partial-data caveat.
  const result = computeStudentSuccessPrediction({
    attendancePercent: 95,
    homeworkCompletionRate: 100, // placeholder for missing homework (excluded)
    averageMarksPercent: 80,
    communicationGaps: 0,
    behaviorIncidents: 0,
    recentMarksTrend: 5,
    attendanceHasData: true,
    homeworkHasData: false,
    dataCompleteness: "partial",
    unmonitored: false,
  });
  // honest low-concern band preserved for a student with good REAL data
  assertEquals(result.dropoutProbability < 30, true);
  assertEquals(result.predictions.dropoutRisk.includes("Low"), true);
  // not flagged unmonitored, but the partial caveat is present
  assertEquals(result.predictions.unmonitored, false);
  assertEquals(result.predictions.dataCompleteness, "partial");
  assertEquals(result.riskSignals.some((s) => s.code === "partial_monitoring_data"), true);
  assertEquals(result.predictions.monitoringCaveat !== null, true);
});

// End-to-end through computeAndStoreStudentSuccessSnapshots: the provenance flags
// must flow from loadStudentSignals into the persisted snapshot.

function studentRow(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    student_id: "st-1",
    student_name: "Asha",
    class_name: "Grade 5",
    section_name: "A",
    absent_count: 0,
    attendance_percent: 92,
    hw_submitted: 9,
    hw_total: 10,
    avg_marks_pct: 80,
    behavior_incidents: 0,
    fee_outstanding: 0,
    fee_overdue_days: 0,
    ...overrides,
  };
}

class SuccessStoreMockDb {
  insertArgs: unknown[][] = [];
  constructor(private row: Record<string, unknown>) {}
  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("INSERT INTO intel_student_success_snapshots")) {
      this.insertArgs.push(args);
      return [{
        id: "snap-1",
        student_id: args[2],
        student_name: args[3],
        class_name: args[4],
        section_name: args[5],
        dropout_probability: args[6],
        attendance_prediction: args[7],
        performance_decline_score: args[8],
        improvement_score: args[9],
        risk_signals: args[10],
        predictions: args[11],
        computed_at: "2026-01-01T00:00:00Z",
      }] as unknown as T[];
    }
    return [this.row] as T[]; // the loadStudentSignals SELECT
  }
  // deno-lint-ignore require-await
  async queryCount(): Promise<number> {
    return 0;
  }
  get raw(): never {
    throw new Error("unused");
  }
}

function parseSuccessInsert(args: unknown[]) {
  return {
    dropoutProbability: args[6] as number,
    improvementScore: args[9] as number,
    riskSignals: JSON.parse(args[10] as string) as Array<{ code: string }>,
    predictions: JSON.parse(args[11] as string) as Record<string, unknown>,
  };
}

Deno.test("computeAndStoreStudentSuccessSnapshots: unmonitored student stored NEEDS-REVIEW, never low-concern/improving", async () => {
  const db = new SuccessStoreMockDb(
    studentRow({ attendance_percent: null, hw_total: 0, hw_submitted: 0 }),
  );
  const stored = await computeAndStoreStudentSuccessSnapshots(
    db as unknown as TenantQueryClient,
    ORG,
    SCHOOL,
  );
  assertEquals(stored.length, 1);
  assertEquals(db.insertArgs.length, 1);
  const ins = parseSuccessInsert(db.insertArgs[0]);
  // persisted scores respect the CHECK (0-100) bounds and the safeguarding floor/cap
  assertEquals(ins.dropoutProbability >= 40, true); // watchlist floor, never low
  assertEquals(ins.dropoutProbability <= 100, true);
  assertEquals(ins.improvementScore <= 45, true); // below the "improving" bucket
  // caveat + machine-readable provenance persisted for the UI
  assertEquals(ins.riskSignals.some((s) => s.code === "no_monitoring_data"), true);
  assertEquals(ins.predictions.unmonitored, true);
  assertEquals(ins.predictions.dataCompleteness, "none");
  assertEquals(ins.predictions.monitoringCaveat !== null, true);
});

Deno.test("computeAndStoreStudentSuccessSnapshots: a student with REAL good data keeps its honest low-concern posture", async () => {
  const db = new SuccessStoreMockDb(
    studentRow({ attendance_percent: 95, hw_total: 10, hw_submitted: 9, avg_marks_pct: 85 }),
  );
  await computeAndStoreStudentSuccessSnapshots(db as unknown as TenantQueryClient, ORG, SCHOOL);
  const ins = parseSuccessInsert(db.insertArgs[0]);
  assertEquals(ins.dropoutProbability < 40, true); // not floored
  assertEquals(ins.improvementScore > 45, true); // not capped
  assertEquals(ins.predictions.unmonitored, false);
  assertEquals(ins.riskSignals.some((s) => s.code === "no_monitoring_data"), false);
});
