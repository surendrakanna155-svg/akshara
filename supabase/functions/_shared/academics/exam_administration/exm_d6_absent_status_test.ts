// EXM-D6 — Absent / "AB" (+ Medical Leave "ML", Debarred "DB") status on exam
// mark entries, plus the per-row mark-update audit (integrity gap (e)).
//
// What is proven DB-free here (same fake-TenantQueryClient seam the other exam
// tests use — answer by SQL substring):
//
//  1. updateExamMark with a non-'present' status forces marks_obtained = NULL
//     regardless of the number supplied, sets status, and keeps marks_entered
//     (so the "all marks entered" process-gate is satisfied for absent students).
//  2. A 'present' status persists the actual marks (unchanged behaviour).
//  3. examMarkToApi surfaces status + statusCode (AB/ML/DB) and null marks for a
//     non-present row.
//  4. publishExamResults sets grade_letter to the display code (AB/ML/DB) for a
//     non-present student, and a computed letter grade for a present one.
//  5. Published immutability still holds: an edit to a published row is rejected
//     (WHERE published = false → 0 rows → ExamMarkNotFoundError).
//  6. examAudit.markUpdated captures the FULL before→after of BOTH marks and
//     status (so the original attempt is recoverable), and emitMutationAudit
//     writes one audit row bound to the actor + one exam.mark.updated domain
//     event.
//
// Enum-validation of `status` (422) lives in the handler and is covered by the
// route-contract layer; here we prove the repository + audit invariants.

import {
  assertEquals,
  assertInstanceOf,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../../jwt.ts";
import type { TenantQueryClient } from "../../tenant_db.ts";
import { emitMutationAudit, examAudit } from "../../audit/mutation_audit_catalog.ts";
import {
  type ExamMarkRow,
  type ExamSessionRow,
  ExamMarkNotFoundError,
  examMarkToApi,
  examStatusDisplayCode,
  isExamMarkStatus,
  publishExamResults,
  updateExamMark,
} from "./exam_administration_repository.ts";

const ORG = "org-1";
const SCHOOL = "school-1";
const ACTOR = "e0000000-0000-4000-8000-000000000001";

function markRow(overrides: Partial<ExamMarkRow> = {}): ExamMarkRow {
  return {
    id: "mark-1",
    organization_id: ORG,
    school_id: SCHOOL,
    student_id: "stu-1",
    exam_id: "exam-1",
    exam_title: "Term 1",
    class_label: "8A",
    marks_obtained: 40,
    max_marks: 100,
    student_name: "Asha",
    roll_number: "12",
    student_code: "S12",
    published: false,
    grade_letter: null,
    marks_entered: true,
    status: "present",
    updated_at: "2026-06-28T00:00:00Z",
    row_version: 3,
    ...overrides,
  };
}

/**
 * Fake DB that echoes the UPDATE's persisted marks/status back on the RETURNING
 * row (captures what the repository actually wrote), and returns the seed row on
 * reads.
 */
class UpdateSpyDb {
  lastUpdateArgs: unknown[] | null = null;
  constructor(private current: ExamMarkRow) {}
  // deno-lint-ignore no-explicit-any
  queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    if (sql.includes("SELECT * FROM exam_mark_entries")) {
      return Promise.resolve([this.current] as T[]);
    }
    if (sql.includes("UPDATE exam_mark_entries")) {
      this.lastUpdateArgs = args;
      // args: [org, school, id, persistedMarks, status]
      const persistedMarks = args[3] as number | null;
      const status = args[4] as ExamMarkRow["status"];
      return Promise.resolve([
        {
          ...this.current,
          marks_obtained: persistedMarks,
          marks_entered: true,
          status,
          row_version: this.current.row_version + 1,
        },
      ] as T[]);
    }
    // UPDATE exam_sessions (coordinator reset) → no rows.
    return Promise.resolve([] as T[]);
  }
}

function db(row: ExamMarkRow): UpdateSpyDb {
  return new UpdateSpyDb(row);
}

// ── (1)(2) updateExamMark: status → marks NULL for non-present ────────────────

Deno.test("EXM-D6: an 'absent' update forces marks_obtained NULL (ignoring the supplied number) and keeps marks_entered", async () => {
  const spy = db(markRow());
  const updated = await updateExamMark(
    spy as unknown as TenantQueryClient,
    ORG,
    SCHOOL,
    "mark-1",
    99, // a number is supplied but must be discarded for a non-present status
    null,
    "absent",
  );
  // Persisted marks are NULL, status is 'absent', marks_entered true.
  assertEquals(spy.lastUpdateArgs?.[3], null);
  assertEquals(spy.lastUpdateArgs?.[4], "absent");
  assertEquals(updated.marks_obtained, null);
  assertEquals(updated.status, "absent");
  assertEquals(updated.marks_entered, true);
});

