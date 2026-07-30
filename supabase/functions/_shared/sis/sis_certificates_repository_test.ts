import {
  assertEquals,
  assertRejects,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { InvalidStudentStatusTransitionError } from "./sis_status_codec.ts";
import { StudentNotFoundError } from "./sis_students_repository.ts";
import {
  certificateDataToApi,
  formatTcSerial,
  InvalidCertificateTypeError,
  issueCertificate,
  issueTransferCertificate,
  NoDuesPendingError,
  outstandingForStudent,
  SIMPLE_CERTIFICATE_TYPES,
  TC_FINANCE_CLEARANCE_STATEMENT,
} from "./sis_certificates_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const STAFF = "a3000000-0000-4000-8000-000000000001";
const STUDENT = "a4000000-0000-4000-8000-000000000001";
const MISSING = "a4000000-0000-4000-8000-0000000000ff";

type Row = Record<string, unknown>;

interface StudentSeed {
  id: string;
  status: string; // DB status: active|inactive|alumni|transferred
  displayName?: string;
  admissionNumber?: string;
  publicStudentId?: string;
  className?: string;
  sectionName?: string | null;
  academicYear?: string;
  guardianName?: string;
}

interface FeeAccountSeed {
  academicYear: string;
  totalFee: number;
  amountPaid: number;
  outstandingAmount: number;
  status: string;
}

/**
 * Faithful in-memory model of the exact SQL the certificates repository issues.
 * Reproduces: getStudent's three SELECTs (students / student_profiles /
 * sis_student_enrollments / student_guardians), the schools lookup, the
 * finance_student_accounts open-dues SUM, the school_tc_counters ON CONFLICT
 * arithmetic (mirrors allocatePublicStudentId), the certificate-issue INSERT,
 * and the students status UPDATE. This lets the tests prove the whole TC engine
 * end-to-end without a live DB.
 */
class CertMockDb {
  students = new Map<string, StudentSeed>();
  // student_id -> array of open account outstanding amounts.
  openAccounts = new Map<string, number[]>();
  schoolCode: string | null = "DPSKKP";
  schoolName: string | null = "Delhi Public School";
  tcCounters = new Map<string, number>();
  issues: Row[] = [];
  statusUpdates: Array<{ id: string; status: string }> = [];
  // SCE-1 slice 3: student_id -> an approved waiver's covered amount (or absent).
  approvedWaivers = new Map<string, number>();
  waiverConsumed: Array<{ studentId: string; issueId: string }> = [];
  clearanceSnapshots: Array<{ issueId: string; amount: number; waiverId: string | null }> = [];
  // "fee" certificate — student_id -> per-academic-year finance_student_accounts rows.
  feeAccounts = new Map<string, FeeAccountSeed[]>();
  // PRA-P1-20: student_code -> library obligations (un-waived fines + unreturned books).
  libraryDues = new Map<string, { fine: number; unreturned: number }>();

  seedStudent(seed: StudentSeed) {
    this.students.set(seed.id, seed);
  }
  seedOpenAccounts(studentId: string, amounts: number[]) {
    this.openAccounts.set(studentId, amounts);
  }
  seedApprovedWaiver(studentId: string, coveredAmount: number) {
    this.approvedWaivers.set(studentId, coveredAmount);
  }
  seedFeeAccount(studentId: string, account: FeeAccountSeed) {
    const existing = this.feeAccounts.get(studentId) ?? [];
    existing.push(account);
    this.feeAccounts.set(studentId, existing);
  }
  seedLibraryDues(studentCode: string, dues: { fine: number; unreturned: number }) {
    this.libraryDues.set(studentCode, dues);
  }

  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    // getStudent — core row
    if (sql.includes("FROM students") && sql.includes("student_code, display_name, status")) {
      const s = this.students.get(String(args[0]));
      if (!s) return [] as T[];
      return [{
        id: s.id,
        organization_id: ORG,
        school_id: SCHOOL,
        student_code: "STU-2026-00001",
        display_name: s.displayName ?? "Test Student",
        status: s.status,
        created_at: "2026-06-01T00:00:00.000Z",
        updated_at: "2026-06-01T00:00:00.000Z",
      }] as T[];
    }
    // getStudent — profile row
    if (sql.includes("FROM student_profiles") && sql.includes("date_of_birth::text")) {
      const s = this.students.get(String(args[0]));
      if (!s) return [] as T[];
      return [{
        id: "profile-1",
        student_id: s.id,
        admission_number: s.admissionNumber ?? "ADM-001",
        public_student_id: s.publicStudentId ?? "DPSKKP-0001",
        date_of_birth: "2010-05-01",
        gender: "male",
        blood_group: null,
        address: null,
        city: null,
        state: null,
        postal_code: null,
        country: null,
        created_at: "2026-06-01T00:00:00.000Z",
        updated_at: "2026-06-01T00:00:00.000Z",
      }] as T[];
    }
    // getStudent — current enrollment
    if (sql.includes("FROM sis_student_enrollments")) {
      const s = this.students.get(String(args[0]));
      if (!s || s.className === undefined) return [] as T[];
      return [{
        id: "enr-1",
        student_id: s.id,
        academic_year: s.academicYear ?? "2026-2027",
        class_name: s.className,
        section_name: s.sectionName ?? "A",
        roll_number: "12",
        is_current: true,
        created_at: "2026-06-01T00:00:00.000Z",
        updated_at: "2026-06-01T00:00:00.000Z",
      }] as T[];
    }
    // getStudent — guardians
    if (sql.includes("FROM student_guardians")) {
      const s = this.students.get(String(args[0]));
      if (!s || !s.guardianName) return [] as T[];
      return [{
        id: "grd-1",
        student_id: s.id,
        guardian_user_id: "usr-g1",
        relationship: "father",
        is_primary: true,
        status: "active",
        display_name: s.guardianName,
        phone: "9999999999",
        email: null,
      }] as T[];
    }
    // schools lookup (name, code)
    if (sql.includes("SELECT name, code FROM schools")) {
      return [{ name: this.schoolName, code: this.schoolCode }] as T[];
    }
    // finance no-dues SUM over OPEN accounts
    if (sql.includes("SUM(outstanding_amount)") && sql.includes("finance_student_accounts")) {
      const amounts = this.openAccounts.get(String(args[2])) ?? [];
      const sum = amounts.reduce((a, b) => a + b, 0);
      return [{ outstanding: String(sum) }] as T[];
    }
    // PRA-P1-20: library dues (fine total + unreturned-book count) keyed by code.
    if (sql.includes("FROM library_entities") && sql.includes("entity_type = 'fine'")) {
      const dues = this.libraryDues.get(String(args[2])) ?? { fine: 0, unreturned: 0 };
      return [{ fine: String(dues.fine), unreturned: String(dues.unreturned) }] as T[];
    }
    // "fee" certificate — single-year finance_student_accounts pull (real data,
    // never fabricated). Preferred-year lookup carries `academic_year = $4`;
    // the fallback (no current enrollment / no row for that year) omits it and
    // picks the most recent account by academic_year.
    if (sql.includes("FROM finance_student_accounts") && sql.includes("total_fee::text")) {
      const accounts = this.feeAccounts.get(String(args[2])) ?? [];
      if (accounts.length === 0) return [] as T[];
      const toRow = (a: FeeAccountSeed) => ({
        academic_year: a.academicYear,
        total_fee: String(a.totalFee),
        amount_paid: String(a.amountPaid),
        outstanding_amount: String(a.outstandingAmount),
        status: a.status,
      });
      if (sql.includes("academic_year = $4")) {
        const match = accounts.find((a) => a.academicYear === String(args[3]));
        return match ? [toRow(match)] as T[] : [] as T[];
      }
      const sorted = [...accounts].sort((a, b) => b.academicYear.localeCompare(a.academicYear));
      return [toRow(sorted[0]!)] as T[];
    }
    // SCE-1 slice 3 — the gate's approved-waiver lookup.
    if (sql.includes("FROM student_clearance_waivers") && sql.includes("status = 'approved'")) {
      const covered = this.approvedWaivers.get(String(args[2]));
      return covered === undefined
        ? [] as T[]
        : [{ id: "waiver-1", blocking_amount: String(covered) }] as T[];
    }
    // SCE-1 slice 3 — consume the covering waiver on issue.
    if (sql.includes("UPDATE student_clearance_waivers") && sql.includes("status = 'consumed'")) {
      this.waiverConsumed.push({ studentId: String(args[2]), issueId: String(args[4]) });
      return [{ id: "waiver-1", status: "consumed" }] as T[];
    }
    // SCE-1 slice 3 — the clearance snapshot onto the issue row.
    if (sql.includes("UPDATE sis_certificate_issues") && sql.includes("clearance_snapshot_amount")) {
      this.clearanceSnapshots.push({
        issueId: String(args[2]),
        amount: Number(args[0]),
        waiverId: args[1] === null ? null : String(args[1]),
      });
      return [] as T[];
    }
    // TC serial ON CONFLICT counter — mirrors allocatePublicStudentId arithmetic
    if (sql.includes("INSERT INTO school_tc_counters")) {
      const key = `${args[0]}|${args[1]}`;
      const current = this.tcCounters.get(key);
      let allocated: number;
      if (current === undefined) {
        this.tcCounters.set(key, 2);
        allocated = 1;
      } else {
        const next = current + 1;
        this.tcCounters.set(key, next);
        allocated = next - 1;
      }
      return [{ allocated }] as T[];
    }
    // certificate issue INSERT
    if (sql.includes("INSERT INTO sis_certificate_issues")) {
      const row = {
        id: crypto.randomUUID(),
        organization_id: args[0],
        school_id: args[1],
        student_id: args[2],
        certificate_type: args[3],
        serial_no: args[4] ?? null,
        reason: args[5] ?? null,
        issued_by: args[6],
        issued_at: "2026-07-03T00:00:00.000Z",
      };
      this.issues.push(row);
      return [{
        id: row.id,
        serial_no: row.serial_no,
        reason: row.reason,
        issued_at: row.issued_at,
      }] as T[];
    }
    // status UPDATE
    if (sql.includes("UPDATE students SET") && sql.includes("status = $1")) {
      const s = this.students.get(String(args[1]));
      // Honor the terminal `AND status = $5` guard: the transition applies only
      // while the student is still in the status we read+validated. A concurrent
      // TC issuance that already flipped it yields zero rows → the repository
      // throws + rolls back, so no duplicate certificate is minted.
      if (!s || s.status !== String(args[4])) return [] as T[];
      this.statusUpdates.push({ id: String(args[1]), status: String(args[0]) });
      s.status = String(args[0]);
      return [{ id: String(args[1]) }] as T[];
    }
    return [] as T[];
  }

  // deno-lint-ignore require-await
  async queryCount(): Promise<number> {
    return 0;
  }

  peekTcCounter(): number | undefined {
    return this.tcCounters.get(`${ORG}|${SCHOOL}`);
  }
}

