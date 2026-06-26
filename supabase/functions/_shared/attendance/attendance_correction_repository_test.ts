import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  applyAttendanceCorrection,
  type AttendanceCorrectionRow,
} from "./attendance_correction_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const STUDENT = "a4000000-0000-4000-8000-000000000001";
const CORRECTION_ID = "att_corr_1";

function baseCorrection(): AttendanceCorrectionRow {
  return {
    id: CORRECTION_ID,
    organization_id: ORG,
    school_id: SCHOOL,
    sis_student_id: "sis-1",
    student_id: STUDENT,
    student_name: "Asha",
    class_label: "8",
    section_name: "A",
    date_label: "Today",
    session_date: null,
    from_mark: "absent",
    to_mark: "present",
    reason: "Marked absent by mistake",
    requester_id: "teacher-1",
    requester_name: "Teacher",
    requester_role: "teacher",
    present_delta: 1,
    status: "pending",
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  };
}

/**
 * Stateful fake that models a submitted attendance session with one record for
 * STUDENT (initial mark "absent"). The UPDATE...RETURNING in
 * applyAttendanceCorrection flips the modelled mark and returns one row, exactly
 * as the real submitted-session match would.
 */
class FakeDb {
  recordMark = "absent";
  recordUpdated = false;
  correction = baseCorrection();

  // deno-lint-ignore no-explicit-any
  async queryObject<T>(sql: string, _args: unknown[] = []): Promise<T[]> {
    const normalized = sql.replace(/\s+/g, " ").trim();

    // getAttendanceCorrection
    if (
      normalized.startsWith("SELECT * FROM attendance_corrections") &&
      normalized.includes("AND id = $3")
    ) {
      return [this.correction] as unknown as T[];
    }

    // applyAttendanceCorrection UPDATE on the real attendance record
    if (normalized.startsWith("UPDATE attendance_records ar")) {
      // The student's record exists in a submitted session -> one row updated.
      this.recordMark = "present";
      this.recordUpdated = true;
      return [{ id: "att_rec_1" }] as unknown as T[];
    }

    // updateAttendanceCorrectionStatus
    if (
      normalized.startsWith("UPDATE attendance_corrections SET status") &&
      normalized.includes("RETURNING *")
    ) {
      this.correction = { ...this.correction, status: "approved" };
      return [this.correction] as unknown as T[];
    }

    return [] as unknown as T[];
  }
}

Deno.test("applyAttendanceCorrection updates the real record mark and approves", async () => {
  const fake = new FakeDb();
  const db = fake as unknown as TenantQueryClient;

  assertEquals(fake.recordMark, "absent");

  const result = await applyAttendanceCorrection(db, ORG, SCHOOL, CORRECTION_ID);

  assertEquals(fake.recordUpdated, true, "attendance_records row should be updated");
  assertEquals(fake.recordMark, "present", "mark should flip absent -> present");
  assertEquals(result.status, "approved", "correction should be approved");
});

Deno.test("applyAttendanceCorrection on already-approved correction is a no-op", async () => {
  const fake = new FakeDb();
  fake.correction = { ...baseCorrection(), status: "approved" };
  const db = fake as unknown as TenantQueryClient;

  const result = await applyAttendanceCorrection(db, ORG, SCHOOL, CORRECTION_ID);

  assertEquals(result.status, "approved");
  assertEquals(fake.recordUpdated, false, "no UPDATE should run for already-approved");
});
