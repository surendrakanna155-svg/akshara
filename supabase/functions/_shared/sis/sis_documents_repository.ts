import type { TenantQueryClient } from "../tenant_db.ts";

export interface StudentDocumentRow {
  id: string;
  organization_id: string;
  school_id: string;
  student_id: string;
  document_type: string;
  status: string;
  file_uri: string | null;
  uploaded_by: string | null;
  uploaded_at: string;
  verified_by: string | null;
  verified_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface CreateStudentDocumentInput {
  documentType: string;
  status?: string;
  fileUri?: string | null;
  uploadedBy: string;
}

export async function listStudentDocuments(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
): Promise<StudentDocumentRow[]> {
  return await db.queryObject<StudentDocumentRow>(
    `SELECT * FROM student_documents
     WHERE organization_id = $1 AND school_id = $2 AND student_id = $3::uuid
     ORDER BY uploaded_at DESC`,
    [organizationId, schoolId, studentId],
  );
}

export async function createStudentDocument(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
  input: CreateStudentDocumentInput,
): Promise<StudentDocumentRow> {
  const rows = await db.queryObject<StudentDocumentRow>(
    `INSERT INTO student_documents (
       organization_id, school_id, student_id,
       document_type, status, file_uri, uploaded_by
     ) VALUES ($1, $2, $3::uuid, $4, $5, $6, $7::uuid)
     RETURNING *`,
    [
      organizationId,
      schoolId,
      studentId,
      input.documentType,
      input.status ?? "pending",
      input.fileUri ?? null,
      input.uploadedBy,
    ],
  );
  return rows[0]!;
}

export function documentToApi(row: StudentDocumentRow): Record<string, unknown> {
  return {
    id: row.id,
    type: row.document_type,
    documentType: row.document_type,
    status: row.status,
    fileUri: row.file_uri,
    uploadedAt: row.uploaded_at,
    verifiedAt: row.verified_at,
  };
}
