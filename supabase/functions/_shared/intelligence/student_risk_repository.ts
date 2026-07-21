import type { TenantQueryClient } from "../tenant_db.ts";
import { attendancePercentSql } from "../attendance/attendance_percentage.ts";
import { computeStudentRisk, riskLevelFromScore } from "./student_risk_engine.ts";
import type { RiskReason } from "./student_risk_engine.ts";
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

// ── SAFEGUARDING data-provenance (ICA-H4) ───────────────────────────────────
// How much of the two daily-engagement monitoring signals (attendance,
// homework) is actually MEASURED for a student, vs. simply absent.
export type MonitoringCompleteness = "full" | "partial" | "none";

// loadStudentSignals return row. Extends the shared StudentSignalRow with
// explicit data-provenance flags so downstream consumers can tell a real
// measurement apart from an ABSENCE of monitoring data. The old code coerced a
// missing attendance/homework into an optimistic constant (92 / 85), which
// scored a newly-enrolled or unmonitored student as low-risk and hid exactly
// the students no one is watching. These flags replace that fail-UNSAFE guess.
export interface StudentSignalRowWithMonitoring extends StudentSignalRow {
  // true when >= 1 attendance day is marked (attendance_percent is not NULL).
  attendance_has_data: boolean;
  // true when >= 1 homework submission row exists (hw_total > 0).
  homework_has_data: boolean;
  data_completeness: MonitoringCompleteness;
  // true when the DOMINANT monitoring signal (attendance) has NO data, so a low
  // computed score is not trustworthy. Such a student is stored as a "needs
  // review" band — never low-risk-by-default (see computeAndStoreRiskSnapshots).
  unmonitored: boolean;
}

// Stored-band floor for an UNMONITORED student. Equals the medium threshold in
// riskLevelFromScore() (score >= 40 -> "medium"), so an unmonitored student can
// never be persisted as "low" and never sinks to the bottom of a score-ordered
// early-warning list.
const UNMONITORED_REVIEW_SCORE = 40;

