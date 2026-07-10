// Adaptive AI — P3-AI-2 / W2.S: Universal School Search repository (DB-driven).
//
// Deterministic, RLS-scoped candidate fetch — ZERO model calls. Matches the
// student identity fields across students (+ profile + current enrollment) using
// the indexed prefix/exact paths of the ranking ladder (decision 7/10). RLS
// already scopes to the tenant/school; the explicit org/school predicates add
// defense-in-depth and let the indexes do the work.

import type { TenantQueryClient } from "../tenant_db.ts";
import type { StudentCandidate } from "./search_ranking.ts";

/** How many raw candidates to consider before the pure ranker caps the display
 * set — a few times the display limit so ranking has material to order. */
function candidateCap(displayLimit: number): number {
  return Math.min(60, Math.max(displayLimit * 3, 15));
}

interface StudentRow {
  id: string;
  display_name: string;
  student_code: string;
  status: string;
  admission_number: string | null;
  public_student_id: string | null;
  class_name: string | null;
  section_name: string | null;
  roll_number: string | null;
}

/** Fetch student candidates whose identity fields match `query`. Prefix match on
 * codes/admission/public-id/name; exact on roll; partial (contains) on name as
 * the last-resort path. Returns the count of matches (for the group total) and
 * the capped candidate rows. */
export async function searchStudents(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  query: string,
  displayLimit: number,
): Promise<{ candidates: StudentCandidate[]; total: number }> {
  const cap = candidateCap(displayLimit);
  const q = query.trim();
  const rows = await db.queryObject<StudentRow>(
    `SELECT s.id::text AS id, s.display_name, s.student_code, s.status,
            sp.admission_number, sp.public_student_id,
            e.class_name, e.section_name, e.roll_number
       FROM students s
       LEFT JOIN student_profiles sp ON sp.student_id = s.id
       LEFT JOIN sis_student_enrollments e
         ON e.student_id = s.id AND e.is_current = true
      WHERE s.organization_id = $1 AND s.school_id = $2
        AND (
          lower(s.display_name) LIKE lower($3) || '%'
          OR lower(s.display_name) LIKE '%' || lower($3) || '%'
          OR lower(s.student_code) LIKE lower($3) || '%'
          OR lower(sp.admission_number) LIKE lower($3) || '%'
          OR lower(sp.public_student_id) LIKE lower($3) || '%'
          OR lower(e.roll_number) = lower($3)
        )
      ORDER BY s.display_name
      LIMIT $4`,
    [organizationId, schoolId, q, cap],
  );

  const candidates: StudentCandidate[] = rows.map((r) => ({
    id: r.id,
    displayName: r.display_name,
    studentCode: r.student_code,
    admissionNumber: r.admission_number,
    publicStudentId: r.public_student_id,
    className: r.class_name,
    sectionName: r.section_name,
    rollNumber: r.roll_number,
    status: r.status,
  }));

  return { candidates, total: candidates.length };
}
