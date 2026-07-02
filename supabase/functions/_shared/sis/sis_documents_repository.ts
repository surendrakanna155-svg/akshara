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

export interface VerifyStudentDocumentInput {
  status: "verified" | "rejected";
  verifierId: string;
  note?: string | null;
}

export class StudentDocumentNotFoundError extends Error {
  constructor(docId: string) {
    super(`Student document not found: ${docId}`);
    this.name = "StudentDocumentNotFoundError";
  }
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

/**
 * SIS-3 — verify (or reject) a previously uploaded student document. Stamps
 * `status`, `verified_by`, and `verified_at` on the row. Scoped to org+school so
 * a caller can never touch another school's row (RLS also enforces this, but the
 * explicit WHERE keeps the 404 semantics deterministic without relying on RLS).
 * Throws {@link StudentDocumentNotFoundError} when no row matches (404).
 *
 * `note` is accepted for API symmetry but there is no column to persist it on
 * `student_documents`; it is surfaced only through the emitted audit metadata.
 */
export async function verifyStudentDocument(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  docId: string,
  input: VerifyStudentDocumentInput,
): Promise<StudentDocumentRow> {
  const rows = await db.queryObject<StudentDocumentRow>(
    `UPDATE student_documents
        SET status = $4,
            verified_by = $5::uuid,
            verified_at = timezone('utc', now())
      WHERE id = $1::uuid
        AND organization_id = $2
        AND school_id = $3
      RETURNING *`,
    [docId, organizationId, schoolId, input.status, input.verifierId],
  );
  const row = rows[0];
  if (!row) throw new StudentDocumentNotFoundError(docId);
  return row;
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
    verifiedBy: row.verified_by,
  };
}
