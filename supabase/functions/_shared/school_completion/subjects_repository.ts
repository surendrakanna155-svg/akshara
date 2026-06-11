import type { TenantQueryClient } from "../tenant_db.ts";

export interface SubjectRow {
  id: string;
  organization_id: string;
  school_id: string;
  subject_code: string;
  subject_name: string;
  category: string;
  grade_labels: unknown;
  status: string;
  created_at: string;
  updated_at: string;
}

export interface CreateSubjectInput {
  subjectCode: string;
  subjectName: string;
  category?: string;
  gradeLabels?: string[];
  status?: string;
  createdBy: string;
}

export interface UpdateSubjectInput {
  subjectName?: string;
  category?: string;
  gradeLabels?: string[];
  status?: string;
}

export async function listSubjects(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
): Promise<SubjectRow[]> {
  return await db.queryObject<SubjectRow>(
    `SELECT * FROM academic_subjects
     WHERE organization_id = $1 AND school_id = $2
     ORDER BY subject_name ASC`,
    [orgId, schoolId],
  );
}

export async function createSubject(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  input: CreateSubjectInput,
): Promise<SubjectRow> {
  const rows = await db.queryObject<SubjectRow>(
    `INSERT INTO academic_subjects (
       organization_id, school_id, subject_code, subject_name, category, grade_labels, status, created_by
     ) VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7, $8)
     RETURNING *`,
    [
      orgId,
      schoolId,
      input.subjectCode.trim(),
      input.subjectName.trim(),
      input.category ?? "core",
      JSON.stringify(input.gradeLabels ?? []),
      input.status ?? "active",
      input.createdBy,
    ],
  );
  return rows[0]!;
}

export async function updateSubject(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  subjectId: string,
  input: UpdateSubjectInput,
): Promise<SubjectRow | null> {
  const rows = await db.queryObject<SubjectRow>(
    `UPDATE academic_subjects
     SET subject_name = coalesce($4, subject_name),
         category = coalesce($5, category),
         grade_labels = coalesce($6::jsonb, grade_labels),
         status = coalesce($7, status),
         updated_at = timezone('utc', now())
     WHERE id = $1 AND organization_id = $2 AND school_id = $3
     RETURNING *`,
    [
      subjectId,
      orgId,
      schoolId,
      input.subjectName ?? null,
      input.category ?? null,
      input.gradeLabels ? JSON.stringify(input.gradeLabels) : null,
      input.status ?? null,
    ],
  );
  return rows[0] ?? null;
}

export function subjectToApi(row: SubjectRow) {
  return {
    id: row.id,
    subjectCode: row.subject_code,
    subjectName: row.subject_name,
    category: row.category,
    gradeLabels: Array.isArray(row.grade_labels) ? row.grade_labels : [],
    status: row.status,
  };
}
