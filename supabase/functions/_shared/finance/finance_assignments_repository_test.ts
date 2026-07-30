import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import {
  requirePermission,
  requireSchoolOperationalScope,
} from "../permission_middleware.ts";
import {
  assignmentToApi,
  studentAccountListItemToApi,
  studentAccountToApi,
} from "./finance_mapper.ts";
import {
  bulkAssignFeeStructure,
  DuplicateAssignmentError,
  FeeProrationOverrideReasonRequiredError,
  FeeStructureNotBoundError,
  HandoffNotReadyError,
  assignFeeStructure,
  assignFromHandoff,
  cancelAssignment,
  getStudentAccount,
  resolveStudentIdsForBoundStructure,
} from "./finance_assignments_repository.ts";
import type { TenantQueryClient } from "../tenant_db.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";
const STAFF = "a3000000-0000-4000-8000-000000000001";
const STUDENT = "a4000000-0000-4000-8000-000000000001";
const STUDENT_2 = "a4000000-0000-4000-8000-000000000002";
const STUDENT_3 = "a4000000-0000-4000-8000-000000000003";
const STRUCTURE = "b7000000-0000-4000-8000-000000000001";
const HANDOFF = "b6000000-0000-4000-8000-000000000001";
// Cap 73 — an April-start academic year (matches the real academic_foundation
// fixture convention used elsewhere in this codebase).
const ACADEMIC_YEAR_ID = "ce100000-0000-4000-8000-000000000001";
const AY_START = "2026-04-01";
const AY_END = "2027-03-31";
// Cap 67 — class/section binding fixtures.
const CLASS_A = "cf100000-0000-4000-8000-000000000001";
const SECTION_A = "d0100000-0000-4000-8000-000000000001";

type Row = Record<string, unknown>;

const PRORATION_SETTING_KEY = "payments.midyear_admission_proration_policy";

class MockAssignmentsDb {
  structures = [{
    id: STRUCTURE,
    name: "Probe Structure A",
    academic_year: "2026-27",
    academic_year_id: ACADEMIC_YEAR_ID as string | null,
    class_id: null as string | null,
    section_id: null as string | null,
    status: "active",
  }];
  items = [{ fee_structure_id: STRUCTURE, amount: "50000", organization_id: ORG, school_id: SCHOOL_A }];
  assignments: Row[] = [];
  accounts: Row[] = [];
  invoices: Row[] = [];
  failOnInvoiceInsert = false;
  // ICA-C4 — set the FIRST batched (unnest) finance_student_accounts INSERT to
  // raise a Postgres unique_violation, simulating a concurrent writer that
  // opened a finance_student_accounts row (UNIQUE(student_id, academic_year))
  // between the set-based read and the batched INSERT. Exercises the
  // ROLLBACK-TO-SAVEPOINT + per-student fallback recovery.
  raceOnBatchAccountInsert = false;
  // ICA-C4 — every SQL string issued, so a test can prove the set-based path is
  // BOUNDED (no per-student duplicate SELECT / SAVEPOINT that grows with N).
  queryLog: string[] = [];
  // ICA-C4 — a faithful model of Postgres SAVEPOINT / RELEASE / ROLLBACK TO
  // SAVEPOINT: a snapshot of every mutable table, so a rolled-back set-based
  // batch is actually undone before the fallback loop re-runs (otherwise the
  // fallback would see the half-written rows as duplicates and skip everyone).
  private savepoints = new Map<
    string,
    { assignments: Row[]; accounts: Row[]; invoices: Row[] }
  >();

  private snapshot() {
    return {
      assignments: structuredClone(this.assignments),
      accounts: structuredClone(this.accounts),
      invoices: structuredClone(this.invoices),
    };
  }

  private restore(snap: { assignments: Row[]; accounts: Row[]; invoices: Row[] }) {
    this.assignments = structuredClone(snap.assignments);
    this.accounts = structuredClone(snap.accounts);
    this.invoices = structuredClone(snap.invoices);
  }
  handoffs = [{
    id: HANDOFF,
    organization_id: ORG,
    school_id: SCHOOL_A,
    student_id: STUDENT,
    academic_year: "2026-27",
    recommended_fee_plan_id: STRUCTURE,
    handoff_status: "sent_to_finance",
    student_name: "Probe Student A",
    admission_number: "ADM-PROBE-A",
    class_label: "5",
  }];
  students = [
    { id: STUDENT, display_name: "Probe Student A", status: "active" },
    { id: STUDENT_2, display_name: "Probe Student B", status: "active" },
    { id: STUDENT_3, display_name: "Probe Student C", status: "active" },
  ];
  // Cap 73 — academic year calendar bounds (for proration).
  academicYears: Row[] = [{
    id: ACADEMIC_YEAR_ID,
    organization_id: ORG,
    school_id: SCHOOL_A,
    start_date: AY_START,
    end_date: AY_END,
    status: "active",
  }];
  // Cap 73 — finance_settings row; null = unconfigured (falls back to the
  // TEMPLATE default, exactly like the real repository).
  financeSettings: Row | null = null;
  // Cap 67 — enrollments backing the bulk-assign auto-resolve-from-class path.
  enrollments: Row[] = [];

  async queryCount(): Promise<number> {
    return this.assignments.length;
  }

  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    this.queryLog.push(sql);
    // ── Transaction-control (SAVEPOINT / RELEASE / ROLLBACK TO SAVEPOINT) ──
    const trimmed = sql.trim();
    if (trimmed.startsWith("SAVEPOINT ")) {
      this.savepoints.set(trimmed.slice("SAVEPOINT ".length).trim(), this.snapshot());
      return [] as T[];
    }
    if (trimmed.startsWith("RELEASE SAVEPOINT ")) {
      this.savepoints.delete(trimmed.slice("RELEASE SAVEPOINT ".length).trim());
      return [] as T[];
    }
    if (trimmed.startsWith("ROLLBACK TO SAVEPOINT ")) {
      const snap = this.savepoints.get(trimmed.slice("ROLLBACK TO SAVEPOINT ".length).trim());
      if (snap) this.restore(snap);
      return [] as T[];
    }

    // ── ICA-C4 set-based (batched) reads/writes. These are gated on `= ANY` /
    // `unnest` / `DISTINCT ON`, which the pre-existing scalar branches below
    // never contain, so they must be matched FIRST to avoid mis-routing. ──

    // Batched duplicate-assignment check (one query for the whole cohort).
    if (sql.includes("SELECT student_id FROM finance_fee_assignments") && sql.includes("= ANY")) {
      const feeStructureId = args[0];
      const academicYear = args[1];
      const ids = new Set(args[4] as string[]);
      return this.assignments
        .filter((a) =>
          a.fee_structure_id === feeStructureId &&
          a.academic_year === academicYear &&
          ids.has(a.student_id as string)
        )
        .map((a) => ({ student_id: a.student_id })) as T[];
    }

    // Batched existing-account read (one query for the whole cohort).
    if (
      sql.includes("SELECT * FROM finance_student_accounts") &&
      sql.includes("academic_year = $1") &&
      sql.includes("= ANY")
    ) {
      const academicYear = args[0];
      const ids = new Set(args[3] as string[]);
      return this.accounts.filter((a) =>
        a.academic_year === academicYear && ids.has(a.student_id as string)
      ) as T[];
    }

