// PRA-P0-21 (S6): Parent Insights AI must NEVER fabricate a child's metrics.
//
// The bug: the source `intel_student_risk_snapshots` read returned 0 rows under a
// parent token (school-scope-only RLS), and the service silently defaulted the
// missing metrics to 85%/80%/70%/"your child" and had the model narrate them as
// real. These pin the two halves of the fix that ARE unit-testable: (1) the
// service now REJECTS (ParentInsightsNoDataError) instead of defaulting when no
// snapshot is readable, and uses only real present metrics otherwise; (2) the RLS
// migration grants a parent read of ONLY their own active-linked child's snapshot
// (the DB-enforced half — pinned by asserting the policy shape). The handler
// child_ids ownership gate is the third layer (defence in depth).

import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import {
  generateParentInsightSnapshot,
  ParentInsightsNoDataError,
} from "./parent_insights_service.ts";
import type { TenantQueryClient } from "../tenant_db.ts";

function fakeDb(rows: unknown[]): TenantQueryClient {
  return {
    // deno-lint-ignore no-explicit-any
    queryObject(_sql: string, _args?: unknown[]): Promise<any[]> {
      return Promise.resolve(rows as any[]);
    },
  } as unknown as TenantQueryClient;
}

Deno.test("P0-21 no readable snapshot → throws NoData, never fabricates 85/80/70", async () => {
  await assertRejects(
    () => generateParentInsightSnapshot(fakeDb([]), "stu-1", "weekly"),
    ParentInsightsNoDataError,
  );
});

Deno.test("P0-21 present snapshot → REAL metrics, no fabricated defaults", async () => {
  const snap = await generateParentInsightSnapshot(
    fakeDb([{
      inputs: {
        attendance_percent: 52,
        homework_completion_rate: 40,
        average_marks: 55,
        student_name: "Asha",
      },
    }]),
    "stu-1",
    "weekly",
  );
  assert(snap.progressSummary.includes("Asha"));
  assert(snap.progressSummary.includes("52%"), snap.progressSummary);
  assert(snap.attendanceInsights[0].includes("52%"));
  assert(snap.attendanceInsights[0].includes("below"));
  assert(snap.homeworkInsights[0].includes("40%"));
  // The old fabricated numbers must never appear from a real 52/40/55 snapshot.
  assert(!snap.progressSummary.includes("85%"));
  assert(!snap.progressSummary.includes("80%"));
  assert(!snap.progressSummary.includes("70%"));
});

Deno.test("P0-21 present snapshot with a missing metric → 'not available', not a number", async () => {
  const snap = await generateParentInsightSnapshot(
    fakeDb([{ inputs: { average_marks: 61, student_name: "Ravi" } }]),
    "stu-1",
    "weekly",
  );
  assertEquals(snap.attendanceInsights[0], "Attendance data is not available yet.");
  assertEquals(snap.homeworkInsights[0], "Homework completion data is not available yet.");
  assert(snap.progressSummary.includes("attendance not available"), snap.progressSummary);
  assert(snap.progressSummary.includes("marks 61%"), snap.progressSummary);
});

Deno.test("P0-21 migration grants parent-scope SELECT on the risk-snapshot source", async () => {
  const sql = await Deno.readTextFile(
    new URL(
      "../../../migrations/20260900000015_pra_p0_21_parent_insights_risk_scope.sql",
      import.meta.url,
    ),
  );
  assert(sql.includes("CREATE POLICY intel_student_risk_parent_read ON intel_student_risk_snapshots"));
  assert(sql.includes("FOR SELECT"));
  assert(sql.includes("app_current_scope() = 'parent'"));
  assert(sql.includes("guardian_user_id = app_current_parent_user_id()"));
  assert(sql.includes("sg.status = 'active'"));
  // It must NOT weaken the source table to a blanket parent read (no child fence
  // would re-open the cross-child leak).
  assert(sql.includes("student_id IN ("));
});
