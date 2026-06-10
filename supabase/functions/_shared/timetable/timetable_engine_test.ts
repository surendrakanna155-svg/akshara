import { assertEquals } from "jsr:@std/assert@1";
import {
  detectAllConflicts,
  generateSectionPeriods,
  validateTimetablePeriods,
} from "./timetable_engine.ts";
import { calculateTeacherWorkload, TEACHER_OVERLOAD_THRESHOLD } from "./timetable_workload.ts";
import { buildSchedulingRecommendations } from "./timetable_scheduling_advisor.ts";

Deno.test("generateSectionPeriods fills weekly grid from catalog assignments", () => {
  const periods = generateSectionPeriods(
    {
      sectionId: "sec-1",
      className: "8",
      sectionName: "A",
      assignments: [{
        assignmentId: "a1",
        teacherId: "t1",
        teacherName: "Teacher A",
        sectionId: "sec-1",
        className: "8",
        sectionName: "A",
        role: "class_teacher",
        isPrimary: true,
      }],
    },
    { periodsPerDay: 6, daysPerWeek: 5 },
  );
  assertEquals(periods.length, 30);
  assertEquals(periods[0]?.subjectLabel, "Mathematics");
});

Deno.test("detectAllConflicts finds teacher and room clashes", () => {
  const conflicts = detectAllConflicts([
    {
      timetableId: "tt-1",
      sectionId: "sec-1",
      dayOfWeek: 1,
      periodNumber: 1,
      subjectLabel: "Math",
      teacherId: "t1",
      teacherAssignmentId: null,
      roomLabel: "Room 201",
    },
    {
      timetableId: "tt-2",
      sectionId: "sec-2",
      dayOfWeek: 1,
      periodNumber: 1,
      subjectLabel: "Science",
      teacherId: "t1",
      teacherAssignmentId: null,
      roomLabel: "Room 201",
    },
  ]);
  assertEquals(conflicts.some((c) => c.type === "teacher"), true);
  assertEquals(conflicts.some((c) => c.type === "room"), true);
});

Deno.test("validateTimetablePeriods reports gaps for incomplete grids", () => {
  const result = validateTimetablePeriods(
    "sec-1",
    "tt-1",
    generateSectionPeriods(
      {
        sectionId: "sec-1",
        className: "5",
        sectionName: "A",
        assignments: [],
      },
      { periodsPerDay: 6, daysPerWeek: 5 },
    ).slice(0, 10),
    6,
    5,
  );
  assertEquals(result.valid, false);
  assertEquals(result.gapCount > 0, true);
});

Deno.test("teacher workload marks overload above threshold", () => {
  const periods = Array.from({ length: TEACHER_OVERLOAD_THRESHOLD + 1 }, (_, i) => ({
    dayOfWeek: 1,
    periodNumber: (i % 6) + 1,
    subjectLabel: "Math",
    teacherId: "t-heavy",
    teacherAssignmentId: null,
    roomLabel: "Room 1",
    teacherName: "Heavy Teacher",
  }));
  const workload = calculateTeacherWorkload(periods);
  assertEquals(workload[0]?.isOverloaded, true);
});

Deno.test("scheduling advisor returns read-only recommendations", () => {
  const recommendations = buildSchedulingRecommendations({
    validation: {
      valid: false,
      conflictCount: 1,
      gapCount: 2,
      conflicts: [{
        type: "teacher",
        message: "Teacher overlap",
        dayOfWeek: 1,
        periodNumber: 2,
        entityId: "t1",
        timetableIds: ["tt-1", "tt-2"],
        sectionIds: ["sec-1", "sec-2"],
      }],
      gaps: [],
    },
    workload: [],
    summary: {
      academicYearId: "yr-1",
      totalTimetables: 2,
      draftCount: 2,
      validatedCount: 0,
      publishedCount: 0,
      conflictCount: 1,
      gapCount: 2,
      overloadedTeacherCount: 0,
    },
  });
  assertEquals(recommendations.length > 0, true);
  assertEquals(recommendations.every((r) => r.readOnly === true), true);
});

Deno.test("timetable router exposes generate and publish routes", async () => {
  const { matchTimetableRoute } = await import("./timetable_router.ts");
  assertEquals(matchTimetableRoute("POST", "/academic/timetables/generate")?.handler.name, "handleGenerateTimetables");
  assertEquals(
    matchTimetableRoute("POST", "/academic/timetables/d0500000-0000-4000-8000-000000000001/publish")?.handler.name,
    "handlePublishTimetable",
  );
});