    // Multi-row assignment INSERT (unnest) with ON CONFLICT DO NOTHING.
    if (sql.includes("INSERT INTO finance_fee_assignments") && sql.includes("unnest")) {
      const ids = args[2] as string[];
      const feeStructureId = args[3];
      const academicYear = args[4];
      const inserted: Row[] = [];
      for (const sid of ids) {
        // ON CONFLICT (student_id, fee_structure_id, academic_year) DO NOTHING.
        const conflict = this.assignments.some((a) =>
          a.student_id === sid &&
          a.fee_structure_id === feeStructureId &&
          a.academic_year === academicYear
        );
        if (conflict) continue;
        const row = {
          id: crypto.randomUUID(),
          organization_id: args[0],
          school_id: args[1],
          student_id: sid,
          fee_structure_id: feeStructureId,
          academic_year: academicYear,
          assignment_status: "active",
          assigned_by: args[5],
          assigned_at: "2026-06-12T00:00:00.000Z",
          created_at: "2026-06-12T00:00:00.000Z",
          updated_at: "2026-06-12T00:00:00.000Z",
          proration_policy: args[6],
          proration_basis: args[7],
          proration_total_months: args[8],
          proration_months_charged: args[9],
          proration_reference_date: args[10],
          proration_annual_amount: args[11] != null ? String(args[11]) : null,
          proration_charged_amount: args[12] != null ? String(args[12]) : null,
          proration_fallback_reason: args[13],
          proration_is_override: args[14],
          proration_override_reason: args[15],
          proration_overridden_by: args[16],
        };
        this.assignments.push(row);
        inserted.push(row);
      }
      return inserted as T[];
    }

    // Multi-row account INSERT (unnest over parallel student_id/assignment_id).
    if (sql.includes("INSERT INTO finance_student_accounts") && sql.includes("unnest")) {
      if (this.raceOnBatchAccountInsert) {
        // Model the whole statement failing atomically on a unique_violation —
        // nothing is inserted.
        const err = new Error(
          "duplicate key value violates unique constraint \"finance_student_accounts_student_id_academic_year_key\"",
        ) as Error & { code: string };
        err.code = "23505";
        throw err;
      }
      const studentIds = args[4] as string[];
      const assignmentIds = args[5] as string[];
      const total = String(args[3]);
      const inserted: Row[] = [];
      for (let i = 0; i < studentIds.length; i++) {
        const row = {
          id: crypto.randomUUID(),
          organization_id: args[0],
          school_id: args[1],
          student_id: studentIds[i],
          fee_assignment_id: assignmentIds[i],
          academic_year: args[2],
          total_fee: total,
          amount_paid: "0",
          outstanding_amount: total,
          status: "open",
          created_at: "2026-06-12T00:00:00.000Z",
          updated_at: "2026-06-12T00:00:00.000Z",
        };
        this.accounts.push(row);
        inserted.push(row);
      }
      return inserted as T[];
    }

    // Batched TRN-9 reuse bump (one UPDATE for every reuse account).
    if (
      sql.includes("UPDATE finance_student_accounts SET") &&
      sql.includes("total_fee = total_fee +") &&
      sql.includes("= ANY")
    ) {
      const delta = Number(args[0]);
      const ids = new Set(args[1] as string[]);
      const updated: Row[] = [];
      for (const a of this.accounts) {
        if (ids.has(a.id as string)) {
          a.total_fee = String(Number(a.total_fee) + delta);
          a.outstanding_amount = String(Number(a.outstanding_amount) + delta);
          a.status = "open";
          updated.push(a);
        }
      }
      return updated as T[];
    }

    // Batched enrichment — student display names.
    if (sql.includes("SELECT id, display_name FROM students") && sql.includes("= ANY")) {
      const ids = new Set(args[0] as string[]);
      return this.students
        .filter((s) => ids.has(s.id))
        .map((s) => ({ id: s.id, display_name: s.display_name })) as T[];
    }

    // Batched enrichment — latest handoff per student (DISTINCT ON).
    if (sql.includes("DISTINCT ON (student_id)") && sql.includes("admissions_fee_handoffs")) {
      const ids = new Set(args[0] as string[]);
      const seen = new Set<string>();
      const out: Row[] = [];
      for (const h of this.handoffs) {
        if (ids.has(h.student_id) && !seen.has(h.student_id)) {
          seen.add(h.student_id);
          out.push({
            student_id: h.student_id,
            admission_number: h.admission_number,
            class_label: h.class_label,
            student_name: h.student_name,
          });
        }
      }
      return out as T[];
    }

