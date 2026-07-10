// Adaptive AI — P3-AI-2 / W2.S: Universal School Search repository (DB-driven).
//
// Deterministic, RLS-scoped candidate fetch — ZERO model calls. Matches the
// student identity fields across students (+ profile + current enrollment) using
// the indexed prefix/exact paths of the ranking ladder (decision 7/10). RLS
// already scopes to the tenant/school; the explicit org/school predicates add
// defense-in-depth and let the indexes do the work.

import type { TenantQueryClient } from "../tenant_db.ts";
import type {
  AdmissionCandidate,
  StaffCandidate,
  StudentCandidate,
} from "./search_ranking.ts";

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
  total_matches: number;
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
            e.class_name, e.section_name, e.roll_number,
            count(*) OVER()::int AS total_matches
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
      -- Fetch in MATCH-PRIORITY order (mirrors classifyStudentMatch) so the LIMIT
      -- keeps the highest-priority matches. Ordering by name alone truncated an
      -- exact admission#/ID match whose name sorts late — the #1 search promise.
      ORDER BY
        CASE
          WHEN lower(sp.admission_number) LIKE lower($3) || '%' THEN 0
          WHEN lower(s.student_code) LIKE lower($3) || '%'
            OR lower(sp.public_student_id) LIKE lower($3) || '%' THEN 1
          WHEN lower(e.roll_number) = lower($3) THEN 3
          WHEN lower(s.display_name) LIKE lower($3) || '%' THEN 4
          ELSE 5
        END,
        s.display_name
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

  // total = all matches (window count before LIMIT), not the post-cap slice.
  return { candidates, total: rows[0]?.total_matches ?? candidates.length };
}

interface StaffRow {
  id: string;
  display_name: string;
  employee_code: string;
  email: string | null;
  phone: string | null;
  status: string;
  total_matches: number;
}

/** Fetch staff candidates by name/code/contact. Requires viewEmployees (gated in
 * the handler); phone/email are staff contact fields that permission authorizes. */
export async function searchStaff(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  query: string,
  displayLimit: number,
): Promise<{ candidates: StaffCandidate[]; total: number }> {
  const cap = candidateCap(displayLimit);
  const q = query.trim();
  const rows = await db.queryObject<StaffRow>(
    `SELECT id::text AS id, display_name, employee_code, email, phone, status,
            count(*) OVER()::int AS total_matches
       FROM employees
      WHERE organization_id = $1 AND school_id = $2
        AND (
          lower(display_name) LIKE lower($3) || '%'
          OR lower(display_name) LIKE '%' || lower($3) || '%'
          OR lower(employee_code) LIKE lower($3) || '%'
          OR lower(email) LIKE lower($3) || '%'
          OR replace(phone, ' ', '') LIKE '%' || replace($3, ' ', '') || '%'
        )
      ORDER BY
        CASE
          WHEN lower(employee_code) LIKE lower($3) || '%' THEN 1
          WHEN replace(phone, ' ', '') LIKE '%' || replace($3, ' ', '') || '%'
            OR lower(email) LIKE lower($3) || '%' THEN 2
          WHEN lower(display_name) LIKE lower($3) || '%' THEN 4
          ELSE 5
        END,
        display_name
      LIMIT $4`,
    [organizationId, schoolId, q, cap],
  );
  const candidates: StaffCandidate[] = rows.map((r) => ({
    id: r.id,
    displayName: r.display_name,
    employeeCode: r.employee_code,
    email: r.email,
    phone: r.phone,
    status: r.status,
  }));
  return { candidates, total: rows[0]?.total_matches ?? candidates.length };
}

interface AdmissionRow {
  id: string;
  student_name: string;
  parent_name: string;
  class_label: string | null;
  phone: string | null;
  stage: string;
  total_matches: number;
}

/** Fetch admission-lead candidates by student/parent name or phone. Requires
 * viewAdmissions (gated in the handler). */
export async function searchAdmissionsLeads(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  query: string,
  displayLimit: number,
): Promise<{ candidates: AdmissionCandidate[]; total: number }> {
  const cap = candidateCap(displayLimit);
  const q = query.trim();
  const rows = await db.queryObject<AdmissionRow>(
    `SELECT id::text AS id, student_name, parent_name, class_label, phone, stage,
            count(*) OVER()::int AS total_matches
       FROM admissions_leads
      WHERE organization_id = $1 AND school_id = $2
        AND (
          lower(student_name) LIKE lower($3) || '%'
          OR lower(student_name) LIKE '%' || lower($3) || '%'
          OR lower(parent_name) LIKE lower($3) || '%'
          OR replace(phone, ' ', '') LIKE '%' || replace($3, ' ', '') || '%'
        )
      ORDER BY
        CASE
          WHEN replace(phone, ' ', '') LIKE '%' || replace($3, ' ', '') || '%' THEN 2
          WHEN lower(student_name) LIKE lower($3) || '%'
            OR lower(parent_name) LIKE lower($3) || '%' THEN 4
          ELSE 5
        END,
        student_name
      LIMIT $4`,
    [organizationId, schoolId, q, cap],
  );
  const candidates: AdmissionCandidate[] = rows.map((r) => ({
    id: r.id,
    studentName: r.student_name,
    parentName: r.parent_name,
    classLabel: r.class_label,
    phone: r.phone,
    stage: r.stage,
  }));
  return { candidates, total: rows[0]?.total_matches ?? candidates.length };
}
