// QA-X-033 (security) — exam results anti-tamper.
//
// Two server-side invariants protect published exam results from tampering:
//
//  (1) PUBLISH GATE — handlePublishExamResults (exam_administration_handlers.ts)
//      requires the publishExamResults permission AND, unless requireApproval is
//      explicitly false, a matching APPROVED approval_request
//      (findApprovedByEntity returns a row). With no approval it throws
//      ExamApprovalRequiredError, which mapExamError turns into 403 — and the
//      throw is BEFORE publishExamResults, so a denied publish never writes.
//
//  (2) POST-PUBLISH IMMUTABILITY — exam_administration_repository.updateExamMark
//      runs `UPDATE exam_mark_entries ... WHERE ... AND published = false`. Once a
//      mark is published (published=true) the WHERE matches 0 rows, the RETURNING
//      set is empty, and the function throws ExamMarkNotFoundError. So you cannot
//      silently rewrite a grade after results have gone live to parents/students.
//
// This is the SAME DB-free seam the existing exam tests use:
//   • a fake TenantQueryClient that answers by SQL substring (exam_mark_conflict_test.ts);
//   • static-source assertions for handler WIRING + the approval ORDERING and the
//     403 mapping (qw4_exam_publish_audit_test.ts).
//
// Live remainder (needs ERP_TENANT_DATABASE_URL): the real 403 through the publish
// route (it traverses withTenantContext, which has no fake-DB seam) and a real
// persisted-row reject after a live publish belong to the live cert.

import {
  assertEquals,
  assertInstanceOf,
  assertRejects,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../../tenant_db.ts";
import { findApprovedByEntity } from "../../approval/approval_repository.ts";
import {
  type ExamMarkRow,
  ExamApprovalRequiredError,
  ExamMarkNotFoundError,
  updateExamMark,
} from "./exam_administration_repository.ts";

const ORG = "org-1";
const SCHOOL = "school-1";

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
    updated_at: "2026-06-28T00:00:00Z",
    row_version: 3,
    ...overrides,
  };
}

// ── (1) PUBLISH GATE: no approval → no publish ────────────────────────────────

/** Fake DB whose approval_requests table is empty (no approved row exists). */
class NoApprovalDb {
  // deno-lint-ignore no-explicit-any
  queryObject<T>(sql: string, _args: any[] = []): Promise<T[]> {
    if (sql.includes("FROM approval_requests")) {
      return Promise.resolve([] as T[]); // nothing approved
    }
    return Promise.resolve([] as T[]);
  }
}

function approvalDb(db: NoApprovalDb): TenantQueryClient {
  return db as unknown as TenantQueryClient;
}

Deno.test("QA-X-033: with no approved approval_request, findApprovedByEntity returns null (the gate's 'deny' input)", async () => {
  const approved = await findApprovedByEntity(
    approvalDb(new NoApprovalDb()),
    ORG,
    SCHOOL,
    "examResults",
    "exam_session",
    "exam-1",
  );
  // null here is precisely what makes handlePublishExamResults throw
  // ExamApprovalRequiredError before publishing.
  assertEquals(approved, null);
});

Deno.test("QA-X-033: ExamApprovalRequiredError is the gate's 403 signal (distinct typed error)", () => {
  const err = new ExamApprovalRequiredError();
  assertInstanceOf(err, ExamApprovalRequiredError);
  assertEquals(err.name, "ExamApprovalRequiredError");
  // Message documents the gate to operators.
  assertStringIncludes(err.message, "approval is required");
});

Deno.test("QA-X-033 (handler wiring): publish THROWS ExamApprovalRequiredError when findApprovedByEntity is null, BEFORE publishExamResults", async () => {
  const src = await Deno.readTextFile(
    new URL("./exam_administration_handlers.ts", import.meta.url),
  );
  // The gate: look up an approved request, and throw if there is none.
  assertStringIncludes(src, "findApprovedByEntity(");
  assertStringIncludes(src, "throw new ExamApprovalRequiredError()");

  // ORDERING: the approval lookup + throw must precede the publish write, so a
  // denied publish never mutates exam_mark_entries.
  const approvalLookup = src.indexOf("findApprovedByEntity(");
  const approvalThrow = src.indexOf("throw new ExamApprovalRequiredError()");
  const publish = src.indexOf("publishExamResults(db");
  if (approvalLookup < 0 || approvalThrow < 0 || publish < 0) {
    throw new Error("expected approval gate + publish call in handlePublishExamResults");
  }
  if (!(approvalLookup < approvalThrow && approvalThrow < publish)) {
    throw new Error(
      "approval gate must be enforced (and throw) BEFORE publishExamResults",
    );
  }
});