Deno.test("formatTcSerial: TC/<code>/<year>/<4-digit seq>, zero-padded", () => {
  assertEquals(formatTcSerial("DPSKKP", "2026-2027", 1), "TC/DPSKKP/2026-2027/0001");
  assertEquals(formatTcSerial("DPSKKP", "2026-2027", 42), "TC/DPSKKP/2026-2027/0042");
  // Beyond 4 digits it keeps growing (never-reused > pad).
  assertEquals(formatTcSerial("DPSKKP", "2026-2027", 12345), "TC/DPSKKP/2026-2027/12345");
});

Deno.test("issueCertificate: bonafide is recorded and returns the PDF data", async () => {
  const mock = new CertMockDb();
  mock.seedStudent({
    id: STUDENT,
    status: "active",
    displayName: "Asha Rao",
    admissionNumber: "ADM-77",
    publicStudentId: "DPSKKP-0007",
    className: "Grade 5",
    guardianName: "Ravi Rao",
  });
  const client = mock as unknown as TenantQueryClient;

  const data = await issueCertificate(client, ORG, SCHOOL, {
    studentId: STUDENT,
    type: "bonafide",
    reason: "bank account",
    issuedBy: STAFF,
  });

  // Recorded in the register with NO serial (only TC gets one) and no status change.
  assertEquals(mock.issues.length, 1);
  assertEquals(mock.issues[0]?.certificate_type, "bonafide");
  assertEquals(mock.issues[0]?.serial_no, null);
  assertEquals(mock.statusUpdates.length, 0);
  // Returns the data the client PDF renders.
  assertEquals(data.certificateType, "bonafide");
  assertEquals(data.serialNo, null);
  assertEquals(data.student.displayName, "Asha Rao");
  assertEquals(data.student.admissionNumber, "ADM-77");
  assertEquals(data.student.publicStudentId, "DPSKKP-0007");
  assertEquals(data.student.className, "Grade 5");
  assertEquals(data.student.guardianName, "Ravi Rao");
  assertEquals(data.school.name, "Delhi Public School");
});

