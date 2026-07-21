// Advanced AI Predictions (B9) — deterministic scorers over real pilot data.
//
// Three forward-looking, school-scoped prediction lists, each computed ENTIRELY
// from real operational tables (no fabricated numbers, no invented students):
//   • fee-default        — finance_invoices outstanding + days overdue
//   • admission-conversion — admissions_leads funnel progression + lead score
//   • student-risk       — REUSES the certified intelligence engine
//                          (loadStudentSignals + computeStudentRisk)
//
// Every scorer is deterministic and always succeeds. The optional Claude
// narrative (predictions_ai.ts) only adds prose on top — numbers are locked here.

import type { TenantQueryClient } from "../tenant_db.ts";
import {
  computeStudentRisk,
  riskLevelFromScore,
} from "../intelligence/student_risk_engine.ts";
import { loadStudentSignals } from "../intelligence/student_risk_repository.ts";
import type { MonitoringCompleteness } from "../intelligence/student_risk_repository.ts";
import type { RiskLevel } from "../intelligence/intelligence_types.ts";

// SAFEGUARDING (ICA-H4). Stored-band floor for an UNMONITORED student — mirrors
// UNMONITORED_REVIEW_SCORE in student_risk_repository.ts (equal to the "medium"
// threshold in riskLevelFromScore, so an unmonitored student can never be scored
// "low" and never sinks to the bottom of a score-ordered early-warning list).
// That repository constant is not exported, so it is mirrored here; a shared
// extraction (e.g. into intelligence_types.ts) is a tidy follow-up.
const UNMONITORED_REVIEW_SCORE = 40;

function clamp(n: number): number {
  return Math.max(0, Math.min(100, Math.round(n)));
}

// ─── Fee-default prediction ─────────────────────────────────────────────────

export interface FeeDefaultPrediction {
  studentId: string;
  studentName: string;
  className: string;
  outstandingInr: number;
  billedInr: number;
  daysOverdue: number;
  riskScore: number;
  riskLevel: RiskLevel;
}

interface FeeRow {
  student_id: string;
  student_name: string;
  class_name: string;
  outstanding: number;
  billed: number;
  days_overdue: number;
}

/**
 * Per-student fee-default risk from open invoices. Risk rises with how long a
 * payment is overdue and how large the unpaid share is — both real figures.
 */
export async function computeFeeDefaultRisk(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
): Promise<FeeDefaultPrediction[]> {
  const rows = await db.queryObject<FeeRow>(
    `SELECT i.student_id,
            s.display_name AS student_name,
            COALESCE(e.class_name, 'Unassigned') AS class_name,
            sum(i.outstanding_amount)::float8 AS outstanding,
            sum(i.total_amount)::float8 AS billed,
            COALESCE(max(GREATEST(0, (CURRENT_DATE - i.due_date))), 0)::int AS days_overdue
     FROM finance_invoices i
     JOIN students s ON s.id = i.student_id
     LEFT JOIN LATERAL (
       SELECT class_name FROM sis_student_enrollments
       WHERE student_id = i.student_id AND organization_id = $1 AND school_id = $2
         AND is_current = true
       LIMIT 1
     ) e ON true
     WHERE i.organization_id = $1 AND i.school_id = $2
       AND i.invoice_status IN ('issued', 'partially_paid')
       AND i.outstanding_amount > 0
     GROUP BY i.student_id, s.display_name, e.class_name
     ORDER BY outstanding DESC`,
    [orgId, schoolId],
  );

  return rows.map((r) => {
    const overdueWeight = (Math.min(r.days_overdue, 90) / 90) * 55;
    const ratio = r.billed > 0 ? Math.min(r.outstanding / r.billed, 1) : 1;
    const riskScore = clamp(overdueWeight + ratio * 45);
    return {
      studentId: r.student_id,
      studentName: r.student_name.trim(),
      className: r.class_name,
      outstandingInr: Math.round(r.outstanding),
      billedInr: Math.round(r.billed),
      daysOverdue: r.days_overdue,
      riskScore,
      riskLevel: riskLevelFromScore(riskScore),
    };
  });
}

// ─── Admission-conversion (enrolment-likelihood) prediction ─────────────────

export type ConversionBand = "hot" | "warm" | "cool";

export interface AdmissionConversionPrediction {
  leadId: string;
  studentName: string;
  classLabel: string;
  source: string;
  stage: string;
  leadScore: string;
  ageDays: number;
  applicationStatus: string | null;
  likelihood: number;
  band: ConversionBand;
}

interface LeadRow {
  id: string;
  student_name: string;
  class_label: string;
  source: string;
  stage: string;
  score: string;
  age_days: number;
  app_status: string | null;
}

function conversionBand(likelihood: number): ConversionBand {
  if (likelihood >= 70) return "hot";
  if (likelihood >= 45) return "warm";
  return "cool";
}

/**
 * Per-lead enrolment likelihood from real funnel signals: the lead's warmth
 * score, how far its application has progressed, and how long it has sat without
 * advancing (stale leads decay). Leads already rejected score near zero.
 */
