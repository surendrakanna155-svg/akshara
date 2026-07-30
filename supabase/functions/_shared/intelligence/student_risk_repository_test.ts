import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { attendancePercentSql } from "../attendance/attendance_percentage.ts";
import {
  computeAndStoreRiskSnapshots,
  INTEL_RISK_API_PROBE_SQL,
  INTEL_RISK_PROBE_SCHOOL_A,
  INTEL_RISK_PROBE_SCHOOL_B,
  INTEL_RISK_PROBE_SQL,
  loadStudentSignals,
} from "./student_risk_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";

// Mock DB that captures the signals SQL and returns a fixed student row. The
// `feeRow` fields let each test control whether the fee LATERAL returns a real
// balance or is absent (undefined → the mapper's honest 0 default). The
// `attendanceRow` fields let attendance-specific tests override absent_count /
// attendance_percent (CANONICAL — computed by the shared attendancePercentSql()
// fragment now, not derived here) while every other test keeps the default
// "20 marked, 0 absent, fully present" fixture (100% under either formula).
class SignalsMockDb {
  lastSql = "";
  lastArgs: unknown[] = [];
  constructor(
    private feeRow: Record<string, unknown>,
    private attendanceRow: Record<string, unknown> = { absent_count: 0, attendance_percent: 100 },
  ) {}
  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    this.lastSql = sql;
    this.lastArgs = args;
    return [{
      student_id: "st-1",
      student_name: "Asha",
      class_name: "Grade 5",
      section_name: "A",
      hw_submitted: 10,
      hw_total: 10,
      avg_marks_pct: 80,
      behavior_incidents: 0,
      ...this.attendanceRow,
      ...this.feeRow,
    }] as T[];
  }
  // deno-lint-ignore require-await
  async queryCount(): Promise<number> {
    return 0;
  }
  get raw(): never {
    throw new Error("unused");
  }
}

Deno.test("student risk repository exports tenant isolation probe SQL", () => {
  assert(INTEL_RISK_PROBE_SQL.includes("intel_student_risk_snapshots"));
  assert(INTEL_RISK_API_PROBE_SQL.includes("app_current_tenant_id()"));
  assert(INTEL_RISK_API_PROBE_SQL.includes("app_current_school_id()"));
  assertEquals(INTEL_RISK_PROBE_SCHOOL_A, "f0500000-0000-4000-8000-000000000001");
  assertEquals(INTEL_RISK_PROBE_SCHOOL_B, "f0500000-0000-4000-8000-000000000002");
});

Deno.test("recovery migration seeds match repository probe fixture ids", async () => {
  const recoverySql = await Deno.readTextFile(
    new URL("../../../migrations/20260627100000_staging_intelligence_layer_recovery.sql", import.meta.url),
  );
  assert(recoverySql.includes(INTEL_RISK_PROBE_SCHOOL_A));
  assert(recoverySql.includes(INTEL_RISK_PROBE_SCHOOL_B));
});

Deno.test("loadStudentSignals reads the fee balance from finance_student_accounts", async () => {
  const db = new SignalsMockDb({ fee_outstanding: 12500, fee_overdue_days: 42 });
  const signals = await loadStudentSignals(
    db as unknown as TenantQueryClient,
    ORG,
    SCHOOL,
    "2025-26",
  );

  // reads the AUTHORITATIVE column/table, scoped like the other joins
  assert(db.lastSql.includes("finance_student_accounts"));
  assert(db.lastSql.includes("outstanding_amount"));
  assert(db.lastSql.includes("fsa.organization_id = $1"));
  assert(db.lastSql.includes("fsa.school_id = $2"));
  assert(db.lastSql.includes("fsa.status = 'open'"));
  // current-year scoping is applied when a year label is supplied
  assert(db.lastSql.includes("fsa.academic_year = $3"));
  assertEquals(db.lastArgs, [ORG, SCHOOL, "2025-26"]);

  assertEquals(signals.length, 1);
  assertEquals(signals[0].fee_outstanding_amount, 12500);
  assertEquals(signals[0].fee_overdue_days, 42);
});

Deno.test("loadStudentSignals defaults fee balance to 0 when no account exists", async () => {
  // fee LATERAL returns no row → coalesced fields are absent in the mock
  const db = new SignalsMockDb({});
  const signals = await loadStudentSignals(
    db as unknown as TenantQueryClient,
    ORG,
    SCHOOL,
  );

  // no year supplied → year filter is bypassed ($3 is null)
  assertEquals(db.lastArgs, [ORG, SCHOOL, null]);
  assertEquals(signals.length, 1);
  assertEquals(signals[0].fee_outstanding_amount, 0);
  assertEquals(signals[0].fee_overdue_days, 0);
});

