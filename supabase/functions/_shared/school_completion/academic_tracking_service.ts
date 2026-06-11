import type { TenantQueryClient } from "../tenant_db.ts";

export interface PendingSyllabusAlert {
  className: string;
  subjectId: string;
  chapterName: string | null;
  topicName: string;
  daysPending: number;
}

export interface TeacherProgressDashboard {
  topicsCompleted: number;
  topicsPending: number;
  chaptersCompleted: number;
  chaptersTotal: number;
  coveragePercent: number;
  pendingAlerts: PendingSyllabusAlert[];
}

export interface PrincipalAcademicDashboard {
  classCoverage: Array<{
    className: string;
    subjectId: string;
    coveragePercent: number;
    pendingTopics: number;
  }>;
  overallCoveragePercent: number;
}

export async function completeTopic(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  input: {
    topicId: string;
    teacherUserId: string;
    lessonLogId?: string;
  },
): Promise<void> {
  await db.queryObject(
    `INSERT INTO syllabus_topic_completions (
       organization_id, school_id, topic_id, teacher_user_id, lesson_log_id
     ) VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (organization_id, school_id, topic_id, teacher_user_id)
     DO UPDATE SET lesson_log_id = EXCLUDED.lesson_log_id, completed_at = now()`,
    [orgId, schoolId, input.topicId, input.teacherUserId, input.lessonLogId ?? null],
  );
  await db.queryObject(
    `UPDATE syllabus_topics SET status = 'completed', updated_at = now()
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [input.topicId, orgId, schoolId],
  );

  const topic = await db.queryObject<{ chapter_id: string | null }>(
    `SELECT chapter_id FROM syllabus_topics WHERE id = $1`,
    [input.topicId],
  );
  const chapterId = topic[0]?.chapter_id;
  if (!chapterId) return;

  const pending = await db.queryObject<{ count: string }>(
    `SELECT count(*)::text AS count FROM syllabus_topics
     WHERE chapter_id = $1 AND status != 'completed'`,
    [chapterId],
  );
  if (Number(pending[0]?.count ?? 0) === 0) {
    await db.queryObject(
      `UPDATE syllabus_chapters SET status = 'completed', updated_at = now() WHERE id = $1`,
      [chapterId],
    );
  } else {
    await db.queryObject(
      `UPDATE syllabus_chapters SET status = 'in_progress', updated_at = now() WHERE id = $1`,
      [chapterId],
    );
  }
}

export async function buildTeacherProgressDashboard(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  teacherUserId: string,
): Promise<TeacherProgressDashboard> {
  const topics = await db.queryObject<{ id: string; status: string; topic_name: string; class_name: string; subject_id: string }>(
    `SELECT t.id, t.status, t.topic_name, t.class_name, t.subject_id
     FROM syllabus_topics t
     WHERE t.organization_id = $1 AND t.school_id = $2`,
    [orgId, schoolId],
  );
  const completions = await db.queryObject<{ topic_id: string }>(
    `SELECT topic_id FROM syllabus_topic_completions
     WHERE organization_id = $1 AND school_id = $2 AND teacher_user_id = $3`,
    [orgId, schoolId, teacherUserId],
  );
  const completedIds = new Set(completions.map((c) => c.topic_id));

  const chapters = await db.queryObject<{ status: string }>(
    `SELECT status FROM syllabus_chapters
     WHERE organization_id = $1 AND school_id = $2`,
    [orgId, schoolId],
  );

  const topicsCompleted = topics.filter((t) => completedIds.has(t.id) || t.status === "completed").length;
  const topicsPending = topics.length - topicsCompleted;
  const chaptersCompleted = chapters.filter((c) => c.status === "completed").length;

  const pendingAlerts: PendingSyllabusAlert[] = topics
    .filter((t) => !completedIds.has(t.id) && t.status !== "completed")
    .slice(0, 10)
    .map((t) => ({
      className: t.class_name,
      subjectId: t.subject_id,
      chapterName: null,
      topicName: t.topic_name,
      daysPending: 7,
    }));

  const coveragePercent = topics.length > 0
    ? Math.round((topicsCompleted / topics.length) * 100)
    : 0;

  return {
    topicsCompleted,
    topicsPending,
    chaptersCompleted,
    chaptersTotal: chapters.length,
    coveragePercent,
    pendingAlerts,
  };
}

export async function buildPrincipalAcademicDashboard(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
): Promise<PrincipalAcademicDashboard> {
  const topics = await db.queryObject<{ class_name: string; subject_id: string; status: string }>(
    `SELECT class_name, subject_id, status FROM syllabus_topics
     WHERE organization_id = $1 AND school_id = $2`,
    [orgId, schoolId],
  );

  const classNames = [...new Set(topics.map((t) => t.class_name))];
  const classCoverage: PrincipalAcademicDashboard["classCoverage"] = [];

  for (const className of classNames) {
    const subjectIds = [...new Set(topics.filter((t) => t.class_name === className).map((t) => t.subject_id))];
    for (const subjectId of subjectIds) {
      const subjectTopics = topics.filter((t) => t.class_name === className && t.subject_id === subjectId);
      const completed = subjectTopics.filter((t) => t.status === "completed").length;
      const total = subjectTopics.length;
      classCoverage.push({
        className,
        subjectId,
        coveragePercent: total > 0 ? Math.round((completed / total) * 100) : 0,
        pendingTopics: total - completed,
      });
    }
  }

  const overall = classCoverage.length > 0
    ? Math.round(classCoverage.reduce((s, c) => s + c.coveragePercent, 0) / classCoverage.length)
    : 0;

  return { classCoverage, overallCoveragePercent: overall };
}
