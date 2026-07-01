import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  applyApprovedLeaveExcuse,
  AttendanceClosedDayError,
  AttendanceLockedError,
  AttendanceRosterMismatchError,
  countMarksForTest,
  diffRoster,
  type AttendanceMarkEntry,
} from "./pilot_operations_repository.ts";

// Attendance integrity gates #6/#7 — the pure roster-reconciliation used on
// submit. The DB-backed guards (#1 immutability, #5 holiday, #8 year-closure,
// #2/#3 unique session) are proven by the live cert; here we pin the pure logic.

Deno.test("diffRoster: exact match → no missing, no extra", () => {
  const r = diffRoster(["a", "b", "c"], ["c", "b", "a"]);
  assertEquals(r.missing, []);
  assertEquals(r.extra, []);
});

Deno.test("diffRoster: an enrolled student not marked → missing", () => {
  const r = diffRoster(["a", "b"], ["a", "b", "c"]);
  assertEquals(r.missing, ["c"]);
  assertEquals(r.extra, []);
});

Deno.test("diffRoster: a marked student not on the roster (withdrawn/transferred) → extra", () => {
  const r = diffRoster(["a", "b", "x"], ["a", "b"]);
  assertEquals(r.missing, []);
  assertEquals(r.extra, ["x"]);
});

Deno.test("diffRoster: both missing and extra are reported", () => {
  const r = diffRoster(["a", "x"], ["a", "b"]);
  assertEquals(r.missing, ["b"]);
  assertEquals(r.extra, ["x"]);
});

Deno.test("diffRoster: empty submission against a roster → all missing", () => {
  const r = diffRoster([], ["a", "b"]);
  assertEquals(r.missing.sort(), ["a", "b"]);
  assertEquals(r.extra, []);
});

Deno.test("attendance integrity error types carry their semantics", () => {
  const locked = new AttendanceLockedError();
  assertEquals(locked.name, "AttendanceLockedError");
  const closed = new AttendanceClosedDayError("holiday");
  assertEquals(closed.name, "AttendanceClosedDayError");
  const mismatch = new AttendanceRosterMismatchError(["b"], ["x"]);
  assertEquals(mismatch.name, "AttendanceRosterMismatchError");
  assertEquals(mismatch.missing, ["b"]);
  assertEquals(mismatch.extra, ["x"]);
});

// ── ATT-D3 Part A — half_day / excused counting ─────────────────────────────

Deno.test("countMarks: counts half_day and excused without breaking present/absent/late", () => {
  const entries: AttendanceMarkEntry[] = [
    { studentId: "a", mark: "present" },
    { studentId: "b", mark: "absent" },
    { studentId: "c", mark: "late" },
    { studentId: "d", mark: "excused" },
    { studentId: "e", mark: "half_day" },
    { studentId: "f", mark: "half_day" },
  ];
  const counts = countMarksForTest(entries);
  assertEquals(counts.present, 1);
  assertEquals(counts.absent, 1);
  assertEquals(counts.late, 1);
  assertEquals(counts.excused, 1);
  assertEquals(counts.halfDay, 2);
});

// ── ATT-D3 Part B — pure auto-excuse override ───────────────────────────────

Deno.test("applyApprovedLeaveExcuse: overrides marks for students on approved leave", () => {
  const entries: AttendanceMarkEntry[] = [
    { studentId: "a", mark: "present" },
    { studentId: "b", mark: "absent" },
    { studentId: "c", mark: "late" },
  ];
  const out = applyApprovedLeaveExcuse(entries, new Set(["b", "c"]));
  assertEquals(out.map((e) => e.mark), ["present", "excused", "excused"]);
});

Deno.test("applyApprovedLeaveExcuse: keeps excused students on the roster (same ids, same length)", () => {
  const entries: AttendanceMarkEntry[] = [
    { studentId: "a", mark: "absent" },
    { studentId: "b", mark: "present" },
  ];
  const out = applyApprovedLeaveExcuse(entries, new Set(["a"]));
  assertEquals(out.length, entries.length);
  assertEquals(out.map((e) => e.studentId).sort(), ["a", "b"]);
});

Deno.test("applyApprovedLeaveExcuse: empty leave set returns entries unchanged (same reference)", () => {
  const entries: AttendanceMarkEntry[] = [{ studentId: "a", mark: "present" }];
  const out = applyApprovedLeaveExcuse(entries, new Set());
  assertEquals(out, entries);
});

Deno.test("applyApprovedLeaveExcuse: an already-excused student is left as-is", () => {
  const entries: AttendanceMarkEntry[] = [{ studentId: "a", mark: "excused" }];
  const out = applyApprovedLeaveExcuse(entries, new Set(["a"]));
  assertEquals(out.map((e) => e.mark), ["excused"]);
});

Deno.test("applyApprovedLeaveExcuse: leave for a student not being marked is a no-op", () => {
  const entries: AttendanceMarkEntry[] = [{ studentId: "a", mark: "present" }];
  const out = applyApprovedLeaveExcuse(entries, new Set(["z"]));
  assertEquals(out.map((e) => e.mark), ["present"]);
});

Deno.test("applyApprovedLeaveExcuse then countMarks: excused override reflects in counts", () => {
  const entries: AttendanceMarkEntry[] = [
    { studentId: "a", mark: "present" },
    { studentId: "b", mark: "absent" },
  ];
  const counts = countMarksForTest(applyApprovedLeaveExcuse(entries, new Set(["b"])));
  assertEquals(counts.present, 1);
  assertEquals(counts.absent, 0);
  assertEquals(counts.excused, 1);
});
