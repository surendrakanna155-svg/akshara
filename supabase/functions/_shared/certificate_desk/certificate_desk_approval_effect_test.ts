import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  CertificateRequestNotFoundError,
  CertificateRequestStateError,
} from "./certificate_desk_repository.ts";
import { applyCertificateRequestDecision } from "./certificate_desk_approval_effect.ts";
import { InvalidStudentStatusTransitionError } from "../sis/sis_status_codec.ts";
import { StudentNotFoundError } from "../sis/sis_students_repository.ts";

const ORG = "c1000000-0000-4000-8000-000000000001";
const SCHOOL = "c2000000-0000-4000-8000-000000000001";
const STAFF = "c3000000-0000-4000-8000-000000000001";
const STUDENT = "c4000000-0000-4000-8000-000000000001";

type Row = Record<string, unknown>;

interface RequestSeed {
  id: string;
  status: string;
  certificate_type: string;
  student_id: string;
  purpose: string | null;
}

/**
 * Combines the certificate_desk request-table mock (guarded terminal UPDATEs)
 * with a faithful reproduction of the SIS certificate engine's SQL (the SAME
 * shape as sis_certificates_repository_test.ts's CertMockDb), because
 * applyCertificateRequestDecision calls straight into the REAL
 * issueCertificate / issueTransferCertificate functions — this is the one
 * seam in this module that is genuinely a JOIN-free but multi-table
 * integration, and the fake DB below hand-models every fragment those
 * functions issue.
 */
class DecisionMockDb {
  requests = new Map<string, RequestSeed>();
  students = new Map<string, { id: string; status: string; className?: string; academicYear?: string }>();
  openAccounts = new Map<string, number[]>();
  schoolCode: string | null = "DPSKKP";
  issues: Row[] = [];
  statusUpdates: Array<{ id: string; status: string }> = [];
  tcCounters = new Map<string, number>();

  seedRequest(seed: RequestSeed) {
    this.requests.set(seed.id, seed);
  }
  seedStudent(id: string, status: string, className?: string, academicYear?: string) {
    this.students.set(id, { id, status, className, academicYear });
  }
  seedOpenAccounts(studentId: string, amounts: number[]) {
    this.openAccounts.set(studentId, amounts);
  }

  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    // ── certificate_desk_repository fragments ──────────────────────────
    if (sql.includes("SELECT") && sql.includes("FROM sis_certificate_requests") && sql.includes("WHERE id =")) {
      const r = this.requests.get(String(args[0]));
      if (!r) return [] as T[];
      return [{
        id: r.id,
        organization_id: ORG,
        school_id: SCHOOL,
        student_id: r.student_id,
        certificate_type: r.certificate_type,
        purpose: r.purpose,
        status: r.status,
        requested_by: STAFF,
        requested_by_role: "officeStaff",
        approval_request_id: "appr-1",
        issued_certificate_id: null,
        issue_note: null,
        decided_at: null,
        created_at: "2026-07-15T00:00:00.000Z",
        updated_at: "2026-07-15T00:00:00.000Z",
      }] as T[];
    }
    if (sql.includes("UPDATE sis_certificate_requests") && sql.includes("AND status = 'pending'")) {
      const r = this.requests.get(String(args[0]));
      if (!r || r.status !== "pending") return [] as T[];
      if (sql.includes("status = 'rejected'")) r.status = "rejected";
      else if (sql.includes("status = 'issued'")) r.status = "issued";
      else if (sql.includes("status = 'blocked_dues'")) r.status = "blocked_dues";
      return [{
        id: r.id,
        organization_id: ORG,
        school_id: SCHOOL,
        student_id: r.student_id,
        certificate_type: r.certificate_type,
        purpose: r.purpose,
        status: r.status,
        requested_by: STAFF,
        requested_by_role: "officeStaff",
        approval_request_id: "appr-1",
        issued_certificate_id: args[3] ?? null,
        issue_note: sql.includes("issue_note") ? (args[3] ?? null) : null,
        decided_at: "2026-07-15T01:00:00.000Z",
        created_at: "2026-07-15T00:00:00.000Z",
        updated_at: "2026-07-15T01:00:00.000Z",
      }] as T[];
    }

