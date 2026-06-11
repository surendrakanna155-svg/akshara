import type { TenantQueryClient } from "../tenant_db.ts";

export interface LessonLogRow {
  id: string;
  organization_id: string;
  school_id: string;
  teacher_user_id: string;
  class_name: string;
  section_name: string | null;
  subject_id: string | null;
  topic: string;
  outcome: string;
  notes: string | null;
  recorded_on: string;
  created_at: string;
}

export interface CreateLessonLogInput {
  className: string;
  sectionName?: string;
  subjectId?: string;
  topic: string;
  outcome?: string;
  notes?: string;
  recordedOn?: string;
  teacherUserId: string;
  createdBy: string;
}

export async function listLessonLogs(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  filters: { className?: string; teacherUserId?: string } = {},
): Promise<LessonLogRow[]> {
  const args: unknown[] = [orgId, schoolId];
  let where = "organization_id = $1 AND school_id = $2";
  if (filters.className) {
    args.push(filters.className);
    where += ` AND class_name = $${args.length}`;
  }
  if (filters.teacherUserId) {
    args.push(filters.teacherUserId);
    where += ` AND teacher_user_id = $${args.length}`;
  }
  return await db.queryObject<LessonLogRow>(
    `SELECT * FROM teacher_lesson_logs
     WHERE ${where}
     ORDER BY recorded_on DESC, created_at DESC
     LIMIT 100`,
    args,
  );
}

export async function createLessonLog(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  input: CreateLessonLogInput,
): Promise<LessonLogRow> {
  const rows = await db.queryObject<LessonLogRow>(
    `INSERT INTO teacher_lesson_logs (
       organization_id, school_id, teacher_user_id, class_name, section_name,
       subject_id, topic, outcome, notes, recorded_on, created_by
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, coalesce($10::date, CURRENT_DATE), $11)
     RETURNING *`,
    [
      orgId,
      schoolId,
      input.teacherUserId,
      input.className.trim(),
      input.sectionName ?? null,
      input.subjectId ?? null,
      input.topic.trim(),
      input.outcome ?? "completed",
      input.notes ?? null,
      input.recordedOn ?? null,
      input.createdBy,
    ],
  );
  return rows[0]!;
}

export function lessonLogToApi(row: LessonLogRow) {
  return {
    id: row.id,
    teacherUserId: row.teacher_user_id,
    className: row.class_name,
    sectionName: row.section_name,
    subjectId: row.subject_id,
    topic: row.topic,
    outcome: row.outcome,
    notes: row.notes,
    recordedOn: row.recorded_on,
  };
}