Deno.test("QA-X-033 (handler wiring): ExamApprovalRequiredError maps to HTTP 403", async () => {
  const src = await Deno.readTextFile(
    new URL("./exam_administration_handlers.ts", import.meta.url),
  );
  // mapExamError must turn the approval-required error into a 403 (not a 200/500).
  const idx = src.indexOf("error instanceof ExamApprovalRequiredError");
  if (idx < 0) throw new Error("expected ExamApprovalRequiredError to be mapped");
  // The 403 status appears on the errorEnvelope for this branch.
  const branch = src.slice(idx, idx + 160);
  assertStringIncludes(branch, "EXAM_APPROVAL_REQUIRED");
  assertStringIncludes(branch, "403");
});

// ── (2) POST-PUBLISH IMMUTABILITY: edit after publish is rejected ─────────────

/**
 * Fake DB modelling the published-row case. The `getExamMark` SELECT returns the
 * (published) row, but the `updateExamMark` UPDATE carries `AND published = false`
 * so on a published row it matches 0 rows → empty RETURNING set.
 */
class PublishedMarkDb {
  constructor(private current: ExamMarkRow) {}
  // deno-lint-ignore no-explicit-any
  queryObject<T>(sql: string, _args: any[] = []): Promise<T[]> {
    if (sql.includes("SELECT * FROM exam_mark_entries")) {
      return Promise.resolve([this.current] as T[]); // the published row, for reads
    }
    if (sql.includes("UPDATE exam_mark_entries")) {
      // WHERE ... AND published = false ⇒ a published row is NOT matched.
      return Promise.resolve([] as T[]);
    }
    return Promise.resolve([] as T[]);
  }
}

function publishedDb(row: ExamMarkRow): TenantQueryClient {
  return new PublishedMarkDb(row) as unknown as TenantQueryClient;
}

Deno.test("QA-X-033: editing a mark AFTER publish (published=true) is rejected → ExamMarkNotFoundError (no row updated)", async () => {
  const err = await assertRejects(
    () =>
      updateExamMark(
        publishedDb(markRow({ published: true })),
        ORG,
        SCHOOL,
        "mark-1",
        99, // attacker tries to bump the grade post-publish
      ),
  );
  // The `published = false` guard means the UPDATE touched 0 rows; the function
  // refuses the edit rather than silently no-op-succeeding.
  assertInstanceOf(err, ExamMarkNotFoundError);
});

Deno.test("QA-X-033: the SAME edit on an UNpublished row succeeds (control — the guard is published-specific, not a blanket block)", async () => {
  // Control: an unpublished row IS editable, so the post-publish reject above is
  // attributable to the published flag, not to a broken update path.
  class EditableDb {
    constructor(private current: ExamMarkRow) {}
    // deno-lint-ignore no-explicit-any
    queryObject<T>(sql: string, _args: any[] = []): Promise<T[]> {
      if (sql.includes("SELECT * FROM exam_mark_entries")) {
        return Promise.resolve([this.current] as T[]);
      }
      if (sql.includes("UPDATE exam_mark_entries")) {
        return Promise.resolve(
          [{ ...this.current, marks_obtained: 55, marks_entered: true }] as T[],
        );
      }
      return Promise.resolve([] as T[]);
    }
  }
  const db = new EditableDb(markRow({ published: false })) as unknown as TenantQueryClient;
  const updated = await updateExamMark(db, ORG, SCHOOL, "mark-1", 55);
  assertEquals(updated.marks_obtained, 55);
});

Deno.test("QA-X-033 (repository invariant): updateExamMark's UPDATE is fenced by `published = false`", async () => {
  const src = await Deno.readTextFile(
    new URL("./exam_administration_repository.ts", import.meta.url),
  );
  // Lock the immutability guard in source so a refactor that drops it fails here.
  assertStringIncludes(src, "UPDATE exam_mark_entries");
  assertStringIncludes(src, "AND published = false");
});

Deno.test("QA-X-033 (repository invariant): findApprovedByEntity only matches an APPROVED request (status='approved')", async () => {
  const src = await Deno.readTextFile(
    new URL("../../approval/approval_repository.ts", import.meta.url),
  );
  // The publish gate trusts findApprovedByEntity; lock that it filters on the
  // approved status (a pending/rejected request must NOT unlock a publish).
  const idx = src.indexOf("export async function findApprovedByEntity");
  if (idx < 0) throw new Error("findApprovedByEntity not found");
  assertStringIncludes(src.slice(idx, idx + 600), "status = 'approved'");
});
