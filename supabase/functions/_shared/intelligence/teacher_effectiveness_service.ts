import type { TenantQueryClient } from "../tenant_db.ts";
import {
  computeTeacherLessonAnalytics,
  fetchLessonLogsForAnalytics,
  fetchSyllabusTopics,
} from "../school_completion/lesson_analytics_service.ts";

export interface LessonEffectivenessScore {
  id: string;
  lessonLogId: string | null;
  className: string;
  subjectId: string | null;
  topic: string;
  effectivenessScore: number;
  completionRate: number;
  studentEngagementScore: number;
  syllabusAlignmentScore: number;
  recordedOn: string;
}

export interface TopicMasteryEntry {
  className: string;
  subjectId: string | null;
  topicName: string;
  masteryPercent: number;
  lessonsCompleted: number;
  avgEffectivenessScore: number;
}

export interface TeacherPerformanceInsights {
  overallEffectivenessScore: number;
  lessonsCompleted: number;
  syllabusCoveragePercent: number;
  avgStudentEngagement: number;
  strengths: string[];
  improvementAreas: string[];
  recentHighlights: string[];
}

export interface TeacherPlanningItem {
  priority: "high" | "medium" | "low";
  category: string;
  action: string;
  dueHint: string | null;
}

export interface TeacherPlanningCenter {
  weeklyFocus: string;
  pendingTopics: string[];
  upcomingAssessments: string[];
  planningItems: TeacherPlanningItem[];
}

export interface ParentMeetingSummaryInput {
  studentId: string;
  studentName: string;
  className: string;
  meetingDate: string;
  attendancePercent?: number;
  recentMarks?: number;
  homeworkCompletionRate?: number;
  behaviorNotes?: string;
  strengths?: string[];
  concerns?: string[];
  actionItems?: string[];
}

export interface ParentMeetingSummary {
  studentId: string;
  studentName: string;
  className: string;
  meetingDate: string;
  summary: {
    opening: string;
    academicProgress: string;
    attendance: string;
    homework: string;
    behavior: string;
    strengths: string[];
    concerns: string[];
    actionItems: string[];
    closing: string;
  };
  printable: boolean;
}

export function computeLessonEffectivenessScore(input: {
  outcome: string;
  hasSyllabusTopic: boolean;
  topicLength: number;
}): {
  effectivenessScore: number;
  completionRate: number;
  studentEngagementScore: number;
  syllabusAlignmentScore: number;
} {
  const completed = input.outcome === "completed";
  const completionRate = completed ? 100 : input.outcome === "partial" ? 60 : 20;
  const syllabusAlignmentScore = input.hasSyllabusTopic ? 90 : 55;
  const engagementBase = completed ? 80 : 45;
  const topicBonus = Math.min(10, Math.floor(input.topicLength / 8));
  const studentEngagementScore = Math.min(100, engagementBase + topicBonus);
  const effectivenessScore = Math.round(
    completionRate * 0.35 +
      studentEngagementScore * 0.35 +
      syllabusAlignmentScore * 0.3,
  );

  return {
    effectivenessScore,
    completionRate,
    studentEngagementScore,
    syllabusAlignmentScore,
  };
}

export function buildTopicMasteryFromLessons(
  scores: LessonEffectivenessScore[],
): TopicMasteryEntry[] {
  const map = new Map<string, TopicMasteryEntry & { totalScore: number }>();

  for (const score of scores) {
    const key = `${score.className}::${score.subjectId ?? "none"}::${score.topic}`;
    const existing = map.get(key) ?? {
      className: score.className,
      subjectId: score.subjectId,
      topicName: score.topic,
      masteryPercent: 0,
      lessonsCompleted: 0,
      avgEffectivenessScore: 0,
      totalScore: 0,
    };
    existing.lessonsCompleted += 1;
    existing.totalScore += score.effectivenessScore;
    existing.masteryPercent = Math.min(
      100,
      existing.masteryPercent + Math.round(score.completionRate / 2),
    );
    existing.avgEffectivenessScore = Math.round(
      existing.totalScore / existing.lessonsCompleted,
    );
    map.set(key, existing);
  }

  return [...map.values()]
    .map(({ totalScore: _total, ...entry }) => entry)
    .sort((a, b) => a.masteryPercent - b.masteryPercent);
}

