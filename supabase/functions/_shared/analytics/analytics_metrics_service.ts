import type { TenantQueryClient } from "../tenant_db.ts";
import type { RawSchoolMetrics } from "./analytics_types.ts";

export async function loadRawSchoolMetrics(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<RawSchoolMetrics> {
  const [students] = await db.queryObject<{ count: number }>(
    `SELECT count(*)::int AS count FROM students
     WHERE organization_id = $1 AND school_id = $2`,
    [organizationId, schoolId],
  );
  const [enrollments] = await db.queryObject<{ count: number }>(
    `SELECT count(*)::int AS count FROM sis_student_enrollments
     WHERE organization_id = $1 AND school_id = $2 AND is_current = true`,
    [organizationId, schoolId],
  );
  const [attendance] = await db.queryObject<{ absent: number; total: number }>(
    `SELECT
       count(*) FILTER (WHERE mark = 'absent')::int AS absent,
       count(*)::int AS total
     FROM attendance_records
     WHERE organization_id = $1 AND school_id = $2`,
    [organizationId, schoolId],
  );
  const [marks] = await db.queryObject<{ low: number; total: number }>(
    `SELECT
       count(*) FILTER (WHERE marks_obtained < max_marks * 0.4)::int AS low,
       count(*)::int AS total
     FROM exam_mark_entries
     WHERE organization_id = $1 AND school_id = $2`,
    [organizationId, schoolId],
  );
  const [invoices] = await db.queryObject<{ count: number }>(
    `SELECT count(*)::int AS count FROM finance_invoices
     WHERE organization_id = $1 AND school_id = $2
       AND invoice_status IN ('issued', 'partially_paid')`,
    [organizationId, schoolId],
  );
  const [collections] = await db.queryObject<{ count: number }>(
    `SELECT count(*)::int AS count FROM finance_collections
     WHERE organization_id = $1 AND school_id = $2 AND collection_status = 'completed'`,
    [organizationId, schoolId],
  );
  const [leads] = await db.queryObject<{ count: number }>(
    `SELECT count(*)::int AS count FROM admissions_leads
     WHERE organization_id = $1 AND school_id = $2`,
    [organizationId, schoolId],
  );
  const [applications] = await db.queryObject<{ count: number }>(
    `SELECT count(*)::int AS count FROM admissions_applications
     WHERE organization_id = $1 AND school_id = $2 AND status IN ('approved', 'enrolled')`,
    [organizationId, schoolId],
  );
  const [teachers] = await db.queryObject<{ count: number }>(
    `SELECT count(DISTINCT teacher_id)::int AS count FROM teacher_assignments
     WHERE organization_id = $1 AND school_id = $2`,
    [organizationId, schoolId],
  );
  const [notifications] = await db.queryObject<{ delivered: number; failed: number }>(
    `SELECT
       count(*) FILTER (WHERE status = 'delivered')::int AS delivered,
       count(*) FILTER (WHERE status = 'failed')::int AS failed
     FROM notification_deliveries
     WHERE organization_id = $1`,
    [organizationId],
  );

  let timetableConflictCount = 0;
  let timetableGapCount = 0;
  let overloadedTeachers = 0;
  try {
    const yearRows = await db.queryObject<{ id: string }>(
      `SELECT id FROM academic_years
       WHERE organization_id = $1 AND school_id = $2 AND is_current = true
       LIMIT 1`,
      [organizationId, schoolId],
    );
    if (yearRows[0]?.id) {
      const { getTimetableSummary, getSchoolConflicts, getSchoolWorkload } = await import(
        "../timetable/timetable_repository.ts"
      );
      const summary = await getTimetableSummary(db, organizationId, schoolId, yearRows[0].id);
      const conflicts = await getSchoolConflicts(db, organizationId, schoolId, yearRows[0].id);
      const workload = await getSchoolWorkload(db, organizationId, schoolId, yearRows[0].id);
      timetableConflictCount = conflicts.length;
      timetableGapCount = summary.gapCount;
      overloadedTeachers = workload.filter((w) => w.isOverloaded).length;
    }
  } catch {
    // Timetable module optional during partial deploy
  }

  const totalAttendance = attendance?.total ?? 0;
  const absentRate = totalAttendance > 0 ? (attendance!.absent / totalAttendance) : 0;
  const totalMarks = marks?.total ?? 0;
  const lowMarksRate = totalMarks > 0 ? (marks!.low / totalMarks) : 0;

  return {
    studentCount: students?.count ?? 0,
    enrollmentCount: enrollments?.count ?? 0,
    absentRate,
    lowMarksRate,
    openInvoiceCount: invoices?.count ?? 0,
    completedCollections: collections?.count ?? 0,
    leadCount: leads?.count ?? 0,
    convertedApplications: applications?.count ?? 0,
    timetableConflictCount,
    timetableGapCount,
    overloadedTeachers,
    notificationDelivered: notifications?.delivered ?? 0,
    notificationFailed: notifications?.failed ?? 0,
    teacherAssignmentCount: teachers?.count ?? 0,
  };
}