Deno.test("issueCertificate: unknown student -> StudentNotFoundError (404)", async () => {
  const mock = new CertMockDb();
  const client = mock as unknown as TenantQueryClient;
  await assertRejects(
    () => issueCertificate(client, ORG, SCHOOL, {
      studentId: MISSING,
      type: "study",
      issuedBy: STAFF,
    }),
    StudentNotFoundError,
  );
  assertEquals(mock.issues.length, 0);
});

Deno.test("issueCertificate: 'transfer' is rejected here (must use the TC engine)", async () => {
  const mock = new CertMockDb();
  mock.seedStudent({ id: STUDENT, status: "active" });
  const client = mock as unknown as TenantQueryClient;
  await assertRejects(
    () => issueCertificate(client, ORG, SCHOOL, {
      studentId: STUDENT,
      type: "transfer",
      issuedBy: STAFF,
    }),
    InvalidCertificateTypeError,
  );
  assertEquals(mock.issues.length, 0);
});

Deno.test("SIMPLE_CERTIFICATE_TYPES includes 'fee' (a plain recorded issuance, no status change)", () => {
  assertEquals(SIMPLE_CERTIFICATE_TYPES.includes("fee"), true);
  assertEquals(SIMPLE_CERTIFICATE_TYPES.includes("transfer"), false);
});

Deno.test("issueCertificate: fee — pulls the REAL finance summary for the current-enrollment academic year", async () => {
  const mock = new CertMockDb();
  mock.seedStudent({
    id: STUDENT,
    status: "active",
    displayName: "Meera Iyer",
    className: "Grade 10",
    academicYear: "2026-2027",
  });
  mock.seedFeeAccount(STUDENT, {
    academicYear: "2026-2027",
    totalFee: 50000,
    amountPaid: 30000,
    outstandingAmount: 20000,
    status: "open",
  });
  // A prior year's account must NOT be picked when the current year matches.
  mock.seedFeeAccount(STUDENT, {
    academicYear: "2025-2026",
    totalFee: 45000,
    amountPaid: 45000,
    outstandingAmount: 0,
    status: "closed",
  });
  const client = mock as unknown as TenantQueryClient;

  const data = await issueCertificate(client, ORG, SCHOOL, {
    studentId: STUDENT,
    type: "fee",
    reason: "income tax filing",
    issuedBy: STAFF,
  });

  // Simple issuance: no serial, no status change.
  assertEquals(mock.issues.length, 1);
  assertEquals(mock.issues[0]?.certificate_type, "fee");
  assertEquals(data.serialNo, null);
  assertEquals(mock.statusUpdates.length, 0);
  // The real finance pull — the CURRENT year's account, not the prior one.
  assertEquals(data.fee, {
    academicYear: "2026-2027",
    totalFee: 50000,
    amountPaid: 30000,
    outstanding: 20000,
    accountStatus: "open",
  });
});

