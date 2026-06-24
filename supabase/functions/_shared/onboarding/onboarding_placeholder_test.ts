// DB-backed logic tests for first-time student onboarding (Track A).
//
// These exercise the real repository/provisioning code paths (preview duplicate
// detection, masked Aadhaar storage + hash, placeholder generation, rollback,
// idempotency) against a focused in-memory fake of `TenantQueryClient` that
// pattern-matches the exact SQL the code issues. No live Postgres required.

import { assertEquals } from "jsr:@std/assert@1";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  createImportPreview,
  generatePlaceholderStudents,
  rollbackImportJob,
} from "./onboarding_repository.ts";
import {
  createImportedStudent,
  hashAadhaar,
} from "./onboarding_user_provisioning.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const USER = "a3000000-0000-4000-8000-000000000001";

interface StudentRecord {
  id: string;
  organization_id: string;
  school_id: string;
  user_id: string | null;
  student_code: string;
  display_name: string;
  status: string;
  is_placeholder: boolean;
  aadhaar: string | null;
  aadhaar_hash: string | null;
}

interface JobRecord {
  id: string;
  organization_id: string;
  school_id: string;
  import_type: string;
  status: string;
  file_name: string;
  total_rows: number;
  valid_rows: number;
  invalid_rows: number;
  duplicate_rows: number;
  committed_rows: number;
  report: Record<string, unknown>;
  created_at: string;
  updated_at: string;
}

interface RowRecord {
  id: string;
  job_id: string;
  organization_id: string;
  school_id: string;
  row_number: number;
  payload: Record<string, unknown>;
  status: string;
  errors: unknown;
  matched_entity_id: string | null;
  created_entity_id: string | null;
}

/** Minimal in-memory store + SQL pattern matcher for the onboarding code. */
class FakeDb {
  students: StudentRecord[] = [];
  profiles: Array<Record<string, unknown>> = [];
  enrollments: Array<Record<string, unknown>> = [];
  guardians: Array<Record<string, unknown>> = [];
  jobs: JobRecord[] = [];
  rows: RowRecord[] = [];
  private seq = 0;

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

