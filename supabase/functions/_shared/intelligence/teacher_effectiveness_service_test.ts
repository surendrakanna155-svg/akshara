import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildTeacherPerformanceInsights,
  buildTeacherPlanningCenter,
  buildTopicMasteryFromLessons,
  computeLessonEffectivenessScore,
  generateStructuredParentMeetingSummary,
} from "./teacher_effectiveness_service.ts";

Deno.test("computeLessonEffectivenessScore weights completion and alignment", () => {
  const completed = computeLessonEffectivenessScore({
    outcome: "completed",
    hasSyllabusTopic: true,
    topicLength: 16,
  });
  assertEquals(completed.completionRate, 100);
  assertEquals(completed.syllabusAlignmentScore, 90);
  assertEquals(completed.effectivenessScore >= 85, true);

  const partial = computeLessonEffectivenessScore({
    outcome: "partial",
    hasSyllabusTopic: false,
    topicLength: 4,
  });
  assertEquals(partial.completionRate, 60);
  assertEquals(partial.syllabusAlignmentScore, 55);
});

Deno.test("buildTopicMasteryFromLessons aggregates by topic", () => {
  const mastery = buildTopicMasteryFromLessons([
    {
      id: "1",
      lessonLogId: "l1",
      className: "Grade 8",
      subjectId: "s1",
      topic: "Fractions",
      effectivenessScore: 80,
      completionRate: 100,
      studentEngagementScore: 75,
      syllabusAlignmentScore: 90,
      recordedOn: "2026-06-01",
    },
    {
      id: "2",
      lessonLogId: "l2",
      className: "Grade 8",
      subjectId: "s1",
      topic: "Fractions",
      effectivenessScore: 70,
      completionRate: 60,
      studentEngagementScore: 65,
      syllabusAlignmentScore: 90,
      recordedOn: "2026-06-02",
    },
  ]);
  assertEquals(mastery.length, 1);
  assertEquals(mastery[0]!.lessonsCompleted, 2);
  assertEquals(mastery[0]!.avgEffectivenessScore, 75);
});

Deno.test("generateStructuredParentMeetingSummary returns printable sections", () => {
  const summary = generateStructuredParentMeetingSummary({
    studentId: "student_1",
    studentName: "Arjun Reddy",
    className: "Grade 8",
    meetingDate: "2026-06-15",
    attendancePercent: 62,
    recentMarks: 54,
    homeworkCompletionRate: 55,
    behaviorNotes: "Participates actively in class discussions.",
  });
  assertEquals(summary.printable, true);
  assertEquals(summary.summary.strengths.length > 0, true);
  assertEquals(summary.summary.concerns.length > 0, true);
  assertEquals(summary.summary.opening.includes("Arjun Reddy"), true);
});

Deno.test("buildTeacherPlanningCenter prioritizes pending topics", () => {
  const center = buildTeacherPlanningCenter({
    pendingTopics: ["Algebra basics", "Linear equations"],
    coveragePercent: 45,
    improvementAreas: ["Increase syllabus topic completion rate"],
  });
  assertEquals(center.pendingTopics.length, 2);
  assertEquals(center.planningItems[0]!.priority, "high");
  assertEquals(center.weeklyFocus, "Algebra basics");
});

Deno.test("buildTeacherPerformanceInsights flags low coverage", () => {
  const insights = buildTeacherPerformanceInsights({
    scores: [
      {
        id: "1",
        lessonLogId: "l1",
        className: "Grade 8",
        subjectId: "s1",
        topic: "Decimals",
        effectivenessScore: 65,
        completionRate: 60,
        studentEngagementScore: 55,
        syllabusAlignmentScore: 55,
        recordedOn: "2026-06-01",
      },
    ],
    coveragePercent: 40,
  });
  assertEquals(insights.improvementAreas.length > 0, true);
  assertEquals(insights.syllabusCoveragePercent, 40);
});
