import type { TenantQueryClient } from "../tenant_db.ts";
import { documentToApi, listStudentDocuments } from "./sis_documents_repository.ts";
import { resolveStudentId } from "./sis_student_resolver.ts";
import { getStudent, StudentNotFoundError, type StudentDetailData } from "./sis_students_repository.ts";

export async function loadStudentDetailByIdOrCode(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  idOrCode: string,
): Promise<StudentDetailData | null> {
  const resolved = await resolveStudentId(db, organizationId, schoolId, idOrCode);
  if (!resolved) return null;
  return getStudent(db, organizationId, schoolId, resolved);
}

export async function loadStudentDocumentsByIdOrCode(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  idOrCode: string,
): Promise<Record<string, unknown>[]> {
  const resolved = await resolveStudentId(db, organizationId, schoolId, idOrCode);
  if (!resolved) throw new StudentNotFoundError(idOrCode);
  const rows = await listStudentDocuments(db, organizationId, schoolId, resolved);
  return rows.map(documentToApi);
}
