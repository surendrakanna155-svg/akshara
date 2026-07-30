// QA-X-021 — student bulk-import integrity (round-trip).
//
// RE-SCOPE NOTE: An education/syllabus/marks CSV importer does NOT exist
// (owner-deferred); this re-scopes QA-X-021 to the certified student importer
// in `onboarding_repository.ts` (preview -> commit -> rollback). The broad
// "any-entity bulk importer" variant is DEFERRED and intentionally not tested.
//
// The existing `onboarding_repository_test.ts` covers the pure CSV parser /
// row validators, and `onboarding_placeholder_test.ts` covers preview-dedupe +
// placeholder generation + rollback. NEITHER exercises the full valid+bad-row
// preview -> commit -> rollback ROUND TRIP with the no-partial-commit guarantee,
// which is the integrity property this row asserts.
//
// DB-free: reuses the same in-memory `TenantQueryClient` fake-DB seam those
// tests use — a class that pattern-matches the exact SQL the code issues. No
// live Postgres required.

import { assertEquals } from "jsr:@std/assert@1";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  commitImportJob,
  createImportPreview,
  rollbackImportJob,
} from "./onboarding_repository.ts";

const ORG = "b1000000-0000-4000-8000-000000000001";
const SCHOOL = "b2000000-0000-4000-8000-000000000001";
const USER = "b3000000-0000-4000-8000-000000000001";

interface StudentRecord {
  id: string;
  organization_id: string;
  school_id: string;
  user_id: string | null;
  student_code: string;
  display_name: string;
  admission_number: string;
  aadhaar: string | null;
  aadhaar_hash: string | null;
}

interface JobRecord {
  id: string;
  organization_id: string;
  school_id: string;
  import_type: string;
  status: string;
  total_rows: number;
  valid_rows: number;
  invalid_rows: number;
  duplicate_rows: number;
  committed_rows: number;
  report: Record<string, unknown>;
}

interface RowRecord {
  id: string;
  job_id: string;
  row_number: number;
  payload: Record<string, unknown>;
  status: string;
  errors: unknown;
  matched_entity_id: string | null;
  created_entity_id: string | null;
}

/**
 * In-memory fake `TenantQueryClient` that models just enough of the schema to
 * exercise the preview -> commit -> rollback round trip. SAVEPOINT / RELEASE /
 * ROLLBACK TO SAVEPOINT are no-ops here because the happy-path rows never throw;
 * the no-partial-commit guarantee under test comes from commit only ever
 * SELECTing rows whose preview status is 'valid'.
 */
class ImportFakeDb {
  students: StudentRecord[] = [];
  profiles: Array<{ student_id: string; public_student_id?: unknown }> = [];
  enrollments: Array<{ student_id: string }> = [];
  guardians: Array<{ student_id: string }> = [];
  jobs: JobRecord[] = [];
  rows: RowRecord[] = [];
  // PSID plumbing: per-school code + counter model for allocatePublicStudentId.
  schoolCode: string | null = "IMPSCH";
  counters = new Map<string, number>();
  private seq = 0;

  /** Pre-existing students keyed by admission number (DB-side dedupe source). */
  seedExistingStudent(admissionNumber: string): string {
    const id = this.id("seed");
    this.students.push({
      id,
      organization_id: ORG,
      school_id: SCHOOL,
      user_id: null,
      student_code: admissionNumber,
      display_name: "Existing",
      admission_number: admissionNumber,
      aadhaar: null,
      aadhaar_hash: null,
    });
    this.profiles.push({ student_id: id });
    return id;
  }

  private id(prefix: string): string {
    this.seq++;
    return `${prefix}-${this.seq.toString().padStart(4, "0")}`;
  }

  get client(): TenantQueryClient {
    // deno-lint-ignore no-explicit-any
    return { queryObject: (sql: string, args: unknown[] = []) => this.run(sql, args) } as any;
  }

