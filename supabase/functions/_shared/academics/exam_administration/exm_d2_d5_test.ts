// EXM-D2 (grace / moderation) + EXM-D5 (seating) repository logic.
//
// 🔴 Integrity (frozen): a grace adjustment is a SEPARATE row; the ORIGINAL mark
// (exam_mark_entries.marks_obtained) is NEVER overwritten. The EFFECTIVE mark =
// clamp(original + Σdeltas, 0, max). Grace is rejected once published. The
// per-delta breakdown is coordinator-only. These tests drive the pure/DB logic
// over a fake DB so integrity is proven WITHOUT a live tenant Postgres.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../../tenant_db.ts";
import {
  clampEffectiveMark,
  ExamGracePhaseError,
  type ExamPhase,
  planSeating,
  recordExamMarkAdjustment,
  type SeatingCandidate,
} from "./exam_administration_repository.ts";

const ORG = "org-1";
const SCHOOL = "school-1";

// A fake DB for the grace path: serves an exam session in a given phase, one
// present mark entry (original 40 / max 50), and CAPTURES the adjustment insert
// so we can assert the original mark is never touched.
class GraceDb {
  inserted: Array<Record<string, unknown>> = [];
  updatedMarks = 0;

  constructor(
    private readonly phase: ExamPhase,
    private readonly original: number | null = 40,
    private readonly status = "present",
    private readonly existingDelta = 0,
  ) {}

  // deno-lint-ignore no-explicit-any
  queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    // getExamSession
    if (
      sql.includes("FROM exam_sessions") &&
      sql.includes("AND id = $3") &&
      !sql.includes("exam_mark_entries")
    ) {
      return Promise.resolve([{
        id: "exam-1",
        organization_id: ORG,
        school_id: SCHOOL,
        max_marks: 50,
        phase: this.phase,
        grade: "8",
        section_name: "A",
        subject: "Mathematics",
        title: "Unit Test",
      }] as unknown as T[]);
    }
    // Load the student's mark entry (grace path).
    if (
      sql.includes("FROM exam_mark_entries") &&
      sql.includes("AND student_id = $4") &&
      sql.includes("SELECT *")
    ) {
      return Promise.resolve([{
        id: "exam-1_stu-1",
        organization_id: ORG,
        school_id: SCHOOL,
        student_id: "stu-1",
        exam_id: "exam-1",
        marks_obtained: this.original,
        max_marks: 50,
        status: this.status,
        marks_entered: true,
        published: false,
      }] as unknown as T[]);
    }
    // INSERT adjustment (capture + return the row).
    if (sql.includes("INSERT INTO exam_mark_adjustments")) {
      const row = {
        id: "adj-1",
        organization_id: args[0],
        school_id: args[1],
        exam_id: args[2],
        student_id: args[3],
        delta: args[4],
        reason: args[5],
        adjusted_by: args[6],
        created_at: "2026-07-02T00:00:00Z",
      };
      this.inserted.push(row);
      return Promise.resolve([row] as unknown as T[]);
    }
    // SUM(delta) — existing deltas + the just-inserted one.
    if (sql.includes("COALESCE(SUM(delta)")) {
      const insertedDelta = this.inserted.reduce(
        (s, r) => s + Number(r.delta ?? 0),
        0,
      );
      return Promise.resolve(
        [{ total: `${this.existingDelta + insertedDelta}` }] as unknown as T[],
      );
    }
    // Any UPDATE of exam_mark_entries would mean the original was touched.
    if (sql.includes("UPDATE exam_mark_entries")) {
      this.updatedMarks++;
      return Promise.resolve([] as T[]);
    }
    return Promise.resolve([] as T[]);
  }
  queryCount(): Promise<number> {
    return Promise.resolve(0);
  }
}

function db(x: GraceDb): TenantQueryClient {
  return x as unknown as TenantQueryClient;
}

