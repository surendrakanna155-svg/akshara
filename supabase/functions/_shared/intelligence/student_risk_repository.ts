import type { TenantQueryClient } from "../tenant_db.ts";
import { computeStudentRisk } from "./student_risk_engine.ts";
import type { StudentRiskSnapshotRow, StudentSignalRow } from "./intelligence_types.ts";

export const INTEL_RISK_PROBE_SCHOOL_A = "f0500000-0000-4000-8000-000000000001";
export const INTEL_RISK_PROBE_SCHOOL_B = "f0500000-0000-4000-8000-000000000002";
export const INTEL_RISK_PROBE_SQL = `
  SELECT count(*)::text AS count FROM intel_student_risk_snapshots WHERE id = $1::uuid
`;
export const INTEL_RISK_API_PROBE_SQL = `
  SELECT count(*)::text AS count
  FROM intel_student_risk_snapshots
  WHERE organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
`;

export async function loadStudentSignals(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<StudentSignalRow[]> {
  const rows = await client.queryObject<{
    student_id: string;
    student_name: string;
    class_name: string;
    section_name: string | null;
    absent_count: number;
    total_attendance: number;
    hw_submitted: number;
    hw_total: number;
    avg_marks_pct: number;
    behavior_incidents: number;
  }>(
    `SELECT
       s.id AS student_id,
       s.display_name AS student_name,
       coalesce(e.class_name, 'Unassigned') AS class_name,
       e.section_name,
       coalesce(att.absent_count, 0)::int AS absent_count,
       coalesce(att.total_count, 0)::int AS total_attendance,
       coalesce(hw.submitted, 0)::int AS hw_submitted,
       coalesce(hw.total, 0)::int AS hw_total,
       coalesce(marks.avg_pct, 70)::int AS avg_marks_pct,
       coalesce(conduct.incident_count, 0)::int AS behavior_incidents
     FROM students s
     LEFT JOIN LATERAL (
       SELECT class_name, section_name
       FROM sis_student_enrollments
       WHERE student_id = s.id AND organization_id = $1 AND school_id = $2 AND is_current = true
       LIMIT 1
     ) e ON true
     LEFT JOIN LATERAL (
       SELECT
         count(*) FILTER (WHERE ar.mark = 'absent')::int AS absent_count,
         count(*)::int AS total_count
       FROM attendance_records ar
       WHERE ar.student_id = s.id AND ar.organization_id = $1 AND ar.school_id = $2
     ) att ON true
     LEFT JOIN LATERAL (
       SELECT
         count(*) FILTER (WHERE hs.status IN ('submitted', 'reviewed'))::int AS submitted,
         count(*)::int AS total
       FROM homework_submissions hs
       WHERE hs.student_id = s.id AND hs.organization_id = $1 AND hs.school_id = $2
     ) hw ON true
     LEFT JOIN LATERAL (
       SELECT coalesce(avg(
         CASE WHEN em.max_marks > 0 THEN (em.marks_obtained::float / em.max_marks) * 100 ELSE 70 END
       ), 70)::int AS avg_pct
       FROM exam_mark_entries em
       WHERE em.student_id = s.id AND em.organization_id = $1 AND em.school_id = $2
     ) marks ON true
     LEFT JOIN LATERAL (
       -- behavior_incidents: real source = student_conduct_incidents
       -- (count unresolved incidents on file for this student).
       SELECT count(*)::int AS incident_count
       FROM student_conduct_incidents sci
       WHERE sci.student_id = s.id
         AND sci.organization_id = $1 AND sci.school_id = $2
         AND sci.status IN ('open', 'escalated')
     ) conduct ON true
     WHERE s.organization_id = $1 AND s.school_id = $2 AND s.status = 'active'
     ORDER BY s.display_name`,
    [organizationId, schoolId],
  );

  return rows.map((row) => {
    const attendancePercent = row.total_attendance > 0
      ? Math.round(((row.total_attendance - row.absent_count) / row.total_attendance) * 100)
      : 92;
    const homeworkCompletionRate = row.hw_total > 0
      ? Math.round((row.hw_submitted / row.hw_total) * 100)
      : 85;
    return {
      student_id: row.student_id,
      student_name: row.student_name.trim(),
      class_name: row.class_name,
      section_name: row.section_name,
      attendance_percent: attendancePercent,
      homework_completion_rate: homeworkCompletionRate,
      average_marks_percent: row.avg_marks_pct,
      // communication_gaps: no reliable source on the live schema yet — parent
      // communication is logged as sent drafts (intel_communication_drafts), not
      // as "pending/failed" gaps. Left at 0 until a delivery-status source exists;
      // this signal carries only a 0.1 weight in the deterministic formula.
      communication_gaps: 0,
      // behavior_incidents: real count of unresolved conduct incidents on file.
      behavior_incidents: row.behavior_incidents,
      // timetable_missed_sessions: period-level timetable attendance is not tracked
      // (attendance_records are day-level), so this is a coarse proxy derived from
      // day-level absences until per-period attendance exists.
      timetable_missed_sessions: row.absent_count > 5 ? 2 : 0,
    };
  });
}

export async function computeAndStoreRiskSnapshots(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  academicYearLabel: string,
): Promise<StudentRiskSnapshotRow[]> {
  await client.queryObject(
    `DELETE FROM intel_student_risk_snapshots
     WHERE organization_id = $1 AND school_id = $2`,
    [organizationId, schoolId],
  );

  const signals = await loadStudentSignals(client, organizationId, schoolId);
  const stored: StudentRiskSnapshotRow[] = [];

  for (const signal of signals) {
    const computed = computeStudentRisk({
      attendancePercent: signal.attendance_percent,
      homeworkCompletionRate: signal.homework_completion_rate,
      averageMarksPercent: signal.average_marks_percent,
      communicationGaps: signal.communication_gaps,
      behaviorIncidents: signal.behavior_incidents,
      timetableMissedSessions: signal.timetable_missed_sessions,
    });

    const rows = await client.queryObject<StudentRiskSnapshotRow>(
      `INSERT INTO intel_student_risk_snapshots (
         organization_id, school_id, student_id, academic_year_label,
         class_name, section_name, risk_score, risk_level,
         reasons, interventions, teacher_actions, parent_notifications, inputs
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::jsonb, $10::jsonb, $11::jsonb, $12::jsonb, $13::jsonb)
       RETURNING *`,
      [
        organizationId,
        schoolId,
        signal.student_id,
        academicYearLabel,
        signal.class_name,
        signal.section_name,
        computed.riskScore,
        computed.riskLevel,
        JSON.stringify(computed.reasons),
        JSON.stringify(computed.interventions),
        JSON.stringify(computed.teacherActions),
        JSON.stringify(computed.parentNotifications),
        JSON.stringify(signal),
      ],
    );
    if (rows[0]) stored.push(rows[0]);
  }

  return stored;
}

export async function listRiskSnapshots(
  client: TenantQueryClient,
  filters: { className?: string; riskLevel?: string },
): Promise<StudentRiskSnapshotRow[]> {
  const conditions = ["1=1"];
  const params: unknown[] = [];
  let idx = 1;
  if (filters.className) {
    conditions.push(`class_name ILIKE $${idx}`);
    params.push(`%${filters.className}%`);
    idx += 1;
  }
  if (filters.riskLevel) {
    conditions.push(`risk_level = $${idx}`);
    params.push(filters.riskLevel);
    idx += 1;
  }
  return await client.queryObject<StudentRiskSnapshotRow>(
    `SELECT * FROM intel_student_risk_snapshots
     WHERE ${conditions.join(" AND ")}
     ORDER BY risk_score DESC, class_name, section_name`,
    params,
  );
}

export async function getRiskSnapshotByStudent(
  client: TenantQueryClient,
  studentId: string,
): Promise<StudentRiskSnapshotRow | null> {
  const rows = await client.queryObject<StudentRiskSnapshotRow>(
    `SELECT * FROM intel_student_risk_snapshots
     WHERE student_id = $1
     ORDER BY computed_at DESC LIMIT 1`,
    [studentId],
  );
  return rows[0] ?? null;
}

export interface ClassRiskSummary {
  className: string;
  studentCount: number;
  averageRiskScore: number;
  criticalCount: number;
  highCount: number;
  mediumCount: number;
  lowCount: number;
}

export async function listClassRiskSummaries(
  client: TenantQueryClient,
): Promise<ClassRiskSummary[]> {
  const rows = await client.queryObject<{
    class_name: string;
    student_count: number;
    avg_score: number;
    critical_count: number;
    high_count: number;
    medium_count: number;
    low_count: number;
  }>(
    `SELECT
       class_name,
       count(*)::int AS student_count,
       round(avg(risk_score))::int AS avg_score,
       count(*) FILTER (WHERE risk_level = 'critical')::int AS critical_count,
       count(*) FILTER (WHERE risk_level = 'high')::int AS high_count,
       count(*) FILTER (WHERE risk_level = 'medium')::int AS medium_count,
       count(*) FILTER (WHERE risk_level = 'low')::int AS low_count
     FROM intel_student_risk_snapshots
     GROUP BY class_name
     ORDER BY avg_score DESC`,
  );

  return rows.map((r) => ({
    className: r.class_name,
    studentCount: r.student_count,
    averageRiskScore: r.avg_score,
    criticalCount: r.critical_count,
    highCount: r.high_count,
    mediumCount: r.medium_count,
    lowCount: r.low_count,
  }));
}