export async function loadStudentSignals(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  academicYearLabel?: string,
): Promise<StudentSignalRowWithMonitoring[]> {
  const rows = await client.queryObject<{
    student_id: string;
    student_name: string;
    class_name: string;
    section_name: string | null;
    absent_count: number;
    attendance_percent: number | null;
    hw_submitted: number;
    hw_total: number;
    avg_marks_pct: number;
    behavior_incidents: number;
    fee_outstanding: number;
    fee_overdue_days: number;
  }>(
    `SELECT
       s.id AS student_id,
       s.display_name AS student_name,
       coalesce(e.class_name, 'Unassigned') AS class_name,
       e.section_name,
       coalesce(att.absent_count, 0)::int AS absent_count,
       att.attendance_percent,
       coalesce(hw.submitted, 0)::int AS hw_submitted,
       coalesce(hw.total, 0)::int AS hw_total,
       coalesce(marks.avg_pct, 70)::int AS avg_marks_pct,
       coalesce(conduct.incident_count, 0)::int AS behavior_incidents,
       coalesce(fee.outstanding, 0)::numeric AS fee_outstanding,
       coalesce(fee.overdue_days, 0)::int AS fee_overdue_days
     FROM students s
     LEFT JOIN LATERAL (
       SELECT class_name, section_name
       FROM sis_student_enrollments
       WHERE student_id = s.id AND organization_id = $1 AND school_id = $2 AND is_current = true
       LIMIT 1
     ) e ON true
     LEFT JOIN LATERAL (
       -- attendance_percent: CANONICAL (2026-07-09) — present+late+0.5×half_day
       -- over total_marked−excused, via the shared attendance_percentage.ts
       -- fragments. This used to derive attendance_percent downstream as
       -- (total-absent_count)/total, which counted late/excused/half_day as
       -- full presence and included excused in the denominator — divergent
       -- from every other attendance-% surface. absent_count itself is kept
       -- as-is: it only feeds the timetable_missed_sessions coarse proxy
       -- below, not the attendance percentage.
       SELECT
         count(*) FILTER (WHERE ar.mark = 'absent')::int AS absent_count,
         ${attendancePercentSql("ar.mark")} AS attendance_percent
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
     LEFT JOIN LATERAL (
       -- fee_outstanding: AUTHORITATIVE per-year balance from
       -- finance_student_accounts.outstanding_amount — the same column that
       -- collections decrement and the finance defaulters / finance-intelligence
       -- reads use. Scope to the current academic year when known ($3); when the
       -- caller has no year, fall back to summing the student's OPEN accounts
       -- (mirrors the defaulters read: status='open' AND outstanding_amount>0).
       -- overdue_days is derived from the effective due date — the earliest
       -- installment/term due date when a schedule exists, else the invoice's
       -- own due_date — exactly as the finance defaulters/intelligence aging
       -- computes it (FIN-6; mirrors finance_aging.overdueDaysSql).
       SELECT
         coalesce(sum(fsa.outstanding_amount), 0)::numeric AS outstanding,
         coalesce(
           max(EXTRACT(day FROM now() - fi.effective_due))
             FILTER (WHERE fi.effective_due IS NOT NULL),
           0
         )::int AS overdue_days
       FROM finance_student_accounts fsa
       LEFT JOIN (
         SELECT fi.student_id, fi.organization_id, fi.school_id,
                COALESCE(
                  (SELECT MIN(ii.due_date) FROM finance_invoice_installments ii
                    WHERE ii.invoice_id = fi.id),
                  fi.due_date) AS effective_due
           FROM finance_invoices fi
          WHERE fi.invoice_status IN ('issued', 'partially_paid')
       ) fi ON fi.student_id = fsa.student_id
         AND fi.organization_id = fsa.organization_id
         AND fi.school_id = fsa.school_id
         AND fi.effective_due < CURRENT_DATE
       WHERE fsa.student_id = s.id
         AND fsa.organization_id = $1 AND fsa.school_id = $2
         AND fsa.status = 'open'
         AND fsa.outstanding_amount > 0
         AND ($3::text IS NULL OR fsa.academic_year = $3::text)
     ) fee ON true
     WHERE s.organization_id = $1 AND s.school_id = $2 AND s.status = 'active'
     ORDER BY s.display_name`,
    [organizationId, schoolId, academicYearLabel ?? null],
  );

  return rows.map((row) => {
    // ── SAFEGUARDING (ICA-H4) ──────────────────────────────────────────────
    // attendance_percent is SQL NULL only when nothing is marked yet (or every
    // marked day was excused); hw_total is 0 when no homework rows exist. Both
    // are ABSENCES OF MONITORING DATA — not evidence of good standing. The old
    // code coerced them into optimistic constants (92 / 85), scoring a newly-
    // enrolled or unmonitored student as low-risk and silently hiding exactly
    // the students no one is watching (fail-UNSAFE). Instead we record explicit
    // data-provenance flags and EXCLUDE an unmeasured dimension from the risk
    // arithmetic (feed a gap-0 placeholder of 100 -> contributes nothing rather
    // than inventing an optimistic score). The `unmonitored` flag then forces
    // the stored band off "low" downstream (see computeAndStoreRiskSnapshots).
    const attendanceHasData = row.attendance_percent !== null;
    const homeworkHasData = row.hw_total > 0;
    const attendancePercent = attendanceHasData ? row.attendance_percent! : 100;
    const homeworkCompletionRate = homeworkHasData
      ? Math.round((row.hw_submitted / row.hw_total) * 100)
      : 100;
    const dataCompleteness: MonitoringCompleteness =
      attendanceHasData && homeworkHasData
        ? "full"
        : (!attendanceHasData && !homeworkHasData ? "none" : "partial");
    // Attendance is the dominant daily-engagement / safeguarding signal
    // (weight 0.25 in the engine). When it is absent, a low computed score is
    // not trustworthy -> the student is UNMONITORED (needs review), never
    // low-risk-by-default.
    const unmonitored = !attendanceHasData;
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
      // fee_outstanding_amount: authoritative per-year balance from
      // finance_student_accounts.outstanding_amount (0 when the student has no
      // open account or is fully paid up).
      fee_outstanding_amount: Number(row.fee_outstanding) || 0,
      fee_overdue_days: Number(row.fee_overdue_days) || 0,
      // SAFEGUARDING (ICA-H4): explicit data provenance. Persisted in the
      // snapshot `inputs` jsonb so the UI can distinguish "measured" from
      // "no data yet" and show the unmonitored caveat.
      attendance_has_data: attendanceHasData,
      homework_has_data: homeworkHasData,
      data_completeness: dataCompleteness,
      unmonitored,
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

  const signals = await loadStudentSignals(
    client,
    organizationId,
    schoolId,
    academicYearLabel,
  );
  const stored: StudentRiskSnapshotRow[] = [];

  for (const signal of signals) {
    const computed = computeStudentRisk({
      attendancePercent: signal.attendance_percent,
      homeworkCompletionRate: signal.homework_completion_rate,
      averageMarksPercent: signal.average_marks_percent,
      communicationGaps: signal.communication_gaps,
      behaviorIncidents: signal.behavior_incidents,
      timetableMissedSessions: signal.timetable_missed_sessions,
      feeOutstandingAmount: signal.fee_outstanding_amount,
      feeOverdueDays: signal.fee_overdue_days,
    });

    // ── SAFEGUARDING (ICA-H4) ──────────────────────────────────────────────
    // An UNMONITORED student (no attendance data) had the dominant signal
    // excluded from the score, so a "low" verdict is not trustworthy. Floor the
    // stored band to a "needs review" state (never below medium), keep any
    // higher engine band, and replace the misleading "Stable profile" reason
    // with an explicit no-monitoring-data caveat the UI can surface. A student
    // with only PARTIAL data keeps its honest engine band but carries a caveat.
    // NOTE: risk_level is a DB-constrained enum (low|medium|high|critical), so a
    // first-class "unmonitored" band + engine-level weight re-normalisation is a
    // tracked follow-up (needs a migration + student_risk_engine.ts change); the
    // `unmonitored` / *_has_data flags are already persisted in `inputs` for it.
    let riskScore = computed.riskScore;
    let riskLevel = computed.riskLevel;
    let reasons: RiskReason[] = computed.reasons;
    if (signal.unmonitored) {
      riskScore = Math.max(computed.riskScore, UNMONITORED_REVIEW_SCORE);
      riskLevel = riskLevelFromScore(riskScore); // >= "medium", never "low"
      reasons = [
        {
          code: "no_monitoring_data",
          label: "No monitoring data",
          severity: "medium",
          detail:
            "No attendance has been marked for this student, so risk cannot be assessed from monitoring data. Flagged for review — not confirmed low-risk.",
        },
        ...computed.reasons.filter((r) => r.code !== "stable"),
      ];
    } else if (signal.data_completeness === "partial") {
      // attendance present, homework absent (the only non-unmonitored partial
      // case): the score already excludes the unmeasured homework dimension.
      reasons = [
        ...computed.reasons,
        {
          code: "partial_monitoring_data",
          label: "Partial monitoring data",
          severity: "low",
          detail:
            "No homework data yet; score reflects the available signals only.",
        },
      ];
    }

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
        riskScore,
        riskLevel,
        JSON.stringify(reasons),
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
