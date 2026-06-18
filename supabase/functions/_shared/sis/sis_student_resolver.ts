import type { TenantQueryClient } from "../tenant_db.ts";

const UUID_SEGMENT =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Resolves a path identifier to canonical students.id (UUID).
 * Accepts UUID, student_code (SIS-STU-*), or admission_number.
 */
export async function resolveStudentId(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  idOrCode: string,
): Promise<string | null> {
  const trimmed = idOrCode.trim();
  if (!trimmed) return null;

  if (UUID_SEGMENT.test(trimmed)) {
    const rows = await db.queryObject<{ id: string }>(
      `SELECT id FROM students
       WHERE id = $1::uuid AND organization_id = $2 AND school_id = $3`,
      [trimmed, organizationId, schoolId],
    );
    return rows[0]?.id ?? null;
  }

  const rows = await db.queryObject<{ id: string }>(
    `SELECT s.id
     FROM students s
     LEFT JOIN student_profiles sp
       ON sp.student_id = s.id
      AND sp.organization_id = s.organization_id
      AND sp.school_id = s.school_id
     WHERE s.organization_id = $1
       AND s.school_id = $2
       AND (s.student_code = $3 OR sp.admission_number = $3)
     LIMIT 1`,
    [organizationId, schoolId, trimmed],
  );
  return rows[0]?.id ?? null;
}