Deno.test("issueCertificate: fee — falls back to the most recent account when there is no current enrollment", async () => {
  const mock = new CertMockDb();
  // No className -> getStudent's enrollment mock returns no current enrollment.
  mock.seedStudent({ id: STUDENT, status: "alumni" });
  mock.seedFeeAccount(STUDENT, {
    academicYear: "2024-2025",
    totalFee: 40000,
    amountPaid: 40000,
    outstandingAmount: 0,
    status: "closed",
  });
  mock.seedFeeAccount(STUDENT, {
    academicYear: "2025-2026",
    totalFee: 42000,
    amountPaid: 42000,
    outstandingAmount: 0,
    status: "closed",
  });
  const client = mock as unknown as TenantQueryClient;

  const data = await issueCertificate(client, ORG, SCHOOL, {
    studentId: STUDENT,
    type: "fee",
    issuedBy: STAFF,
  });

  assertEquals(data.fee?.academicYear, "2025-2026", "picks the most recent account, not the oldest");
  assertEquals(data.fee?.totalFee, 42000);
});

Deno.test("issueCertificate: fee — no finance account at all -> fee is null, NEVER fabricated", async () => {
  const mock = new CertMockDb();
  mock.seedStudent({ id: STUDENT, status: "active", className: "Grade 3", academicYear: "2026-2027" });
  // No seedFeeAccount call at all.
  const client = mock as unknown as TenantQueryClient;

  const data = await issueCertificate(client, ORG, SCHOOL, {
    studentId: STUDENT,
    type: "fee",
    issuedBy: STAFF,
  });

  assertEquals(data.fee, null);
  assertEquals(mock.issues.length, 1, "the certificate is still recorded even with no finance data");
});

Deno.test("issueCertificate: non-fee types never carry a fee summary", async () => {
  const mock = new CertMockDb();
  mock.seedStudent({ id: STUDENT, status: "active", className: "Grade 5" });
  mock.seedFeeAccount(STUDENT, {
    academicYear: "2026-2027",
    totalFee: 10000,
    amountPaid: 10000,
    outstandingAmount: 0,
    status: "closed",
  });
  const client = mock as unknown as TenantQueryClient;

  const data = await issueCertificate(client, ORG, SCHOOL, {
    studentId: STUDENT,
    type: "bonafide",
    issuedBy: STAFF,
  });
  assertEquals(data.fee, null);
});

Deno.test("issueCertificate: an unknown type is a validation error", async () => {
  const mock = new CertMockDb();
  mock.seedStudent({ id: STUDENT, status: "active" });
  const client = mock as unknown as TenantQueryClient;
  await assertRejects(
    () => issueCertificate(client, ORG, SCHOOL, {
      studentId: STUDENT,
      type: "character",
      issuedBy: STAFF,
    }),
    InvalidCertificateTypeError,
  );
});

Deno.test("issueTransferCertificate: 0 dues -> serial allocated + status->transferred", async () => {
  const mock = new CertMockDb();
  mock.seedStudent({
    id: STUDENT,
    status: "active",
    className: "Grade 8",
    academicYear: "2026-2027",
  });
  mock.seedOpenAccounts(STUDENT, []); // no open dues
  const client = mock as unknown as TenantQueryClient;

  const result = await issueTransferCertificate(client, ORG, SCHOOL, {
    studentId: STUDENT,
    reason: "relocation",
    issuedBy: STAFF,
  });

  // First TC of the school is 0001, folded into the TC/<code>/<year>/<seq> format.
  assertEquals(result.serialNo, "TC/DPSKKP/2026-2027/0001");
  assertEquals(result.certificate.serialNo, "TC/DPSKKP/2026-2027/0001");
  // Recorded as a transfer issuance with the serial.
  assertEquals(mock.issues.length, 1);
  assertEquals(mock.issues[0]?.certificate_type, "transfer");
  assertEquals(mock.issues[0]?.serial_no, "TC/DPSKKP/2026-2027/0001");
  // Status auto-set to transferred.
  assertEquals(mock.statusUpdates.length, 1);
  assertEquals(mock.statusUpdates[0]?.status, "transferred");
  assertEquals(result.certificate.student.status, "transferred");
  // Counter advanced to the NEXT value (2 after one alloc).
  assertEquals(mock.peekTcCounter(), 2);
});