    if (sql.includes("FROM finance_fee_structures") && sql.includes("status = 'active'")) {
      const found = this.structures.find((s) => s.id === args[0]);
      return (found
        ? [{
          name: found.name,
          academic_year: found.academic_year,
          academic_year_id: found.academic_year_id,
          class_id: found.class_id,
          section_id: found.section_id,
        }]
        : []) as T[];
    }
    // Cap 67 — resolveStudentIdsForBoundStructure's own structure lookup
    // (deliberately narrower than ensureFeeStructureExists's — no status filter).
    if (sql.includes("SELECT class_id, section_id FROM finance_fee_structures")) {
      const found = this.structures.find((s) => s.id === args[0]);
      return (found ? [{ class_id: found.class_id, section_id: found.section_id }] : []) as T[];
    }
    // Cap 73 — academic year calendar bounds (getAcademicYear).
    if (sql.includes("FROM academic_years")) {
      const found = this.academicYears.find((y) =>
        y.id === args[0] && y.organization_id === args[1] && y.school_id === args[2]
      );
      return (found ? [found] : []) as T[];
    }
    // Cap 73 — configured proration policy (getSettingsRow).
    if (sql.includes("FROM finance_settings")) {
      return (this.financeSettings ? [this.financeSettings] : []) as T[];
    }
    // Cap 67 — bulk-assign auto-resolve-from-class (resolveStudentIdsForBoundStructure).
    if (sql.includes("FROM sis_student_enrollments")) {
      const activeStudentIds = new Set(
        this.students.filter((s) => s.status === "active").map((s) => s.id),
      );
      const rows = this.enrollments.filter((e) =>
        e.class_id === args[2] &&
        (args[3] == null || e.section_id === args[3]) &&
        e.is_current === true &&
        activeStudentIds.has(e.student_id as string)
      );
      const distinctStudentIds = [...new Set(rows.map((r) => r.student_id))];
      return distinctStudentIds.map((id) => ({ student_id: id })) as T[];
    }
    if (sql.includes("SUM(amount)")) {
      // Sum this structure's own items (args[0] = fee_structure_id) so a second,
      // different structure invoices its own amount (TRN-9), not a hardcoded one.
      const sum = this.items
        .filter((it) => it.fee_structure_id === args[0])
        .reduce((acc, it) => acc + parseFloat(String(it.amount)), 0);
      return [{ total: String(sum) }] as T[];
    }
    if (sql.includes("FROM finance_student_accounts") && sql.includes("student_id = $1") && sql.includes("academic_year = $2")) {
      // TRN-9: the get-or-create lookup now selects the full account row (SELECT *)
      // so it can be reused, not just its id.
      const found = this.accounts.find((a) =>
        a.student_id === args[0] && a.academic_year === args[1]
      );
      return (found ? [found] : []) as T[];
    }
    if (sql.includes("INSERT INTO finance_fee_assignments")) {
      const row = {
        id: crypto.randomUUID(),
        organization_id: args[0],
        school_id: args[1],
        student_id: args[2],
        fee_structure_id: args[3],
        academic_year: args[4],
        assignment_status: "active",
        assigned_by: args[5],
        assigned_at: "2026-06-12T00:00:00.000Z",
        created_at: "2026-06-12T00:00:00.000Z",
        updated_at: "2026-06-12T00:00:00.000Z",
        // Cap 73 — mid-year admission proration, recorded per-assignment.
        proration_policy: args[6],
        proration_basis: args[7],
        proration_total_months: args[8],
        proration_months_charged: args[9],
        proration_reference_date: args[10],
        proration_annual_amount: args[11] != null ? String(args[11]) : null,
        proration_charged_amount: args[12] != null ? String(args[12]) : null,
        proration_fallback_reason: args[13],
        proration_is_override: args[14],
        proration_override_reason: args[15],
        proration_overridden_by: args[16],
      };
      this.assignments.push(row);
      return [row as T];
    }
    if (sql.includes("INSERT INTO finance_student_accounts")) {
      const row = {
        id: crypto.randomUUID(),
        organization_id: args[0],
        school_id: args[1],
        student_id: args[2],
        fee_assignment_id: args[3],
        academic_year: args[4],
        total_fee: String(args[5]),
        amount_paid: "0",
        outstanding_amount: String(args[5]),
        status: "open",
        created_at: "2026-06-12T00:00:00.000Z",
        updated_at: "2026-06-12T00:00:00.000Z",
      };
      this.accounts.push(row);
      return [row as T];
    }
    if (sql.includes("INSERT INTO finance_invoices")) {
      if (this.failOnInvoiceInsert) {
        throw new Error("simulated invoice insert failure");
      }
      const row = {
        id: crypto.randomUUID(),
        organization_id: args[0],
        school_id: args[1],
        student_id: args[2],
        fee_assignment_id: args[3],
        academic_year: args[4],
        invoice_number: args[5],
        invoice_date: args[6],
        due_date: args[7],
        subtotal_amount: String(args[8]),
        discount_amount: "0",
        total_amount: String(args[8]),
        outstanding_amount: String(args[8]),
        invoice_status: "issued",
        created_by: args[9],
        created_at: "2026-06-12T00:00:00.000Z",
        updated_at: "2026-06-12T00:00:00.000Z",
      };
      this.invoices.push(row);
      return [row as T];
    }
    if (sql.includes("FROM finance_invoices") && sql.includes("fee_assignment_id = $1")) {
      const found = this.invoices.find((i) => i.fee_assignment_id === args[0]);
      return (found ? [found] : []) as T[];
    }
    if (sql.includes("SELECT id FROM finance_invoices") && sql.includes("fee_assignment_id = $1")) {
      const found = this.invoices.find((i) => i.fee_assignment_id === args[0]);
      return (found ? [{ id: found.id }] : []) as T[];
    }
    if (sql.includes("SELECT id FROM finance_fee_assignments") && sql.includes("student_id = $1")) {
      const found = this.assignments.find((a) =>
        a.student_id === args[0] && a.fee_structure_id === args[1] && a.academic_year === args[2]
      );
      return (found ? [{ id: found.id }] : []) as T[];
    }
    if (sql.includes("FROM admissions_fee_handoffs") && sql.includes("WHERE id = $1")) {
      const found = this.handoffs.find((h) => h.id === args[0]);
      return (found ? [found] : []) as T[];
    }
    if (sql.includes("UPDATE admissions_fee_handoffs")) {
      const handoff = this.handoffs.find((h) => h.id === args[0]);
      if (handoff) handoff.handoff_status = "completed";
      return [] as T[];
    }
    if (sql.includes("SELECT name FROM finance_fee_structures")) {
      return [{ name: "Probe Structure A" }] as T[];
    }
    if (sql.includes("SELECT display_name FROM students")) {
      return [{ display_name: "Probe Student A" }] as T[];
    }
    if (sql.includes("admissions_fee_handoffs") && sql.includes("ORDER BY created_at DESC")) {
      return [this.handoffs[0]] as T[];
    }
    if (sql.includes("UPDATE finance_fee_assignments SET") && sql.includes("cancelled")) {
      const row = this.assignments.find((a) => a.id === args[0]);
      if (!row || row.assignment_status !== "active") return [] as T[];
      row.assignment_status = "cancelled";
      return [row as T];
    }
    if (
      sql.includes("UPDATE finance_student_accounts SET") &&
      sql.includes("total_fee = total_fee +")
    ) {
      // TRN-9 reuse bump: fold a second structure's total into the shared account.
      const row = this.accounts.find((a) => a.id === args[1]);
      if (row) {
        row.total_fee = String(Number(row.total_fee) + Number(args[0]));
        row.outstanding_amount = String(
          Number(row.outstanding_amount) + Number(args[0]),
        );
        row.status = "open";
      }
      return (row ? [row] : []) as T[];
    }
    if (sql.includes("UPDATE finance_student_accounts SET") && sql.includes("closed")) {
      const row = this.accounts.find((a) => a.fee_assignment_id === args[0]);
      if (row) row.status = "closed";
      return (row ? [row] : []) as T[];
    }
    if (sql.includes("SELECT * FROM finance_student_accounts") && sql.includes("student_id = $1")) {
      const row = this.accounts.find((a) => a.student_id === args[0]);
      return (row ? [row] : []) as T[];
    }
    if (sql.includes("SELECT * FROM finance_fee_assignments") && sql.includes("WHERE id = $1")) {
      const row = this.assignments.find((a) => a.id === args[0]);
      return (row ? [row] : []) as T[];
    }
    return [] as T[];
  }
}

function asDb(mock: MockAssignmentsDb): TenantQueryClient {
  return mock as unknown as TenantQueryClient;
}

function schoolClaims(permissions: string[]): AccessTokenClaims {
  return {
    sub: STAFF,
    tenant_id: ORG,
    organization_id: ORG,
    school_id: SCHOOL_A,
    role: "schoolAdmin",
    role_slugs: ["schoolAdmin"],
    primary_role: "schoolAdmin",
    permissions,
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "test",
  };
}

Deno.test("assignFeeStructure creates assignment and student account", async () => {
  const db = new MockAssignmentsDb();
  const result = await assignFeeStructure(asDb(db), ORG, SCHOOL_A, {
    studentId: STUDENT,
    feeStructureId: STRUCTURE,
    academicYear: "2026-27",
    assignedBy: STAFF,
  });
  assertEquals(result.account.total_fee, "50000");
  assertEquals(result.account.outstanding_amount, "50000");
  assertEquals(result.account.amount_paid, "0");
  assertEquals(db.assignments.length, 1);
  assertEquals(db.accounts.length, 1);
  assertEquals(db.invoices.length, 1);
  assertEquals(result.invoice.invoice_status, "issued");
  assertEquals(result.invoice.total_amount, "50000");
  assertEquals(result.invoice.outstanding_amount, "50000");
});

Deno.test("assignFeeStructure prevents duplicate assignment", async () => {
  const db = new MockAssignmentsDb();
  const input = {
    studentId: STUDENT,
    feeStructureId: STRUCTURE,
    academicYear: "2026-27",
    assignedBy: STAFF,
  };
  await assignFeeStructure(asDb(db), ORG, SCHOOL_A, input);
  await assertRejects(
    () => assignFeeStructure(asDb(db), ORG, SCHOOL_A, input),
    DuplicateAssignmentError,
  );
});

