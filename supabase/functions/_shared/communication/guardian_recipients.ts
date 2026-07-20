import type { TenantQueryClient } from "../tenant_db.ts";

/**
 * PRA-P0-16 / P1-44 (S5): resolve a set of SIS student codes to the DISTINCT
 * user ids of their ACTIVE guardians, scoped to one org+school. This is the ONE
 * place student→guardian delivery resolution lives, shared by teacher
 * parent-communication (P0-16 "Send to parent") and transport route-delay alerts
 * (P1-44), so both notify exactly the affected students' guardians — never the
 * whole school.
 *
 * `sisStudentIds` are `students.student_code` values (the SIS-facing id, unique
 * per school — see migration 20260609100000). Codes are de-duplicated and blanks
 * dropped before the query; an empty input returns `[]` without a round-trip.
 * Only `status = 'active'` guardian links are returned (an unlinked/inactive
 * guardian never gets notified), matching the active-link RLS hardening in
 * migration 20260900000012. Callers use the returned count to set an HONEST
 * status/recipient count rather than a hardcoded one.
 */
export async function guardianUserIdsForStudents(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  sisStudentIds: string[],
): Promise<string[]> {
  const codes = Array.from(
    new Set(
      sisStudentIds
        .map((code) => String(code ?? "").trim())
        .filter((code) => code.length > 0),
    ),
  );
  if (codes.length === 0) return [];
  const rows = await db.queryObject<{ guardian_user_id: string }>(
    `SELECT DISTINCT sg.guardian_user_id
       FROM students s
       JOIN student_guardians sg ON sg.student_id = s.id
      WHERE s.organization_id = $1
        AND s.school_id = $2
        AND s.student_code = ANY($3::text[])
        AND sg.status = 'active'`,
    [organizationId, schoolId, codes],
  );
  return rows.map((row) => row.guardian_user_id);
}
