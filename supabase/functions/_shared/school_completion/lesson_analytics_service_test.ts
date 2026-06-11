import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  computePrincipalCoverage,
  computeTeacherLessonAnalytics,
} from "./lesson_analytics_service.ts";

Deno.test("computeTeacherLessonAnalytics calculates coverage from logs and topics", () => {
  const result = computeTeacherLessonAnalytics({
    teacherUserId: "t1",
    topics: [
      { id: "top1", subject_id: "s1", class_name: "G7", topic_name: "A", sequence_order: 1, status: "pending" },
      { id: "top2", subject_id: "s1", class_name: "G7", topic_name: "B", sequence_order: 2, status: "pending" },
      { id: "top3", subject_id: "s1", class_name: "G7", topic_name: "C", sequence_order: 3, status: "pending" },
      { id: "top4", subject_id: "s1", class_name: "G7", topic_name: "D", sequence_order: 4, status: "pending" },
    ],
    logs: [
      {
        id: "l1",
        teacher_user_id: "t1",
        class_name: "G7",
        section_name: null,
        subject_id: "s1",
        topic: "A",
        outcome: "completed",
        syllabus_topic_id: "top1",
        recorded_on: "2026-06-01",
      },
    ],
  });
  assertEquals(result.completedLessons, 1);
  assertEquals(result.coveragePercent, 25);
  assertEquals(result.pendingTopics.length, 3);
});

Deno.test("computePrincipalCoverage groups by class and subject", () => {
  const coverage = computePrincipalCoverage({
    topics: [
      { id: "top1", subject_id: "s1", class_name: "G7", topic_name: "A", sequence_order: 1, status: "completed" },
      { id: "top2", subject_id: "s1", class_name: "G7", topic_name: "B", sequence_order: 2, status: "pending" },
    ],
    logs: [],
  });
  assertEquals(coverage.length, 1);
  assertEquals(coverage[0]!.coveragePercent, 50);
});
