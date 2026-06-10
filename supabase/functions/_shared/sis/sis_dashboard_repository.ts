import type { TenantQueryClient } from "../tenant_db.ts";
import { statusFromDb } from "./sis_status_codec.ts";

export interface DistributionRow {
  label: string;
  count: number;
  percent: number;
}

export interface DashboardRecentStudent {
  id: string;
  student_name: string;
  admission_number: string;
  class_name: string;
  section_name: string;
  created_at: string;
  status: string;
}

export interface DashboardRecentEnrollment {
  id: string;
  student_id: string;
  student_name: string;
  admission_number: string;
  class_name: string;
  section_name: string;
  enrolled_at: string;
  status: string;
}

export interface DashboardRecentConversion {
  id: string;
  student_name: string;
  admission_number: string;
  class_name: string;
  section_name: string;
  converted_at: string;
}

export interface SisDashboardSnapshot {
  totalStudents: number;
  activeStudents: number;
  inactiveStudents: number;
  graduatedStudents: number;
  transferredStudents: number;
  currentEnrollments: number;
  recentAdmissions: number;
  recentConversions: number;
  pendingConversions: number;
  distinctClasses: number;
  distinctSections: number;
  classDistribution: DistributionRow[];
  sectionDistribution: DistributionRow[];
  genderDistribution: DistributionRow[];
  recentStudents: DashboardRecentStudent[];
  recentEnrollments: DashboardRecentEnrollment[];
  recentConversionsList: DashboardRecentConversion[];
}

/** SQL fragment mirroring dashboard directory visibility for tenant probes. */
export const SIS_DASHBOARD_PROBE_SQL = `
  SELECT count(*)::text AS count
  FROM students s
  INNER JOIN student_profiles sp ON sp.student_id = s.id
  INNER JOIN sis_student_enrollments se
    ON se.student_id = s.id AND se.is_current = true
`;

export function computeDistributionPercentages(
  rows: Array<{ label: string; count: number }>,
): DistributionRow[] {
  const total = rows.reduce((sum, row) => sum + row.count, 0);
  if (total <= 0) {
    return rows.map((row) => ({ ...row, percent: 0 }));
  }
  return rows.map((row) => ({
    label: row.label,
    count: row.count,
    percent: Math.round((row.count / total) * 100),
  }));
}

