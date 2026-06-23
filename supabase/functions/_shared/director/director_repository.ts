// Director portal aggregation — live, org-wide, no student PII.
//
// Every figure here is computed from real operational tables (students,
// finance, admissions, sis, attendance, exams) scoped to ONE organization, or
// read from the director-owned tables (compliance, reports, metric inputs).
// Inputs that have no operational source (marketing spend, operating expense,
// physical capacity) come from `director_metric_inputs` and surface as honest
// zeros until a school enters them — nothing is fabricated.
//
// All queries run on a `withTenantContext` (erp_tenant) connection: the
// org-scope token satisfies the additive `*_director_org_read` RLS policies, so
// RLS — not application code — remains the isolation boundary.

import type { TenantQueryClient } from "../tenant_db.ts";

const CRORE = 10_000_000; // 1 Cr = 1e7
const LAKH = 100_000; // 1 L = 1e5

export type DirectorSchoolStatus =
  | "topPerformer"
  | "onTrack"
  | "atRisk"
  | "critical";

export interface DirectorSchoolRow {
  schoolId: string;
  schoolName: string;
  location: string;
  students: number;
  revenueCr: number;
  admissionsQtd: number;
  feeCollectionPercent: number;
  healthScore: number;
  status: DirectorSchoolStatus;
}

export interface TrendPoint {
  label: string;
  value: number;
}

function round1(value: number): number {
  return Math.round(value * 10) / 10;
}

function pct(part: number, whole: number): number {
  return whole > 0 ? Math.round((part / whole) * 100) : 0;
}

function statusForHealth(score: number): DirectorSchoolStatus {
  if (score >= 85) return "topPerformer";
  if (score >= 70) return "onTrack";
  if (score >= 55) return "atRisk";
  return "critical";
}

/** Trailing six calendar months as {label, monthStart} including the current month. */
function sixMonthWindow(now: Date): { label: string; key: string; start: Date }[] {
  const months: { label: string; key: string; start: Date }[] = [];
  const fmt = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  for (let i = 5; i >= 0; i--) {
    const d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - i, 1));
    months.push({
      label: fmt[d.getUTCMonth()],
      key: `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}`,
      start: d,
    });
  }
  return months;
}