// ─── CANONICAL attendance-% (2026-07-09) ────────────────────────────────────
// loadStudentSignals used to derive attendance_percent downstream from
// (total_count − absent_count) / total_count, which counted late/excused/
// half_day marks as full presence and included excused days in the
// denominator. It now selects the shared attendancePercentSql() fragment
// directly, so the SQL layer (not this file) owns the arithmetic.

Deno.test("loadStudentSignals routes attendance through the shared canonical SQL fragment", async () => {
  const db = new SignalsMockDb({});
  await loadStudentSignals(db as unknown as TenantQueryClient, ORG, SCHOOL);
  assert(db.lastSql.includes(attendancePercentSql("ar.mark")));
});

Deno.test("loadStudentSignals: canonical attendance treats late as present and excludes excused from the denominator", async () => {
  // A 25-day window: 15 present, 3 late, 2 excused, 1 half_day, 4 absent.
  // OLD formula ((total-absent)/total): (25-4)/25 = 84%.
  // CANONICAL: attended = 15 + 3 + 0.5×1 = 18.5; denom = 25 - 2 excused = 23
  //   -> round(18.5/23*100) = 80%. The SQL layer computes this; the mock
  // supplies the value the canonical fragment would have returned.
  const db = new SignalsMockDb({}, { absent_count: 4, attendance_percent: 80 });
  const signals = await loadStudentSignals(db as unknown as TenantQueryClient, ORG, SCHOOL);
  assertEquals(signals[0].attendance_percent, 80); // CANONICAL — was 84 under the old formula
});

// ─── SAFEGUARDING (ICA-H4) ───────────────────────────────────────────────────
// Missing attendance/homework is an ABSENCE OF MONITORING DATA, not evidence of
// good standing. The old mapper coerced it into optimistic constants (92 / 85),
// scoring a newly-enrolled or unmonitored student as low-risk and hiding exactly
// the students no one is watching. It now records explicit data-provenance flags
// and never fabricates an optimistic percentage.

// A store-aware mock DB: routes DELETE / the loadStudentSignals SELECT / the
// snapshot INSERT, capturing each INSERT's bound params so a test can assert the
// stored risk_score / risk_level / reasons / inputs.
function studentRow(overrides: Record<string, unknown> = {}) {
  return {
    student_id: "st-1",
    student_name: "Asha",
    class_name: "Grade 5",
    section_name: "A",
    absent_count: 0,
    attendance_percent: 100,
    hw_submitted: 10,
    hw_total: 10,
    avg_marks_pct: 80,
    behavior_incidents: 0,
    fee_outstanding: 0,
    fee_overdue_days: 0,
    ...overrides,
  };
}

