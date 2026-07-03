import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
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
// balance or is absent (undefined → the mapper's honest 0 default).
class SignalsMockDb {
  lastSql = "";
  lastArgs: unknown[] = [];
  constructor(private feeRow: Record<string, unknown>) {}
  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    this.lastSql = sql;
    this.lastArgs = args;
    return [{
      student_id: "st-1",
      student_name: "Asha",
      class_name: "Grade 5",
      section_name: "A",
      absent_count: 0,
      total_attendance: 20,
      hw_submitted: 10,
      hw_total: 10,
      avg_marks_pct: 80,
      behavior_incidents: 0,
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