export function buildTeacherPerformanceInsights(input: {
  scores: LessonEffectivenessScore[];
  coveragePercent: number;
}): TeacherPerformanceInsights {
  const lessonsCompleted = input.scores.filter((s) => s.completionRate >= 60).length;
  const avgEngagement = input.scores.length > 0
    ? Math.round(
      input.scores.reduce((sum, s) => sum + s.studentEngagementScore, 0) /
        input.scores.length,
    )
    : 0;
  const overallEffectivenessScore = input.scores.length > 0
    ? Math.round(
      input.scores.reduce((sum, s) => sum + s.effectivenessScore, 0) / input.scores.length,
    )
    : 0;

  const strengths: string[] = [];
  const improvementAreas: string[] = [];
  if (input.coveragePercent >= 70) strengths.push("Strong syllabus coverage pace");
  else improvementAreas.push("Increase syllabus topic completion rate");
  if (avgEngagement >= 75) strengths.push("High student engagement in recorded lessons");
  else improvementAreas.push("Plan more interactive lesson segments");
  if (overallEffectivenessScore >= 80) {
    strengths.push("Consistently effective lesson delivery");
  } else {
    improvementAreas.push("Align more lessons to syllabus topics");
  }

  const recentHighlights = input.scores
    .filter((s) => s.effectivenessScore >= 80)
    .slice(0, 5)
    .map((s) => `${s.topic} (${s.className}) — ${s.effectivenessScore}% effective`);

  return {
    overallEffectivenessScore,
    lessonsCompleted,
    syllabusCoveragePercent: input.coveragePercent,
    avgStudentEngagement: avgEngagement,
    strengths,
    improvementAreas,
    recentHighlights,
  };
}

export function buildTeacherPlanningCenter(input: {
  pendingTopics: string[];
  coveragePercent: number;
  improvementAreas: string[];
}): TeacherPlanningCenter {
  const planningItems: TeacherPlanningItem[] = [];

  if (input.pendingTopics.length > 0) {
    planningItems.push({
      priority: "high",
      category: "syllabus",
      action: `Complete pending topic: ${input.pendingTopics[0]}`,
      dueHint: "This week",
    });
  }
  if (input.coveragePercent < 60) {
    planningItems.push({
      priority: "high",
      category: "coverage",
      action: "Schedule catch-up sessions for behind-schedule syllabus units",
      dueHint: "Next 3 days",
    });
  }
  for (const area of input.improvementAreas.slice(0, 2)) {
    planningItems.push({
      priority: "medium",
      category: "improvement",
      action: area,
      dueHint: null,
    });
  }
  if (planningItems.length === 0) {
    planningItems.push({
      priority: "low",
      category: "planning",
      action: "Review upcoming unit plan and prepare formative assessments",
      dueHint: null,
    });
  }

  return {
    weeklyFocus: input.pendingTopics[0] ?? "Maintain current teaching momentum",
    pendingTopics: input.pendingTopics.slice(0, 8),
    upcomingAssessments: ["Unit test — end of month", "Formative quiz — next Friday"],
    planningItems: planningItems.slice(0, 8),
  };
}

export function generateStructuredParentMeetingSummary(
  input: ParentMeetingSummaryInput,
): ParentMeetingSummary {
  const attendance = input.attendancePercent ?? 0;
  const marks = input.recentMarks ?? 0;
  const homework = input.homeworkCompletionRate ?? 0;
  const strengths = input.strengths?.length
    ? input.strengths
    : marks >= 70
    ? ["Consistent academic effort"]
    : ["Shows willingness to improve"];
  const concerns = input.concerns?.length
    ? input.concerns
    : attendance < 75
    ? ["Attendance below school benchmark"]
    : homework < 70
    ? ["Homework completion needs attention"]
    : [];
  const actionItems = input.actionItems?.length
    ? input.actionItems
    : [
      "Maintain daily homework routine",
      "Schedule follow-up review in two weeks",
    ];

  return {
    studentId: input.studentId,
    studentName: input.studentName,
    className: input.className,
    meetingDate: input.meetingDate,
    summary: {
      opening: `Parent meeting for ${input.studentName} (${input.className}) on ${input.meetingDate}.`,
      academicProgress: marks > 0
        ? `Recent assessment average: ${marks}%. ${
          marks >= 75 ? "Performance is on track." : "Additional academic support is recommended."
        }`
        : "Academic progress reviewed based on recent class performance.",
      attendance: attendance > 0
        ? `Attendance: ${attendance}%. ${
          attendance >= 75 ? "Within acceptable range." : "Improvement needed to meet 75% benchmark."
        }`
        : "Attendance discussed with parent.",
      homework: homework > 0
        ? `Homework completion: ${homework}%.`
        : "Homework habits reviewed.",
      behavior: input.behaviorNotes ?? "Behavior and classroom participation discussed positively.",
      strengths,
      concerns,
      actionItems,
      closing: "Thank you for your partnership. We will monitor progress and reconnect as needed.",
    },
    printable: true,
  };
}