    // ── SIS certificate engine fragments (mirrors sis_certificates_repository_test.ts) ──
    if (sql.includes("FROM students") && sql.includes("student_code, display_name, status")) {
      const s = this.students.get(String(args[0]));
      if (!s) return [] as T[];
      return [{
        id: s.id,
        organization_id: ORG,
        school_id: SCHOOL,
        student_code: "STU-2026-00001",
        display_name: "Test Student",
        status: s.status,
        created_at: "2026-06-01T00:00:00.000Z",
        updated_at: "2026-06-01T00:00:00.000Z",
      }] as T[];
    }
    if (sql.includes("FROM student_profiles") && sql.includes("date_of_birth::text")) {
      const s = this.students.get(String(args[0]));
      if (!s) return [] as T[];
      return [{
        id: "profile-1",
        student_id: s.id,
        admission_number: "ADM-001",
        public_student_id: "DPSKKP-0001",
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
    if (sql.includes("FROM sis_student_enrollments")) {
      const s = this.students.get(String(args[0]));
      if (!s || s.className === undefined) return [] as T[];
      return [{
        id: "enr-1",
        student_id: s.id,
        academic_year: s.academicYear ?? "2026-2027",
        class_name: s.className,
        section_name: "A",
        roll_number: "12",
        is_current: true,
        created_at: "2026-06-01T00:00:00.000Z",
        updated_at: "2026-06-01T00:00:00.000Z",
      }] as T[];
    }
    if (sql.includes("FROM student_guardians")) {
      return [] as T[];
    }
    if (sql.includes("SELECT name, code FROM schools")) {
      return [{ name: "Delhi Public School", code: this.schoolCode }] as T[];
    }
    if (sql.includes("SUM(outstanding_amount)") && sql.includes("finance_student_accounts")) {
      const amounts = this.openAccounts.get(String(args[2])) ?? [];
      const sum = amounts.reduce((a, b) => a + b, 0);
      return [{ outstanding: String(sum) }] as T[];
    }
    if (sql.includes("FROM finance_student_accounts") && sql.includes("total_fee::text")) {
      return [] as T[]; // no fee-summary fixtures needed for these tests
    }
    if (sql.includes("FROM student_clearance_waivers") && sql.includes("status = 'approved'")) {
      return [] as T[]; // no waiver in these scenarios
    }
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
        issued_at: "2026-07-15T00:00:00.000Z",
      };
      this.issues.push(row);
      return [{
        id: row.id,
        serial_no: row.serial_no,
        reason: row.reason,
        issued_at: row.issued_at,
      }] as T[];
    }
    if (sql.includes("UPDATE students SET") && sql.includes("status = $1")) {
      const s = this.students.get(String(args[1]));
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
}

function client(mock: DecisionMockDb): TenantQueryClient {
  return mock as unknown as TenantQueryClient;
}

// ─── rejected ──────────────────────────────────────────────────────────────

Deno.test("applyCertificateRequestDecision: rejected -> guarded pending -> rejected", async () => {
  const mock = new DecisionMockDb();
  const reqId = "req-1";
  mock.seedRequest({ id: reqId, status: "pending", certificate_type: "bonafide", student_id: STUDENT, purpose: null });

  const result = await applyCertificateRequestDecision(
    client(mock),
    ORG,
    SCHOOL,
    reqId,
    "rejected",
    STAFF,
    "not eligible",
  );

  assertEquals(result, { requestStatus: "rejected", certificateRequestId: reqId });
  assertEquals(mock.requests.get(reqId)?.status, "rejected");
  assertEquals(mock.issues.length, 0, "rejecting never issues a certificate");
});

Deno.test("applyCertificateRequestDecision: unknown request id throws CertificateRequestNotFoundError", async () => {
  const mock = new DecisionMockDb();
  await assertRejects(
    () => applyCertificateRequestDecision(client(mock), ORG, SCHOOL, "missing", "rejected", STAFF, null),
    CertificateRequestNotFoundError,
  );
});

// ─── approved -> issued (simple type) ──────────────────────────────────────

Deno.test("applyCertificateRequestDecision: approved bonafide -> issued, stamps certificateIssueId", async () => {
  const mock = new DecisionMockDb();
  const reqId = "req-2";
  mock.seedRequest({ id: reqId, status: "pending", certificate_type: "bonafide", student_id: STUDENT, purpose: "bank KYC" });
  mock.seedStudent(STUDENT, "active", "Grade 6");

  const result = await applyCertificateRequestDecision(client(mock), ORG, SCHOOL, reqId, "approved", STAFF, null);

  assertEquals(result.requestStatus, "issued");
  assertEquals(result.certificateRequestId, reqId);
  assertEquals(typeof result.certificateIssueId, "string");
  assertEquals("serialNo" in result, false, "a non-transfer issuance never carries a serial");
  assertEquals(mock.issues.length, 1);
  assertEquals(mock.issues[0]?.certificate_type, "bonafide");
  assertEquals(mock.requests.get(reqId)?.status, "issued");
});

Deno.test("applyCertificateRequestDecision: approved 'fee' -> issued through the SIMPLE path (no status change)", async () => {
  const mock = new DecisionMockDb();
  const reqId = "req-fee";
  mock.seedRequest({ id: reqId, status: "pending", certificate_type: "fee", student_id: STUDENT, purpose: "tax filing" });
  mock.seedStudent(STUDENT, "active", "Grade 9", "2026-2027");

  const result = await applyCertificateRequestDecision(client(mock), ORG, SCHOOL, reqId, "approved", STAFF, null);

  assertEquals(result.requestStatus, "issued");
  assertEquals(mock.issues[0]?.certificate_type, "fee");
  assertEquals(mock.statusUpdates.length, 0, "fee issuance never flips student status");
});

// ─── approved -> issued (transfer) ──────────────────────────────────────

Deno.test("applyCertificateRequestDecision: approved transfer with 0 dues -> issued, carries serialNo, flips status", async () => {
  const mock = new DecisionMockDb();
  const reqId = "req-3";
  mock.seedRequest({ id: reqId, status: "pending", certificate_type: "transfer", student_id: STUDENT, purpose: "relocation" });
  mock.seedStudent(STUDENT, "active", "Grade 8", "2026-2027");
  mock.seedOpenAccounts(STUDENT, []);

  const result = await applyCertificateRequestDecision(client(mock), ORG, SCHOOL, reqId, "approved", STAFF, null);

  assertEquals(result.requestStatus, "issued");
  assertEquals(typeof result.serialNo, "string");
  assertEquals((result.serialNo as string).startsWith("TC/DPSKKP/"), true);
  assertEquals(mock.statusUpdates.at(-1)?.status, "transferred");
  assertEquals(mock.requests.get(reqId)?.status, "issued");
});

// ─── approved -> blocked_dues (caught, not rethrown) ─────────────────────

Deno.test("applyCertificateRequestDecision: approved transfer with OUTSTANDING dues -> blocked_dues, NOT thrown (decision still records)", async () => {
  const mock = new DecisionMockDb();
  const reqId = "req-4";
  mock.seedRequest({ id: reqId, status: "pending", certificate_type: "transfer", student_id: STUDENT, purpose: "relocation" });
  mock.seedStudent(STUDENT, "active", "Grade 8");
  mock.seedOpenAccounts(STUDENT, [5000]);

  const result = await applyCertificateRequestDecision(client(mock), ORG, SCHOOL, reqId, "approved", STAFF, null);

  assertEquals(result.requestStatus, "blocked_dues");
  assertEquals(result.issued, false);
  assertEquals(typeof result.note, "string");
  assertEquals((result.note as string).includes("5000"), true);
  assertEquals(mock.requests.get(reqId)?.status, "blocked_dues");
  assertEquals(mock.issues.length, 0, "nothing was issued");
  assertEquals(mock.statusUpdates.length, 0, "the student status was never flipped");
});

// ─── engine failures PROPAGATE (fail closed) — they are the rollback ────────
//
// These MUST NOT be caught. The TC engine throws InvalidStudentStatusTransitionError
// from BOTH before its first write (sis_certificates_repository.ts:471) and AFTER it
// has burned a serial + inserted the issue row (:560, the concurrent-TC guard) — the
// two are indistinguishable by type. Catching the type to report a friendly
// "blocked_dues" would turn the late one's rollback into a COMMIT, leaving a phantom
// TC in the register with a burned serial. So every engine throw propagates and the
// enclosing withTenantContext rolls the whole decision back.

Deno.test("applyCertificateRequestDecision: approved transfer for an ALREADY-transferred student PROPAGATES (never swallowed into blocked_dues)", async () => {
  const mock = new DecisionMockDb();
  const reqId = "req-5";
  mock.seedRequest({ id: reqId, status: "pending", certificate_type: "transfer", student_id: STUDENT, purpose: null });
  mock.seedStudent(STUDENT, "transferred", "Grade 8");
  mock.seedOpenAccounts(STUDENT, []);

  await assertRejects(
    () => applyCertificateRequestDecision(client(mock), ORG, SCHOOL, reqId, "approved", STAFF, null),
    InvalidStudentStatusTransitionError,
  );

  // The request is left untouched: in production the throw rolls the whole
  // transaction back, so it must not have been pre-emptively marked.
  assertEquals(mock.requests.get(reqId)?.status, "pending");
  assertEquals(mock.issues.length, 0, "nothing was issued");
});

Deno.test("applyCertificateRequestDecision: approved for a student that no longer exists PROPAGATES", async () => {
  const mock = new DecisionMockDb();
  const reqId = "req-6";
  mock.seedRequest({ id: reqId, status: "pending", certificate_type: "bonafide", student_id: STUDENT, purpose: null });
  // No seedStudent -> getStudent returns null -> StudentNotFoundError.

  await assertRejects(
    () => applyCertificateRequestDecision(client(mock), ORG, SCHOOL, reqId, "approved", STAFF, null),
    StudentNotFoundError,
  );

  assertEquals(mock.requests.get(reqId)?.status, "pending");
});

// ─── concurrent double-decide (defense in depth) ──────────────────────────

Deno.test("CONCURRENT double-decide on the SAME request: the second call's guarded UPDATE finds it no longer pending and throws", async () => {
  const mock = new DecisionMockDb();
  const reqId = "req-7";
  mock.seedRequest({ id: reqId, status: "pending", certificate_type: "bonafide", student_id: STUDENT, purpose: null });
  mock.seedStudent(STUDENT, "active", "Grade 4");

  const first = await applyCertificateRequestDecision(client(mock), ORG, SCHOOL, reqId, "approved", STAFF, null);
  assertEquals(first.requestStatus, "issued");
  assertEquals(mock.issues.length, 1);

  // A second decide on the SAME request (e.g. a retried decide, or — in
  // production this can only happen if the upstream decideApproval guard on
  // approval_requests were ever bypassed; that guard is the PRIMARY defense —
  // see approval_orchestrator.ts. This test proves certificate_desk's OWN
  // guard is ALSO safe, defense-in-depth, per the file header's "known
  // recurring defect class" note). getCertificateRequestById re-reads the row
  // (status is now 'issued'), so the loser's dispatch proceeds to call the SIS
  // engine again — but markRequestIssued's terminal guard
  // (`AND status = 'pending'`) is what must stop it from EVER being recorded
  // as a second successful decision: it throws CertificateRequestStateError
  // instead of silently no-op'ing or overwriting the first winner.
  //
  // NOTE (fake-DB limitation): this mock does not model the enclosing
  // withTenantContext transaction, so the loser's SIS-engine INSERT (already
  // executed before the guarded UPDATE throws) is NOT rolled back here the way
  // it would be on real Postgres — mock.issues will show 2 rows. In
  // production the throw below rolls back the WHOLE transaction, including
  // that second sis_certificate_issues INSERT, so only one certificate is
  // ever actually issued. This is the same fake-DB caveat documented in
  // sis_certificates_repository_test.ts's own concurrent-TC tests.
  await assertRejects(
    () => applyCertificateRequestDecision(client(mock), ORG, SCHOOL, reqId, "approved", STAFF, null),
    CertificateRequestStateError,
  );
  // The request row itself — the thing THIS module's guard actually protects —
  // never records a second "issued" transition or a second issued_certificate_id.
  assertEquals(mock.requests.get(reqId)?.status, "issued", "still the FIRST winner's status");
});
