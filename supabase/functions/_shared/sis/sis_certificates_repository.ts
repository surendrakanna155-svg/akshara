// SIS-1 Certificate Issuance + SIS-D1 Transfer-Certificate (TC) engine.
//
// Bonafide / Study / Conduct = a RECORDED ISSUANCE: the certificate data comes
// live from the existing student record; a row is written to the immutable
// sis_certificate_issues register. No status change.
//
// The TRANSFER certificate is the TC engine — ONE transaction, fully audited:
//   1. NO-DUES GATE: sum the student's outstanding across OPEN
//      finance_student_accounts (current + prior years). If > 0, throw
//      NoDuesPendingError (409 DUES_PENDING) and write NOTHING.
//   2. Allocate a per-school SEQUENTIAL TC serial via school_tc_counters
//      (mirrors allocatePublicStudentId EXACTLY — never reused, concurrency-safe).
//   3. INSERT the sis_certificate_issues row (type='transfer', serial_no).
//   4. Auto status -> transferred via the status codec's terminal-transition
//      guard (assertValidStatusTransition).
// The caller (handler) audits sisAudit.transferCertificateIssued and wraps the
// whole thing in a tenant transaction, so any throw rolls the entire unit back.

import type { TenantQueryClient } from "../tenant_db.ts";
import {
  assertValidStatusTransition,
  InvalidStudentStatusTransitionError,
  statusFromDb,
  statusToDb,
} from "./sis_status_codec.ts";
import {
  getStudent,
  StudentNotFoundError,
  type StudentDetailData,
} from "./sis_students_repository.ts";
import { resolveClearanceDecision } from "../clearance/clearance_gate.ts";
import { consumeWaiver } from "../clearance/clearance_waiver_repository.ts";

export type CertificateType = "bonafide" | "study" | "conduct" | "transfer";

/** The non-transfer, self-service certificate types (a plain recorded issuance). */
export const SIMPLE_CERTIFICATE_TYPES: readonly CertificateType[] = [
  "bonafide",
  "study",
  "conduct",
] as const;

const TC_SEQ_PAD = 4;

export class InvalidCertificateTypeError extends Error {
  constructor(type: string) {
    super(
      `Invalid certificate type: ${type}. Expected one of bonafide, study, conduct, transfer.`,
    );
    this.name = "InvalidCertificateTypeError";
  }
}

/**
 * SIS-D1 no-dues gate — the student still has an outstanding balance, so a
 * Transfer Certificate cannot be issued. Carries the amount for the 409 body.
 * Thrown BEFORE any serial is allocated / row is written / status is changed.
 */
export class NoDuesPendingError extends Error {
  readonly outstanding: number;
  constructor(outstanding: number) {
    super(
      `Cannot issue a Transfer Certificate: student has ${outstanding} outstanding in fees. Clear all dues first.`,
    );
    this.name = "NoDuesPendingError";
    this.outstanding = outstanding;
  }
}

export interface CertificateData {
  issueId: string;
  certificateType: CertificateType;
  serialNo: string | null;
  reason: string | null;
  issuedAt: string;
  /** The certificate payload the client PDF renders from. */
  student: {
    studentId: string;
    displayName: string;
    publicStudentId: string | null;
    admissionNumber: string | null;
    dateOfBirth: string | null;
    className: string | null;
    sectionName: string | null;
    academicYear: string | null;
    rollNumber: string | null;
    guardianName: string | null;
    status: string;
  };
  school: {
    schoolId: string;
    name: string | null;
    code: string | null;
  };
}

interface IssueRow {
  id: string;
  serial_no: string | null;
  reason: string | null;
  issued_at: string;
}

interface SchoolRow {
  name: string | null;
  code: string | null;
}

function assertCertificateType(type: string): CertificateType {
  if (
    type === "bonafide" || type === "study" || type === "conduct" ||
    type === "transfer"
  ) {
    return type;
  }
  throw new InvalidCertificateTypeError(type);
}