Deno.test("TRN-9: assigning a DIFFERENT structure reuses the student's existing per-year account", async () => {
  // Owner decision: tuition + transport coexist as MULTIPLE invoices under ONE
  // finance_student_accounts row. Assigning a second, different structure to a
  // student who already has an account must SUCCEED and REUSE that account (no
  // second account row, no DuplicateStudentAccountError).
  const db = new MockAssignmentsDb();
  const TRANSPORT_STRUCTURE = "b7000000-0000-4000-8000-000000000099";
  db.structures.push({
    id: TRANSPORT_STRUCTURE,
    name: "Transport Fee",
    academic_year: "2026-27",
    academic_year_id: ACADEMIC_YEAR_ID,
    class_id: null,
    section_id: null,
    status: "active",
  });
  db.items.push({
    fee_structure_id: TRANSPORT_STRUCTURE,
    amount: "12000",
    organization_id: ORG,
    school_id: SCHOOL_A,
  });

  // First structure → opens the account.
  await assignFeeStructure(asDb(db), ORG, SCHOOL_A, {
    studentId: STUDENT,
    feeStructureId: STRUCTURE,
    academicYear: "2026-27",
    assignedBy: STAFF,
  });
  assertEquals(db.accounts.length, 1);

  // Second, DIFFERENT structure → reuses the SAME account, raises a NEW invoice.
  const second = await assignFeeStructure(asDb(db), ORG, SCHOOL_A, {
    studentId: STUDENT,
    feeStructureId: TRANSPORT_STRUCTURE,
    academicYear: "2026-27",
    assignedBy: STAFF,
  });
  // Still ONE account row — reused, not duplicated.
  assertEquals(db.accounts.length, 1);
  // But TWO assignments and TWO invoices now hang off it.
  assertEquals(db.assignments.length, 2);
  assertEquals(db.invoices.length, 2);
  // The reused account now AGGREGATES both structures (tuition 50000 + transport
  // 12000) so its authoritative balance — which collections decrement and the
  // dashboard/defaulters read — reflects the student's true total dues.
  assertEquals(second.account.total_fee, "62000");
  assertEquals(second.account.outstanding_amount, "62000");
  assertEquals(second.account.amount_paid, "0");
  // The second invoice carries the transport structure's own outstanding.
  assertEquals(second.invoice.total_amount, "12000");
  assertEquals(second.invoice.outstanding_amount, "12000");
});

Deno.test("cancelAssignment marks assignment and account closed", async () => {
  const db = new MockAssignmentsDb();
  const created = await assignFeeStructure(asDb(db), ORG, SCHOOL_A, {
    studentId: STUDENT,
    feeStructureId: STRUCTURE,
    academicYear: "2026-27",
    assignedBy: STAFF,
  });
  const cancelled = await cancelAssignment(
    asDb(db),
    ORG,
    SCHOOL_A,
    created.assignment.id as string,
  );
  assertEquals(cancelled?.assignment.assignment_status, "cancelled");
  assertEquals(cancelled?.account.status, "closed");
});

Deno.test("getStudentAccount returns enriched account", async () => {
  const db = new MockAssignmentsDb();
  await assignFeeStructure(asDb(db), ORG, SCHOOL_A, {
    studentId: STUDENT,
    feeStructureId: STRUCTURE,
    academicYear: "2026-27",
    assignedBy: STAFF,
  });
  const account = await getStudentAccount(asDb(db), ORG, SCHOOL_A, STUDENT);
  assertEquals(account?.studentName, "Probe Student A");
  assertEquals(account?.feeStructureName, "Probe Structure A");
});

Deno.test("assignFromHandoff completes handoff and creates account", async () => {
  const db = new MockAssignmentsDb();
  const result = await assignFromHandoff(
    asDb(db),
    ORG,
    SCHOOL_A,
    HANDOFF,
    null,
    STAFF,
  );
  assertEquals(db.handoffs[0]!.handoff_status, "completed");
  assertEquals(result.account.status, "open");
  assertEquals(result.admissionNumber, "ADM-PROBE-A");
});

Deno.test("assignFromHandoff rejects completed handoff", async () => {
  const db = new MockAssignmentsDb();
  db.handoffs[0]!.handoff_status = "completed";
  await assertRejects(
    () => assignFromHandoff(asDb(db), ORG, SCHOOL_A, HANDOFF, null, STAFF),
    HandoffNotReadyError,
  );
});

Deno.test("studentAccountToApi maps to client contract", async () => {
  const db = new MockAssignmentsDb();
  const result = await assignFeeStructure(asDb(db), ORG, SCHOOL_A, {
    studentId: STUDENT,
    feeStructureId: STRUCTURE,
    academicYear: "2026-27",
    assignedBy: STAFF,
  });
  const api = studentAccountToApi(result);
  assertEquals(api.totalDue, "50000");
  assertEquals(api.balance, "50000");
  assertEquals(api.status, "active");
});

Deno.test("studentAccountListItemToApi maps a list row (WEB-007)", () => {
  const api = studentAccountListItemToApi({
    id: "acc-1",
    student_id: STUDENT,
    fee_assignment_id: "fa-1",
    academic_year: "2026-27",
    total_fee: "50000",
    amount_paid: "20000",
    outstanding_amount: "30000",
    status: "open",
    student_name: "Asha Rao",
    admission_number: "ADM-1001",
    class_label: "Grade 5-A",
    fee_structure_id: STRUCTURE,
    fee_structure_name: "Standard Tuition",
  });
  assertEquals(api.studentName, "Asha Rao");
  assertEquals(api.admissionNumber, "ADM-1001");
  assertEquals(api.totalDue, "50000");
  assertEquals(api.totalPaid, "20000");
  assertEquals(api.balance, "30000");
  assertEquals(api.status, "active");
  assertEquals(api.feeAssignmentId, "fa-1");
});

Deno.test("studentAccountListItemToApi tolerates null enrichment", () => {
  const api = studentAccountListItemToApi({
    id: "acc-2",
    student_id: STUDENT,
    fee_assignment_id: "fa-2",
    academic_year: "2026-27",
    total_fee: "0",
    amount_paid: "0",
    outstanding_amount: "0",
    status: "closed",
    student_name: null,
    admission_number: null,
    class_label: null,
    fee_structure_id: null,
    fee_structure_name: null,
  });
  assertEquals(api.studentName, "");
  assertEquals(api.admissionNumber, "");
  assertEquals(api.classLabel, "");
  assertEquals(api.feeStructureId, "");
  assertEquals(api.status, "closed");
});

Deno.test("assignmentToApi maps assignment row", () => {
  const api = assignmentToApi({
    id: "a1",
    organization_id: ORG,
    school_id: SCHOOL_A,
    student_id: STUDENT,
    fee_structure_id: STRUCTURE,
    academic_year: "2026-27",
    assignment_status: "active",
    assigned_by: STAFF,
    assigned_at: "2026-06-12T00:00:00.000Z",
    created_at: "2026-06-12T00:00:00.000Z",
    updated_at: "2026-06-12T00:00:00.000Z",
    proration_policy: "full_annual",
    proration_basis: "month",
    proration_total_months: 12,
    proration_months_charged: 12,
    proration_reference_date: "2026-04-01",
    proration_annual_amount: "50000",
    proration_charged_amount: "50000",
    proration_fallback_reason: null,
    proration_is_override: false,
    proration_override_reason: null,
    proration_overridden_by: null,
  });
  assertEquals(api.feeStructureId, STRUCTURE);
  const proration = api.proration as Record<string, unknown>;
  assertEquals(proration.policy, "full_annual");
  assertEquals(proration.monthsCharged, 12);
});

Deno.test("manageFinance required for assignment writes", () => {
  assertEquals(requirePermission(schoolClaims(["viewFinance"]), "manageFinance")?.status, 403);
  assertEquals(
    requirePermission(schoolClaims(["viewFinance", "manageFinance"]), "manageFinance"),
    null,
  );
});

