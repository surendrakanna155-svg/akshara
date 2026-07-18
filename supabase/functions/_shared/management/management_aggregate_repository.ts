import type { TenantQueryClient } from "../tenant_db.ts";
import { getDashboard as getFinanceDashboard } from "../finance/finance_dashboard_repository.ts";
import { getDashboard as getAdmissionsDashboard } from "../admissions/admissions_dashboard_repository.ts";
// PRA-P0-22 / P2-22 (S4): the ONE canonical attendance formula (present + late +
// 0.5·half_day over total-minus-excused) — never re-implement it inline.
import {
  attendanceDenominatorSql,
  attendedDaysSql,
} from "../attendance/attendance_percentage.ts";
// PRA-P1-47 (S4): the ONE canonical "days overdue" expression Finance's
// defaulters list is built from — a defaulter is OVERDUE, not merely outstanding.
import { overdueDaysSql } from "../finance/finance_aging.ts";
// PRA-P1-48 (S4): the real pending-approval queue for the executive dashboard
// (was a hardcoded empty array).
import { listPendingApprovals } from "../approval/approval_repository.ts";

// MJ-C8 (PRINC-1): the Principal/Management executive dashboards used to serve
// a never-refreshed `management_entities` seed snapshot, so every school saw the
// same fictional figures. This module recomputes those payloads from the real
// live tables inside the caller's tenant RLS context (finance_*, admissions_*,
// students, attendance_*, exam_*). It reuses the already-live finance and
// admissions aggregation repositories so the numbers match the rest of the app.

// ---------------------------------------------------------------------------
// Formatting helpers (deterministic; the Flutter mapper consumes these strings
// verbatim, so the shape "₹2.4Cr" / "₹45L" / "₹1,200" matches the old seed).
// ---------------------------------------------------------------------------

/** Format a rupee amount the way the seed payloads did: Cr / L / plain. */
export function formatInr(amount: number): string {
  const value = Math.max(0, Math.round(amount));
  if (value >= 10000000) {
    const cr = value / 10000000;
    return `₹${trimDecimal(cr)}Cr`;
  }
  if (value >= 100000) {
    const lakh = value / 100000;
    return `₹${trimDecimal(lakh)}L`;
  }
  return `₹${value.toLocaleString("en-IN")}`;
}

function trimDecimal(value: number): string {
  // One decimal place, but drop a trailing ".0" (so "2.4Cr" / "45L").
  const rounded = Math.round(value * 10) / 10;
  return Number.isInteger(rounded) ? String(rounded) : rounded.toFixed(1);
}

/** Render a 0-100 rate as a whole-percent string ("87%"). */
export function formatPercent(rate: number): string {
  return `${Math.round(rate)}%`;
}

// ---------------------------------------------------------------------------
// Academic aggregates (attendance + exams). Finance/admissions are delegated to
// the existing repositories; academics has no executive-summary repo yet, so we
// compute it here from the canonical pilot-operations tables.
// ---------------------------------------------------------------------------

export interface AcademicAggregate {
  /** Whole-percent average attendance across submitted sessions (0 = no data). */
  avgAttendancePercent: number;
  /** Whole-percent pass rate across published marks (0 = no data). */
  passRate: number;
  /** Average score percent across published marks (0 = no data). */
  avgScorePercent: number;
  /** Whether any attendance records exist for this school. */
  hasAttendance: boolean;
  /** Whether any published exam marks exist for this school. */
  hasExams: boolean;
  /** Per-class published-exam performance, highest pass-rate first. */
  classPerformance: Array<{
    classLabel: string;
    students: number;
    passPercent: number;
    avgPercent: number;
  }>;
  /** Per-subject published-exam performance, lowest pass-rate first. */
  subjectPerformance: Array<{
    subject: string;
    passPercent: number;
    avgPercent: number;
    atRiskCount: number;
  }>;
  /** PRA-P2-22: real per-class attendance % (canonical formula), NOT the school scalar. */
  attendanceByClass: Array<{ classLabel: string; attendancePercent: number }>;
}

// A mark counts as a pass at 33% of max (standard Indian board threshold).
const PASS_THRESHOLD = 0.33;

