// Adaptive AI — P3-AI-2 / W2 student rollout: pure generator tests (DB-free).

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  collectStudentRawItems,
  studentAttendanceItems,
  studentHomeworkItems,
} from "./student_sources.ts";
import { buildFeed } from "./priority_engine.ts";

Deno.test("student homework: overdue and due-soon surface; done and far-off do not", () => {
  const items = studentHomeworkItems([
    { homeworkId: "h1", title: "Algebra", subject: "Maths", status: "overdue", dueInDays: -2 },
    { homeworkId: "h2", title: "Essay", subject: "English", status: "pending", dueInDays: 1 }, // due soon
    { homeworkId: "h3", title: "Poster", subject: "Art", status: "pending", dueInDays: 5 }, // too far
    { homeworkId: "h4", title: "Lab", subject: "Science", status: "submitted", dueInDays: 0 }, // done
    { homeworkId: "h5", title: "Old", subject: "Maths", status: "pending" }, // no date
  ]);
  assertEquals(items.map((i) => i.itemKey), ["student:homework:h1", "student:homework:h2"]);
  const overdue = items[0]!;
  assertEquals(overdue.type, "exception");
  assertEquals(overdue.factors.dueInDays, 0); // overdue reads as max-urgency
  const dueSoon = items[1]!;
  assertEquals(dueSoon.type, "deadline");
  assertEquals(dueSoon.factors.dueInDays, 1);
  assertEquals(dueSoon.personas, ["student"]);
});

Deno.test("student attendance: gentle nudge below threshold, nothing otherwise", () => {
  assertEquals(studentAttendanceItems(92).length, 0); // healthy → no nudge
  assertEquals(studentAttendanceItems(null).length, 0); // no data → no nudge
  const low = studentAttendanceItems(64);
  assertEquals(low.length, 1);
  assertEquals(low[0]!.itemKey, "student:attendance");
  assert(low[0]!.detail.includes("64%"));
});

Deno.test("student feed never exposes risk/dropout/predictive language (product safety)", () => {
  const raw = collectStudentRawItems({
    homework: [{ homeworkId: "h1", title: "X", subject: "Maths", status: "overdue" }],
    attendancePercent: 50,
  });
  const blob = JSON.stringify(raw).toLowerCase();
  for (const banned of ["risk", "dropout", "drop-out", "probability", "predict", "at-risk"]) {
    assert(!blob.includes(banned), `student feed must not contain "${banned}"`);
  }
});

Deno.test("student items are persona-isolated (never surface to parent/teacher/principal)", () => {
  const raw = collectStudentRawItems({
    homework: [{ homeworkId: "h1", title: "X", subject: "Maths", status: "overdue" }],
    attendancePercent: 50,
  });
  assertEquals(raw.length, 2);
  assertEquals(buildFeed(raw, "student", "2026-07-10T00:00:00Z").items.length, 2);
  assertEquals(buildFeed(raw, "parent", "2026-07-10T00:00:00Z").items.length, 0);
  assertEquals(buildFeed(raw, "teacher", "2026-07-10T00:00:00Z").items.length, 0);
  assertEquals(buildFeed(raw, "principal", "2026-07-10T00:00:00Z").items.length, 0);
});

Deno.test("collectStudentRawItems tolerates absent sources", () => {
  assertEquals(collectStudentRawItems({}).length, 0);
});