Deno.test("non-school scopes denied for finance assignments", () => {
  const orgClaims: AccessTokenClaims = {
    ...schoolClaims(["viewFinance", "manageFinance"]),
    scope: "organization",
    school_id: null,
    role: "organizationAdmin",
    role_slugs: ["organizationAdmin"],
    primary_role: "organizationAdmin",
  };
  assertEquals(requireSchoolOperationalScope(orgClaims)?.status, 403);
});

Deno.test("assignFeeStructure propagates invoice insert failure", async () => {
  const db = new MockAssignmentsDb();
  db.failOnInvoiceInsert = true;
  await assertRejects(
    () => assignFeeStructure(asDb(db), ORG, SCHOOL_A, {
      studentId: STUDENT,
      feeStructureId: STRUCTURE,
      academicYear: "2026-27",
      assignedBy: STAFF,
    }),
    Error,
    "simulated invoice insert failure",
  );
  assertEquals(db.invoices.length, 0);
});

// ─── PRC-A gap fix: bulk/class-wide assignment ─────────────────────────────

Deno.test("bulkAssignFeeStructure assigns every student in the batch, reusing assignFeeStructure", async () => {
  const db = new MockAssignmentsDb();
  const result = await bulkAssignFeeStructure(asDb(db), ORG, SCHOOL_A, {
    feeStructureId: STRUCTURE,
    academicYear: "2026-27",
    studentIds: [STUDENT, STUDENT_2, STUDENT_3],
    assignedBy: STAFF,
  });

  assertEquals(result.total, 3);
  assertEquals(result.assigned.length, 3);
  assertEquals(result.skipped.length, 0);
  // Same invoice/account math as the single-student path — not reimplemented.
  assertEquals(db.assignments.length, 3);
  assertEquals(db.accounts.length, 3);
  assertEquals(db.invoices.length, 3);
  for (const item of result.assigned) {
    assertEquals(item.account.total_fee, "50000");
    assertEquals(item.invoice.invoice_status, "issued");
  }
});

Deno.test("bulkAssignFeeStructure skips an already-assigned duplicate and reports it — the batch is not poisoned, remaining students still assign", async () => {
  const db = new MockAssignmentsDb();
  // STUDENT already has THIS structure for THIS year — a bulk call over a
  // class routinely includes students like this one.
  await assignFeeStructure(asDb(db), ORG, SCHOOL_A, {
    studentId: STUDENT,
    feeStructureId: STRUCTURE,
    academicYear: "2026-27",
    assignedBy: STAFF,
  });
  assertEquals(db.assignments.length, 1);

  const result = await bulkAssignFeeStructure(asDb(db), ORG, SCHOOL_A, {
    feeStructureId: STRUCTURE,
    academicYear: "2026-27",
    studentIds: [STUDENT, STUDENT_2, STUDENT_3],
    assignedBy: STAFF,
  });

  assertEquals(result.total, 3);
  // The duplicate is SKIPPED — not a fatal error for the batch.
  assertEquals(result.skipped.length, 1);
  assertEquals(result.skipped[0]?.studentId, STUDENT);
  assertEquals(result.skipped[0]?.reason, "already_assigned");
  // The remaining two students — after the duplicate — still assigned.
  assertEquals(result.assigned.length, 2);
  assertEquals(
    result.assigned.map((a) => a.assignment.student_id).sort(),
    [STUDENT_2, STUDENT_3].sort(),
  );
  // 1 pre-existing + 2 new = 3 total; the duplicate did not create a 2nd row
  // for STUDENT, and did not stop STUDENT_2/STUDENT_3 from being written.
  assertEquals(db.assignments.length, 3);
  assertEquals(db.accounts.length, 3);
  assertEquals(db.invoices.length, 3);
});

Deno.test("bulkAssignFeeStructure propagates a genuine unexpected error instead of silently skipping it", async () => {
  const db = new MockAssignmentsDb();
  db.failOnInvoiceInsert = true;
  await assertRejects(
    () =>
      bulkAssignFeeStructure(asDb(db), ORG, SCHOOL_A, {
        feeStructureId: STRUCTURE,
        academicYear: "2026-27",
        studentIds: [STUDENT, STUDENT_2],
        assignedBy: STAFF,
      }),
    Error,
    "simulated invoice insert failure",
  );
});

// ─── Cap 73 (owner decision #5) — mid-year admission fee proration ─────────

Deno.test("REGRESSION GUARD: with no finance_settings configured, assignFeeStructure charges the FULL annual amount (today's behaviour, unchanged)", async () => {
  const db = new MockAssignmentsDb();
  // db.financeSettings is null by default — an unconfigured school.
  const result = await assignFeeStructure(asDb(db), ORG, SCHOOL_A, {
    studentId: STUDENT,
    feeStructureId: STRUCTURE,
    academicYear: "2026-27",
    assignedBy: STAFF,
    admissionDate: "2026-09-15", // mid-year — would matter if prorated, but must NOT here
  });
  assertEquals(result.account.total_fee, "50000");
  assertEquals(result.invoice.total_amount, "50000");
  assertEquals(result.assignment.proration_policy, "full_annual");
  assertEquals(result.assignment.proration_is_override, false);
});

Deno.test("prorate_from_admission_month: a mid-year admission charges LESS than the full annual amount, account/invoice reflect the CHARGED (not annual) total", async () => {
  const db = new MockAssignmentsDb();
  db.financeSettings = {
    organization_id: ORG,
    school_id: SCHOOL_A,
    settings: { [PRORATION_SETTING_KEY]: "prorate_from_admission_month" },
  };
  const result = await assignFeeStructure(asDb(db), ORG, SCHOOL_A, {
    studentId: STUDENT,
    feeStructureId: STRUCTURE,
    academicYear: "2026-27",
    assignedBy: STAFF,
    admissionDate: "2026-10-01", // 7th of 12 months (April=1 .. October=7)
  });
  assertEquals(result.assignment.proration_policy, "prorate_from_admission_month");
  assertEquals(result.assignment.proration_total_months, 12);
  assertEquals(result.assignment.proration_months_charged, 6); // Oct..Mar inclusive = 6
  const charged = Number(result.account.total_fee);
  assertEquals(charged < 50000, true);
  assertEquals(charged > 0, true);
  // Invoice + account both carry the CHARGED total, never the raw annual one.
  assertEquals(result.invoice.total_amount, result.account.total_fee);
  assertEquals(result.invoice.outstanding_amount, result.account.total_fee);
  // The assignment row records BOTH the annual reference and the charged
  // amount so a user can see how the charge was derived.
  assertEquals(result.assignment.proration_annual_amount, "50000");
  assertEquals(result.assignment.proration_charged_amount, result.account.total_fee);
});

Deno.test("prorate_from_admission_month: admission in the FIRST month charges the full annual amount", async () => {
  const db = new MockAssignmentsDb();
  db.financeSettings = {
    settings: { [PRORATION_SETTING_KEY]: "prorate_from_admission_month" },
  };
  const result = await assignFeeStructure(asDb(db), ORG, SCHOOL_A, {
    studentId: STUDENT,
    feeStructureId: STRUCTURE,
    academicYear: "2026-27",
    assignedBy: STAFF,
    admissionDate: "2026-04-05",
  });
  assertEquals(result.assignment.proration_months_charged, 12);
  assertEquals(result.account.total_fee, "50000");
});

Deno.test("prorate_from_admission_month: admission in the LAST month charges roughly one month's share", async () => {
  const db = new MockAssignmentsDb();
  db.financeSettings = {
    settings: { [PRORATION_SETTING_KEY]: "prorate_from_admission_month" },
  };
  const result = await assignFeeStructure(asDb(db), ORG, SCHOOL_A, {
    studentId: STUDENT,
    feeStructureId: STRUCTURE,
    academicYear: "2026-27",
    assignedBy: STAFF,
    admissionDate: "2027-03-20",
  });
  assertEquals(result.assignment.proration_months_charged, 1);
  const charged = Number(result.account.total_fee);
  assertEquals(charged > 0 && charged < 50000 / 11, true);
});

