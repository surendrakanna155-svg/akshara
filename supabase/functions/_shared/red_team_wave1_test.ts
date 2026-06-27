// Red Team Wave 1 — Transactional Integrity unit tests (mockable invariants).
// The DB-level guarantees (FOR UPDATE serialization, unique/idempotency replay,
// CHECK bounds) are proven end-to-end by the live cert
// (scripts/qa/live_cert_wave1.py); these tests pin the application-layer
// invariants that do not require a real Postgres.
import { assert, assertEquals, assertNotEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "./tenant_db.ts";
import { createAttendanceCorrection } from "./attendance/attendance_correction_repository.ts";
import { createExamSession } from "./academics/exam_administration/exam_administration_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const STUDENT = "a4000000-0000-4000-8000-000000000001";

// Minimal capturing mock: resolves a student id and echoes the INSERTed id back
// so we can assert the id the repository generated.
class IdCaptureDb {
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("FROM students")) {
      return [{ id: STUDENT }] as T[];
    }
    if (sql.includes("INSERT INTO attendance_corrections")) {
      return [{ id: args[0], status: "pending" }] as T[];
    }
    if (sql.includes("INSERT INTO exam_sessions")) {
      return [{ id: args[0] }] as T[];
    }
    return [] as T[];
  }
  async queryCount(): Promise<number> {
    return 0;
  }
}

function db(): TenantQueryClient {
  return new IdCaptureDb() as unknown as TenantQueryClient;
}

const correctionInput = {
  sisStudentId: STUDENT,
  studentName: "Cert Child",
  classLabel: "8",
  section: "A",
  dateLabel: "Today",
  fromMark: "Absent" as const,
  toMark: "Present" as const,
  reason: "test",
  requesterId: STUDENT,
  requesterName: "Parent",
  requesterRole: "parent",
};

Deno.test("RT-04: attendance correction id is a collision-free UUID, not count+1", async () => {
  const a = await createAttendanceCorrection(db(), ORG, SCHOOL, correctionInput);
  const b = await createAttendanceCorrection(db(), ORG, SCHOOL, correctionInput);
  assert(String(a.id).startsWith("att_corr_"), `got ${a.id}`);
  assertNotEquals(a.id, "att_corr_1");
  assertNotEquals(a.id, b.id); // two concurrent submits never collide on the PK
});

Deno.test("RT-04: an explicit input.id is still honoured (parent-scope path)", async () => {
  const row = await createAttendanceCorrection(db(), ORG, SCHOOL, {
    ...correctionInput,
    id: "att_corr_p_explicit",
  });
  assertEquals(row.id, "att_corr_p_explicit");
});

Deno.test("RT-05: exam session id is a collision-free UUID, not count+1", async () => {
  const examInput = {
    title: "Unit Test 1",
    subject: "Math",
    grade: "8",
    section: "A",
    termLabel: "Term 1",
    dateLabel: "Today",
    timeLabel: "10:00",
    venueLabel: "Room 1",
    syllabusLabel: "Ch 1-3",
    maxMarks: 100,
    examType: "unit_test",
  };
  const a = await createExamSession(db(), ORG, SCHOOL, examInput);
  const b = await createExamSession(db(), ORG, SCHOOL, examInput);
  assert(String(a.id).startsWith("exam_"), `got ${a.id}`);
  assertNotEquals(a.id, "exam_1");
  assertNotEquals(a.id, b.id);
});