Deno.test("issueTransferCertificate: outstanding>0 -> 409 DUES_PENDING, NOTHING written", async () => {
  const mock = new CertMockDb();
  mock.seedStudent({ id: STUDENT, status: "active", className: "Grade 8" });
  // Two open accounts (current + prior year) that sum to a positive balance.
  mock.seedOpenAccounts(STUDENT, [12000, 3000]);
  const client = mock as unknown as TenantQueryClient;

  const error = await assertRejects(
    () => issueTransferCertificate(client, ORG, SCHOOL, {
      studentId: STUDENT,
      reason: "relocation",
      issuedBy: STAFF,
    }),
    NoDuesPendingError,
  );
  // Amount surfaced for the 409 body.
  assertEquals(error.outstanding, 15000);
  assertStringIncludes(error.message, "15000");
  // NO serial burned, NO issue row, NO status change — the gate blocks first.
  assertEquals(mock.peekTcCounter(), undefined);
  assertEquals(mock.issues.length, 0);
  assertEquals(mock.statusUpdates.length, 0);
});

// ── PRA-P1-20: library dues also block the TC (no false "dues cleared") ────────

Deno.test("PRA-P1-20: an unpaid LIBRARY FINE (fees clear) blocks the TC, nothing written", async () => {
  const mock = new CertMockDb();
  mock.seedStudent({ id: STUDENT, status: "active", className: "Grade 8" });
  mock.seedOpenAccounts(STUDENT, []); // fees clear
  mock.seedLibraryDues("STU-2026-00001", { fine: 120, unreturned: 0 });
  const client = mock as unknown as TenantQueryClient;

  const error = await assertRejects(
    () => issueTransferCertificate(client, ORG, SCHOOL, {
      studentId: STUDENT,
      reason: "relocation",
      issuedBy: STAFF,
    }),
    NoDuesPendingError,
  );
  assertEquals(error.libraryFine, 120);
  assertStringIncludes(error.message, "library fines");
  // Gate blocks BEFORE any write — the TC would have lied "dues cleared".
  assertEquals(mock.peekTcCounter(), undefined);
  assertEquals(mock.issues.length, 0);
  assertEquals(mock.statusUpdates.length, 0);
});

Deno.test("PRA-P1-20: an UNRETURNED BOOK (fees + fines clear) blocks the TC", async () => {
  const mock = new CertMockDb();
  mock.seedStudent({ id: STUDENT, status: "active", className: "Grade 8" });
  mock.seedOpenAccounts(STUDENT, []);
  mock.seedLibraryDues("STU-2026-00001", { fine: 0, unreturned: 1 });
  const client = mock as unknown as TenantQueryClient;

  const error = await assertRejects(
    () => issueTransferCertificate(client, ORG, SCHOOL, {
      studentId: STUDENT,
      reason: "relocation",
      issuedBy: STAFF,
    }),
    NoDuesPendingError,
  );
  assertEquals(error.unreturnedBooks, 1);
  assertStringIncludes(error.message, "unreturned library book");
  assertEquals(mock.issues.length, 0);
});

Deno.test("PRA-P1-20: fees + library both clear -> TC issues normally (control)", async () => {
  const mock = new CertMockDb();
  mock.seedStudent({ id: STUDENT, status: "active", className: "Grade 8", academicYear: "2026-2027" });
  mock.seedOpenAccounts(STUDENT, []);
  mock.seedLibraryDues("STU-2026-00001", { fine: 0, unreturned: 0 });
  const client = mock as unknown as TenantQueryClient;

  const result = await issueTransferCertificate(client, ORG, SCHOOL, {
    studentId: STUDENT,
    reason: "relocation",
    issuedBy: STAFF,
  });
  assertEquals(mock.issues.length, 1);
  assertEquals(result.certificate.student.status, "transferred");
});

// ── ICA-H2: the TC asserts ONLY finance clearance, never a blanket "all dues" ──

Deno.test("ICA-H2: an issued TC carries a FINANCE-scoped clearance statement, never 'all dues'", async () => {
  const mock = new CertMockDb();
  mock.seedStudent({ id: STUDENT, status: "active", className: "Grade 8", academicYear: "2026-2027" });
  mock.seedOpenAccounts(STUDENT, []); // finance clear → gate passes
  const client = mock as unknown as TenantQueryClient;

  const result = await issueTransferCertificate(client, ORG, SCHOOL, {
    studentId: STUDENT,
    reason: "relocation",
    issuedBy: STAFF,
  });

  // The statement is present and scoped to the ONLY gate-verified source: finance.
  assertEquals(result.certificate.clearanceStatement, TC_FINANCE_CLEARANCE_STATEMENT);
  assertStringIncludes(result.certificate.clearanceStatement ?? "", "financial dues");
  // It must NOT over-claim clearance of advisory (inventory/library) dues.
  assertEquals(
    (result.certificate.clearanceStatement ?? "").toLowerCase().includes("all dues have been cleared"),
    false,
    "the TC must never assert an unconditional 'all dues have been cleared'",
  );

  // The API projection the client PDF reads carries the same truthful sentence.
  const api = certificateDataToApi(result.certificate);
  assertEquals(api.clearanceStatement, TC_FINANCE_CLEARANCE_STATEMENT);
});