Deno.test("prorate_from_admission_month: admission BEFORE the academic year start still charges the full year", async () => {
  const db = new MockAssignmentsDb();
  db.financeSettings = {
    settings: { [PRORATION_SETTING_KEY]: "prorate_from_admission_month" },
  };
  const result = await assignFeeStructure(asDb(db), ORG, SCHOOL_A, {
    studentId: STUDENT,
    feeStructureId: STRUCTURE,
    academicYear: "2026-27",
    assignedBy: STAFF,
    admissionDate: "2026-01-01",
  });
  assertEquals(result.assignment.proration_months_charged, 12);
  assertEquals(result.account.total_fee, "50000");
});

Deno.test("prorate_from_admission_month: admission AFTER the academic year end still charges a minimum of one month", async () => {
  const db = new MockAssignmentsDb();
  db.financeSettings = {
    settings: { [PRORATION_SETTING_KEY]: "prorate_from_admission_month" },
  };
  const result = await assignFeeStructure(asDb(db), ORG, SCHOOL_A, {
    studentId: STUDENT,
    feeStructureId: STRUCTURE,
    academicYear: "2026-27",
    assignedBy: STAFF,
    admissionDate: "2027-08-01",
  });
  assertEquals(result.assignment.proration_months_charged, 1);
  assertEquals(Number(result.account.total_fee) > 0, true);
});

Deno.test("prorate configured but the fee structure has NO resolvable academic year: falls back to full_annual, not a guess", async () => {
  const db = new MockAssignmentsDb();
  db.financeSettings = {
    settings: { [PRORATION_SETTING_KEY]: "prorate_from_admission_month" },
  };
  // Legacy/unbound structure with no academic_year_id (pre-cap-73 data shape).
  db.structures.push({
    id: "b7000000-0000-4000-8000-000000000077",
    name: "Legacy Structure",
    academic_year: "2026-27",
    academic_year_id: null,
    class_id: null,
    section_id: null,
    status: "active",
  });
  db.items.push({
    fee_structure_id: "b7000000-0000-4000-8000-000000000077",
    amount: "30000",
    organization_id: ORG,
    school_id: SCHOOL_A,
  });
  const result = await assignFeeStructure(asDb(db), ORG, SCHOOL_A, {
    studentId: STUDENT,
    feeStructureId: "b7000000-0000-4000-8000-000000000077",
    academicYear: "2026-27",
    assignedBy: STAFF,
    admissionDate: "2026-10-01",
  });
  assertEquals(result.assignment.proration_policy, "full_annual");
  assertEquals(result.assignment.proration_fallback_reason, "academic_year_bounds_unavailable");
  assertEquals(result.account.total_fee, "30000");
});

Deno.test("proration override: a policy override WITHOUT a reason is rejected", async () => {
  const db = new MockAssignmentsDb();
  await assertRejects(
    () =>
      assignFeeStructure(asDb(db), ORG, SCHOOL_A, {
        studentId: STUDENT,
        feeStructureId: STRUCTURE,
        academicYear: "2026-27",
        assignedBy: STAFF,
        prorationPolicyOverride: "prorate_from_admission_month",
      }),
    FeeProrationOverrideReasonRequiredError,
  );
  assertEquals(db.assignments.length, 0);
});

Deno.test("proration override: WITH a reason, overrides the school's configured policy and records actor/reason for audit", async () => {
  const db = new MockAssignmentsDb();
  // School is configured full_annual...
  db.financeSettings = { settings: { [PRORATION_SETTING_KEY]: "full_annual" } };
  // ...but an authorized user overrides to prorate for THIS one assignment.
  const result = await assignFeeStructure(asDb(db), ORG, SCHOOL_A, {
    studentId: STUDENT,
    feeStructureId: STRUCTURE,
    academicYear: "2026-27",
    assignedBy: STAFF,
    admissionDate: "2027-03-15",
    prorationPolicyOverride: "prorate_from_admission_month",
    prorationOverrideReason: "Owner-approved exception, ticket FIN-9001",
  });
  assertEquals(result.assignment.proration_policy, "prorate_from_admission_month");
  assertEquals(result.assignment.proration_is_override, true);
  assertEquals(result.assignment.proration_override_reason, "Owner-approved exception, ticket FIN-9001");
  // Actor (who performed/authorized the override) + when (assigned_at) are
  // already on the row.
  assertEquals(result.assignment.proration_overridden_by, STAFF);
  assertEquals(result.assignment.assigned_by, STAFF);
  assertEquals(result.assignment.assigned_at, "2026-06-12T00:00:00.000Z");
});

Deno.test("proration override: choosing the SAME policy the school already has configured is NOT flagged as an override", async () => {
  const db = new MockAssignmentsDb();
  db.financeSettings = { settings: { [PRORATION_SETTING_KEY]: "full_annual" } };
  const result = await assignFeeStructure(asDb(db), ORG, SCHOOL_A, {
    studentId: STUDENT,
    feeStructureId: STRUCTURE,
    academicYear: "2026-27",
    assignedBy: STAFF,
    prorationPolicyOverride: "full_annual",
    prorationOverrideReason: "not actually a change",
  });
  assertEquals(result.assignment.proration_is_override, false);
  assertEquals(result.assignment.proration_overridden_by, null);
});

Deno.test("idempotency: a duplicate assignment is STILL rejected with proration wiring in place", async () => {
  const db = new MockAssignmentsDb();
  db.financeSettings = { settings: { [PRORATION_SETTING_KEY]: "prorate_from_admission_month" } };
  const input = {
    studentId: STUDENT,
    feeStructureId: STRUCTURE,
    academicYear: "2026-27",
    assignedBy: STAFF,
    admissionDate: "2026-10-01",
  };
  await assignFeeStructure(asDb(db), ORG, SCHOOL_A, input);
  await assertRejects(
    () => assignFeeStructure(asDb(db), ORG, SCHOOL_A, input),
    DuplicateAssignmentError,
  );
  assertEquals(db.assignments.length, 1);
});

Deno.test("bulkAssignFeeStructure applies the SAME proration uniformly across the whole batch", async () => {
  const db = new MockAssignmentsDb();
  db.financeSettings = { settings: { [PRORATION_SETTING_KEY]: "prorate_from_admission_month" } };
  const result = await bulkAssignFeeStructure(asDb(db), ORG, SCHOOL_A, {
    feeStructureId: STRUCTURE,
    academicYear: "2026-27",
    studentIds: [STUDENT, STUDENT_2, STUDENT_3],
    assignedBy: STAFF,
    admissionDate: "2027-03-20", // last month => ~1 month charged
  });
  assertEquals(result.assigned.length, 3);
  const chargedAmounts = result.assigned.map((a) => a.account.total_fee);
  // Every student in the batch gets the IDENTICAL prorated charge.
  assertEquals(new Set(chargedAmounts).size, 1);
  for (const assigned of result.assigned) {
    assertEquals(assigned.assignment.proration_months_charged, 1);
    assertEquals(Number(assigned.account.total_fee) < 50000, true);
  }
});

// ─── Cap 67 — bulk-assign resolves students FROM a bound class/section ─────