export async function getAcademicAggregate(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<AcademicAggregate> {
  // PRA-P0-22 / P2-22 (S4): compute attendance from the CANONICAL formula
  // (attended = present + late + 0.5·half_day; denominator = total − excused),
  // grouped per class in ONE pass. The old inline query counted 'excused' as
  // attended and dropped 'half_day' entirely (wrong school-wide number), and the
  // per-class dashboard column reused that single school scalar for every class.
  const attendanceRows = await db.queryObject<{
    class_label: string;
    attended: string;
    denominator: string;
    total: string;
  }>(
    `SELECT
       COALESCE(NULLIF(s.class_label, ''), 'Unassigned') AS class_label,
       ${attendedDaysSql("ar.mark")}::float8::text AS attended,
       ${attendanceDenominatorSql("ar.mark")}::text AS denominator,
       COUNT(*)::text AS total
     FROM attendance_records ar
     JOIN attendance_sessions s ON s.id = ar.session_id
     WHERE ar.organization_id = $1 AND ar.school_id = $2
       AND s.status = 'submitted'
     GROUP BY COALESCE(NULLIF(s.class_label, ''), 'Unassigned')
     ORDER BY 1`,
    [organizationId, schoolId],
  );
  let attSchoolAttended = 0;
  let attSchoolDenominator = 0;
  let attTotal = 0;
  const attendanceByClass = attendanceRows.map((r) => {
    const attended = Number(r.attended);
    const denominator = Number(r.denominator);
    attSchoolAttended += attended;
    attSchoolDenominator += denominator;
    attTotal += Number(r.total);
    return {
      classLabel: r.class_label,
      attendancePercent: denominator > 0
        ? Math.round((attended / denominator) * 100)
        : 0,
    };
  });
  const avgAttendancePercent = attSchoolDenominator > 0
    ? Math.round((attSchoolAttended / attSchoolDenominator) * 100)
    : 0;

  const markRows = await db.queryObject<{
    passed: string;
    total: string;
    avg_percent: string;
  }>(
    `SELECT
       COUNT(*) FILTER (
         WHERE m.max_marks > 0 AND m.marks_obtained::numeric / m.max_marks >= $3
       )::text AS passed,
       COUNT(*)::text AS total,
       COALESCE(ROUND(AVG(
         CASE WHEN m.max_marks > 0
           THEN m.marks_obtained::numeric / m.max_marks * 100
           ELSE 0 END
       )), 0)::text AS avg_percent
     FROM exam_mark_entries m
     WHERE m.organization_id = $1 AND m.school_id = $2
       AND m.published = true`,
    [organizationId, schoolId, PASS_THRESHOLD],
  );
  const markTotal = Number(markRows[0]?.total ?? "0");
  const markPassed = Number(markRows[0]?.passed ?? "0");
  const passRate = markTotal > 0
    ? Math.round((markPassed / markTotal) * 100)
    : 0;
  const avgScorePercent = Number(markRows[0]?.avg_percent ?? "0");

  const classRows = await db.queryObject<{
    class_label: string;
    students: string;
    passed: string;
    total: string;
    avg_percent: string;
  }>(
    `SELECT
       COALESCE(NULLIF(m.class_label, ''), 'Unassigned') AS class_label,
       COUNT(DISTINCT m.student_id)::text AS students,
       COUNT(*) FILTER (
         WHERE m.max_marks > 0 AND m.marks_obtained::numeric / m.max_marks >= $3
       )::text AS passed,
       COUNT(*)::text AS total,
       COALESCE(ROUND(AVG(
         CASE WHEN m.max_marks > 0
           THEN m.marks_obtained::numeric / m.max_marks * 100
           ELSE 0 END
       )), 0)::text AS avg_percent
     FROM exam_mark_entries m
     WHERE m.organization_id = $1 AND m.school_id = $2
       AND m.published = true
     GROUP BY COALESCE(NULLIF(m.class_label, ''), 'Unassigned')
     ORDER BY 1`,
    [organizationId, schoolId, PASS_THRESHOLD],
  );
  const classPerformance = classRows.map((row) => {
    const total = Number(row.total);
    const passed = Number(row.passed);
    return {
      classLabel: row.class_label,
      students: Number(row.students),
      passPercent: total > 0 ? Math.round((passed / total) * 100) : 0,
      avgPercent: Number(row.avg_percent),
    };
  }).sort((a, b) => b.passPercent - a.passPercent);

  const subjectRows = await db.queryObject<{
    subject: string;
    passed: string;
    total: string;
    at_risk: string;
    avg_percent: string;
  }>(
    `SELECT
       COALESCE(NULLIF(es.subject, ''), 'General') AS subject,
       COUNT(*) FILTER (
         WHERE m.max_marks > 0 AND m.marks_obtained::numeric / m.max_marks >= $3
       )::text AS passed,
       COUNT(*)::text AS total,
       COUNT(*) FILTER (
         WHERE m.max_marks > 0 AND m.marks_obtained::numeric / m.max_marks < $3
       )::text AS at_risk,
       COALESCE(ROUND(AVG(
         CASE WHEN m.max_marks > 0
           THEN m.marks_obtained::numeric / m.max_marks * 100
           ELSE 0 END
       )), 0)::text AS avg_percent
     FROM exam_mark_entries m
     JOIN exam_sessions es
       ON es.id = m.exam_id
      AND es.organization_id = m.organization_id
      AND es.school_id = m.school_id
     WHERE m.organization_id = $1 AND m.school_id = $2
       AND m.published = true
     GROUP BY COALESCE(NULLIF(es.subject, ''), 'General')
     ORDER BY 1`,
    [organizationId, schoolId, PASS_THRESHOLD],
  );
  const subjectPerformance = subjectRows.map((row) => {
    const total = Number(row.total);
    const passed = Number(row.passed);
    return {
      subject: row.subject,
      passPercent: total > 0 ? Math.round((passed / total) * 100) : 0,
      avgPercent: Number(row.avg_percent),
      atRiskCount: Number(row.at_risk),
    };
  }).sort((a, b) => a.passPercent - b.passPercent);

  return {
    avgAttendancePercent,
    passRate,
    avgScorePercent,
    hasAttendance: attTotal > 0,
    hasExams: markTotal > 0,
    classPerformance,
    subjectPerformance,
    attendanceByClass,
  };
}

// ---------------------------------------------------------------------------
// Combined snapshot used by all 6 management read endpoints.
// ---------------------------------------------------------------------------

export interface ManagementAggregate {
  finance: Awaited<ReturnType<typeof getFinanceDashboard>>;
  admissions: Awaited<ReturnType<typeof getAdmissionsDashboard>>;
  academic: AcademicAggregate;
  /** Count of active students on the roster (students.status = 'active'). */
  activeStudents: number;
  /** PRA-P1-47: fee defaulters = OVERDUE accounts (Finance's daysOverdue > 0), not merely any outstanding balance. */
  defaulterCount: number;
  /** PRA-P0-23: collections this calendar month (month-to-date) — the real "Revenue MTD". */
  collectedThisMonth: number;
  /** PRA-P1-48: real pending-approval queue (was hardcoded []). */
  pendingApprovals: Array<{
    id: string;
    type: string;
    title: string;
    summary: string;
    requesterName: string;
    createdAt: string;
  }>;
}

export async function getManagementAggregate(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<ManagementAggregate> {
  const finance = await getFinanceDashboard(db, organizationId, schoolId);
  const admissions = await getAdmissionsDashboard(db, organizationId, schoolId);
  const academic = await getAcademicAggregate(db, organizationId, schoolId);
  // PRA-P1-48: the real pending-approval queue (was a hardcoded empty array).
  const approvals = await listPendingApprovals(db, organizationId, schoolId);

  const studentRows = await db.queryObject<
    { active: string; defaulters: string; collected_mtd: string }
  >(
    `SELECT
       (SELECT count(*)::text FROM students
         WHERE organization_id = $1 AND school_id = $2 AND status = 'active') AS active,
       -- PRA-P1-47: a defaulter is OVERDUE (Finance's canonical daysOverdue > 0),
       -- not merely any open account with a balance.
       (SELECT count(*)::text FROM finance_student_accounts fsa
         WHERE fsa.organization_id = $1 AND fsa.school_id = $2
           AND fsa.status = 'open'
           AND ${overdueDaysSql("fsa.student_id", "fsa.organization_id")} > 0) AS defaulters,
       -- PRA-P0-23: month-to-date collections — the real "Revenue MTD".
       (SELECT COALESCE(SUM(amount_collected), 0)::text FROM finance_collections
         WHERE organization_id = $1 AND school_id = $2
           AND collection_status IN ('completed', 'partially_refunded', 'refunded')
           AND collection_date >= date_trunc('month', CURRENT_DATE)) AS collected_mtd`,
    [organizationId, schoolId],
  );

  return {
    finance,
    admissions,
    academic,
    activeStudents: Number(studentRows[0]?.active ?? "0"),
    defaulterCount: Number(studentRows[0]?.defaulters ?? "0"),
    collectedThisMonth: Number(studentRows[0]?.collected_mtd ?? "0"),
    pendingApprovals: approvals.map((a) => ({
      id: a.id,
      type: a.type,
      title: a.title,
      summary: a.summary,
      requesterName: a.requester_name,
      createdAt: a.created_at,
    })),
  };
}