export async function buildLessonEffectivenessScores(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  teacherUserId: string,
  className?: string,
): Promise<LessonEffectivenessScore[]> {
  const stored = await db.queryObject<{
    id: string;
    lesson_log_id: string | null;
    class_name: string;
    subject_id: string | null;
    topic: string;
    effectiveness_score: number;
    completion_rate: number;
    student_engagement_score: number;
    syllabus_alignment_score: number;
    computed_at: string;
  }>(
    `SELECT id, lesson_log_id, class_name, subject_id, topic,
            effectiveness_score, completion_rate, student_engagement_score,
            syllabus_alignment_score, computed_at::text
     FROM teacher_lesson_effectiveness
     WHERE organization_id = $1 AND school_id = $2 AND teacher_user_id = $3
       ${className ? "AND class_name = $4" : ""}
     ORDER BY computed_at DESC LIMIT 50`,
    className ? [orgId, schoolId, teacherUserId, className] : [orgId, schoolId, teacherUserId],
  );

  if (stored.length > 0) {
    return stored.map((row) => ({
      id: row.id,
      lessonLogId: row.lesson_log_id,
      className: row.class_name,
      subjectId: row.subject_id,
      topic: row.topic,
      effectivenessScore: row.effectiveness_score,
      completionRate: row.completion_rate,
      studentEngagementScore: row.student_engagement_score,
      syllabusAlignmentScore: row.syllabus_alignment_score,
      recordedOn: row.computed_at,
    }));
  }

  const logs = await fetchLessonLogsForAnalytics(db, orgId, schoolId, teacherUserId, className);
  return logs.slice(0, 30).map((log) => {
    const scores = computeLessonEffectivenessScore({
      outcome: log.outcome,
      hasSyllabusTopic: Boolean(log.syllabus_topic_id),
      topicLength: log.topic.length,
    });
    return {
      id: log.id,
      lessonLogId: log.id,
      className: log.class_name,
      subjectId: log.subject_id,
      topic: log.topic,
      effectivenessScore: scores.effectivenessScore,
      completionRate: scores.completionRate,
      studentEngagementScore: scores.studentEngagementScore,
      syllabusAlignmentScore: scores.syllabusAlignmentScore,
      recordedOn: log.recorded_on,
    };
  });
}

export async function buildTopicMasteryAnalytics(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  teacherUserId: string,
): Promise<TopicMasteryEntry[]> {
  const stored = await db.queryObject<{
    class_name: string;
    subject_id: string | null;
    topic_name: string;
    mastery_percent: number;
    lessons_completed: number;
    avg_effectiveness_score: number;
  }>(
    `SELECT class_name, subject_id, topic_name, mastery_percent,
            lessons_completed, avg_effectiveness_score
     FROM teacher_topic_mastery
     WHERE organization_id = $1 AND school_id = $2 AND teacher_user_id = $3
     ORDER BY mastery_percent ASC`,
    [orgId, schoolId, teacherUserId],
  );

  if (stored.length > 0) {
    return stored.map((row) => ({
      className: row.class_name,
      subjectId: row.subject_id,
      topicName: row.topic_name,
      masteryPercent: row.mastery_percent,
      lessonsCompleted: row.lessons_completed,
      avgEffectivenessScore: row.avg_effectiveness_score,
    }));
  }

  const scores = await buildLessonEffectivenessScores(db, orgId, schoolId, teacherUserId);
  return buildTopicMasteryFromLessons(scores);
}

export async function buildTeacherPerformanceInsightsForUser(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  teacherUserId: string,
): Promise<TeacherPerformanceInsights> {
  const [topics, logs, scores] = await Promise.all([
    fetchSyllabusTopics(db, orgId, schoolId),
    fetchLessonLogsForAnalytics(db, orgId, schoolId, teacherUserId),
    buildLessonEffectivenessScores(db, orgId, schoolId, teacherUserId),
  ]);
  const lessonAnalytics = computeTeacherLessonAnalytics({ topics, logs, teacherUserId });
  return buildTeacherPerformanceInsights({
    scores,
    coveragePercent: lessonAnalytics.coveragePercent,
  });
}

export async function buildTeacherPlanningCenterForUser(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  teacherUserId: string,
): Promise<TeacherPlanningCenter> {
  const [topics, logs, scores] = await Promise.all([
    fetchSyllabusTopics(db, orgId, schoolId),
    fetchLessonLogsForAnalytics(db, orgId, schoolId, teacherUserId),
    buildLessonEffectivenessScores(db, orgId, schoolId, teacherUserId),
  ]);
  const lessonAnalytics = computeTeacherLessonAnalytics({ topics, logs, teacherUserId });
  const insights = buildTeacherPerformanceInsights({
    scores,
    coveragePercent: lessonAnalytics.coveragePercent,
  });
  return buildTeacherPlanningCenter({
    pendingTopics: lessonAnalytics.pendingTopics,
    coveragePercent: lessonAnalytics.coveragePercent,
    improvementAreas: insights.improvementAreas,
  });
}

export async function storeParentMeetingSummary(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  teacherUserId: string,
  summary: ParentMeetingSummary,
): Promise<{ id: string }> {
  const rows = await db.queryObject<{ id: string }>(
    `INSERT INTO parent_meeting_summaries (
       organization_id, school_id, teacher_user_id, student_id, meeting_date, summary_json
     ) VALUES ($1, $2, $3, $4, $5::date, $6::jsonb)
     RETURNING id`,
    [
      orgId,
      schoolId,
      teacherUserId,
      summary.studentId,
      summary.meetingDate,
      JSON.stringify(summary.summary),
    ],
  );
  return { id: rows[0]!.id };
}