function monthKey(value: unknown): string {
  const d = new Date(value as string);
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}`;
}

// ─── School rows (the heart of the portfolio view) ──────────────────────────

export async function getSchoolRows(
  db: TenantQueryClient,
  orgId: string,
): Promise<DirectorSchoolRow[]> {
  const schools = await db.queryObject<{ id: string; name: string; location: string }>(
    `SELECT s.id, s.name,
            COALESCE(NULLIF(s.settings->>'city', ''), NULLIF(s.settings->>'location', ''), '') AS location
     FROM schools s
     WHERE s.organization_id = $1 AND s.deleted_at IS NULL
     ORDER BY s.name`,
    [orgId],
  );

  const studentRows = await db.queryObject<{ school_id: string; cnt: number }>(
    `SELECT school_id, count(*)::int AS cnt FROM students
     WHERE organization_id = $1 AND status = 'active' GROUP BY school_id`,
    [orgId],
  );
  const revenueRows = await db.queryObject<{ school_id: string; amt: number }>(
    `SELECT school_id, COALESCE(sum(amount_collected), 0)::float8 AS amt
     FROM finance_collections
     WHERE organization_id = $1 AND collection_status = 'completed' GROUP BY school_id`,
    [orgId],
  );
  const billingRows = await db.queryObject<{ school_id: string; billed: number; collected: number }>(
    `SELECT school_id,
            COALESCE(sum(total_amount), 0)::float8 AS billed,
            COALESCE(sum(total_amount - outstanding_amount), 0)::float8 AS collected
     FROM finance_invoices
     WHERE organization_id = $1 AND invoice_status IN ('issued', 'partially_paid', 'paid')
     GROUP BY school_id`,
    [orgId],
  );
  const admissionRows = await db.queryObject<{ school_id: string; cnt: number }>(
    `SELECT school_id, count(*)::int AS cnt FROM admissions_enrollments
     WHERE organization_id = $1 AND created_at >= now() - interval '90 days'
     GROUP BY school_id`,
    [orgId],
  );
  const attendanceRows = await db.queryObject<{ school_id: string; present: number; total: number }>(
    `SELECT school_id,
            count(*) FILTER (WHERE mark <> 'absent')::int AS present,
            count(*)::int AS total
     FROM attendance_records WHERE organization_id = $1 GROUP BY school_id`,
    [orgId],
  );
  const academicRows = await db.queryObject<{ school_id: string; pass: number; total: number }>(
    `SELECT school_id,
            count(*) FILTER (WHERE marks_obtained >= max_marks * 0.4)::int AS pass,
            count(*)::int AS total
     FROM exam_mark_entries WHERE organization_id = $1 GROUP BY school_id`,
    [orgId],
  );

  const byId = <T extends { school_id: string }>(rows: T[]) =>
    new Map(rows.map((r) => [r.school_id, r]));
  const students = byId(studentRows);
  const revenue = byId(revenueRows);
  const billing = byId(billingRows);
  const admissions = byId(admissionRows);
  const attendance = byId(attendanceRows);
  const academic = byId(academicRows);

  return schools.map((s) => {
    const bill = billing.get(s.id);
    const feePct = bill ? pct(bill.collected, bill.billed) : 0;
    const att = attendance.get(s.id);
    const acad = academic.get(s.id);

    // Health is a weighted index of the signals that actually have data.
    const parts: { v: number; w: number }[] = [];
    if (bill && bill.billed > 0) parts.push({ v: feePct, w: 0.4 });
    if (att && att.total > 0) parts.push({ v: pct(att.present, att.total), w: 0.3 });
    if (acad && acad.total > 0) parts.push({ v: pct(acad.pass, acad.total), w: 0.3 });
    const weight = parts.reduce((sum, p) => sum + p.w, 0);
    const healthScore = weight > 0
      ? Math.round(parts.reduce((sum, p) => sum + p.v * p.w, 0) / weight)
      : 75; // no graded/financial data yet → neutral onboarding baseline

    return {
      schoolId: s.id,
      schoolName: s.name,
      location: s.location,
      students: students.get(s.id)?.cnt ?? 0,
      revenueCr: round1((revenue.get(s.id)?.amt ?? 0) / CRORE),
      admissionsQtd: admissions.get(s.id)?.cnt ?? 0,
      feeCollectionPercent: feePct,
      healthScore,
      status: statusForHealth(healthScore),
    };
  });
}

// ─── Revenue ────────────────────────────────────────────────────────────────

export async function getRevenue(db: TenantQueryClient, orgId: string, now: Date) {
  const schoolRows = await getSchoolRows(db, orgId);
  const chainRevenueCr = round1(schoolRows.reduce((sum, s) => sum + s.revenueCr, 0));

  const [expense] = await db.queryObject<{ amt: number }>(
    `SELECT COALESCE(sum(operating_expense_inr), 0)::float8 AS amt
     FROM director_metric_inputs WHERE organization_id = $1`,
    [orgId],
  );
  const expensesCr = round1((expense?.amt ?? 0) / CRORE);
  const netCr = round1(chainRevenueCr - expensesCr);
  const marginPercent = chainRevenueCr > 0 ? Math.round((netCr / chainRevenueCr) * 100) : 0;

  // Forecast = realized collections + still-outstanding receivable (real pipeline).
  const [outstanding] = await db.queryObject<{ amt: number }>(
    `SELECT COALESCE(sum(outstanding_amount), 0)::float8 AS amt
     FROM finance_invoices
     WHERE organization_id = $1 AND invoice_status IN ('issued', 'partially_paid')`,
    [orgId],
  );
  const forecastCr = round1(chainRevenueCr + (outstanding?.amt ?? 0) / CRORE);

  const trendRows = await db.queryObject<{ m: string; amt: number }>(
    `SELECT date_trunc('month', created_at) AS m, sum(amount_collected)::float8 AS amt
     FROM finance_collections
     WHERE organization_id = $1 AND collection_status = 'completed'
       AND created_at >= date_trunc('month', now()) - interval '5 months'
     GROUP BY 1 ORDER BY 1`,
    [orgId],
  );
  const trendMap = new Map(trendRows.map((r) => [monthKey(r.m), r.amt]));
  const revenueTrend: TrendPoint[] = sixMonthWindow(now).map((w) => ({
    label: w.label,
    value: round1((trendMap.get(w.key) ?? 0) / CRORE),
  }));

  return {
    chainRevenueCr,
    expensesCr,
    netCr,
    marginPercent,
    forecastCr,
    revenueBySchool: schoolRows,
    revenueTrend,
  };
}

// ─── Growth ─────────────────────────────────────────────────────────────────

export async function getGrowth(db: TenantQueryClient, orgId: string, now: Date) {
  const [active] = await db.queryObject<{ cnt: number }>(
    `SELECT count(*)::int AS cnt FROM students
     WHERE organization_id = $1 AND status = 'active'`,
    [orgId],
  );
  const activeStudents = active?.cnt ?? 0;

  const [enr] = await db.queryObject<{ cnt: number }>(
    `SELECT count(*)::int AS cnt FROM sis_student_enrollments
     WHERE organization_id = $1 AND created_at >= now() - interval '365 days'`,
    [orgId],
  );
  const newEnrollments = enr?.cnt ?? 0;

  const [withdrawn] = await db.queryObject<{ cnt: number }>(
    `SELECT count(*)::int AS cnt FROM students
     WHERE organization_id = $1 AND status IN ('transferred', 'inactive', 'alumni')`,
    [orgId],
  );
  const withdrawals = withdrawn?.cnt ?? 0;
  const netGrowth = newEnrollments - withdrawals;
  const yoyGrowthPercent = pct(netGrowth, activeStudents);

  const [cap] = await db.queryObject<{ cap: number }>(
    `SELECT COALESCE(sum(student_capacity), 0)::int AS cap FROM (
       SELECT DISTINCT ON (school_id) school_id, student_capacity
       FROM director_metric_inputs WHERE organization_id = $1
       ORDER BY school_id, period_month DESC
     ) latest`,
    [orgId],
  );
  const capacityPercent = pct(activeStudents, cap?.cap ?? 0);

  // Cumulative enrollment curve over the trailing six months.
  const window = sixMonthWindow(now);
  const [base] = await db.queryObject<{ cnt: number }>(
    `SELECT count(*)::int AS cnt FROM sis_student_enrollments
     WHERE organization_id = $1 AND created_at < $2`,
    [orgId, window[0].start.toISOString()],
  );
  const monthly = await db.queryObject<{ m: string; cnt: number }>(
    `SELECT date_trunc('month', created_at) AS m, count(*)::int AS cnt
     FROM sis_student_enrollments
     WHERE organization_id = $1 AND created_at >= $2
     GROUP BY 1 ORDER BY 1`,
    [orgId, window[0].start.toISOString()],
  );
  const monthlyMap = new Map(monthly.map((r) => [monthKey(r.m), r.cnt]));
  let running = base?.cnt ?? 0;
  const enrollmentTrend: TrendPoint[] = window.map((w) => {
    running += monthlyMap.get(w.key) ?? 0;
    return { label: w.label, value: running };
  });

  // Current retention rate, projected flat across the window (single honest figure).
  const retention = activeStudents + withdrawals > 0
    ? Math.round((activeStudents / (activeStudents + withdrawals)) * 100)
    : 0;
  const retentionTrend: TrendPoint[] = window.map((w) => ({ label: w.label, value: retention }));

  return {
    yoyGrowthPercent,
    newEnrollments,
    withdrawals,
    netGrowth,
    capacityPercent,
    enrollmentTrend,
    retentionTrend,
  };
}

// ─── Admissions funnel (org-wide) ───────────────────────────────────────────

export async function getAdmissions(db: TenantQueryClient, orgId: string) {
  const [funnel] = await db.queryObject<{
    inquiries: number;
    applications: number;
    interviews: number;
    enrolled: number;
  }>(
    `SELECT
       (SELECT count(*)::int FROM admissions_leads WHERE organization_id = $1) AS inquiries,
       (SELECT count(*)::int FROM admissions_applications
          WHERE organization_id = $1 AND status <> 'draft') AS applications,
       (SELECT count(*)::int FROM admissions_applications
          WHERE organization_id = $1 AND status IN ('under_review', 'approved')) AS interviews,
       (SELECT count(*)::int FROM admissions_enrollments WHERE organization_id = $1) AS enrolled`,
    [orgId],
  );

  const perSchool = await db.queryObject<{ name: string; leads: number; enrolled: number }>(
    `SELECT s.name,
            (SELECT count(*)::int FROM admissions_leads l
               WHERE l.organization_id = $1 AND l.school_id = s.id) AS leads,
            (SELECT count(*)::int FROM admissions_enrollments e
               WHERE e.organization_id = $1 AND e.school_id = s.id) AS enrolled
     FROM schools s
     WHERE s.organization_id = $1 AND s.deleted_at IS NULL`,
    [orgId],
  );
  const bySchoolConversion: Record<string, number> = {};
  for (const row of perSchool) {
    bySchoolConversion[row.name] = pct(row.enrolled, row.leads);
  }

  return {
    inquiries: funnel?.inquiries ?? 0,
    applications: funnel?.applications ?? 0,
    interviews: funnel?.interviews ?? 0,
    enrolled: funnel?.enrolled ?? 0,
    conversionPercent: pct(funnel?.enrolled ?? 0, funnel?.inquiries ?? 0),
    bySchoolConversion,
  };
}

// ─── Marketing (org-wide; spend/CPL/ROI need entered inputs) ────────────────

export async function getMarketing(db: TenantQueryClient, orgId: string) {
  const [leadsRow] = await db.queryObject<{ cnt: number }>(
    `SELECT count(*)::int AS cnt FROM admissions_leads WHERE organization_id = $1`,
    [orgId],
  );
  const totalLeads = leadsRow?.cnt ?? 0;

  const [spendRow] = await db.queryObject<{ spend: number }>(
    `SELECT COALESCE(sum(marketing_spend_inr), 0)::float8 AS spend
     FROM director_metric_inputs WHERE organization_id = $1`,
    [orgId],
  );
  const spendInr = spendRow?.spend ?? 0;

  const [revRow] = await db.queryObject<{ amt: number }>(
    `SELECT COALESCE(sum(amount_collected), 0)::float8 AS amt FROM finance_collections
     WHERE organization_id = $1 AND collection_status = 'completed'`,
    [orgId],
  );
  const revenueInr = revRow?.amt ?? 0;

  return {
    totalSpendLakhs: round1(spendInr / LAKH),
    totalLeads,
    cplInr: spendInr > 0 && totalLeads > 0 ? Math.round(spendInr / totalLeads) : 0,
    roiPercent: spendInr > 0 ? Math.round(((revenueInr - spendInr) / spendInr) * 100) : 0,
    // No channel-attribution source exists yet → empty rather than invented splits.
    channelPerformance: {} as Record<string, number>,
  };
}

// ─── Compliance (real, persisted) ───────────────────────────────────────────

interface ComplianceRow {
  id: string;
  school_name: string;
  category: string;
  requirement: string;
  status: string;
  due_date: string;
  owner: string;
  evidence_uploaded: boolean;
  acknowledged: boolean;
}

function mapCompliance(r: ComplianceRow) {
  return {
    id: r.id,
    schoolName: r.school_name,
    category: r.category,
    requirement: r.requirement,
    status: r.status,
    dueDate: new Date(r.due_date).toISOString(),
    owner: r.owner,
    evidenceUploaded: r.evidence_uploaded,
    acknowledged: r.acknowledged,
  };
}

export async function getCompliance(db: TenantQueryClient, orgId: string) {
  const rows = await db.queryObject<ComplianceRow>(
    `SELECT id, school_name, category, requirement, status, due_date, owner,
            evidence_uploaded, acknowledged
     FROM director_compliance_items WHERE organization_id = $1
     ORDER BY due_date ASC`,
    [orgId],
  );
  return rows.map(mapCompliance);
}

export async function acknowledgeCompliance(
  db: TenantQueryClient,
  orgId: string,
  userId: string,
  complianceId: string,
) {
  const rows = await db.queryObject<ComplianceRow>(
    `UPDATE director_compliance_items
     SET acknowledged = true, acknowledged_by = $3, acknowledged_at = now()
     WHERE organization_id = $1 AND id = $2
     RETURNING id, school_name, category, requirement, status, due_date, owner,
               evidence_uploaded, acknowledged`,
    [orgId, complianceId, userId],
  );
  return rows.length > 0 ? mapCompliance(rows[0]) : null;
}

// ─── Strategic reports (real catalog) ───────────────────────────────────────

interface ReportRow {
  id: string;
  title: string;
  description: string;
  file_type: string;
  last_generated_at: string;
}

function mapReport(r: ReportRow) {
  return {
    id: r.id,
    title: r.title,
    description: r.description,
    fileType: r.file_type,
    lastGeneratedAt: new Date(r.last_generated_at).toISOString(),
  };
}

export async function getReports(db: TenantQueryClient, orgId: string) {
  const rows = await db.queryObject<ReportRow>(
    `SELECT id, title, description, file_type, last_generated_at
     FROM director_reports WHERE organization_id = $1
     ORDER BY last_generated_at DESC`,
    [orgId],
  );
  return rows.map(mapReport);
}

export async function markReportGenerated(
  db: TenantQueryClient,
  orgId: string,
  userId: string,
  reportId: string,
) {
  const rows = await db.queryObject<{ id: string; last_generated_at: string }>(
    `UPDATE director_reports
     SET last_generated_at = now(), generated_by = $3
     WHERE organization_id = $1 AND id = $2
     RETURNING id, last_generated_at`,
    [orgId, reportId, userId],
  );
  return rows.length > 0 ? rows[0] : null;
}

// ─── Executive summary (deterministic from real aggregates; AI = Batch 8) ───

export function buildExecutiveSummary(
  focusArea: string,
  schools: DirectorSchoolRow[],
  revenue: { chainRevenueCr: number; marginPercent: number },
  admissions: { enrolled: number; inquiries: number; conversionPercent: number },
): string {
  const totalStudents = schools.reduce((sum, s) => sum + s.students, 0);
  const atRisk = schools.filter((s) => s.status === "atRisk" || s.status === "critical");
  const avgFee = schools.length > 0
    ? Math.round(schools.reduce((sum, s) => sum + s.feeCollectionPercent, 0) / schools.length)
    : 0;

  const riskLine = atRisk.length > 0
    ? `${atRisk.length} campus${atRisk.length === 1 ? "" : "es"} need attention (${atRisk.map((s) => s.schoolName).join(", ")}).`
    : "All campuses are tracking on or above plan.";

  return [
    `Portfolio spans ${schools.length} school${schools.length === 1 ? "" : "s"} and ${totalStudents.toLocaleString("en-IN")} active students.`,
    `Combined collections stand at ₹${revenue.chainRevenueCr} Cr with ${avgFee}% average fee realization and a ${revenue.marginPercent}% net margin.`,
    `Admissions converted ${admissions.enrolled} enrolments from ${admissions.inquiries} enquiries (${admissions.conversionPercent}%).`,
    riskLine,
    focusArea && focusArea !== "dashboard" ? `Focus area: ${focusArea}.` : "",
  ].filter((line) => line.length > 0).join(" ");
}

// ─── Dashboard composite ────────────────────────────────────────────────────

export async function getDashboard(db: TenantQueryClient, orgId: string, now: Date) {
  const schoolRows = await getSchoolRows(db, orgId);
  const revenue = await getRevenue(db, orgId, now);
  const growth = await getGrowth(db, orgId, now);
  const marketing = await getMarketing(db, orgId);
  const admissions = await getAdmissions(db, orgId);
  const compliance = await getCompliance(db, orgId);

  const totalStudents = schoolRows.reduce((sum, s) => sum + s.students, 0);
  const atRisk = schoolRows.filter((s) => s.status === "atRisk" || s.status === "critical").length;
  const newAdmissions = schoolRows.reduce((sum, s) => sum + s.admissionsQtd, 0);

  const kpis = [
    { id: "schools", label: "Total Schools", value: String(schoolRows.length) },
    { id: "students", label: "Total Students", value: totalStudents.toLocaleString("en-IN") },
    { id: "revenue", label: "Combined Revenue", value: `${revenue.chainRevenueCr} Cr` },
    { id: "admissions", label: "New Admissions QTD", value: String(newAdmissions) },
    { id: "risk", label: "Schools at Risk", value: String(atRisk) },
  ];

  const complianceAlerts = compliance
    .filter((c) => c.status === "overdue" || c.status === "dueSoon")
    .slice(0, 5);

  return {
    kpis,
    schoolRows,
    revenue,
    growth,
    marketing,
    admissions,
    complianceAlerts,
    executiveSummary: buildExecutiveSummary("dashboard", schoolRows, revenue, admissions),
  };
}
