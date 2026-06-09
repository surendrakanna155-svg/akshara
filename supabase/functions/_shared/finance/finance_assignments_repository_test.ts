import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import {
  requirePermission,
  requireSchoolOperationalScope,
} from "../permission_middleware.ts";
import { assignmentToApi, studentAccountToApi } from "./finance_mapper.ts";
import {
  DuplicateAssignmentError,
  DuplicateStudentAccountError,
  HandoffNotReadyError,
  assignFeeStructure,
  assignFromHandoff,
  cancelAssignment,
  getStudentAccount,
} from "./finance_assignments_repository.ts";
import type { TenantQueryClient } from "../tenant_db.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";
const STAFF = "a3000000-0000-4000-8000-000000000001";
const STUDENT = "a4000000-0000-4000-8000-000000000001";
const STRUCTURE = "b7000000-0000-4000-8000-000000000001";
const HANDOFF = "b6000000-0000-4000-8000-000000000001";

type Row = Record<string, unknown>;

class MockAssignmentsDb {
  structures = [{ id: STRUCTURE, name: "Probe Structure A", academic_year: "2026-27", status: "active" }];
  items = [{ fee_structure_id: STRUCTURE, amount: "50000", organization_id: ORG, school_id: SCHOOL_A }];
  assignments: Row[] = [];
  accounts: Row[] = [];
  invoices: Row[] = [];
  failOnInvoiceInsert = false;
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
  students = [{ id: STUDENT, display_name: "Probe Student A" }];

  async queryCount(): Promise<number> {
    return this.assignments.length;
  }

  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("FROM finance_fee_structures") && sql.includes("status = 'active'")) {
      const found = this.structures.find((s) => s.id === args[0]);
      return (found ? [{ name: found.name, academic_year: found.academic_year }] : []) as T[];
    }
    if (sql.includes("SUM(amount)")) {
      return [{ total: "50000" }] as T[];
    }
    if (sql.includes("FROM finance_student_accounts") && sql.includes("student_id = $1") && sql.includes("academic_year = $2")) {
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

Deno.test("assignFeeStructure prevents duplicate student account year", async () => {
  const db = new MockAssignmentsDb();
  db.accounts.push({
    id: "existing",
    student_id: STUDENT,
    academic_year: "2026-27",
    organization_id: ORG,
    school_id: SCHOOL_A,
  });
  await assertRejects(
    () => assignFeeStructure(asDb(db), ORG, SCHOOL_A, {
      studentId: STUDENT,
      feeStructureId: STRUCTURE,
      academicYear: "2026-27",
      assignedBy: STAFF,
    }),
    DuplicateStudentAccountError,
  );
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
  });
  assertEquals(api.feeStructureId, STRUCTURE);
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
