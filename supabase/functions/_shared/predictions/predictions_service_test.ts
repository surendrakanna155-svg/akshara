import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  buildPredictionsBaseline,
  computeAdmissionConversion,
  computeFeeDefaultRisk,
  computeStudentRiskList,
} from "./predictions_service.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";

class MockDb {
  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, _args: unknown[] = []): Promise<T[]> {
    const has = (...f: string[]) => f.every((x) => sql.includes(x));

    // fee-default aggregate
    if (has("FROM finance_invoices i", "JOIN students s")) {
      return [
        { student_id: "st-1", student_name: "Asha", class_name: "Grade 5",
          outstanding: 9000, billed: 10000, days_overdue: 80 },     // long overdue + 90% unpaid → high
        { student_id: "st-2", student_name: "Ravi", class_name: "Grade 6",
          outstanding: 500, billed: 10000, days_overdue: 3 },       // barely overdue, small → low
      ] as T[];
    }

    // admission-conversion leads + latest application status
    if (has("FROM admissions_leads l")) {
      return [
        { id: "ld-1", student_name: "Meena", class_label: "Grade 1", source: "website",
          stage: "application", score: "hot", age_days: 5, app_status: "under_review" }, // hot
        { id: "ld-2", student_name: "Kiran", class_label: "Grade 1", source: "walkin",
          stage: "new_enquiry", score: "cold", age_days: 60, app_status: null },          // cool
        { id: "ld-3", student_name: "Sara", class_label: "Grade 2", source: "referral",
          stage: "rejected", score: "warm", age_days: 30, app_status: "rejected" },       // ~0
      ] as T[];
    }

    // student-risk: loadStudentSignals query. attendance_percent is the CANONICAL
    // column loadStudentSignals reads (a real number => "has data"; SQL NULL =>
    // unmonitored, per the ICA-H4 provenance rewrite). Both students below have
    // REAL attendance data.
    if (has("FROM students s", "attendance_records ar")) {
      return [
        { student_id: "st-1", student_name: "Asha", class_name: "Grade 5", section_name: "A",
          absent_count: 8, attendance_percent: 40, hw_submitted: 2, hw_total: 10,
          avg_marks_pct: 30, behavior_incidents: 1 },  // multiple gaps → high risk
        { student_id: "st-2", student_name: "Ravi", class_name: "Grade 6", section_name: "B",
          absent_count: 0, attendance_percent: 95, hw_submitted: 10, hw_total: 10,
          avg_marks_pct: 88, behavior_incidents: 0 },  // stable → low risk
      ] as T[];
    }
    return [] as T[];
  }
  // deno-lint-ignore require-await
  async queryCount(): Promise<number> { return 0; }
  get raw(): never { throw new Error("unused"); }
}

const db = () => new MockDb() as unknown as TenantQueryClient;

Deno.test("fee-default: long-overdue large balance scores higher than fresh small one", async () => {
  const rows = await computeFeeDefaultRisk(db(), ORG, SCHOOL);
  assertEquals(rows.length, 2);
  assertEquals(rows[0].studentName, "Asha");
  assertEquals(rows[0].riskScore > rows[1].riskScore, true);
  assertEquals(rows[0].riskLevel === "critical" || rows[0].riskLevel === "high", true);
  assertEquals(rows[0].outstandingInr, 9000);
  assertEquals(rows[0].daysOverdue, 80);
});

Deno.test("admission-conversion: hot under-review > cold stale > rejected", async () => {
  const rows = await computeAdmissionConversion(db(), ORG, SCHOOL);
  assertEquals(rows.length, 3);
  const byId = new Map(rows.map((r) => [r.leadId, r]));
  assertEquals(byId.get("ld-1")!.band, "hot");
  assertEquals(byId.get("ld-3")!.likelihood, 5); // rejected
  assertEquals(byId.get("ld-1")!.likelihood > byId.get("ld-2")!.likelihood, true);
  assertEquals(byId.get("ld-2")!.likelihood > byId.get("ld-3")!.likelihood, true);
});

Deno.test("student-risk: reuses the engine, sorts highest-risk first", async () => {
  const rows = await computeStudentRiskList(db(), ORG, SCHOOL);
  assertEquals(rows.length, 2);
  assertEquals(rows[0].studentName, "Asha"); // highest risk first
  assertEquals(rows[0].riskScore > rows[1].riskScore, true);
  assertEquals(rows[1].riskLevel, "low");
  assertEquals(rows[0].topReason.length > 0, true);
});

// A one-row mock for the loadStudentSignals SELECT, so a test can drive the
// exact attendance/homework provenance of a single student.
class OneSignalMockDb {
  constructor(private row: Record<string, unknown>) {}
  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, _args: unknown[] = []): Promise<T[]> {
    if (sql.includes("attendance_records ar")) return [this.row] as T[];
    return [] as T[];
  }
  // deno-lint-ignore require-await
  async queryCount(): Promise<number> {
    return 0;
  }
  get raw(): never {
    throw new Error("unused");
  }
}

Deno.test("student-risk (ICA-H4): a no-attendance-data student is surfaced NEEDS-REVIEW, never low-risk", async () => {
  // attendance_percent NULL + no homework rows = an ABSENCE of monitoring data,
  // not evidence of good standing. Before the fix this scored ~low and sank to
  // the bottom of the early-warning list.
  const db = new OneSignalMockDb({
    student_id: "st-x", student_name: "Nomonitor", class_name: "Grade 3", section_name: "A",
    absent_count: 0, attendance_percent: null, hw_submitted: 0, hw_total: 0,
    avg_marks_pct: 70, behavior_incidents: 0,
  }) as unknown as TenantQueryClient;
  const rows = await computeStudentRiskList(db, ORG, SCHOOL);
  assertEquals(rows.length, 1);
  const r = rows[0];
  // the exit requirement: never low-risk-by-default for an unmonitored student
  assertEquals(r.riskLevel === "low", false);
  assertEquals(r.riskLevel, "medium"); // floored to the "needs review" band
  assertEquals(r.riskScore >= 40, true); // surfaces in a score-ordered list
  assertEquals(r.unmonitored, true);
  assertEquals(r.dataCompleteness, "none");
  assertEquals(r.topReason, "No monitoring data");
});

Deno.test("baseline narrative is honest about empty and populated sets", () => {
  assertEquals(buildPredictionsBaseline("fee-default", { total: 0, high: 0 }, []),
    "No fee-default risk signals in the current data.");
  const s = buildPredictionsBaseline("student-risk", { total: 3, high: 1 }, ["Asha"]);
  assertEquals(s.includes("3 record(s)"), true);
  assertEquals(s.includes("Asha"), true);
});