class StoreMockDb {
  insertArgs: unknown[][] = [];
  constructor(private row: Record<string, unknown>) {}
  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("DELETE")) return [] as T[];
    if (sql.includes("INSERT INTO intel_student_risk_snapshots")) {
      this.insertArgs.push(args);
      return [{
        id: "snap-1",
        risk_score: args[6],
        risk_level: args[7],
        reasons: args[8],
        inputs: args[12],
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

function parseInsert(args: unknown[]) {
  return {
    riskScore: args[6] as number,
    riskLevel: args[7] as string,
    reasons: JSON.parse(args[8] as string) as Array<{ code: string; severity: string }>,
    inputs: JSON.parse(args[12] as string) as Record<string, unknown>,
  };
}

Deno.test("loadStudentSignals: no attendance + no homework is flagged UNMONITORED, never faked to 92/85", async () => {
  const db = new StoreMockDb(studentRow({ attendance_percent: null, hw_total: 0, hw_submitted: 0 }));
  const signals = await loadStudentSignals(db as unknown as TenantQueryClient, ORG, SCHOOL);
  const s = signals[0];
  // the fabricated optimistic constants are GONE
  assertEquals(s.attendance_percent === 92, false);
  assertEquals(s.homework_completion_rate === 85, false);
  // explicit data-provenance flags instead
  assertEquals(s.attendance_has_data, false);
  assertEquals(s.homework_has_data, false);
  assertEquals(s.data_completeness, "none");
  assertEquals(s.unmonitored, true);
});

Deno.test("loadStudentSignals: partial data (attendance present, homework null) is not inflated by a fabricated 85", async () => {
  const db = new StoreMockDb(studentRow({ attendance_percent: 88, hw_total: 0, hw_submitted: 0 }));
  const signals = await loadStudentSignals(db as unknown as TenantQueryClient, ORG, SCHOOL);
  const s = signals[0];
  assertEquals(s.attendance_percent, 88); // real attendance preserved
  assertEquals(s.homework_completion_rate === 85, false); // NOT the fabricated optimistic default
  assertEquals(s.attendance_has_data, true);
  assertEquals(s.homework_has_data, false);
  assertEquals(s.data_completeness, "partial");
  assertEquals(s.unmonitored, false); // dominant signal (attendance) is present
});

Deno.test("loadStudentSignals: full data computes the real homework rate and is not flagged", async () => {
  const db = new StoreMockDb(studentRow({ attendance_percent: 90, hw_total: 10, hw_submitted: 8 }));
  const signals = await loadStudentSignals(db as unknown as TenantQueryClient, ORG, SCHOOL);
  const s = signals[0];
  assertEquals(s.homework_completion_rate, 80);
  assertEquals(s.attendance_has_data, true);
  assertEquals(s.homework_has_data, true);
  assertEquals(s.data_completeness, "full");
  assertEquals(s.unmonitored, false);
});

Deno.test("computeAndStoreRiskSnapshots: unmonitored student is stored NEEDS-REVIEW, never low-risk-by-default", async () => {
  // No attendance marked, no homework rows: the old code stored this as ~low.
  const db = new StoreMockDb(studentRow({ attendance_percent: null, hw_total: 0, hw_submitted: 0 }));
  const stored = await computeAndStoreRiskSnapshots(db as unknown as TenantQueryClient, ORG, SCHOOL, "2025-26");
  assertEquals(stored.length, 1);
  assertEquals(db.insertArgs.length, 1);
  const ins = parseInsert(db.insertArgs[0]);

  // the exit requirement: NEVER low-risk-by-default
  assertEquals(ins.riskLevel === "low", false);
  assertEquals(ins.riskLevel, "medium"); // floored to the "needs review" band
  assertEquals(ins.riskScore >= 40, true); // surfaces in a score-ordered list
  // explicit caveat reason, and the misleading "stable" reason is gone
  assertEquals(ins.reasons.some((r) => r.code === "no_monitoring_data"), true);
  assertEquals(ins.reasons.some((r) => r.code === "stable"), false);
  // machine-readable flag persisted in the snapshot inputs for the UI
  assertEquals(ins.inputs.unmonitored, true);
  assertEquals(ins.inputs.data_completeness, "none");
});

Deno.test("computeAndStoreRiskSnapshots: a student with REAL low attendance is still scored high-risk", async () => {
  // Real monitoring data present and bad — the fix must not weaken this path.
  const db = new StoreMockDb(studentRow({
    attendance_percent: 30,
    absent_count: 10,
    hw_total: 10,
    hw_submitted: 1,
    avg_marks_pct: 25,
    behavior_incidents: 3,
    fee_outstanding: 50000,
    fee_overdue_days: 70,
  }));
  await computeAndStoreRiskSnapshots(db as unknown as TenantQueryClient, ORG, SCHOOL, "2025-26");
  const ins = parseInsert(db.insertArgs[0]);

  assertEquals(ins.riskLevel === "high" || ins.riskLevel === "critical", true);
  assertEquals(ins.reasons.some((r) => r.code === "low_attendance"), true);
  // real data present => NOT treated as unmonitored
  assertEquals(ins.reasons.some((r) => r.code === "no_monitoring_data"), false);
  assertEquals(ins.inputs.unmonitored, false);
});

Deno.test("computeAndStoreRiskSnapshots: partial student keeps its honest (low) band + a caveat, not a fabricated 85", async () => {
  // attendance present and healthy (95%), homework simply not tracked yet.
  const db = new StoreMockDb(studentRow({ attendance_percent: 95, hw_total: 0, hw_submitted: 0, avg_marks_pct: 80 }));
  await computeAndStoreRiskSnapshots(db as unknown as TenantQueryClient, ORG, SCHOOL, "2025-26");
  const ins = parseInsert(db.insertArgs[0]);

  // honest low band preserved (real attendance is good) — behavior for students
  // WHO DO have (good) data is unchanged
  assertEquals(ins.riskLevel, "low");
  // the missing homework dimension is excluded, not fabricated as 85%
  assertEquals(ins.inputs.homework_completion_rate === 85, false);
  assertEquals(ins.inputs.data_completeness, "partial");
  assertEquals(ins.reasons.some((r) => r.code === "partial_monitoring_data"), true);
  assertEquals(ins.reasons.some((r) => r.code === "no_monitoring_data"), false);
});