Deno.test("EXM-D6: medical_leave and debarred also persist NULL marks", async () => {
  for (const status of ["medical_leave", "debarred"] as const) {
    const spy = db(markRow());
    const updated = await updateExamMark(
      spy as unknown as TenantQueryClient,
      ORG,
      SCHOOL,
      "mark-1",
      55,
      null,
      status,
    );
    assertEquals(updated.marks_obtained, null);
    assertEquals(updated.status, status);
  }
});

Deno.test("EXM-D6: a 'present' update persists the actual marks (unchanged behaviour)", async () => {
  const spy = db(markRow());
  const updated = await updateExamMark(
    spy as unknown as TenantQueryClient,
    ORG,
    SCHOOL,
    "mark-1",
    77,
    null,
    "present",
  );
  assertEquals(spy.lastUpdateArgs?.[3], 77);
  assertEquals(spy.lastUpdateArgs?.[4], "present");
  assertEquals(updated.marks_obtained, 77);
  assertEquals(updated.status, "present");
});

Deno.test("EXM-D6: updateExamMark defaults status to 'present' when omitted (back-compat)", async () => {
  const spy = db(markRow());
  await updateExamMark(spy as unknown as TenantQueryClient, ORG, SCHOOL, "mark-1", 61);
  assertEquals(spy.lastUpdateArgs?.[4], "present");
});

// ── (3) examMarkToApi surfaces status + statusCode + null marks ───────────────

Deno.test("EXM-D6: examMarkToApi exposes status, statusCode and null marks for an absent row", () => {
  const api = examMarkToApi(
    markRow({ status: "absent", marks_obtained: null }),
  );
  assertEquals(api.status, "absent");
  assertEquals(api.statusCode, "AB");
  assertEquals(api.marksObtained, null);
});

Deno.test("EXM-D6: display codes map absent→AB, medical_leave→ML, debarred→DB, present→null", () => {
  assertEquals(examStatusDisplayCode("absent"), "AB");
  assertEquals(examStatusDisplayCode("medical_leave"), "ML");
  assertEquals(examStatusDisplayCode("debarred"), "DB");
  assertEquals(examStatusDisplayCode("present"), null);
  assertEquals(isExamMarkStatus("nope"), false);
  assertEquals(isExamMarkStatus("debarred"), true);
});

// ── (4) publish sets grade_letter to the display code for non-present ─────────

function session(overrides: Partial<ExamSessionRow> = {}): ExamSessionRow {
  return {
    id: "exam-1",
    organization_id: ORG,
    school_id: SCHOOL,
    title: "Term 1 Maths",
    subject: "Mathematics",
    grade: "8",
    section_name: "A",
    term_label: "Term 1",
    date_label: "",
    time_label: "",
    venue_label: "",
    syllabus_label: "",
    max_marks: 100,
    phase: "processed",
    exam_type: "unit_test",
    marks_entry_deadline: null,
    coordinator_verified_by: null,
    coordinator_verified_at: null,
    rejection_comment: null,
    created_by: null,
    created_at: "",
    updated_at: "",
    ...overrides,
  };
}

/** Fake DB that captures every grade_letter written during publish. */
class PublishSpyDb {
  gradeById: Record<string, string> = {};
  constructor(
    private sess: ExamSessionRow,
    private marks: ExamMarkRow[],
  ) {}
  // deno-lint-ignore no-explicit-any
  queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    if (sql.includes("FROM exam_sessions") && sql.includes("SELECT * FROM exam_sessions")) {
      return Promise.resolve([this.sess] as T[]);
    }
    if (sql.includes("SELECT * FROM exam_sessions")) {
      return Promise.resolve([this.sess] as T[]);
    }
    if (sql.includes("SELECT * FROM exam_mark_entries")) {
      return Promise.resolve(this.marks as T[]);
    }
    if (sql.includes("UPDATE exam_mark_entries") && sql.includes("grade_letter")) {
      // args: [org, school, id, gradeLetter]
      this.gradeById[args[2] as string] = args[3] as string;
      return Promise.resolve([] as T[]);
    }
    if (sql.includes("UPDATE exam_sessions")) {
      return Promise.resolve([this.sess] as T[]);
    }
    return Promise.resolve([] as T[]);
  }
}

Deno.test("EXM-D6: publish grades a present student by percent and a non-present student with the display code", async () => {
  const present = markRow({ id: "m-present", marks_obtained: 85, status: "present" });
  const absent = markRow({
    id: "m-absent",
    marks_obtained: null,
    status: "absent",
    marks_entered: true,
  });
  const ml = markRow({
    id: "m-ml",
    marks_obtained: null,
    status: "medical_leave",
    marks_entered: true,
  });
  const spy = new PublishSpyDb(session(), [present, absent, ml]);
  const count = await publishExamResults(
    spy as unknown as TenantQueryClient,
    ORG,
    SCHOOL,
    "exam-1",
  );
  assertEquals(count, 3);
  assertEquals(spy.gradeById["m-present"], "A"); // 85% → A on the standard scale
  assertEquals(spy.gradeById["m-absent"], "AB");
  assertEquals(spy.gradeById["m-ml"], "ML");
});

