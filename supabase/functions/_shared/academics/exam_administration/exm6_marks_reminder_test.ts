// EXM-6 — the marks-entry-overdue teacher reminder digest builder.
//
// `buildMarksReminder` is the pure core of the reminder: given the exams whose
// marks-entry deadline has passed with marks still pending, it returns the
// title + body scheduled to `all_teachers` on the XCT-2 rail — or null when
// nothing is overdue (so the handler schedules nothing, never a false reminder).

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { buildMarksReminder } from "./exam_administration_handlers.ts";
import type { OverdueMarksEntryRow } from "./exam_administration_repository.ts";

function row(over: Partial<OverdueMarksEntryRow> = {}): OverdueMarksEntryRow {
  return {
    exam_id: "exam_1",
    title: "Term 2 Maths",
    subject: "Mathematics",
    grade: "8",
    section_name: "A",
    marks_entry_deadline: "2026-07-01T10:00:00.000Z",
    entered_count: 10,
    total_count: 30,
    ...over,
  };
}

Deno.test("EXM-6: no overdue exams → no reminder (null, so nothing is scheduled)", () => {
  assertEquals(buildMarksReminder([]), null);
});

Deno.test("EXM-6: a single overdue exam → singular title + subject/class/pending/due digest", () => {
  const reminder = buildMarksReminder([row()]);
  assertEquals(reminder?.title, "Marks entry overdue");
  // 30 total − 10 entered = 20 pending; due date is the deadline's calendar day.
  assertEquals(
    reminder?.body,
    "Marks entry is past its deadline for the following. Please enter the pending marks:\n" +
      "• Mathematics (Class 8-A) — 20 pending, due 2026-07-01",
  );
});

Deno.test("EXM-6: multiple overdue exams → count in the title + one line each", () => {
  const reminder = buildMarksReminder([
    row(),
    row({
      exam_id: "exam_2",
      subject: "Science",
      grade: "9",
      section_name: "B",
      entered_count: 0,
      total_count: 25,
      marks_entry_deadline: "2026-06-28T10:00:00.000Z",
    }),
  ]);
  assertEquals(reminder?.title, "Marks entry overdue — 2 exams");
  assertEquals(
    reminder?.body.includes("• Mathematics (Class 8-A) — 20 pending, due 2026-07-01"),
    true,
  );
  assertEquals(
    reminder?.body.includes("• Science (Class 9-B) — 25 pending, due 2026-06-28"),
    true,
  );
});

Deno.test("EXM-6: a section-less exam labels the class by bare grade", () => {
  const reminder = buildMarksReminder([row({ section_name: "" })]);
  assertEquals(reminder?.body.includes("(Class 8)"), true);
});