Deno.test("EXM-D2: grace records a delta row WITHOUT overwriting the original mark", async () => {
  const fake = new GraceDb("processed", 40);
  const result = await recordExamMarkAdjustment(db(fake), ORG, SCHOOL, {
    examId: "exam-1",
    studentId: "stu-1",
    delta: 5,
    reason: "Re-evaluation",
    adjustedBy: null,
  });
  // The adjustment row was inserted…
  assertEquals(fake.inserted.length, 1);
  assertEquals(fake.inserted[0]!.delta, 5);
  assertEquals(fake.inserted[0]!.reason, "Re-evaluation");
  // …and NO exam_mark_entries row was updated (original preserved).
  assertEquals(fake.updatedMarks, 0);
  // Effective = original 40 + delta 5 = 45 (within max 50).
  assertEquals(result.effectiveMark, 45);
  assertEquals(result.maxMarks, 50);
});

Deno.test("EXM-D2: effective mark is capped at max_marks (never over)", async () => {
  const fake = new GraceDb("processed", 48);
  const result = await recordExamMarkAdjustment(db(fake), ORG, SCHOOL, {
    examId: "exam-1",
    studentId: "stu-1",
    delta: 10, // 48 + 10 = 58 → capped to 50
    reason: "Grace",
    adjustedBy: null,
  });
  assertEquals(result.effectiveMark, 50);
  assertEquals(fake.updatedMarks, 0);
});

Deno.test("EXM-D2: a downward moderation never drops below 0", async () => {
  const fake = new GraceDb("processed", 3);
  const result = await recordExamMarkAdjustment(db(fake), ORG, SCHOOL, {
    examId: "exam-1",
    studentId: "stu-1",
    delta: -10, // 3 - 10 = -7 → clamped to 0
    reason: "Penalty",
    adjustedBy: null,
  });
  assertEquals(result.effectiveMark, 0);
});

Deno.test("EXM-D2: grace is REJECTED after publish (published exam is immutable)", async () => {
  const fake = new GraceDb("published", 40);
  let threw = false;
  try {
    await recordExamMarkAdjustment(db(fake), ORG, SCHOOL, {
      examId: "exam-1",
      studentId: "stu-1",
      delta: 5,
      reason: "too late",
      adjustedBy: null,
    });
  } catch (error) {
    threw = error instanceof ExamGracePhaseError;
  }
  assertEquals(threw, true);
  // Nothing was inserted or updated for a published exam.
  assertEquals(fake.inserted.length, 0);
  assertEquals(fake.updatedMarks, 0);
});

Deno.test("EXM-D2: grace is rejected before results are processed", async () => {
  const fake = new GraceDb("marks_entry", 40);
  let threw = false;
  try {
    await recordExamMarkAdjustment(db(fake), ORG, SCHOOL, {
      examId: "exam-1",
      studentId: "stu-1",
      delta: 5,
      reason: "too early",
      adjustedBy: null,
    });
  } catch (error) {
    threw = error instanceof ExamGracePhaseError;
  }
  assertEquals(threw, true);
});

Deno.test("EXM-D2: grace cannot be applied to a non-present (absent) student", async () => {
  const fake = new GraceDb("processed", null, "absent");
  let threw = false;
  try {
    await recordExamMarkAdjustment(db(fake), ORG, SCHOOL, {
      examId: "exam-1",
      studentId: "stu-1",
      delta: 5,
      reason: "n/a",
      adjustedBy: null,
    });
  } catch {
    threw = true;
  }
  assertEquals(threw, true);
  assertEquals(fake.inserted.length, 0);
});

Deno.test("EXM-D2: clampEffectiveMark bounds a value into [0, max]", () => {
  assertEquals(clampEffectiveMark(45, 50), 45);
  assertEquals(clampEffectiveMark(58, 50), 50);
  assertEquals(clampEffectiveMark(-3, 50), 0);
});

// ── EXM-D5 — seating planner ────────────────────────────────────────────────

function candidate(
  id: string,
  classLabel: string,
  roll: string,
): SeatingCandidate {
  return {
    studentId: id,
    studentCode: id.toUpperCase(),
    studentName: `Student ${id}`,
    rollNumber: roll,
    classLabel,
  };
}

