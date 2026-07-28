import type { TenantQueryClient } from "../tenant_db.ts";

/**
 * Repository for the parent insights write path. Owns the SQL the parent
 * insights handlers previously inlined (handlers orchestrate, repositories own
 * SQL). Every function takes the caller's `db` handle so it runs inside the
 * caller's tenant transaction — it opens no new connection.
 */

/** A single-column `language` row from parent_language_preferences. */
export interface LanguagePreferenceRow {
  language: string;
}

/** The generated snapshot id returned by the insert. */
export interface InsightSnapshotIdRow {
  id: string;
}

/** Field bundle persisted into `parent_insight_snapshots` by {@link insertInsightSnapshot}. */
export interface InsightSnapshotInsert {
  organizationId: string;
  schoolId: string;
  studentId: string;
  period: string;
  language: string;
  strengths: unknown;
  weaknesses: unknown;
  attendanceInsights: unknown;
  homeworkInsights: unknown;
  improvementSuggestions: unknown;
  teacherRemarksSummary: string;
  progressSummary: string;
}

/**
 * Read the caller's preferred language for a specific student, falling back to
 * the account-wide (NULL student) preference. Returns the raw rows so the caller
 * applies its own `rows[0]?.language ?? "english"` fallback.
 */
export async function getLanguagePreferenceForStudent(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  userId: string,
  studentId: string,
): Promise<LanguagePreferenceRow[]> {
  return await db.queryObject<LanguagePreferenceRow>(
    `SELECT language FROM parent_language_preferences
           WHERE organization_id = $1 AND school_id = $2 AND user_id = $3
             AND (student_id = $4 OR student_id IS NULL)
           ORDER BY student_id NULLS LAST
           LIMIT 1`,
    [organizationId, schoolId, userId, studentId],
  );
}

/**
 * Read the caller's language preference for the given student id (which may be
 * NULL to fetch the account-wide default). Returns the raw rows so the caller
 * applies its own `rows[0]?.language ?? "english"` fallback.
 */
export async function getLanguagePreference(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  userId: string,
  studentId: string | null,
): Promise<LanguagePreferenceRow[]> {
  return await db.queryObject<LanguagePreferenceRow>(
    `SELECT language FROM parent_language_preferences
         WHERE organization_id = $1 AND school_id = $2 AND user_id = $3
           AND (($4::uuid IS NULL AND student_id IS NULL) OR student_id = $4)
         LIMIT 1`,
    [organizationId, schoolId, userId, studentId],
  );
}

/** Insert a generated parent insight snapshot, returning its new id row(s). */
export async function insertInsightSnapshot(
  db: TenantQueryClient,
  input: InsightSnapshotInsert,
): Promise<InsightSnapshotIdRow[]> {
  return await db.queryObject<InsightSnapshotIdRow>(
    `INSERT INTO parent_insight_snapshots (
           organization_id, school_id, student_id, period, language,
           strengths, weaknesses, attendance_insights, homework_insights,
           improvement_suggestions, teacher_remarks_summary, progress_summary
         ) VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7::jsonb, $8::jsonb, $9::jsonb, $10::jsonb, $11, $12)
         RETURNING id`,
    [
      input.organizationId,
      input.schoolId,
      input.studentId,
      input.period,
      input.language,
      JSON.stringify(input.strengths),
      JSON.stringify(input.weaknesses),
      JSON.stringify(input.attendanceInsights),
      JSON.stringify(input.homeworkInsights),
      JSON.stringify(input.improvementSuggestions),
      input.teacherRemarksSummary,
      input.progressSummary,
    ],
  );
}

/** List a student's most recent insight snapshots (newest first, capped at 20). */
export async function listInsightSnapshots(
  db: TenantQueryClient,
  studentId: string,
): Promise<Record<string, unknown>[]> {
  return await db.queryObject<Record<string, unknown>>(
    `SELECT id, period, language, progress_summary AS "progressSummary",
                strengths, weaknesses, attendance_insights AS "attendanceInsights",
                homework_insights AS "homeworkInsights",
                improvement_suggestions AS "improvementSuggestions",
                teacher_remarks_summary AS "teacherRemarksSummary",
                printable, voice_ready AS "voiceReady", generated_at AS "generatedAt"
         FROM parent_insight_snapshots
         WHERE student_id = $1
         ORDER BY generated_at DESC
         LIMIT 20`,
    [studentId],
  );
}

/** Upsert the caller's language preference for a specific (non-NULL) student. */
export async function upsertLanguagePreferenceForStudent(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  userId: string,
  studentId: string,
  language: string,
): Promise<void> {
  await db.queryObject(
    `INSERT INTO parent_language_preferences (
             organization_id, school_id, user_id, student_id, language
           ) VALUES ($1, $2, $3, $4, $5)
           ON CONFLICT (organization_id, school_id, user_id, student_id)
             WHERE student_id IS NOT NULL
           DO UPDATE SET language = EXCLUDED.language, updated_at = timezone('utc', now())`,
    [organizationId, schoolId, userId, studentId, language],
  );
}

/** Upsert the caller's account-wide (NULL student) language preference. */
export async function upsertLanguagePreferenceDefault(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  userId: string,
  language: string,
): Promise<void> {
  await db.queryObject(
    `INSERT INTO parent_language_preferences (
             organization_id, school_id, user_id, student_id, language
           ) VALUES ($1, $2, $3, NULL, $4)
           ON CONFLICT (organization_id, school_id, user_id)
             WHERE student_id IS NULL
           DO UPDATE SET language = EXCLUDED.language, updated_at = timezone('utc', now())`,
    [organizationId, schoolId, userId, language],
  );
}