Deno.test("ICA-H2: a non-transfer certificate makes NO dues claim (clearanceStatement null)", async () => {
  const mock = new CertMockDb();
  mock.seedStudent({ id: STUDENT, status: "active", className: "Grade 5" });
  const client = mock as unknown as TenantQueryClient;

  const data = await issueCertificate(client, ORG, SCHOOL, {
    studentId: STUDENT,
    type: "bonafide",
    issuedBy: STAFF,
  });

  assertEquals(data.clearanceStatement, null);
  assertEquals(certificateDataToApi(data).clearanceStatement, null);
});

Deno.test("issueTransferCertificate (SCE-1): a net-zero balance (due offset by a credit) CLEARS — the engine blocks on the authoritative NET, not per-account", async () => {
  const mock = new CertMockDb();
  mock.seedStudent({ id: STUDENT, status: "active", className: "Grade 8" });
  // +5000 owed in one open account, -5000 credit in another → net 0 → clears.
  // (A per-account >0 list would have wrongly blocked on the 5000 line.)
  mock.seedOpenAccounts(STUDENT, [5000, -5000]);
  const client = mock as unknown as TenantQueryClient;

  const result = await issueTransferCertificate(client, ORG, SCHOOL, {
    studentId: STUDENT,
    reason: "relocation",
    issuedBy: STAFF,
  });
  // The TC is issued (net dues are zero): serial burned, status flipped.
  assertEquals(result.serialNo.length > 0, true);
  assertEquals(mock.statusUpdates.at(-1)?.status, "transferred");
});

Deno.test("issueTransferCertificate (SCE-1 slice 3): an APPROVED waiver covering the dues clears the block — TC issued, waiver consumed, decision snapshotted", async () => {
  const mock = new CertMockDb();
  mock.seedStudent({ id: STUDENT, status: "active", className: "Grade 8" });
  mock.seedOpenAccounts(STUDENT, [200]);       // ₹200 blocking dues
  mock.seedApprovedWaiver(STUDENT, 200);        // an approved waiver covering ₹200
  const client = mock as unknown as TenantQueryClient;

  const result = await issueTransferCertificate(client, ORG, SCHOOL, {
    studentId: STUDENT,
    reason: "waived at exit",
    issuedBy: STAFF,
  });

  // The TC issued despite the dues (the waiver covered them).
  assertEquals(result.serialNo.length > 0, true);
  assertEquals(mock.statusUpdates.at(-1)?.status, "transferred");
  // The waiver was consumed (single-use) against this issue.
  assertEquals(mock.waiverConsumed.length, 1);
  assertEquals(mock.waiverConsumed[0].studentId, STUDENT);
  // The clearance decision is snapshotted: the pre-waiver dues + the waiver id.
  assertEquals(mock.clearanceSnapshots.length, 1);
  assertEquals(mock.clearanceSnapshots[0].amount, 200);
  assertEquals(mock.clearanceSnapshots[0].waiverId, "waiver-1");
});

Deno.test("issueTransferCertificate (SCE-1 slice 3): a covering waiver ALREADY CONSUMED by a concurrent issue re-blocks (fail closed, no second TC, no dishonest snapshot)", async () => {
  const mock = new CertMockDb();
  mock.seedStudent({ id: STUDENT, status: "active", className: "Grade 8" });
  mock.seedOpenAccounts(STUDENT, [200]);
  mock.seedApprovedWaiver(STUDENT, 200);
  // Simulate the race: findActiveWaiver still returns the approved row (this txn
  // read before the other committed), but consumeWaiver finds nothing 'approved'
  // to claim (the other txn consumed it) → returns null.
  const raced = {
    // deno-lint-ignore require-await
    async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
      if (sql.includes("UPDATE student_clearance_waivers") && sql.includes("status = 'consumed'")) {
        return [] as T[]; // nothing approved to consume — lost the race
      }
      return mock.queryObject<T>(sql, args);
    },
    queryCount: () => Promise.resolve(0),
  } as unknown as TenantQueryClient;

  const error = await assertRejects(
    () => issueTransferCertificate(raced, ORG, SCHOOL, {
      studentId: STUDENT,
      reason: "waived at exit",
      issuedBy: STAFF,
    }),
    NoDuesPendingError,
  );
  assertEquals(error.outstanding, 200, "re-blocks with the pre-waiver dues");
  // Fail closed: the throw is at the consume step, BEFORE the status flip and
  // snapshot — neither ran. (The serial/issue inserted just before are rolled
  // back by the enclosing withTenantContext txn in production — the mock can't
  // model rollback, so we assert the post-throw steps that provably never ran.)
  assertEquals(mock.statusUpdates.length, 0, "student was NOT flipped to transferred");
  assertEquals(mock.clearanceSnapshots.length, 0, "no dishonest snapshot written");
});

