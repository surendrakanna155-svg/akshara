// Adaptive AI — P3-AI-2 / W2 teacher rollout: pure generator tests (DB-free).
//
// The generators are pure (structural input → RawPriorityItem), so they are
// fully unit-testable without a live Postgres. The loader (loadTeacherFeedSources)
// is proven at the route-contract layer (503 = matched + authorized).

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  collectTeacherRawItems,
  teacherAttendanceItems,
  teacherExamItems,
  teacherHomeworkItems,
} from "./teacher_sources.ts";
import { buildFeed } from "./priority_engine.ts";

Deno.test("teacher attendance: only unmarked classes surface, as due-today exceptions", () => {
  const items = teacherAttendanceItems([
    { classLabel: "8-A", label: "8-A Mathematics", subject: "Mathematics", studentCount: 30, isPending: true },
    { classLabel: "9-B", label: "9-B Science", subject: "Science", studentCount: 25, isPending: false },
  ]);
  assertEquals(items.length, 1);
  const it = items[0]!;
  assertEquals(it.itemKey, "teacher:attendance:8-A");
  assertEquals(it.type, "exception");
  assertEquals(it.personas, ["teacher"]);
  assertEquals(it.factors.dueInDays, 0);
  assertEquals(it.factors.peopleAffected, 30);
  assertEquals(it.source, "teacher_attendance");
  assert(it.entityTags.includes("class:8-A:attendance"));
});

Deno.test("teacher homework: surfaces only assignments with pending submitters in the window", () => {
  const items = teacherHomeworkItems([
    // due tomorrow, 5 of 30 pending → surfaces
    { homeworkId: "hw1", title: "Algebra WS", classLabel: "8-A", subject: "Maths", submittedCount: 25, totalCount: 30, dueInDays: 1 },
    // fully submitted → excluded
    { homeworkId: "hw2", title: "Essay", classLabel: "9-B", subject: "Eng", submittedCount: 20, totalCount: 20, dueInDays: 2 },
    // out of window (due in 30 days) → excluded
    { homeworkId: "hw3", title: "Project", classLabel: "8-A", subject: "Sci", submittedCount: 0, totalCount: 30, dueInDays: 30 },
    // long overdue (>14 days) → excluded
    { homeworkId: "hw4", title: "Old", classLabel: "8-A", subject: "Sci", submittedCount: 1, totalCount: 30, dueInDays: -20 },
    // no due date → excluded
    { homeworkId: "hw5", title: "Undated", classLabel: "8-A", subject: "Sci", submittedCount: 0, totalCount: 30 },
  ]);
  assertEquals(items.map((i) => i.itemKey), ["teacher:homework:hw1"]);
  const it = items[0]!;
  assertEquals(it.type, "follow_up");
  assertEquals(it.factors.peopleAffected, 5); // 30 - 25 pending
  assertEquals(it.factors.dueInDays, 1);
  assertEquals(it.personas, ["teacher"]);
});

Deno.test("teacher homework: recently-overdue with stragglers still surfaces", () => {
  const items = teacherHomeworkItems([
    { homeworkId: "hw6", title: "Late", classLabel: "8-A", subject: "Sci", submittedCount: 28, totalCount: 30, dueInDays: -3 },
  ]);
  assertEquals(items.length, 1);
  assertEquals(items[0]!.factors.peopleAffected, 2);
});

Deno.test("teacher exams: each unpublished exam becomes a marks-entry deadline", () => {
  const items = teacherExamItems([
    { examId: "ex1", title: "Unit Test 1", classLabel: "8-A", maxMarks: 50 },
  ]);
  assertEquals(items.length, 1);
  assertEquals(items[0]!.type, "deadline");
  assertEquals(items[0]!.itemKey, "teacher:exam:ex1");
  assertEquals(items[0]!.source, "teacher_exam");
});

Deno.test("teacher items are persona-isolated: they never surface to another persona", () => {
  const raw = collectTeacherRawItems({
    attendanceClasses: [
      { classLabel: "8-A", label: "8-A Maths", subject: "Maths", studentCount: 30, isPending: true },
    ],
    exams: [{ examId: "ex1", title: "UT1", classLabel: "8-A", maxMarks: 50 }],
  });
  assert(raw.length >= 2);

  const teacherFeed = buildFeed(raw, "teacher", "2026-07-10T00:00:00Z");
  assert(teacherFeed.items.length >= 2, "teacher sees their items");

  // The SAME raw items must produce an empty feed for principal (persona filter).
  const principalFeed = buildFeed(raw, "principal", "2026-07-10T00:00:00Z");
  assertEquals(principalFeed.items.length, 0);
});

Deno.test("collectTeacherRawItems tolerates absent sources", () => {
  assertEquals(collectTeacherRawItems({}).length, 0);
});
