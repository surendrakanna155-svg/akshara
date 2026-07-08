import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { attendancePercentSql } from "../attendance/attendance_percentage.ts";
import {
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

Deno.test("loadStudentSignals: no usable attendance data defaults to 92, not 0 or null", async () => {
  // attendancePercentSql() returns SQL NULL when the denominator is 0 (no
  // marked days at all, or every marked day was excused). The risk engine
  // consumes attendance_percent as a plain number, so the mapper falls back
  // to 92 — the SAME default the old total_attendance===0 branch used —
  // so risk scores do not shift for students with no/no-usable data.
  const db = new SignalsMockDb({}, { absent_count: 0, attendance_percent: null });
  const signals = await loadStudentSignals(db as unknown as TenantQueryClient, ORG, SCHOOL);
  assertEquals(signals[0].attendance_percent, 92);
});