Deno.test("issueTransferCertificate: a concurrent TC on the ZERO-dues path fails closed (RT-10-1 — no duplicate certificate)", async () => {
  const mock = new CertMockDb();
  mock.seedStudent({ id: STUDENT, status: "active", className: "Grade 8" });
  // No open accounts, no waiver → the common no-dues path, where the waiver
  // single-use consume guard does NOT run. Simulate a concurrent TC that already
  // flipped the student to 'transferred' between our read and our write: the
  // terminal `UPDATE students ... AND status = $5` matches 0 rows.
  const raced = {
    // deno-lint-ignore require-await
    async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
      if (sql.includes("UPDATE students SET") && sql.includes("status = $1")) {
        return [] as T[]; // the winner already transferred this student
      }
      return mock.queryObject<T>(sql, args);
    },
    queryCount: () => Promise.resolve(0),
  } as unknown as TenantQueryClient;

  await assertRejects(
    () =>
      issueTransferCertificate(raced, ORG, SCHOOL, {
        studentId: STUDENT,
        reason: "relocation",
        issuedBy: STAFF,
      }),
    InvalidStudentStatusTransitionError,
  );
  // The status flip provably never committed; in production the enclosing
  // withTenantContext txn rolls back the just-inserted issue row + serial, so no
  // second serially-numbered legal document is minted.
  assertEquals(mock.statusUpdates.length, 0, "no second transfer committed");
});

Deno.test("issueTransferCertificate (SCE-1 slice 3): a waiver that NO LONGER covers grown dues does NOT clear — still 409, no write", async () => {
  const mock = new CertMockDb();
  mock.seedStudent({ id: STUDENT, status: "active", className: "Grade 8" });
  mock.seedOpenAccounts(STUDENT, [900]);        // dues grew to ₹900
  mock.seedApprovedWaiver(STUDENT, 200);         // waiver only covers ₹200
  const client = mock as unknown as TenantQueryClient;

  const error = await assertRejects(
    () => issueTransferCertificate(client, ORG, SCHOOL, {
      studentId: STUDENT,
      reason: "relocation",
      issuedBy: STAFF,
    }),
    NoDuesPendingError,
  );
  assertEquals(error.outstanding, 900);
  assertEquals(mock.issues.length, 0);
  assertEquals(mock.waiverConsumed.length, 0);   // an insufficient waiver is NOT consumed
  assertEquals(mock.statusUpdates.length, 0);
});

Deno.test("issueTransferCertificate (SCE-1): 0-dues TC snapshots amount 0 with no waiver", async () => {
  const mock = new CertMockDb();
  mock.seedStudent({ id: STUDENT, status: "active", className: "Grade 8" });
  mock.seedOpenAccounts(STUDENT, []);
  const client = mock as unknown as TenantQueryClient;
  await issueTransferCertificate(client, ORG, SCHOOL, { studentId: STUDENT, issuedBy: STAFF });
  assertEquals(mock.clearanceSnapshots.length, 1);
  assertEquals(mock.clearanceSnapshots[0].amount, 0);
  assertEquals(mock.clearanceSnapshots[0].waiverId, null);
  assertEquals(mock.waiverConsumed.length, 0);
});

Deno.test("issueTransferCertificate (SCE-1): the gate FAILS CLOSED — a finance read error rolls back with NO write, never an un-gated TC", async () => {
  const base = new CertMockDb();
  base.seedStudent({ id: STUDENT, status: "active", className: "Grade 8" });
  // Wrap the mock so the finance no-dues SUM throws (a DB outage on the gate).
  const client = {
    // deno-lint-ignore require-await
    async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
      if (sql.includes("SUM(outstanding_amount)")) throw new Error("finance db unavailable");
      return base.queryObject<T>(sql, args);
    },
    queryCount: () => Promise.resolve(0),
  } as unknown as TenantQueryClient;

  await assertRejects(
    () => issueTransferCertificate(client, ORG, SCHOOL, {
      studentId: STUDENT,
      reason: "relocation",
      issuedBy: STAFF,
    }),
    Error,
    "finance db unavailable",
  );
  // Fail-closed: nothing was written (no serial, no issue row, no status change).
  assertEquals(base.peekTcCounter(), undefined);
  assertEquals(base.issues.length, 0);
  assertEquals(base.statusUpdates.length, 0);
});

Deno.test("issueTransferCertificate: already-transferred student -> status-codec rejection (no write)", async () => {
  const mock = new CertMockDb();
  mock.seedStudent({ id: STUDENT, status: "transferred", className: "Grade 8" });
  mock.seedOpenAccounts(STUDENT, []); // 0 dues, so the gate would pass
  const client = mock as unknown as TenantQueryClient;

  await assertRejects(
    () => issueTransferCertificate(client, ORG, SCHOOL, {
      studentId: STUDENT,
      reason: "duplicate request",
      issuedBy: STAFF,
    }),
    InvalidStudentStatusTransitionError,
  );
  // The transition guard runs BEFORE the serial is allocated — nothing written.
  assertEquals(mock.peekTcCounter(), undefined);
  assertEquals(mock.issues.length, 0);
  assertEquals(mock.statusUpdates.length, 0);
});

