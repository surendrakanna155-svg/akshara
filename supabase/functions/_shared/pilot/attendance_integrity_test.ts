import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  AttendanceClosedDayError,
  AttendanceLockedError,
  AttendanceRosterMismatchError,
  diffRoster,
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