  // deno-lint-ignore no-explicit-any
  private async run(sql: string, args: unknown[]): Promise<any[]> {
    const s = sql.replace(/\s+/g, " ").trim();

    // Transaction control around each committed row — no-op for the fake.
    if (s.startsWith("SAVEPOINT") || s.startsWith("RELEASE SAVEPOINT") ||
      s.startsWith("ROLLBACK TO SAVEPOINT")) {
      return [];
    }

    if (s.startsWith("SELECT code FROM schools")) {
      return this.schoolCode === null ? [] : [{ code: this.schoolCode }];
    }
    if (s.startsWith("INSERT INTO school_public_id_counters")) {
      const key = `${args[0]}|${args[1]}`;
      const current = this.counters.get(key);
      let allocated: number;
      if (current === undefined) {
        this.counters.set(key, 2);
        allocated = 1;
      } else {
        const next = current + 1;
        this.counters.set(key, next);
        allocated = next - 1;
      }
      return [{ allocated }];
    }

    if (s.startsWith("INSERT INTO onboarding_import_jobs")) {
      const job: JobRecord = {
        id: this.id("job"),
        organization_id: String(args[0]),
        school_id: String(args[1]),
        import_type: String(args[2]),
        status: "draft",
        total_rows: Number(args[4]),
        valid_rows: 0,
        invalid_rows: 0,
        duplicate_rows: 0,
        committed_rows: 0,
        report: {},
      };
      this.jobs.push(job);
      return [structuredClone(job)];
    }

    if (s.startsWith("UPDATE onboarding_import_jobs SET status = 'previewed'")) {
      const job = this.jobs.find((j) => j.id === args[0])!;
      job.status = "previewed";
      job.valid_rows = Number(args[1]);
      job.invalid_rows = Number(args[2]);
      job.duplicate_rows = Number(args[3]);
      return [structuredClone(job)];
    }

    if (s.startsWith("UPDATE onboarding_import_jobs SET status = 'committed'")) {
      const job = this.jobs.find((j) => j.id === args[0])!;
      job.status = "committed";
      job.committed_rows = Number(args[1]);
      job.report = { ...job.report, ...JSON.parse(String(args[2])) };
      return [structuredClone(job)];
    }

    if (s.startsWith("UPDATE onboarding_import_jobs SET status = 'rolled_back'")) {
      const job = this.jobs.find((j) => j.id === args[0])!;
      job.status = "rolled_back";
      return [structuredClone(job)];
    }

    if (s.startsWith("SELECT * FROM onboarding_import_jobs WHERE id = $1")) {
      const job = this.jobs.find((j) =>
        j.id === args[0] && j.organization_id === args[1] && j.school_id === args[2]
      );
      return job ? [structuredClone(job)] : [];
    }

    if (s.startsWith("INSERT INTO onboarding_import_rows")) {
      const row: RowRecord = {
        id: this.id("row"),
        job_id: String(args[0]),
        row_number: Number(args[3]),
        payload: JSON.parse(String(args[4])),
        status: String(args[5]),
        errors: JSON.parse(String(args[6])),
        matched_entity_id: (args[7] as string | null) ?? null,
        created_entity_id: null,
      };
      this.rows.push(row);
      return [];
    }

    // commit: only rows the preview marked 'valid' are loaded for insertion.
    if (s.startsWith("SELECT id, row_number, payload, status FROM onboarding_import_rows")) {
      return this.rows
        .filter((r) => r.job_id === args[0] && r.status === "valid")
        .sort((a, b) => a.row_number - b.row_number)
        .map((r) => ({
          id: r.id,
          row_number: r.row_number,
          payload: r.payload,
          status: r.status,
        }));
    }

    if (s.startsWith("UPDATE onboarding_import_rows SET status = 'committed'")) {
      const row = this.rows.find((r) => r.id === args[0]);
      if (row) {
        row.status = "committed";
        row.created_entity_id = (args[1] as string | null) ?? null;
      }
      return [];
    }

    if (s.startsWith("SELECT id, created_entity_id FROM onboarding_import_rows")) {
      return this.rows
        .filter((r) => r.job_id === args[0] && r.status === "committed")
        .map((r) => ({ id: r.id, created_entity_id: r.created_entity_id }));
    }

    if (s.startsWith("UPDATE onboarding_import_rows SET status = 'rolled_back'")) {
      const row = this.rows.find((r) => r.id === args[0]);
      if (row) row.status = "rolled_back";
      return [];
    }

    // findDuplicateStudent: by admission number against existing students.
    if (s.includes("FROM student_profiles sp INNER JOIN students s")) {
      const admission = args[2];
      const match = this.students.find((st) =>
        st.organization_id === args[0] && st.school_id === args[1] &&
        st.admission_number === admission
      );
      return match ? [{ student_id: match.id }] : [];
    }

    // findStudentByAadhaarHash — none seeded in these tests.
    if (s.startsWith("SELECT id FROM students WHERE organization_id = $1 AND school_id = $2 AND aadhaar_hash")) {
      return [];
    }

    if (s.startsWith("SELECT onboarding_upsert_user_by_phone")) {
      // Deterministic per-phone user id so the same parent maps to one user.
      const phone = String(args[0]);
      return [{ onboarding_upsert_user_by_phone: `user-${phone}` }];
    }

    if (s.startsWith("INSERT INTO students")) {
      // Canonical column order (ICA-F2 single identity writer): organization_id,
      // school_id, student_code, display_name, status, created_by, user_id,
      // is_placeholder, aadhaar, aadhaar_hash.
      const rec: StudentRecord = {
        id: this.id("stu"),
        organization_id: String(args[0]),
        school_id: String(args[1]),
        user_id: (args[6] as string | null) ?? null,
        student_code: String(args[2]),
        display_name: String(args[3]),
        admission_number: "", // filled by the student_profiles insert below
        aadhaar: (args[8] as string | null) ?? null,
        aadhaar_hash: (args[9] as string | null) ?? null,
      };
      this.students.push(rec);
      return [{ id: rec.id }];
    }

    if (s.startsWith("INSERT INTO student_profiles")) {
      // Canonical order: organization_id, school_id, student_id, admission_number,
      // public_student_id, ...
      const studentId = String(args[2]);
      const admission = String(args[3]);
      const st = this.students.find((x) => x.id === studentId);
      if (st) st.admission_number = admission;
      this.profiles.push({ student_id: studentId, public_student_id: args[4] });
      return [];
    }

    if (s.startsWith("INSERT INTO sis_student_enrollments")) {
      this.enrollments.push({ student_id: String(args[2]) });
      return [];
    }

    if (s.startsWith("INSERT INTO student_guardians")) {
      this.guardians.push({ student_id: String(args[2]) });
      return [];
    }

    if (s.startsWith("SELECT onboarding_rollback_student")) {
      const sid = args[0];
      this.guardians = this.guardians.filter((g) => g.student_id !== sid);
      this.enrollments = this.enrollments.filter((e) => e.student_id !== sid);
      this.profiles = this.profiles.filter((p) => p.student_id !== sid);
      this.students = this.students.filter((st) => st.id !== sid);
      return [];
    }

    throw new Error(`Unhandled SQL in ImportFakeDb: ${s.slice(0, 80)}`);
  }
}