export async function getDashboard(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<SisDashboardSnapshot> {
  const kpiRows = await db.queryObject<{
    total_students: string;
    active_students: string;
    inactive_students: string;
    graduated_students: string;
    transferred_students: string;
    current_enrollments: string;
    recent_admissions: string;
    recent_conversions: string;
    pending_conversions: string;
    distinct_classes: string;
    distinct_sections: string;
  }>(
    `SELECT
       (SELECT count(*)::text FROM students
        WHERE organization_id = $1 AND school_id = $2) AS total_students,
       (SELECT count(*)::text FROM students
        WHERE organization_id = $1 AND school_id = $2 AND status = 'active') AS active_students,
       (SELECT count(*)::text FROM students
        WHERE organization_id = $1 AND school_id = $2 AND status = 'inactive') AS inactive_students,
       (SELECT count(*)::text FROM students
        WHERE organization_id = $1 AND school_id = $2 AND status = 'alumni') AS graduated_students,
       (SELECT count(*)::text FROM students
        WHERE organization_id = $1 AND school_id = $2 AND status = 'transferred') AS transferred_students,
       (SELECT count(*)::text FROM sis_student_enrollments
        WHERE organization_id = $1 AND school_id = $2 AND is_current = true) AS current_enrollments,
       (SELECT count(*)::text FROM admissions_enrollments
        WHERE organization_id = $1 AND school_id = $2
          AND submitted_at >= (timezone('utc', now()) - interval '30 days')) AS recent_admissions,
       (SELECT count(*)::text FROM admissions_enrollments
        WHERE organization_id = $1 AND school_id = $2
          AND converted_at IS NOT NULL
          AND converted_at >= (timezone('utc', now()) - interval '30 days')) AS recent_conversions,
       (SELECT count(*)::text FROM admissions_enrollments
        WHERE organization_id = $1 AND school_id = $2
          AND conversion_status = 'pending'
          AND converted_at IS NULL) AS pending_conversions,
       (SELECT count(DISTINCT class_name)::text FROM sis_student_enrollments
        WHERE organization_id = $1 AND school_id = $2 AND is_current = true) AS distinct_classes,
       (SELECT count(DISTINCT section_name)::text FROM sis_student_enrollments
        WHERE organization_id = $1 AND school_id = $2 AND is_current = true
          AND section_name IS NOT NULL AND section_name <> '') AS distinct_sections`,
    [organizationId, schoolId],
  );

  const kpi = kpiRows[0]!;

  const classRows = await db.queryObject<{ class_name: string; count: string }>(
    `SELECT e.class_name, count(*)::text AS count
     FROM sis_student_enrollments e
     WHERE e.organization_id = $1 AND e.school_id = $2 AND e.is_current = true
     GROUP BY e.class_name
     ORDER BY e.class_name`,
    [organizationId, schoolId],
  );

  const sectionRows = await db.queryObject<{ section_label: string; count: string }>(
    `SELECT COALESCE(NULLIF(e.section_name, ''), 'Unassigned') AS section_label,
            count(*)::text AS count
     FROM sis_student_enrollments e
     WHERE e.organization_id = $1 AND e.school_id = $2 AND e.is_current = true
     GROUP BY section_label
     ORDER BY section_label`,
    [organizationId, schoolId],
  );

  const genderRows = await db.queryObject<{ gender_label: string; count: string }>(
    `SELECT
       CASE
         WHEN LOWER(sp.gender) IN ('male', 'm') THEN 'Male'
         WHEN LOWER(sp.gender) IN ('female', 'f') THEN 'Female'
         WHEN sp.gender IS NULL OR TRIM(sp.gender) = '' THEN 'Unknown'
         ELSE 'Other'
       END AS gender_label,
       count(*)::text AS count
     FROM students s
     INNER JOIN student_profiles sp ON sp.student_id = s.id
     WHERE s.organization_id = $1 AND s.school_id = $2
     GROUP BY gender_label
     ORDER BY gender_label`,
    [organizationId, schoolId],
  );

  const recentStudents = await db.queryObject<{
    id: string;
    student_name: string;
    admission_number: string;
    class_name: string;
    section_name: string;
    created_at: string;
    status: string;
  }>(
    `SELECT s.id,
       s.display_name AS student_name,
       COALESCE(sp.admission_number, '') AS admission_number,
       COALESCE(e.class_name, '') AS class_name,
       COALESCE(e.section_name, '') AS section_name,
       s.created_at::text AS created_at,
       s.status
     FROM students s
     LEFT JOIN student_profiles sp ON sp.student_id = s.id
     LEFT JOIN sis_student_enrollments e
       ON e.student_id = s.id AND e.is_current = true
     WHERE s.organization_id = $1 AND s.school_id = $2
     ORDER BY s.created_at DESC
     LIMIT 10`,
    [organizationId, schoolId],
  );

  const recentEnrollments = await db.queryObject<{
    id: string;
    student_id: string;
    student_name: string;
    admission_number: string;
    class_name: string;
    section_name: string;
    enrolled_at: string;
    status: string;
  }>(
    `SELECT e.id,
       e.student_id,
       s.display_name AS student_name,
       COALESCE(sp.admission_number, '') AS admission_number,
       e.class_name,
       COALESCE(e.section_name, '') AS section_name,
       e.created_at::text AS enrolled_at,
       s.status
     FROM sis_student_enrollments e
     INNER JOIN students s ON s.id = e.student_id
     LEFT JOIN student_profiles sp ON sp.student_id = s.id
     WHERE e.organization_id = $1 AND e.school_id = $2
     ORDER BY e.created_at DESC
     LIMIT 10`,
    [organizationId, schoolId],
  );

  const recentConversionsList = await db.queryObject<{
    id: string;
    student_name: string;
    admission_number: string;
    class_name: string;
    section_name: string;
    converted_at: string;
  }>(
    `SELECT ae.id,
       ae.student_name,
       COALESCE(ae.admission_number, '') AS admission_number,
       ae.seeking_class AS class_name,
       COALESCE(ae.section, '') AS section_name,
       ae.converted_at::text AS converted_at
     FROM admissions_enrollments ae
     WHERE ae.organization_id = $1 AND ae.school_id = $2
       AND ae.converted_at IS NOT NULL
     ORDER BY ae.converted_at DESC
     LIMIT 10`,
    [organizationId, schoolId],
  );

  return {
    totalStudents: parseInt(kpi.total_students, 10),
    activeStudents: parseInt(kpi.active_students, 10),
    inactiveStudents: parseInt(kpi.inactive_students, 10),
    graduatedStudents: parseInt(kpi.graduated_students, 10),
    transferredStudents: parseInt(kpi.transferred_students, 10),
    currentEnrollments: parseInt(kpi.current_enrollments, 10),
    recentAdmissions: parseInt(kpi.recent_admissions, 10),
    recentConversions: parseInt(kpi.recent_conversions, 10),
    pendingConversions: parseInt(kpi.pending_conversions, 10),
    distinctClasses: parseInt(kpi.distinct_classes, 10),
    distinctSections: parseInt(kpi.distinct_sections, 10),
    classDistribution: computeDistributionPercentages(
      classRows.map((row) => ({
        label: row.class_name,
        count: parseInt(row.count, 10),
      })),
    ),
    sectionDistribution: computeDistributionPercentages(
      sectionRows.map((row) => ({
        label: row.section_label,
        count: parseInt(row.count, 10),
      })),
    ),
    genderDistribution: computeDistributionPercentages(
      genderRows.map((row) => ({
        label: row.gender_label,
        count: parseInt(row.count, 10),
      })),
    ),
    recentStudents: recentStudents.map((row) => ({
      id: row.id,
      student_name: row.student_name,
      admission_number: row.admission_number,
      class_name: row.class_name,
      section_name: row.section_name,
      created_at: row.created_at,
      status: statusFromDb(row.status),
    })),
    recentEnrollments: recentEnrollments.map((row) => ({
      id: row.id,
      student_id: row.student_id,
      student_name: row.student_name,
      admission_number: row.admission_number,
      class_name: row.class_name,
      section_name: row.section_name,
      enrolled_at: row.enrolled_at,
      status: statusFromDb(row.status),
    })),
    recentConversionsList: recentConversionsList.map((row) => ({
      id: row.id,
      student_name: row.student_name,
      admission_number: row.admission_number,
      class_name: row.class_name,
      section_name: row.section_name,
      converted_at: row.converted_at,
    })),
  };
}