// ── (5) published immutability preserved ─────────────────────────────────────

Deno.test("EXM-D6 (integrity preserved): editing a PUBLISHED row is still rejected even with a status change", async () => {
  class PublishedDb {
    constructor(private current: ExamMarkRow) {}
    // deno-lint-ignore no-explicit-any
    queryObject<T>(sql: string, _args: any[] = []): Promise<T[]> {
      if (sql.includes("SELECT * FROM exam_mark_entries")) {
        return Promise.resolve([this.current] as T[]);
      }
      if (sql.includes("UPDATE exam_mark_entries")) {
        return Promise.resolve([] as T[]); // WHERE published = false → 0 rows
      }
      return Promise.resolve([] as T[]);
    }
  }
  const err = await assertRejects(() =>
    updateExamMark(
      new PublishedDb(markRow({ published: true })) as unknown as TenantQueryClient,
      ORG,
      SCHOOL,
      "mark-1",
      0,
      null,
      "absent",
    )
  );
  assertInstanceOf(err, ExamMarkNotFoundError);
});

// ── (6) per-row mark-update audit: full before→after of marks + status ────────

function claims(): AccessTokenClaims {
  return {
    sub: ACTOR,
    tenant_id: ORG,
    organization_id: ORG,
    school_id: SCHOOL,
    role: "teacher",
    role_slugs: ["teacher"],
    primary_role: "teacher",
    permissions: ["manageExamMarks"],
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
  };
}

class AuditSpyDb {
  audits: { args: unknown[] }[] = [];
  domains: { args: unknown[] }[] = [];
  queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("FROM domain_events") && sql.includes("idempotency_key")) {
      return Promise.resolve([] as T[]);
    }
    if (sql.includes("INSERT INTO audit_events")) {
      this.audits.push({ args });
      return Promise.resolve([{ id: crypto.randomUUID() }] as unknown as T[]);
    }
    if (sql.includes("INSERT INTO domain_events")) {
      this.domains.push({ args });
      return Promise.resolve([{ id: crypto.randomUUID() }] as unknown as T[]);
    }
    return Promise.resolve([] as T[]);
  }
}

Deno.test("EXM-D6: examAudit.markUpdated captures the FULL before→after of marks AND status", () => {
  const spec = examAudit.markUpdated(
    "exam-1",
    "mark-1",
    "stu-1",
    { marksObtained: 40, status: "present" },
    { marksObtained: null, status: "absent" },
    5,
    "5",
  );
  assertEquals(spec.audit.eventType, "examMarkUpdated");
  assertEquals(spec.audit.entityType, "exam_mark_entry");
  assertEquals(spec.audit.entityId, "mark-1");
  assertEquals(spec.audit.metadata?.before, { marksObtained: 40, status: "present" });
  assertEquals(spec.audit.metadata?.after, { marksObtained: null, status: "absent" });
  assertEquals(spec.audit.metadata?.studentId, "stu-1");
  assertEquals(spec.domain.eventType, "exam.mark.updated");
  assertEquals(spec.domain.sourceModule, "exam");
  assertEquals(spec.domain.idempotencyKey, "exam.mark.updated:mark-1:5");
  // before→after preserves the original attempt (recoverable for a re-exam).
  assertEquals(
    (spec.domain.payload as Record<string, unknown>).before,
    { marksObtained: 40, status: "present" },
  );
});

Deno.test("EXM-D6: emitMutationAudit on a mark update writes one audit row bound to the actor + one exam.mark.updated domain event", async () => {
  const spy = new AuditSpyDb();
  await emitMutationAudit(
    spy as unknown as TenantQueryClient,
    claims(),
    examAudit.markUpdated(
      "exam-1",
      "mark-1",
      "stu-1",
      { marksObtained: 40, status: "present" },
      { marksObtained: null, status: "absent" },
      6,
      "6",
    ),
  );
  assertEquals(spy.audits.length, 1);
  assertEquals(spy.domains.length, 1);
  const a = spy.audits[0].args;
  assertEquals(a[0], ORG);
  assertEquals(a[1], SCHOOL);
  assertEquals(a[2], ACTOR); // actor binding — WHO edited the mark
  assertEquals(a[5], "examMarkUpdated");
  assertEquals(spy.domains[0].args[2], "exam.mark.updated");
});

Deno.test("EXM-D6 (handler wiring): handleUpdateExamMark validates status + emits the mark-update audit", async () => {
  const src = await Deno.readTextFile(
    new URL("./exam_administration_handlers.ts", import.meta.url),
  );
  // Status is validated against the enum (422) before the DB.
  assertEquals(src.includes("isExamMarkStatus(statusRaw)"), true);
  assertEquals(src.includes("Invalid status:"), true);
  // The per-row audit is emitted with the before→after builder.
  assertEquals(src.includes("examAudit.markUpdated("), true);
  assertEquals(src.includes("emitMutationAudit("), true);
});