const baseRow = {
  classLabel: "5",
  sectionLabel: "A",
  academicYear: "2026-27",
  parentName: "Parent",
  parentPhone: "9876500001",
};

Deno.test("QA-X-021 preview surfaces bad + duplicate rows without committing", async () => {
  const fake = new ImportFakeDb();
  // A student with admission ADM-DUP already exists in the DB.
  fake.seedExistingStudent("ADM-DUP");

  const { job, preview } = await createImportPreview(
    fake.client,
    ORG,
    SCHOOL,
    USER,
    "student",
    "students.csv",
    [
      { ...baseRow, studentName: "Valid One", admissionNumber: "ADM-1" },
      // Missing parentPhone -> validation error -> invalid.
      { studentName: "Bad", admissionNumber: "ADM-2", classLabel: "5", sectionLabel: "A", academicYear: "2026-27", parentName: "P" },
      // Existing admission number -> duplicate (matched to seeded student).
      { ...baseRow, studentName: "Dup", admissionNumber: "ADM-DUP" },
    ],
  );

  assertEquals(preview[0]?.status, "valid");
  assertEquals(preview[1]?.status, "invalid");
  assertEquals((preview[1]?.errors as string[]).length > 0, true);
  assertEquals(preview[2]?.status, "duplicate");
  assertEquals(preview[2]?.matchedEntityId !== null, true);

  // Job counts reflect 1 valid / 1 invalid / 1 duplicate, status = previewed.
  assertEquals(job.status, "previewed");
  assertEquals(job.valid_rows, 1);
  assertEquals(job.invalid_rows, 1);
  assertEquals(job.duplicate_rows, 1);

  // Nothing has been written to students yet beyond the pre-existing seed.
  assertEquals(fake.students.length, 1);
});

