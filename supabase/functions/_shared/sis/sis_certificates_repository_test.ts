import {
  assertEquals,
  assertRejects,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { InvalidStudentStatusTransitionError } from "./sis_status_codec.ts";
import { StudentNotFoundError } from "./sis_students_repository.ts";
import {
  formatTcSerial,
  InvalidCertificateTypeError,
  issueCertificate,
  issueTransferCertificate,
  NoDuesPendingError,
  outstandingForStudent,
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

  seedStudent(seed: StudentSeed) {
    this.students.set(seed.id, seed);
  }
  seedOpenAccounts(studentId: string, amounts: number[]) {
    this.openAccounts.set(studentId, amounts);
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
      this.statusUpdates.push({ id: String(args[1]), status: String(args[0]) });
      const s = this.students.get(String(args[1]));
      if (s) s.status = String(args[0]);
      return [] as T[];
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