Deno.test("resolveStudentIdsForBoundStructure returns current, active students of the bound class/section", async () => {
  const db = new MockAssignmentsDb();
  db.structures[0]!.class_id = CLASS_A;
  db.structures[0]!.section_id = SECTION_A;
  db.enrollments = [
    { student_id: STUDENT, class_id: CLASS_A, section_id: SECTION_A, is_current: true },
    { student_id: STUDENT_2, class_id: CLASS_A, section_id: SECTION_A, is_current: true },
    // Different section — excluded.
    { student_id: STUDENT_3, class_id: CLASS_A, section_id: "other-section", is_current: true },
  ];
  const ids = await resolveStudentIdsForBoundStructure(asDb(db), ORG, SCHOOL_A, STRUCTURE);
  assertEquals(ids.sort(), [STUDENT, STUDENT_2].sort());
});

Deno.test("resolveStudentIdsForBoundStructure excludes stale (non-current) enrollments and inactive students", async () => {
  const db = new MockAssignmentsDb();
  db.structures[0]!.class_id = CLASS_A;
  db.students.push({ id: "a4000000-0000-4000-8000-000000000009", display_name: "Transferred Out", status: "transferred" });
  db.enrollments = [
    { student_id: STUDENT, class_id: CLASS_A, section_id: null, is_current: true },
    // Stale enrollment (student moved sections/classes since).
    { student_id: STUDENT_2, class_id: CLASS_A, section_id: null, is_current: false },
    // Enrolled in the class but the student record itself isn't active.
    { student_id: "a4000000-0000-4000-8000-000000000009", class_id: CLASS_A, section_id: null, is_current: true },
  ];
  const ids = await resolveStudentIdsForBoundStructure(asDb(db), ORG, SCHOOL_A, STRUCTURE);
  assertEquals(ids, [STUDENT]);
});

Deno.test("resolveStudentIdsForBoundStructure throws FeeStructureNotBoundError for an unbound structure", async () => {
  const db = new MockAssignmentsDb();
  await assertRejects(
    () => resolveStudentIdsForBoundStructure(asDb(db), ORG, SCHOOL_A, STRUCTURE),
    FeeStructureNotBoundError,
  );
});

Deno.test("resolveStudentIdsForBoundStructure still throws not-found for a missing structure id", async () => {
  const db = new MockAssignmentsDb();
  await assertRejects(
    () => resolveStudentIdsForBoundStructure(asDb(db), ORG, SCHOOL_A, "missing-structure"),
    Error,
    "Fee structure not found",
  );
});

Deno.test("bulkAssignFeeStructure over auto-resolved ids still works exactly like an explicit list (unbound structure path unaffected)", async () => {
  // An UNBOUND structure's bulk assignment is entirely unaffected by cap 67 —
  // this is the pre-existing explicit-studentIds[] contract, unchanged.
  const db = new MockAssignmentsDb();
  const result = await bulkAssignFeeStructure(asDb(db), ORG, SCHOOL_A, {
    feeStructureId: STRUCTURE,
    academicYear: "2026-27",
    studentIds: [STUDENT, STUDENT_2],
    assignedBy: STAFF,
  });
  assertEquals(result.assigned.length, 2);
});

// ─── ICA-C4 (P1, Performance) — set-based bulk assignment ──────────────────

Deno.test("ICA-C4: a cohort assign creates exactly one linked assignment + account + invoice per student and returns correct counts and money", async () => {
  const db = new MockAssignmentsDb();
  const result = await bulkAssignFeeStructure(asDb(db), ORG, SCHOOL_A, {
    feeStructureId: STRUCTURE,
    academicYear: "2026-27",
    studentIds: [STUDENT, STUDENT_2, STUDENT_3],
    assignedBy: STAFF,
  });

  // Correct counts returned + persisted (one row per student, no fan-out dupes).
  assertEquals(result.total, 3);
  assertEquals(result.assigned.length, 3);
  assertEquals(result.skipped.length, 0);
  assertEquals(db.assignments.length, 3);
  assertEquals(db.accounts.length, 3);
  assertEquals(db.invoices.length, 3);
  assertEquals(new Set(db.assignments.map((a) => a.student_id)).size, 3);

  for (const item of result.assigned) {
    // The account + invoice each hang off THIS student's own new assignment —
    // no cross-wiring in the multi-row INSERT / unnest.
    assertEquals(item.account.fee_assignment_id, item.assignment.id);
    assertEquals(item.invoice.fee_assignment_id, item.assignment.id);
    assertEquals(item.account.student_id, item.assignment.student_id);
    // Money math is identical to the single-assign path (full annual, no proration).
    assertEquals(item.account.total_fee, "50000");
    assertEquals(item.account.outstanding_amount, "50000");
    assertEquals(item.account.amount_paid, "0");
    assertEquals(item.invoice.total_amount, "50000");
    assertEquals(item.invoice.outstanding_amount, "50000");
    assertEquals(item.invoice.invoice_status, "issued");
  }
});

Deno.test("ICA-C4: students who already have the structure are skipped (already_assigned) with NO duplicate rows; the rest still assign", async () => {
  const db = new MockAssignmentsDb();
  // Two of the three students already have THIS structure for THIS year.
  for (const sid of [STUDENT, STUDENT_2]) {
    await assignFeeStructure(asDb(db), ORG, SCHOOL_A, {
      studentId: sid,
      feeStructureId: STRUCTURE,
      academicYear: "2026-27",
      assignedBy: STAFF,
    });
  }
  assertEquals(db.assignments.length, 2);

  const result = await bulkAssignFeeStructure(asDb(db), ORG, SCHOOL_A, {
    feeStructureId: STRUCTURE,
    academicYear: "2026-27",
    studentIds: [STUDENT, STUDENT_2, STUDENT_3],
    assignedBy: STAFF,
  });

  assertEquals(result.total, 3);
  assertEquals(result.skipped.length, 2);
  assertEquals(result.skipped.map((s) => s.studentId).sort(), [STUDENT, STUDENT_2].sort());
  assertEquals(result.skipped.every((s) => s.reason === "already_assigned"), true);
  assertEquals(result.assigned.length, 1);
  assertEquals(result.assigned[0]?.assignment.student_id, STUDENT_3);
  // The two pre-existing students did NOT get a second assignment/account/invoice.
  assertEquals(db.assignments.length, 3);
  assertEquals(db.accounts.length, 3);
  assertEquals(db.invoices.length, 3);
});

Deno.test("ICA-C4: a repeated studentId within ONE call assigns once and skips the repeat as already_assigned", async () => {
  const db = new MockAssignmentsDb();
  const result = await bulkAssignFeeStructure(asDb(db), ORG, SCHOOL_A, {
    feeStructureId: STRUCTURE,
    academicYear: "2026-27",
    studentIds: [STUDENT, STUDENT, STUDENT_2],
    assignedBy: STAFF,
  });
  assertEquals(result.total, 3);
  assertEquals(result.assigned.map((a) => a.assignment.student_id).sort(), [STUDENT, STUDENT_2].sort());
  assertEquals(result.skipped.length, 1);
  assertEquals(result.skipped[0]?.studentId, STUDENT);
  assertEquals(result.skipped[0]?.reason, "already_assigned");
  // Exactly one assignment per distinct student — the repeat created nothing.
  assertEquals(db.assignments.length, 2);
  assertEquals(db.accounts.length, 2);
});

