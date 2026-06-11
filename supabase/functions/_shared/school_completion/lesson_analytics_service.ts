import type { TenantQueryClient } from "../tenant_db.ts";

export interface SyllabusTopicRow {
  id: string;
  subject_id: string;
  class_name: string;
  topic_name: string;
  sequence_order: number;
  status: string;
}

export interface LessonLogAnalyticsRow {
  id: string;
  teacher_user_id: string;
  class_name: string;
  section_name: string | null;
  subject_id: string | null;
  topic: string;
  outcome: string;
  syllabus_topic_id: string | null;
  recorded_on: string;
}

export interface TeacherLessonAnalytics {
  completedLessons: number;
  pendingLessons: number;
  coveragePercent: number;
  pendingTopics: string[];
  upcomingRisk: string | null;
}

export interface PrincipalCoverageEntry {
  className: string;
  subjectId: string | null;
  coveragePercent: number;
  completedTopics: number;
  totalTopics: number;
  pendingTopics: string[];
}

export async function fetchSyllabusTopics(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  className?: string,
): Promise<SyllabusTopicRow[]> {
  if (className) {
    return await db.queryObject<SyllabusTopicRow>(
      `SELECT id, subject_id, class_name, topic_name, sequence_order, status
       FROM syllabus_topics
       WHERE organization_id = $1 AND school_id = $2 AND class_name = $3
       ORDER BY sequence_order ASC`,
      [orgId, schoolId, className],
    );
  }
  return await db.queryObject<SyllabusTopicRow>(
    `SELECT id, subject_id, class_name, topic_name, sequence_order, status
     FROM syllabus_topics
     WHERE organization_id = $1 AND school_id = $2
     ORDER BY class_name, sequence_order ASC`,
    [orgId, schoolId],
  );
}

export async function fetchLessonLogsForAnalytics(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  teacherUserId?: string,
  className?: string,
): Promise<LessonLogAnalyticsRow[]> {
  const conditions = ["organization_id = $1", "school_id = $2"];
  const params: unknown[] = [orgId, schoolId];
  if (teacherUserId) {
    params.push(teacherUserId);
    conditions.push(`teacher_user_id = $${params.length}`);
  }
  if (className) {
    params.push(className);
    conditions.push(`class_name = $${params.length}`);
  }
  return await db.queryObject<LessonLogAnalyticsRow>(
    `SELECT id, teacher_user_id, class_name, section_name, subject_id, topic,
            outcome, syllabus_topic_id, recorded_on::text
     FROM teacher_lesson_logs
     WHERE ${conditions.join(" AND ")}
     ORDER BY recorded_on DESC`,
    params,
  );
}

export function computeTeacherLessonAnalytics(input: {
  topics: SyllabusTopicRow[];
  logs: LessonLogAnalyticsRow[];
  teacherUserId: string;
}): TeacherLessonAnalytics {
  const teacherLogs = input.logs.filter((l) => l.teacher_user_id === input.teacherUserId);
  const completedLessons = teacherLogs.filter((l) => l.outcome === "completed").length;
  const pendingLessons = teacherLogs.filter((l) => l.outcome !== "completed").length;

  const completedTopicIds = new Set(
    teacherLogs
      .filter((l) => l.syllabus_topic_id && l.outcome === "completed")
      .map((l) => l.syllabus_topic_id!),
  );
  const relevantTopics = input.topics;
  const totalTopics = relevantTopics.length;
  const completedTopics = relevantTopics.filter((t) =>
    completedTopicIds.has(t.id) || t.status === "completed"
  ).length;
  const coveragePercent = totalTopics > 0
    ? Math.round((completedTopics / totalTopics) * 100)
    : (completedLessons > 0 ? 100 : 0);

  const pendingTopics = relevantTopics
    .filter((t) => !completedTopicIds.has(t.id) && t.status !== "completed")
    .slice(0, 10)
    .map((t) => t.topic_name);

  const behindSchedule = coveragePercent < 50 && pendingTopics.length > 3;
  const upcomingRisk = behindSchedule
    ? `${pendingTopics.length} syllabus topics pending with ${coveragePercent}% coverage`
    : null;

  return {
    completedLessons,
    pendingLessons,
    coveragePercent,
    pendingTopics,
    upcomingRisk,
  };
}

export function computePrincipalCoverage(input: {
  topics: SyllabusTopicRow[];
  logs: LessonLogAnalyticsRow[];
}): PrincipalCoverageEntry[] {
  const classNames = [...new Set(input.topics.map((t) => t.class_name))];
  const entries: PrincipalCoverageEntry[] = [];

  for (const className of classNames) {
    const classTopics = input.topics.filter((t) => t.class_name === className);
    const subjectIds = [...new Set(classTopics.map((t) => t.subject_id))];

    for (const subjectId of subjectIds) {
      const subjectTopics = classTopics.filter((t) => t.subject_id === subjectId);
      const completedTopicIds = new Set(
        input.logs
          .filter((l) =>
            l.class_name === className &&
            l.subject_id === subjectId &&
            l.outcome === "completed" &&
            l.syllabus_topic_id
          )
          .map((l) => l.syllabus_topic_id!),
      );
      const completedCount = subjectTopics.filter((t) =>
        completedTopicIds.has(t.id) || t.status === "completed"
      ).length;
      const total = subjectTopics.length;
      const pendingTopics = subjectTopics
        .filter((t) => !completedTopicIds.has(t.id) && t.status !== "completed")
        .slice(0, 5)
        .map((t) => t.topic_name);

      entries.push({
        className,
        subjectId,
        coveragePercent: total > 0 ? Math.round((completedCount / total) * 100) : 0,
        completedTopics: completedCount,
        totalTopics: total,
        pendingTopics,
      });
    }
  }

  return entries.sort((a, b) => a.coveragePercent - b.coveragePercent);
}