/** Zero-pads the running sequence and folds in the school code + academic year. */
export function formatTcSerial(
  schoolCode: string,
  academicYear: string,
  seq: number,
): string {
  const year = (academicYear || String(new Date().getUTCFullYear())).trim();
  return `TC/${schoolCode}/${year}/${String(seq).padStart(TC_SEQ_PAD, "0")}`;
}

async function loadSchool(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<SchoolRow> {
  const rows = await db.queryObject<SchoolRow>(
    `SELECT name, code FROM schools WHERE id = $1 AND organization_id = $2`,
    [schoolId, organizationId],
  );
  return rows[0] ?? { name: null, code: null };
}

/**
 * Authoritative no-dues total: the sum of outstanding across the student's OPEN
 * finance_student_accounts (current + all prior years) — the SAME per-year
 * balance the defaulters report reads (finance_defaulters_handlers:
 * status = 'open' AND outstanding_amount > 0). Closed accounts are settled and
 * excluded. Returns a number (0 when the student has no open dues, incl. when
 * they were never assigned any fee).
 */
export async function outstandingForStudent(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
): Promise<number> {
  const rows = await db.queryObject<{ outstanding: string | null }>(
    `SELECT COALESCE(SUM(outstanding_amount), 0)::text AS outstanding
       FROM finance_student_accounts
      WHERE organization_id = $1
        AND school_id = $2
        AND student_id = $3::uuid
        AND status = 'open'`,
    [organizationId, schoolId, studentId],
  );
  return Number(rows[0]?.outstanding ?? 0);
}

/**
 * Atomically allocates the next TC serial for a school and returns the formatted
 * value. Mirrors allocatePublicStudentId EXACTLY: the INSERT ... ON CONFLICT DO
 * UPDATE lands next_seq = 2 on the FIRST allocation (RETURNING next_seq - 1 = 1)
 * and, on conflict, bumps next_seq by one and RETURNS the pre-bump value. The DO
 * UPDATE takes a row-level lock, serializing concurrent allocations for the same
 * (org, school) — every serial DISTINCT, no gaps, never reused. First TC = 0001.
 */
export async function allocateTcSerial(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  schoolCode: string,
  academicYear: string,
): Promise<string> {
  const allocRows = await db.queryObject<{ allocated: number }>(
    `INSERT INTO school_tc_counters (organization_id, school_id, next_seq)
     VALUES ($1, $2, 2)
     ON CONFLICT (organization_id, school_id) DO UPDATE
       SET next_seq = school_tc_counters.next_seq + 1
     RETURNING (school_tc_counters.next_seq - 1) AS allocated`,
    [organizationId, schoolId],
  );
  const allocated = allocRows[0]?.allocated;
  if (allocated == null) {
    throw new Error(
      `TC serial allocation returned no counter value for school ${schoolId}`,
    );
  }
  return formatTcSerial(schoolCode, academicYear, Number(allocated));
}

function buildCertificateData(
  type: CertificateType,
  issued: IssueRow,
  detail: StudentDetailData,
  school: SchoolRow,
): CertificateData {
  const guardianName = detail.guardians.find((g) => g.is_primary)?.display_name ??
    detail.guardians[0]?.display_name ?? null;
  return {
    issueId: issued.id,
    certificateType: type,
    serialNo: issued.serial_no,
    reason: issued.reason,
    issuedAt: issued.issued_at,
    student: {
      studentId: detail.student.id,
      displayName: detail.student.display_name,
      publicStudentId: detail.profile?.public_student_id ?? null,
      admissionNumber: detail.profile?.admission_number ?? null,
      dateOfBirth: detail.profile?.date_of_birth ?? null,
      className: detail.currentEnrollment?.class_name ?? null,
      sectionName: detail.currentEnrollment?.section_name ?? null,
      academicYear: detail.currentEnrollment?.academic_year ?? null,
      rollNumber: detail.currentEnrollment?.roll_number ?? null,
      guardianName,
      status: detail.student.status,
    },
    school: {
      schoolId: schoolId(detail),
      name: school.name,
      code: school.code,
    },
  };
}

function schoolId(detail: StudentDetailData): string {
  return detail.student.school_id;
}

async function insertIssue(
  db: TenantQueryClient,
  organizationId: string,
  school: string,
  studentId: string,
  type: CertificateType,
  serialNo: string | null,
  reason: string | null,
  issuedBy: string,
): Promise<IssueRow> {
  const rows = await db.queryObject<IssueRow>(
    `INSERT INTO sis_certificate_issues (
       organization_id, school_id, student_id, certificate_type,
       serial_no, reason, issued_by
     ) VALUES ($1, $2, $3::uuid, $4, $5, $6, $7::uuid)
     RETURNING id, serial_no, reason, issued_at`,
    [organizationId, school, studentId, type, serialNo, reason, issuedBy],
  );
  return rows[0]!;
}

export interface IssueCertificateInput {
  studentId: string;
  type: CertificateType | string;
  reason?: string | null;
  issuedBy: string;
}

/**
 * SIS-1 — records a bonafide / study / conduct certificate issuance and returns
 * the certificate DATA for the client PDF. Verifies the student is in the
 * caller's org+school (404 otherwise). serial_no is null for these types (they
 * are not sequentially registered — only the TC is). NO status change.
 *
 * Rejects `transfer` here: a transfer certificate MUST go through
 * issueTransferCertificate (the no-dues gate + serial + status change). Callers
 * that pass 'transfer' get an InvalidCertificateTypeError so the gate can never
 * be bypassed via this path.
 */
export async function issueCertificate(
  db: TenantQueryClient,
  organizationId: string,
  schoolIdArg: string,
  input: IssueCertificateInput,
): Promise<CertificateData> {
  const type = assertCertificateType(String(input.type));
  if (type === "transfer") {
    throw new InvalidCertificateTypeError(
      "transfer (use the transfer-certificate engine for a TC)",
    );
  }

  const detail = await getStudent(db, organizationId, schoolIdArg, input.studentId);
  if (!detail) throw new StudentNotFoundError(input.studentId);

  const school = await loadSchool(db, organizationId, schoolIdArg);
  const reason = input.reason?.trim() || null;
  const issued = await insertIssue(
    db,
    organizationId,
    schoolIdArg,
    input.studentId,
    type,
    null,
    reason,
    input.issuedBy,
  );

  return buildCertificateData(type, issued, detail, school);
}

export interface IssueTransferCertificateInput {
  studentId: string;
  reason?: string | null;
  issuedBy: string;
}

export interface TransferCertificateResult {
  certificate: CertificateData;
  serialNo: string;
}

/**
 * SIS-D1 — the Transfer-Certificate engine. Runs as ONE transaction (the caller
 * wraps it in withTenantContext). Order is load-bearing:
 *
 *   1. Load the student (404 if not in org+school).
 *   2. NO-DUES GATE — sum open finance_student_accounts. If > 0, throw
 *      NoDuesPendingError BEFORE anything is written (no serial burned, no row,
 *      no status change). The throw rolls back the (empty-so-far) transaction.
 *   3. Verify 'transferred' is a legal transition from the current status
 *      (assertValidStatusTransition) — an already-terminal student (transferred
 *      /graduated) is rejected BEFORE a serial is allocated.
 *   4. Allocate the sequential TC serial (never reused, concurrency-safe).
 *   5. INSERT the transfer issuance row with the serial.
 *   6. Set students.status -> transferred.
 *
 * The audit (sisAudit.transferCertificateIssued) is emitted by the handler
 * inside the same transaction so a rollback also discards the audit.
 */
export async function issueTransferCertificate(
  db: TenantQueryClient,
  organizationId: string,
  schoolIdArg: string,
  input: IssueTransferCertificateInput,
): Promise<TransferCertificateResult> {
  const detail = await getStudent(db, organizationId, schoolIdArg, input.studentId);
  if (!detail) throw new StudentNotFoundError(input.studentId);

  // 1. NO-DUES GATE — SCE-1: consult the cross-module clearance engine in GATE
  // mode (fails CLOSED on an unreadable blocking source, exactly like the direct
  // finance read it replaces), WITH an approved dues-waiver applied. On the
  // transfer_certificate lifecycle only FINANCE is blocking, and the finance
  // contributor reports the authoritative net — byte-identical to
  // outstandingForStudent — so a student with no dues (and no waiver) behaves
  // EXACTLY as the prior finance-only gate. An APPROVED waiver that still covers
  // the current dues clears the block (maker-checker; slice 3). Blocks before
  // any write; the throw rolls back the empty txn.
  const decision = await resolveClearanceDecision(
    db,
    { organizationId, schoolId: schoolIdArg },
    input.studentId,
    "transfer_certificate",
  );
  if (decision.blocked) {
    throw new NoDuesPendingError(decision.blockingAmount);
  }

  // 2. Status-transition guard — reject an already-terminal student BEFORE we
  // burn a serial. transferred/graduated are terminal per the status codec.
  // assertValidStatusTransition treats transferred->transferred as an allowed
  // no-op, so an ALREADY-transferred/graduated student is caught explicitly
  // here (you cannot re-issue a TC for a student who has already exited).
  const currentApiStatus = statusFromDb(detail.student.status);
  if (currentApiStatus === "transferred" || currentApiStatus === "graduated") {
    throw new InvalidStudentStatusTransitionError(
      `Cannot issue a Transfer Certificate: student is already ${currentApiStatus}.`,
    );
  }
  assertValidStatusTransition(detail.student.status, "transferred");

  // 3. Allocate the sequential TC serial (needs the school code).
  const school = await loadSchool(db, organizationId, schoolIdArg);
  const schoolCode = school.code?.trim();
  if (!schoolCode) {
    throw new Error(
      `Cannot allocate a TC serial: school ${schoolIdArg} has no code.`,
    );
  }
  const academicYear = detail.currentEnrollment?.academic_year ?? "";
  const serialNo = await allocateTcSerial(
    db,
    organizationId,
    schoolIdArg,
    schoolCode,
    academicYear,
  );

  // 4. INSERT the transfer issuance row.
  const reason = input.reason?.trim() || null;
  const issued = await insertIssue(
    db,
    organizationId,
    schoolIdArg,
    input.studentId,
    "transfer",
    serialNo,
    reason,
    input.issuedBy,
  );

  // 4b. SCE-1 — CONSUME the covering waiver (single-use) and SNAPSHOT the
  // clearance decision onto the issue row: the dues that were present at issue
  // and the waiver (if any) that cleared them. Immutable audit of the exit; the
  // snapshot lives inside this same transaction, so a later rollback discards it.
  if (decision.waiver) {
    const consumed = await consumeWaiver(
      db,
      { organizationId, schoolId: schoolIdArg },
      input.studentId,
      "transfer_certificate",
      issued.id,
    );
    // Single-use, race-safe (audit slice-3 P2): if the covering waiver was
    // ALREADY consumed (a concurrent TC issuance beat us to it), it can no
    // longer clear THIS exit — fail closed. The throw rolls back the just-
    // inserted issue row + the allocated serial, so no un-gated second TC and
    // no dishonest snapshot pointing at a waiver another issue already spent.
    if (!consumed) {
      throw new NoDuesPendingError(decision.duesAtGate);
    }
  }
  await db.queryObject(
    `UPDATE sis_certificate_issues
        SET clearance_snapshot_amount = $1, clearance_waiver_id = $2
      WHERE id = $3::uuid AND organization_id = $4 AND school_id = $5`,
    [
      decision.duesAtGate,
      decision.waiver?.id ?? null,
      issued.id,
      organizationId,
      schoolIdArg,
    ],
  );

  // 5. Auto status -> transferred (guard already asserted the transition above).
  // Concurrency guard: pin the write to the status we read+validated in step 2.
  // Two concurrent zero-dues (no-waiver) TC requests would otherwise both burn a
  // serial and both insert a `sis_certificate_issues` row — a duplicate legal
  // document, since the waiver-branch's single-use consume guard doesn't run when
  // there is no waiver. Guarding on the prior status makes the loser match 0 rows
  // (the winner already flipped it) → throw → the enclosing transaction rolls back
  // the issue row + allocated serial. Mirrors the codebase's `WHERE status='...'`
  // atomic-transition pattern (clearance waiver consume, staff-attendance decide).
  const statusUpdated = await db.queryObject<{ id: string }>(
    `UPDATE students SET
        status = $1,
        updated_at = timezone('utc', now())
      WHERE id = $2::uuid AND organization_id = $3 AND school_id = $4
        AND status = $5
      RETURNING id`,
    [statusToDb("transferred"), input.studentId, organizationId, schoolIdArg, detail.student.status],
  );
  if (statusUpdated.length === 0) {
    throw new InvalidStudentStatusTransitionError(
      "Cannot issue a Transfer Certificate: the student status changed concurrently " +
        "(a Transfer Certificate was issued by another request).",
    );
  }

  const updatedDetail: StudentDetailData = {
    ...detail,
    student: { ...detail.student, status: statusToDb("transferred") },
  };

  return {
    certificate: buildCertificateData("transfer", issued, updatedDetail, school),
    serialNo,
  };
}

/** SIS-1 — the issuance register for a student (newest first). */
export async function listCertificateIssues(
  db: TenantQueryClient,
  organizationId: string,
  schoolIdArg: string,
  studentId: string,
): Promise<CertificateIssueRow[]> {
  return await db.queryObject<CertificateIssueRow>(
    `SELECT id, certificate_type, serial_no, reason, issued_by, issued_at
       FROM sis_certificate_issues
      WHERE organization_id = $1 AND school_id = $2 AND student_id = $3::uuid
      ORDER BY issued_at DESC`,
    [organizationId, schoolIdArg, studentId],
  );
}

export interface CertificateIssueRow {
  id: string;
  certificate_type: string;
  serial_no: string | null;
  reason: string | null;
  issued_by: string;
  issued_at: string;
}

export function certificateIssueToApi(
  row: CertificateIssueRow,
): Record<string, unknown> {
  return {
    id: row.id,
    type: row.certificate_type,
    certificateType: row.certificate_type,
    serialNo: row.serial_no ?? "",
    reason: row.reason ?? "",
    issuedBy: row.issued_by,
    issuedAt: row.issued_at,
  };
}

export function certificateDataToApi(
  data: CertificateData,
): Record<string, unknown> {
  return {
    id: data.issueId,
    issueId: data.issueId,
    certificateType: data.certificateType,
    serialNo: data.serialNo ?? "",
    reason: data.reason ?? "",
    issuedAt: data.issuedAt,
    student: {
      studentId: data.student.studentId,
      displayName: data.student.displayName,
      publicStudentId: data.student.publicStudentId ?? "",
      admissionNumber: data.student.admissionNumber ?? "",
      dateOfBirth: data.student.dateOfBirth ?? "",
      className: data.student.className ?? "",
      sectionName: data.student.sectionName ?? "",
      academicYear: data.student.academicYear ?? "",
      rollNumber: data.student.rollNumber ?? "",
      guardianName: data.student.guardianName ?? "",
      status: statusFromDb(data.student.status),
    },
    school: {
      schoolId: data.school.schoolId,
      name: data.school.name ?? "",
      code: data.school.code ?? "",
    },
  };
}
