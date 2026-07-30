// ICA-F2 — unit tests for the single SIS-owned student identity writer.
//
// These prove the ONE owning service centralises the `students` identity-table
// row and the PSID/`student_profiles` identity row: the canonical column set,
// the never-reused Public Student ID allocation, and the ON CONFLICT reuse used
// by the placeholder / retry idempotency paths. DB-free: an in-memory fake that
// pattern-matches the exact SQL, recording the bind args so the canonical column
// mapping is asserted directly.

import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  allocateAndInsertStudentProfile,
  insertStudentIdentityRow,
} from "./sis_student_identity.ts";
import { SchoolCodeMissingError } from "./sis_public_student_id.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const STUDENT = "a4000000-0000-4000-8000-000000000001";

type Row = Record<string, unknown>;

class IdentityFakeDb {
  students: Row[] = [];
  profiles: Row[] = [];
  schoolCode: string | null = "DPSKKP";
  counters = new Map<string, number>();
  /** When set, the students ON CONFLICT insert is treated as a losing race. */
  studentCodeConflict = false;
  lastStudentArgs: unknown[] = [];
  lastProfileArgs: unknown[] = [];

  // deno-lint-ignore no-explicit-any
  async queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    if (sql.includes("SELECT code FROM schools")) {
      return (this.schoolCode === null ? [] : [{ code: this.schoolCode }]) as T[];
    }
    if (sql.includes("INSERT INTO school_public_id_counters")) {
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
      return [{ allocated }] as T[];
    }
    if (sql.includes("INSERT INTO students")) {
      this.lastStudentArgs = args;
      if (this.studentCodeConflict && sql.includes("ON CONFLICT")) {
        return [] as T[]; // lost the race → RETURNING yields nothing
      }
      const row = {
        id: crypto.randomUUID(),
        organization_id: args[0],
        school_id: args[1],
        student_code: args[2],
        display_name: args[3],
        status: args[4],
        created_by: args[5],
        user_id: args[6],
        is_placeholder: args[7],
        aadhaar: args[8],
        aadhaar_hash: args[9],
      };
      this.students.push(row);
      return [{ id: row.id }] as T[];
    }
    if (sql.includes("INSERT INTO student_profiles")) {
      this.lastProfileArgs = args;
      const row = {
        id: crypto.randomUUID(),
        organization_id: args[0],
        school_id: args[1],
        student_id: args[2],
        admission_number: args[3],
        public_student_id: args[4],
        date_of_birth: args[5],
        gender: args[6],
        blood_group: args[7],
        mother_name: args[13],
        created_by: args[14],
      };
      // ON CONFLICT (student_id) DO NOTHING for the reuse path.
      if (sql.includes("ON CONFLICT") && this.profiles.some((p) => p.student_id === args[2])) {
        return [] as T[];
      }
      this.profiles.push(row);
      return [{ id: row.id }] as T[];
    }
    return [] as T[];
  }

  get client(): TenantQueryClient {
    return this as unknown as TenantQueryClient;
  }
}

Deno.test("insertStudentIdentityRow writes the canonical students column set with defaults", async () => {
  const db = new IdentityFakeDb();
  const row = await insertStudentIdentityRow(db.client, ORG, SCHOOL, {
    studentCode: "STU-2026-00001",
    displayName: "Canonical Student",
  });
  assertEquals(row !== null, true);
  assertEquals(db.students.length, 1);
  // status defaults to 'active'; created_by/user_id/aadhaar* default null;
  // is_placeholder defaults false — identical to each writer's prior partial insert.
  assertEquals(db.students[0].status, "active");
  assertEquals(db.students[0].created_by, null);
  assertEquals(db.students[0].user_id, null);
  assertEquals(db.students[0].is_placeholder, false);
  assertEquals(db.students[0].aadhaar, null);
  assertEquals(db.students[0].aadhaar_hash, null);
});

Deno.test("insertStudentIdentityRow carries the onboarding-import columns (user_id + masked Aadhaar)", async () => {
  const db = new IdentityFakeDb();
  await insertStudentIdentityRow(db.client, ORG, SCHOOL, {
    studentCode: "ADM-1",
    displayName: "Imported",
    userId: "student-user-1",
    isPlaceholder: false,
    aadhaarMasked: "XXXXXXXX9012",
    aadhaarHash: "hash-abc",
  });
  assertEquals(db.students[0].user_id, "student-user-1");
  assertEquals(db.students[0].aadhaar, "XXXXXXXX9012");
  assertEquals(db.students[0].aadhaar_hash, "hash-abc");
  assertEquals(db.students[0].is_placeholder, false);
});

Deno.test("insertStudentIdentityRow returns null on a placeholder ON CONFLICT race", async () => {
  const db = new IdentityFakeDb();
  db.studentCodeConflict = true;
  const row = await insertStudentIdentityRow(db.client, ORG, SCHOOL, {
    studentCode: "PH-Grade6-A-1",
    displayName: "Grade 6A — Roll 1",
    isPlaceholder: true,
    reuseOnStudentCodeConflict: true,
  });
  assertEquals(row, null);
  assertEquals(db.students.length, 0);
});

Deno.test("allocateAndInsertStudentProfile allocates the canonical PSID (CODE-0001) and inserts", async () => {
  const db = new IdentityFakeDb();
  const result = await allocateAndInsertStudentProfile(db.client, ORG, SCHOOL, STUDENT, {
    admissionNumber: "ADM-2026-0001",
    gender: "female",
  });
  assertEquals(result.publicStudentId, "DPSKKP-0001");
  assertEquals(result.inserted, true);
  assertEquals(db.profiles[0].public_student_id, "DPSKKP-0001");
  assertEquals(db.profiles[0].admission_number, "ADM-2026-0001");
  assertEquals(db.profiles[0].student_id, STUDENT);
});

Deno.test("allocateAndInsertStudentProfile fails loudly when the school has no code (PSID precondition)", async () => {
  const db = new IdentityFakeDb();
  db.schoolCode = null;
  await assertRejects(
    () =>
      allocateAndInsertStudentProfile(db.client, ORG, SCHOOL, STUDENT, {
        admissionNumber: "ADM-NOCODE",
      }),
    SchoolCodeMissingError,
  );
  assertEquals(db.profiles.length, 0);
});

Deno.test("allocateAndInsertStudentProfile reports inserted=false on an ON CONFLICT (student_id) reuse", async () => {
  const db = new IdentityFakeDb();
  db.profiles.push({ student_id: STUDENT, public_student_id: "DPSKKP-0001" });
  const result = await allocateAndInsertStudentProfile(db.client, ORG, SCHOOL, STUDENT, {
    admissionNumber: "ADM-REUSE",
    reuseOnStudentConflict: true,
  });
  // A PSID number is still drawn from the counter, but no second profile is written.
  assertEquals(result.inserted, false);
  assertEquals(db.profiles.length, 1);
});

Deno.test("the identity writer yields sequential, never-reused PSIDs for one school", async () => {
  const db = new IdentityFakeDb();
  const a = await allocateAndInsertStudentProfile(db.client, ORG, SCHOOL, STUDENT, {
    admissionNumber: "ADM-A",
  });
  const b = await allocateAndInsertStudentProfile(db.client, ORG, SCHOOL, "student-b", {
    admissionNumber: "ADM-B",
  });
  assertEquals(a.publicStudentId, "DPSKKP-0001");
  assertEquals(b.publicStudentId, "DPSKKP-0002");
});