Deno.test("issueTransferCertificate: graduated student is also terminal -> rejected", async () => {
  const mock = new CertMockDb();
  mock.seedStudent({ id: STUDENT, status: "alumni", className: "Grade 12" });
  mock.seedOpenAccounts(STUDENT, []);
  const client = mock as unknown as TenantQueryClient;
  await assertRejects(
    () => issueTransferCertificate(client, ORG, SCHOOL, {
      studentId: STUDENT,
      issuedBy: STAFF,
    }),
    InvalidStudentStatusTransitionError,
  );
  assertEquals(mock.issues.length, 0);
});

Deno.test("issueTransferCertificate: serials are sequential and distinct across students", async () => {
  const mock = new CertMockDb();
  const A = "a4000000-0000-4000-8000-00000000000a";
  const B = "a4000000-0000-4000-8000-00000000000b";
  const C = "a4000000-0000-4000-8000-00000000000c";
  for (const id of [A, B, C]) {
    mock.seedStudent({ id, status: "active", className: "Grade 9", academicYear: "2026-2027" });
    mock.seedOpenAccounts(id, []);
  }
  const client = mock as unknown as TenantQueryClient;

  const first = await issueTransferCertificate(client, ORG, SCHOOL, { studentId: A, issuedBy: STAFF });
  const second = await issueTransferCertificate(client, ORG, SCHOOL, { studentId: B, issuedBy: STAFF });
  const third = await issueTransferCertificate(client, ORG, SCHOOL, { studentId: C, issuedBy: STAFF });

  const seen = new Set([first.serialNo, second.serialNo, third.serialNo]);
  assertEquals(seen.size, 3); // all distinct
  assertEquals(first.serialNo, "TC/DPSKKP/2026-2027/0001");
  assertEquals(second.serialNo, "TC/DPSKKP/2026-2027/0002");
  assertEquals(third.serialNo, "TC/DPSKKP/2026-2027/0003");
  assertEquals(mock.peekTcCounter(), 4); // next value to hand out
});

Deno.test("SIS certificates migration: register table, TC counter, RLS + grants present", async () => {
  const migration = await Deno.readTextFile(
    new URL(
      "../../../migrations/20260849000000_sis_certificates.sql",
      import.meta.url,
    ),
  );

  // 1. Immutable issuance register.
  assertStringIncludes(migration, "CREATE TABLE IF NOT EXISTS sis_certificate_issues");
  assertStringIncludes(
    migration,
    "certificate_type IN ('bonafide', 'study', 'conduct', 'transfer')",
  );
  assertStringIncludes(migration, "ALTER TABLE sis_certificate_issues FORCE ROW LEVEL SECURITY");
  assertStringIncludes(migration, "CREATE POLICY sis_certificate_issues_school_scope");
  assertStringIncludes(migration, "app_current_scope() = 'school'");
  // Append-only: SELECT + INSERT only, NO UPDATE/DELETE grant.
  assertStringIncludes(migration, "GRANT SELECT, INSERT ON sis_certificate_issues TO erp_tenant");
  assertEquals(
    migration.includes("UPDATE, DELETE ON sis_certificate_issues"),
    false,
  );
  assertEquals(
    migration.includes("DELETE ON sis_certificate_issues"),
    false,
  );
  // Index (school_id, student_id).
  assertStringIncludes(migration, "sis_certificate_issues (school_id, student_id)");

  // 2. Per-school TC serial counter (mirrors school_public_id_counters).
  assertStringIncludes(migration, "CREATE TABLE IF NOT EXISTS school_tc_counters");
  assertStringIncludes(migration, "next_seq INTEGER NOT NULL DEFAULT 1");
  assertStringIncludes(migration, "PRIMARY KEY (organization_id, school_id)");
  assertStringIncludes(migration, "ALTER TABLE school_tc_counters FORCE ROW LEVEL SECURITY");
  assertStringIncludes(migration, "CREATE POLICY school_tc_counters_school_scope");
  assertStringIncludes(migration, "GRANT SELECT, INSERT, UPDATE ON school_tc_counters TO erp_tenant");
});

Deno.test("outstandingForStudent: sums only open accounts; 0 when none", async () => {
  const mock = new CertMockDb();
  mock.seedOpenAccounts(STUDENT, [1000, 2500]);
  const client = mock as unknown as TenantQueryClient;
  assertEquals(await outstandingForStudent(client, ORG, SCHOOL, STUDENT), 3500);
  // A student with no seeded open accounts owes nothing.
  assertEquals(await outstandingForStudent(client, ORG, SCHOOL, MISSING), 0);
});

Deno.test("issueTransferCertificate: missing school code fails loudly (no partial write)", async () => {
  const mock = new CertMockDb();
  mock.schoolCode = null;
  mock.seedStudent({ id: STUDENT, status: "active", className: "Grade 8" });
  mock.seedOpenAccounts(STUDENT, []);
  const client = mock as unknown as TenantQueryClient;
  await assertRejects(
    () => issueTransferCertificate(client, ORG, SCHOOL, { studentId: STUDENT, issuedBy: STAFF }),
    Error,
    "has no code",
  );
  // The code check runs before the counter/insert — nothing written.
  assertEquals(mock.peekTcCounter(), undefined);
  assertEquals(mock.issues.length, 0);
  assertEquals(mock.statusUpdates.length, 0);
});