Deno.test("EXM-D5: single class seats sequentially by roll across rooms of capacity", () => {
  const candidates = [
    candidate("s3", "8-A", "03"),
    candidate("s1", "8-A", "01"),
    candidate("s2", "8-A", "02"),
    candidate("s4", "8-A", "04"),
    candidate("s5", "8-A", "05"),
  ];
  const seats = planSeating(candidates, 2); // capacity 2 → 3 rooms
  // Ordered by roll; room fills to 2 then a new room opens.
  assertEquals(seats.map((s) => [s.studentId, s.roomLabel, s.seatNo]), [
    ["s1", "Room 1", 1],
    ["s2", "Room 1", 2],
    ["s3", "Room 2", 1],
    ["s4", "Room 2", 2],
    ["s5", "Room 3", 1],
  ]);
});

Deno.test("EXM-D5: multi-class plan never seats two adjacent students of the SAME class", () => {
  // Two classes, 4 each. capacity 100 → one room, so adjacency spans the whole
  // sequence. The interleave must keep neighbours from the same class apart.
  const candidates = [
    candidate("a1", "8-A", "01"),
    candidate("a2", "8-A", "02"),
    candidate("a3", "8-A", "03"),
    candidate("a4", "8-A", "04"),
    candidate("b1", "8-B", "01"),
    candidate("b2", "8-B", "02"),
    candidate("b3", "8-B", "03"),
    candidate("b4", "8-B", "04"),
  ];
  const seats = planSeating(candidates, 100);
  const classById = new Map(candidates.map((c) => [c.studentId, c.classLabel]));
  // Walk the seat order within each room; no two consecutive seats share a class.
  const byRoom = new Map<string, typeof seats>();
  for (const s of seats) {
    const list = byRoom.get(s.roomLabel) ?? [];
    list.push(s);
    byRoom.set(s.roomLabel, list);
  }
  for (const list of byRoom.values()) {
    list.sort((x, y) => x.seatNo - y.seatNo);
    for (let i = 1; i < list.length; i++) {
      const prev = classById.get(list[i - 1]!.studentId);
      const cur = classById.get(list[i]!.studentId);
      assertEquals(
        prev === cur,
        false,
        `adjacent seats ${list[i - 1]!.seatNo}/${list[i]!.seatNo} share class ${cur}`,
      );
    }
  }
  // All 8 students are seated exactly once.
  assertEquals(seats.length, 8);
  assertEquals(new Set(seats.map((s) => s.studentId)).size, 8);
});

Deno.test("EXM-D5: multi-class adjacency holds even when one class outnumbers another", () => {
  // 5 of A, 2 of B. Perfect no-repeat is impossible (A outnumbers), but the
  // planner still keeps repeats to the unavoidable minimum and seats everyone.
  const candidates = [
    candidate("a1", "8-A", "01"),
    candidate("a2", "8-A", "02"),
    candidate("a3", "8-A", "03"),
    candidate("a4", "8-A", "04"),
    candidate("a5", "8-A", "05"),
    candidate("b1", "8-B", "01"),
    candidate("b2", "8-B", "02"),
  ];
  const seats = planSeating(candidates, 100);
  assertEquals(seats.length, 7);
  assertEquals(new Set(seats.map((s) => s.studentId)).size, 7);
  // Every B student is used to break up A runs → at most (5-1)-2 = 2 A-A repeats.
  const classById = new Map(candidates.map((c) => [c.studentId, c.classLabel]));
  const ordered = [...seats].sort((x, y) => x.seatNo - y.seatNo);
  let repeats = 0;
  for (let i = 1; i < ordered.length; i++) {
    if (
      classById.get(ordered[i - 1]!.studentId) ===
        classById.get(ordered[i]!.studentId)
    ) {
      repeats++;
    }
  }
  // With 5 A and 2 B, the minimum unavoidable A-A adjacencies is 2.
  assertEquals(repeats <= 2, true, `too many same-class adjacencies: ${repeats}`);
});