Deno.test("QA-X-021 commit inserts only valid rows — no partial commit of bad/dup rows", async () => {
  const fake = new ImportFakeDb();
  fake.seedExistingStudent("ADM-DUP");

  const { job } = await createImportPreview(
    fake.client,
    ORG,
    SCHOOL,
    USER,
    "student",
    "students.csv",
    [
      { ...baseRow, studentName: "Valid One", admissionNumber: "ADM-1" },
      { ...baseRow, studentName: "Valid Two", admissionNumber: "ADM-2" },
      { studentName: "Bad", admissionNumber: "ADM-3", classLabel: "5", sectionLabel: "A", academicYear: "2026-27", parentName: "P" },
      { ...baseRow, studentName: "Dup", admissionNumber: "ADM-DUP" },
    ],
  );

  const committed = await commitImportJob(fake.client, ORG, SCHOOL, job.id);

  assertEquals(committed.status, "committed");
  // Exactly the 2 valid rows are committed — the invalid + duplicate are NOT.
  assertEquals(committed.committed_rows, 2);
  // 1 pre-existing seed + 2 newly imported = 3 students total. The bad/dup
  // rows produced no student rows (no partial commit).
  assertEquals(fake.students.length, 3);
  const newCodes = fake.students.map((st) => st.student_code).sort();
  assertEquals(newCodes.includes("ADM-1"), true);
  assertEquals(newCodes.includes("ADM-2"), true);
  // ADM-3 (invalid) was never inserted.
  assertEquals(fake.students.some((st) => st.student_code === "ADM-3"), false);
  // Each committed student has a profile, enrollment, and a guardian link.
  assertEquals(fake.enrollments.length, 2);
  assertEquals(fake.guardians.length, 2);

  // The committed import rows carry created_entity_id; bad/dup rows do not.
  const committedRows = fake.rows.filter((r) => r.status === "committed");
  assertEquals(committedRows.length, 2);
  assertEquals(committedRows.every((r) => r.created_entity_id !== null), true);
});

Deno.test("QA-X-021 rollback reverses the committed import", async () => {
  const fake = new ImportFakeDb();
  const seedId = fake.seedExistingStudent("ADM-DUP");

  const { job } = await createImportPreview(
    fake.client,
    ORG,
    SCHOOL,
    USER,
    "student",
    "students.csv",
    [
      { ...baseRow, studentName: "Valid One", admissionNumber: "ADM-1" },
      { ...baseRow, studentName: "Valid Two", admissionNumber: "ADM-2" },
    ],
  );
  await commitImportJob(fake.client, ORG, SCHOOL, job.id);
  assertEquals(fake.students.length, 3); // seed + 2 imported

  const rolledBack = await rollbackImportJob(fake.client, ORG, SCHOOL, job.id);
  assertEquals(rolledBack.status, "rolled_back");

  // Only the rows THIS job created are reversed; the pre-existing seed remains.
  assertEquals(fake.students.length, 1);
  assertEquals(fake.students[0]?.id, seedId);
  assertEquals(fake.enrollments.length, 0);
  assertEquals(fake.profiles.length, 1); // only the seed's profile remains
  assertEquals(fake.guardians.length, 0);
});