    if (s.startsWith("INSERT INTO onboarding_import_jobs")) {
      const isPlaceholder = s.includes("'student_placeholder'");
      const job: JobRecord = {
        id: this.id("job"),
        organization_id: String(args[0]),
        school_id: String(args[1]),
        import_type: isPlaceholder ? "student_placeholder" : String(args[2]),
        status: isPlaceholder ? "committed" : "draft",
        file_name: String(isPlaceholder ? args[2] : args[3]),
        total_rows: Number(isPlaceholder ? args[3] : args[4]),
        valid_rows: 0,
        invalid_rows: 0,
        duplicate_rows: 0,
        committed_rows: 0,
        report: {},
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
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

    if (
      s.startsWith("UPDATE onboarding_import_jobs SET valid_rows = $2, committed_rows = $2")
    ) {
      const job = this.jobs.find((j) => j.id === args[0])!;
      job.valid_rows = Number(args[1]);
      job.committed_rows = Number(args[1]);
      job.duplicate_rows = Number(args[2]);
      job.report = { ...job.report, ...JSON.parse(String(args[3])) };
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
      // Two shapes:
      //  preview:     (... errors, matched_entity_id) VALUES (... $7=errors, $8=matched)
      //  placeholder: (... errors, created_entity_id) VALUES (... '[]'::jsonb, $7=created)
      const isPreviewShape = s.includes("$7::jsonb, $8");
      const row: RowRecord = {
        id: this.id("row"),
        job_id: String(args[0]),
        organization_id: String(args[1]),
        school_id: String(args[2]),
        row_number: Number(args[3]),
        payload: JSON.parse(String(args[4])),
        status: String(args[5]),
        errors: isPreviewShape ? JSON.parse(String(args[6])) : [],
        matched_entity_id: isPreviewShape ? (args[7] as string | null) ?? null : null,
        created_entity_id: isPreviewShape ? null : (args[6] as string | null) ?? null,
      };
      this.rows.push(row);
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

    // findDuplicateStudent (by admission number) — none in these tests.
    if (s.includes("FROM student_profiles sp INNER JOIN students s")) {
      return [];
    }

    // findStudentByAadhaarHash
    if (s.startsWith("SELECT id FROM students WHERE organization_id = $1 AND school_id = $2 AND aadhaar_hash")) {
      const match = this.students.find((st) =>
        st.organization_id === args[0] && st.school_id === args[1] && st.aadhaar_hash === args[2]
      );
      return match ? [{ id: match.id }] : [];
    }

    // placeholder existence check (by student_code)
    if (s.startsWith("SELECT id FROM students WHERE school_id = $1 AND student_code = $2")) {
      const match = this.students.find((st) =>
        st.school_id === args[0] && st.student_code === args[1]
      );
      return match ? [{ id: match.id }] : [];
    }

    if (s.startsWith("INSERT INTO students")) {
      // Placeholder insert: user_id is the literal NULL (VALUES ($1, $2, NULL ...).
      // Imported insert: user_id is a bind param ($3) and includes aadhaar binds.
      const isPlaceholder = s.includes("VALUES ($1, $2, NULL");
      let rec: StudentRecord;
      if (isPlaceholder) {
        rec = {
          id: this.id("stu"),
          organization_id: String(args[0]),
          school_id: String(args[1]),
          user_id: null,
          student_code: String(args[2]),
          display_name: String(args[3]),
          status: "active",
          is_placeholder: true,
          aadhaar: null,
          aadhaar_hash: null,
        };
      } else {
        rec = {
          id: this.id("stu"),
          organization_id: String(args[0]),
          school_id: String(args[1]),
          user_id: (args[2] as string | null) ?? null,
          student_code: String(args[3]),
          display_name: String(args[4]),
          status: "active",
          is_placeholder: false,
          aadhaar: (args[5] as string | null) ?? null,
          aadhaar_hash: (args[6] as string | null) ?? null,
        };
      }
      // ON CONFLICT DO NOTHING semantics for placeholders.
      if (this.students.some((st) => st.school_id === rec.school_id && st.student_code === rec.student_code)) {
        if (s.includes("ON CONFLICT")) return [];
      }
      this.students.push(rec);
      return [{ id: rec.id }];
    }

    if (s.startsWith("INSERT INTO student_profiles")) {
      this.profiles.push({ student_id: args[0] });
      return [];
    }

    if (s.startsWith("INSERT INTO sis_student_enrollments")) {
      this.enrollments.push({ student_id: args[2] });
      return [];
    }

    if (s.startsWith("INSERT INTO student_guardians")) {
      // Imported students link a guardian; placeholders never reach here.
      this.guardians.push({ student_id: args[2] });
      return [];
    }

    if (s.startsWith("SELECT onboarding_upsert_user_by_phone")) {
      // Placeholder generation must never call this. Imported-student tests in
      // this file pass an explicit parent user id, so they don't hit it either.
      throw new Error("upsertUserByPhone must not be called in these tests");
    }

    if (s.startsWith("DELETE FROM student_guardians")) return [];
    if (s.startsWith("DELETE FROM sis_student_enrollments")) {
      this.enrollments = this.enrollments.filter((e) => e.student_id !== args[0]);
      return [];
    }
    if (s.startsWith("DELETE FROM student_profiles")) {
      this.profiles = this.profiles.filter((p) => p.student_id !== args[0]);
      return [];
    }
    if (s.startsWith("DELETE FROM students")) {
      this.students = this.students.filter((st) => st.id !== args[0]);
      return [];
    }

    throw new Error(`Unhandled SQL in FakeDb: ${s.slice(0, 80)}`);
  }
}

Deno.test("preview flags duplicate Aadhaar within the same file", async () => {
  const fake = new FakeDb();
  const base = {
    classLabel: "5",
    sectionLabel: "A",
    academicYear: "2026-27",
    parentName: "Parent",
    parentPhone: "9876500001",
  };
  const { preview } = await createImportPreview(
    fake.client,
    ORG,
    SCHOOL,
    USER,
    "student",
    "students.csv",
    [
      { ...base, studentName: "A", admissionNumber: "ADM-1", aadhaar: "111122223333" },
      { ...base, studentName: "B", admissionNumber: "ADM-2", aadhaar: "1111 2222 3333" },
    ],
  );
  assertEquals(preview[0]?.status, "valid");
  assertEquals(preview[1]?.status, "duplicate");
  assertEquals((preview[1]?.errors as string[]).includes("duplicate Aadhaar"), true);
});

Deno.test("preview flags Aadhaar that already exists on a student", async () => {
  const fake = new FakeDb();
  fake.students.push({
    id: "stu-existing",
    organization_id: ORG,
    school_id: SCHOOL,
    user_id: null,
    student_code: "OLD-1",
    display_name: "Existing",
    status: "active",
    is_placeholder: false,
    aadhaar: "XXXXXXXX3333",
    aadhaar_hash: await hashAadhaar("111122223333"),
  });

  const { preview } = await createImportPreview(
    fake.client,
    ORG,
    SCHOOL,
    USER,
    "student",
    "students.csv",
    [{
      studentName: "Dup",
      admissionNumber: "ADM-9",
      classLabel: "5",
      sectionLabel: "A",
      academicYear: "2026-27",
      parentName: "Parent",
      parentPhone: "9876500001",
      aadhaar: "111122223333",
    }],
  );
  assertEquals(preview[0]?.status, "duplicate");
  assertEquals(preview[0]?.matchedEntityId, "stu-existing");
  assertEquals((preview[0]?.errors as string[]).includes("duplicate Aadhaar"), true);
});

Deno.test("createImportedStudent stores masked Aadhaar + hash, never raw", async () => {
  const fake = new FakeDb();
  await createImportedStudent(
    fake.client,
    ORG,
    SCHOOL,
    {
      studentName: "Ravi",
      admissionNumber: "ADM-1",
      classLabel: "5",
      sectionLabel: "A",
      academicYear: "2026-27",
      parentName: "Parent",
      parentPhone: "9876500001",
      aadhaar: "123456789012",
    },
    "parent-user",
    null,
  );
  const student = fake.students[0]!;
  assertEquals(student.aadhaar, "XXXXXXXX9012");
  assertEquals(student.aadhaar_hash, await hashAadhaar("123456789012"));
  assertEquals(student.aadhaar?.includes("12345678"), false);
});

Deno.test("generatePlaceholderStudents creates correct count, placeholders, no parent", async () => {
  const fake = new FakeDb();
  const { job, generatedCount } = await generatePlaceholderStudents(
    fake.client,
    ORG,
    SCHOOL,
    USER,
    {
      academicYear: "2026-27",
      classes: [
        { classLabel: "Grade 6", sections: [{ sectionLabel: "A", studentCount: 2 }] },
        { classLabel: "Grade 7", sections: [{ sectionLabel: "B", studentCount: 1 }] },
      ],
    },
  );
  assertEquals(generatedCount, 3);
  assertEquals(job.import_type, "student_placeholder");
  assertEquals(job.committed_rows, 3);
  assertEquals(fake.students.length, 3);
  assertEquals(fake.students.every((st) => st.is_placeholder), true);
  assertEquals(fake.students.every((st) => st.user_id === null), true);
  assertEquals(fake.students[0]?.display_name, "Grade 6A — Roll 1");
  assertEquals(fake.students[0]?.student_code, "PH-Grade6-A-1");
});

Deno.test("generatePlaceholderStudents is idempotent (re-run creates no duplicates)", async () => {
  const fake = new FakeDb();
  const input = {
    academicYear: "2026-27",
    classes: [{ classLabel: "Grade 6", sections: [{ sectionLabel: "A", studentCount: 2 }] }],
  };
  const first = await generatePlaceholderStudents(fake.client, ORG, SCHOOL, USER, input);
  assertEquals(first.generatedCount, 2);

  const second = await generatePlaceholderStudents(fake.client, ORG, SCHOOL, USER, input);
  assertEquals(second.generatedCount, 0);
  assertEquals(fake.students.length, 2);
});

Deno.test("placeholder generation is rollbackable via rollbackImportJob", async () => {
  const fake = new FakeDb();
  const { job } = await generatePlaceholderStudents(
    fake.client,
    ORG,
    SCHOOL,
    USER,
    {
      academicYear: "2026-27",
      classes: [{ classLabel: "Grade 6", sections: [{ sectionLabel: "A", studentCount: 3 }] }],
    },
  );
  assertEquals(fake.students.length, 3);

  const rolledBack = await rollbackImportJob(fake.client, ORG, SCHOOL, job.id);
  assertEquals(rolledBack.status, "rolled_back");
  assertEquals(fake.students.length, 0);
  assertEquals(fake.enrollments.length, 0);
  assertEquals(fake.profiles.length, 0);
});