Deno.test("ICA-C4: TRN-9 reuse inside a bulk batch — a student with an existing per-year account is bumped (one account), a fresh student opens a new one", async () => {
  const db = new MockAssignmentsDb();
  const TRANSPORT = "b7000000-0000-4000-8000-000000000099";
  db.structures.push({
    id: TRANSPORT,
    name: "Transport Fee",
    academic_year: "2026-27",
    academic_year_id: ACADEMIC_YEAR_ID,
    class_id: null,
    section_id: null,
    status: "active",
  });
  db.items.push({ fee_structure_id: TRANSPORT, amount: "12000", organization_id: ORG, school_id: SCHOOL_A });

  // STUDENT already has a tuition account for the year.
  await assignFeeStructure(asDb(db), ORG, SCHOOL_A, {
    studentId: STUDENT,
    feeStructureId: STRUCTURE,
    academicYear: "2026-27",
    assignedBy: STAFF,
  });
  assertEquals(db.accounts.length, 1);

  // Bulk-assign the TRANSPORT structure to STUDENT (reuse+bump) and STUDENT_2 (fresh).
  const result = await bulkAssignFeeStructure(asDb(db), ORG, SCHOOL_A, {
    feeStructureId: TRANSPORT,
    academicYear: "2026-27",
    studentIds: [STUDENT, STUDENT_2],
    assignedBy: STAFF,
  });

  assertEquals(result.assigned.length, 2);
  assertEquals(result.skipped.length, 0);
  // STUDENT reused the SAME account (no 2nd account) — STUDENT_2 opened a fresh one.
  assertEquals(db.accounts.length, 2);
  const studentItem = result.assigned.find((a) => a.assignment.student_id === STUDENT)!;
  const student2Item = result.assigned.find((a) => a.assignment.student_id === STUDENT_2)!;
  // STUDENT's shared account now aggregates tuition 50000 + transport 12000.
  assertEquals(studentItem.account.total_fee, "62000");
  assertEquals(studentItem.account.outstanding_amount, "62000");
  assertEquals(studentItem.account.amount_paid, "0");
  // STUDENT_2's brand-new account carries the transport charge only.
  assertEquals(student2Item.account.total_fee, "12000");
  assertEquals(student2Item.account.outstanding_amount, "12000");
  // 1 tuition + 2 transport assignments/invoices.
  assertEquals(db.assignments.length, 3);
  assertEquals(db.invoices.length, 3);
  assertEquals(studentItem.invoice.total_amount, "12000");
  assertEquals(student2Item.invoice.total_amount, "12000");
});

Deno.test("ICA-C4: a concurrent-duplicate unique_violation on the batched account INSERT is handled gracefully — the batch rolls back to its SAVEPOINT and the per-student fallback completes the whole class", async () => {
  const db = new MockAssignmentsDb();
  // Simulate a concurrent writer opening a finance_student_accounts row
  // (UNIQUE(student_id, academic_year)) between our batched read and our
  // batched INSERT — the set-based account INSERT raises 23505.
  db.raceOnBatchAccountInsert = true;

  const result = await bulkAssignFeeStructure(asDb(db), ORG, SCHOOL_A, {
    feeStructureId: STRUCTURE,
    academicYear: "2026-27",
    studentIds: [STUDENT, STUDENT_2, STUDENT_3],
    assignedBy: STAFF,
  });

  // Recovery is transparent: every student still assigned, exactly once, with
  // correct money — no half-written / orphan rows survived the rolled-back
  // fast path (proves the mock's SAVEPOINT/ROLLBACK actually undid them).
  assertEquals(result.total, 3);
  assertEquals(result.assigned.length, 3);
  assertEquals(result.skipped.length, 0);
  assertEquals(db.assignments.length, 3);
  assertEquals(db.accounts.length, 3);
  assertEquals(db.invoices.length, 3);
  assertEquals(new Set(db.assignments.map((a) => a.student_id)).size, 3);
  for (const item of result.assigned) {
    assertEquals(item.account.total_fee, "50000");
    assertEquals(item.account.fee_assignment_id, item.assignment.id);
  }
});

Deno.test("ICA-C4: bulk enrichment resolves student name/admission/class from the latest handoff, falling back to display_name", async () => {
  const db = new MockAssignmentsDb();
  const result = await bulkAssignFeeStructure(asDb(db), ORG, SCHOOL_A, {
    feeStructureId: STRUCTURE,
    academicYear: "2026-27",
    studentIds: [STUDENT, STUDENT_2],
    assignedBy: STAFF,
  });
  const a = result.assigned.find((x) => x.assignment.student_id === STUDENT)!;
  const b = result.assigned.find((x) => x.assignment.student_id === STUDENT_2)!;
  // STUDENT has a handoff fixture → name + admission + class come from it.
  assertEquals(a.studentName, "Probe Student A");
  assertEquals(a.admissionNumber, "ADM-PROBE-A");
  assertEquals(a.classLabel, "5");
  assertEquals(a.feeStructureName, "Probe Structure A");
  // STUDENT_2 has NO handoff → falls back to students.display_name, no admission/class.
  assertEquals(b.studentName, "Probe Student B");
  assertEquals(b.admissionNumber, undefined);
  assertEquals(b.classLabel, undefined);
  assertEquals(b.feeStructureName, "Probe Structure A");
});

Deno.test("ICA-C4: set-based path issues a BOUNDED query set — zero per-student duplicate SELECTs, zero per-student SAVEPOINTs, batched reads/writes run once regardless of class size", async () => {
  function core(log: string[]) {
    return {
      perStudentDupCheck: log.filter((s) =>
        s.includes("SELECT id FROM finance_fee_assignments") && s.includes("student_id = $1")
      ).length,
      perStudentSavepoint: log.filter((s) => s.trim() === "SAVEPOINT bulk_fee_assignment").length,
      batchedDupCheck: log.filter((s) =>
        s.includes("SELECT student_id FROM finance_fee_assignments") && s.includes("= ANY")
      ).length,
      batchedAssignmentInsert: log.filter((s) =>
        s.includes("INSERT INTO finance_fee_assignments") && s.includes("unnest")
      ).length,
      batchedAccountInsert: log.filter((s) =>
        s.includes("INSERT INTO finance_student_accounts") && s.includes("unnest")
      ).length,
    };
  }

  const small = new MockAssignmentsDb();
  await bulkAssignFeeStructure(asDb(small), ORG, SCHOOL_A, {
    feeStructureId: STRUCTURE,
    academicYear: "2026-27",
    studentIds: [STUDENT, STUDENT_2],
    assignedBy: STAFF,
  });

  const large = new MockAssignmentsDb();
  const bigIds: string[] = [];
  for (let i = 1; i <= 8; i++) {
    const id = `a4000000-0000-4000-8000-00000000010${i}`;
    large.students.push({ id, display_name: `Bulk Student ${i}`, status: "active" });
    bigIds.push(id);
  }
  await bulkAssignFeeStructure(asDb(large), ORG, SCHOOL_A, {
    feeStructureId: STRUCTURE,
    academicYear: "2026-27",
    studentIds: bigIds,
    assignedBy: STAFF,
  });

  const s = core(small.queryLog);
  const l = core(large.queryLog);

  // The N+1 storm is gone: NO per-student duplicate SELECT, NO per-student SAVEPOINT.
  assertEquals(s.perStudentDupCheck, 0);
  assertEquals(l.perStudentDupCheck, 0);
  assertEquals(s.perStudentSavepoint, 0);
  assertEquals(l.perStudentSavepoint, 0);
  // The batched read + writes each run EXACTLY ONCE, and do NOT scale with N.
  assertEquals(s.batchedDupCheck, 1);
  assertEquals(l.batchedDupCheck, 1);
  assertEquals(s.batchedAssignmentInsert, 1);
  assertEquals(l.batchedAssignmentInsert, 1);
  assertEquals(s.batchedAccountInsert, 1);
  assertEquals(l.batchedAccountInsert, 1);
});