export async function computeAdmissionConversion(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
): Promise<AdmissionConversionPrediction[]> {
  const rows = await db.queryObject<LeadRow>(
    `SELECT l.id, l.student_name, l.class_label, l.source, l.stage, l.score,
            (CURRENT_DATE - l.created_at::date)::int AS age_days,
            a.status AS app_status
     FROM admissions_leads l
     LEFT JOIN LATERAL (
       SELECT status FROM admissions_applications
       WHERE lead_id = l.id ORDER BY created_at DESC LIMIT 1
     ) a ON true
     WHERE l.organization_id = $1 AND l.school_id = $2
     ORDER BY l.created_at DESC`,
    [orgId, schoolId],
  );

  return rows.map((r) => {
    let likelihood: number;
    const status = r.app_status;
    if (status === "approved") {
      likelihood = 95;
    } else if (status === "rejected") {
      likelihood = 5;
    } else {
      // Base on lead warmth, then add for application progress and subtract for staleness.
      const base = r.score === "hot" ? 68 : r.score === "warm" ? 50 : r.score === "cold" ? 28 : 42;
      let bump = 0;
      if (status === "under_review") bump += 22;
      else if (status === "submitted" || status === "documents_pending") bump += 14;
      else if (status) bump += 8; // any application started
      if (r.age_days > 45) bump -= 18;
      else if (r.age_days > 21) bump -= 8;
      likelihood = clamp(base + bump);
    }
    return {
      leadId: r.id,
      studentName: r.student_name.trim(),
      classLabel: r.class_label,
      source: r.source,
      stage: r.stage,
      leadScore: r.score,
      ageDays: r.age_days,
      applicationStatus: status,
      likelihood,
      band: conversionBand(likelihood),
    };
  });
}

// ─── Student-risk prediction (REUSE the certified intelligence engine) ──────

export interface StudentRiskPrediction {
  studentId: string;
  studentName: string;
  className: string;
  riskScore: number;
  riskLevel: RiskLevel;
  topReason: string;
  // SAFEGUARDING (ICA-H4): explicit monitoring provenance so a consumer/UI can
  // tell a real measurement apart from an ABSENCE of monitoring data, and so a
  // no-data student is presented as "needs review", never silently low-risk.
  unmonitored: boolean;
  dataCompleteness: MonitoringCompleteness;
}

export async function computeStudentRiskList(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
): Promise<StudentRiskPrediction[]> {
  const signals = await loadStudentSignals(db, orgId, schoolId);
  return signals
    .map((s) => {
      const computed = computeStudentRisk({
        attendancePercent: s.attendance_percent,
        homeworkCompletionRate: s.homework_completion_rate,
        averageMarksPercent: s.average_marks_percent,
        communicationGaps: s.communication_gaps,
        behaviorIncidents: s.behavior_incidents,
        timetableMissedSessions: s.timetable_missed_sessions,
        feeOutstandingAmount: s.fee_outstanding_amount,
        feeOverdueDays: s.fee_overdue_days,
      });

      // ── SAFEGUARDING (ICA-H4) ──────────────────────────────────────────────
      // loadStudentSignals feeds a gap-0 placeholder (100) for an UNMONITORED
      // dimension so it contributes nothing to the risk arithmetic — but that
      // also means a student with NO attendance data computes a LOW score. This
      // list previously ignored the new provenance flags, so such a student was
      // labelled "low / Stable profile" and sorted to the BOTTOM of the
      // early-warning list — hiding exactly the students no one is watching
      // (fail-UNSAFE). Mirror computeAndStoreRiskSnapshots: floor an unmonitored
      // student's score/level to the "needs review" band (never "low") and
      // replace the misleading top reason with the no-monitoring-data caveat. A
      // PARTIAL student keeps its honest engine band; the dataCompleteness flag
      // surfaces the caveat to the UI.
      let riskScore = computed.riskScore;
      let riskLevel = computed.riskLevel;
      let topReason = computed.reasons[0]?.label ?? "Stable profile";
      if (s.unmonitored) {
        riskScore = Math.max(computed.riskScore, UNMONITORED_REVIEW_SCORE);
        riskLevel = riskLevelFromScore(riskScore); // >= "medium", never "low"
        topReason = "No monitoring data";
      }

      return {
        studentId: s.student_id,
        studentName: s.student_name,
        className: s.class_name,
        riskScore,
        riskLevel,
        topReason,
        unmonitored: s.unmonitored,
        dataCompleteness: s.data_completeness,
      };
    })
    .sort((a, b) => b.riskScore - a.riskScore);
}

// ─── Deterministic narrative seed (used by predictions_ai as the safe baseline) ─

export function buildPredictionsBaseline(
  kind: "fee-default" | "admission-conversion" | "student-risk",
  counts: { total: number; high: number },
  topNames: string[],
): string {
  const label = kind === "fee-default"
    ? "fee-default risk"
    : kind === "admission-conversion"
    ? "low-conversion risk"
    : "academic risk";
  if (counts.total === 0) {
    return `No ${label} signals in the current data.`;
  }
  const lead = topNames.length > 0 ? ` Prioritise: ${topNames.slice(0, 3).join(", ")}.` : "";
  return `${counts.total} record(s) analysed; ${counts.high} flagged at high ${label}.${lead}`;
}
