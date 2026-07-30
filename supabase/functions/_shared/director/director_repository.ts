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
import { attendanceDenominatorSql, attendedDaysSql } from "../attendance/attendance_percentage.ts";

const CRORE = 10_000_000; // 1 Cr = 1e7
const LAKH = 100_000; // 1 L = 1e5

// ICA-C2 (perf) — the academic dashboard aggregates (attendance %, pass rate)
// are meant to reflect the CURRENT academic year, not an ever-growing all-time
// scan of every record a chain has ever produced. We bound the attendance_records
// and exam_mark_entries aggregates to a trailing 12-month window — the SAME
// "current-year" convention getGrowth already uses for new enrollments
// (`now() - interval '365 days'`, see :303-307) — so the aggregated working set
// stays bounded as pilot data accumulates year over year.
//
// Deliberately NOT windowed (each is a lifetime figure by design, not a period
// aggregate): the active-student roster count (point-in-time state), and the
// finance_collections / finance_invoices money totals (total revenue realised and
// total receivable outstanding). Admissions already carries its own 90-day QTD
// window. A precise per-school academic_years join is a matview follow-up; this
// self-contained window matches the file's existing precedent with no migration.
const CURRENT_ACADEMIC_YEAR_INTERVAL = "365 days";

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
  // DIR-2 — consolidated collection report: the raw money inputs behind
  // feeCollectionPercent, surfaced per school (in rupees) so the client can
  // render a per-school + org-total collection view. `outstandingInr` is the
  // still-uncollected receivable (billed − collected). Additive to the certified
  // /director/schools contract — existing fields are unchanged.
  billedInr: number;
  collectedInr: number;
  outstandingInr: number;
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
  // CANONICAL attendance-% (2026-07-09): attended = present + late + 0.5×half_day,
  // denom = total_marked − excused — see attendance/attendance_percentage.ts. This
  // used to count anything non-'absent' as fully present and included excused
  // days in the denominator, diverging from every other attendance-% surface.
  // ICA-C2: bounded to the current academic year (trailing 365 days on
  // created_at) — the dashboard attendance % reflects THIS year, and the scan no
  // longer grows without limit as historical records pile up.
  const attendanceRows = await db.queryObject<{ school_id: string; attended: number; denom: number }>(
    `SELECT school_id,
            ${attendedDaysSql("mark")}::float8 AS attended,
            ${attendanceDenominatorSql("mark")}::int AS denom
     FROM attendance_records
     WHERE organization_id = $1
       AND created_at >= now() - interval '${CURRENT_ACADEMIC_YEAR_INTERVAL}'
     GROUP BY school_id`,
    [orgId],
  );
  // ICA-C2: bounded to the current academic year (trailing 365 days). exam_mark_entries
  // has no created_at, so we bound on updated_at (the mark's last-touched/publish time).
  const academicRows = await db.queryObject<{ school_id: string; pass: number; total: number }>(
    `SELECT school_id,
            count(*) FILTER (WHERE marks_obtained >= max_marks * 0.4)::int AS pass,
            count(*)::int AS total
     FROM exam_mark_entries
     WHERE organization_id = $1
       AND updated_at >= now() - interval '${CURRENT_ACADEMIC_YEAR_INTERVAL}'
     GROUP BY school_id`,
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
    // DIR-2 — same billed/collected computed above; outstanding is the residual
    // receivable. Never negative (collected can't exceed billed here).
    const billedInr = Math.round(bill?.billed ?? 0);
    const collectedInr = Math.round(bill?.collected ?? 0);
    const outstandingInr = Math.max(0, billedInr - collectedInr);
    const att = attendance.get(s.id);
    const acad = academic.get(s.id);

    // Health is a weighted index of the signals that actually have data.
    const parts: { v: number; w: number }[] = [];
    if (bill && bill.billed > 0) parts.push({ v: feePct, w: 0.4 });
    if (att && att.denom > 0) parts.push({ v: pct(att.attended, att.denom), w: 0.3 });
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
      billedInr,
      collectedInr,
      outstandingInr,
      healthScore,
      status: statusForHealth(healthScore),
    };
  });
}

// ─── DIR-2: consolidated collection report (per-school + org totals) ─────────
// Reuses the exact billed/collected/outstanding already computed on each school
// row (no re-derivation), so the money math stays consistent with the certified
// /director/schools contract. Backs the optional GET /director/collections.

export interface DirectorCollectionRow {
  schoolId: string;
  name: string;
  feeCollectionPercent: number;
  billedInr: number;
  collectedInr: number;
  outstandingInr: number;
}

export interface DirectorCollectionReport {
  schools: DirectorCollectionRow[];
  totals: {
    billedInr: number;
    collectedInr: number;
    outstandingInr: number;
    feeCollectionPercent: number;
  };
}

export async function getCollectionReport(
  db: TenantQueryClient,
  orgId: string,
): Promise<DirectorCollectionReport> {
  const rows = await getSchoolRows(db, orgId);
  const schools: DirectorCollectionRow[] = rows.map((s) => ({
    schoolId: s.schoolId,
    name: s.schoolName,
    feeCollectionPercent: s.feeCollectionPercent,
    billedInr: s.billedInr,
    collectedInr: s.collectedInr,
    outstandingInr: s.outstandingInr,
  }));
  const billedInr = schools.reduce((sum, s) => sum + s.billedInr, 0);
  const collectedInr = schools.reduce((sum, s) => sum + s.collectedInr, 0);
  const outstandingInr = schools.reduce((sum, s) => sum + s.outstandingInr, 0);
  return {
    schools,
    totals: {
      billedInr,
      collectedInr,
      outstandingInr,
      feeCollectionPercent: pct(collectedInr, billedInr),
    },
  };
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

// ─── Non-derivable metric inputs (spend / expense / capacity) ───────────────
// These three figures have no operational source, so the chain owner enters
// them per school per month. They feed Revenue (expenses, net, margin),
// Marketing (spend, CPL, ROI) and Growth (capacity %). Until entered, those
// metrics report honest zeros — this is the write path that makes them real.

export interface DirectorMetricInput {
  id: string;
  schoolId: string;
  schoolName: string;
  periodMonth: string; // YYYY-MM-01 (first of month)
  marketingSpendInr: number;
  operatingExpenseInr: number;
  studentCapacity: number;
}

interface MetricInputRow {
  id: string;
  school_id: string;
  school_name: string;
  period_month: string;
  marketing_spend_inr: number;
  operating_expense_inr: number;
  student_capacity: number;
}

function mapMetricInput(r: MetricInputRow): DirectorMetricInput {
  return {
    id: r.id,
    schoolId: r.school_id,
    schoolName: r.school_name,
    periodMonth: new Date(r.period_month).toISOString().slice(0, 10),
    marketingSpendInr: Number(r.marketing_spend_inr) || 0,
    operatingExpenseInr: Number(r.operating_expense_inr) || 0,
    studentCapacity: Number(r.student_capacity) || 0,
  };
}

export async function getMetricInputs(
  db: TenantQueryClient,
  orgId: string,
): Promise<DirectorMetricInput[]> {
  const rows = await db.queryObject<MetricInputRow>(
    `SELECT mi.id, mi.school_id, s.name AS school_name, mi.period_month,
            mi.marketing_spend_inr::float8 AS marketing_spend_inr,
            mi.operating_expense_inr::float8 AS operating_expense_inr,
            mi.student_capacity
     FROM director_metric_inputs mi
     JOIN schools s ON s.id = mi.school_id
     WHERE mi.organization_id = $1
     ORDER BY mi.period_month DESC, s.name`,
    [orgId],
  );
  return rows.map(mapMetricInput);
}

export interface MetricInputDraft {
  schoolId: string;
  periodMonth: string; // YYYY-MM-01
  marketingSpendInr: number;
  operatingExpenseInr: number;
  studentCapacity: number;
}

/**
 * Upsert a per-school, per-month metric input. Validates the school belongs to
 * the org first (a foreign school would pass the org-scoped RLS WITH CHECK since
 * we stamp organization_id ourselves, so the guard must be explicit). Returns
 * null when the school is not in this organization.
 */
export async function upsertMetricInput(
  db: TenantQueryClient,
  orgId: string,
  draft: MetricInputDraft,
): Promise<DirectorMetricInput | null> {
  const owned = await db.queryObject<{ ok: number }>(
    `SELECT 1 AS ok FROM schools
     WHERE id = $1 AND organization_id = $2 AND deleted_at IS NULL`,
    [draft.schoolId, orgId],
  );
  if (owned.length === 0) return null;

  const rows = await db.queryObject<MetricInputRow>(
    `INSERT INTO director_metric_inputs
       (organization_id, school_id, period_month,
        marketing_spend_inr, operating_expense_inr, student_capacity)
     VALUES ($1, $2, date_trunc('month', $3::date), $4, $5, $6)
     ON CONFLICT (organization_id, school_id, period_month) DO UPDATE
       SET marketing_spend_inr = EXCLUDED.marketing_spend_inr,
           operating_expense_inr = EXCLUDED.operating_expense_inr,
           student_capacity = EXCLUDED.student_capacity,
           updated_at = now()
     RETURNING id, school_id,
       (SELECT name FROM schools WHERE id = director_metric_inputs.school_id) AS school_name,
       period_month,
       marketing_spend_inr::float8 AS marketing_spend_inr,
       operating_expense_inr::float8 AS operating_expense_inr,
       student_capacity`,
    [
      orgId,
      draft.schoolId,
      draft.periodMonth,
      draft.marketingSpendInr,
      draft.operatingExpenseInr,
      draft.studentCapacity,
    ],
  );
  return rows.length > 0 ? mapMetricInput(rows[0]) : null;
}

// ─── DIR-D1: per-school read-only drill-down snapshot ────────────────────────
// The director "Open Management Portal" action opens an AUDITED, READ-ONLY
// per-school snapshot — NOT impersonation, NOT a token/persona switch, NO
// writes. The schoolId MUST belong to the director's org (reuses the metric-
// inputs school-belongs-to-org guard). A foreign school returns null → the
// handler answers 404 (never leaking another org's data). Every figure is a
// school-level aggregate over the same org-read RLS SELECTs used elsewhere —
// no student/parent PII.

export interface DirectorSchoolSnapshot {
  schoolId: string;
  schoolName: string;
  location: string;
  students: number;
  attendancePercent: number;
  feeCollectionPercent: number;
  billedInr: number;
  collectedInr: number;
  outstandingInr: number;
  admissions: {
    inquiries: number;
    applications: number;
    enrolled: number;
    conversionPercent: number;
  };
  academic: {
    passPercent: number;
    gradedEntries: number;
  };
  healthScore: number;
  status: DirectorSchoolStatus;
}

export async function getSchoolSnapshot(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
): Promise<DirectorSchoolSnapshot | null> {
  // Same explicit school-belongs-to-org guard as upsertMetricInput (:549-554):
  // a foreign school must never resolve, even though org-scope RLS already
  // fences reads to this organization.
  const owned = await db.queryObject<{ name: string; location: string }>(
    `SELECT name,
            COALESCE(NULLIF(settings->>'city', ''), NULLIF(settings->>'location', ''), '') AS location
     FROM schools
     WHERE id = $1 AND organization_id = $2 AND deleted_at IS NULL`,
    [schoolId, orgId],
  );
  if (owned.length === 0) return null;

  const [students] = await db.queryObject<{ cnt: number }>(
    `SELECT count(*)::int AS cnt FROM students
     WHERE organization_id = $1 AND school_id = $2 AND status = 'active'`,
    [orgId, schoolId],
  );
  const [billing] = await db.queryObject<{ billed: number; collected: number }>(
    `SELECT COALESCE(sum(total_amount), 0)::float8 AS billed,
            COALESCE(sum(total_amount - outstanding_amount), 0)::float8 AS collected
     FROM finance_invoices
     WHERE organization_id = $1 AND school_id = $2
       AND invoice_status IN ('issued', 'partially_paid', 'paid')`,
    [orgId, schoolId],
  );
  // CANONICAL attendance-% (2026-07-09) — same divergent present<>'absent'/total
  // formula as getSchoolRows above, now routed through the shared fragments.
  // ICA-C2: same current-academic-year (trailing 365-day) bound as getSchoolRows,
  // so the drill-down attendance % / pass rate match the portfolio row for this
  // school instead of diverging (one all-time, one windowed).
  const [attendance] = await db.queryObject<{ attended: number; denom: number }>(
    `SELECT ${attendedDaysSql("mark")}::float8 AS attended,
            ${attendanceDenominatorSql("mark")}::int AS denom
     FROM attendance_records
     WHERE organization_id = $1 AND school_id = $2
       AND created_at >= now() - interval '${CURRENT_ACADEMIC_YEAR_INTERVAL}'`,
    [orgId, schoolId],
  );
  const [academic] = await db.queryObject<{ pass: number; total: number }>(
    `SELECT count(*) FILTER (WHERE marks_obtained >= max_marks * 0.4)::int AS pass,
            count(*)::int AS total
     FROM exam_mark_entries
     WHERE organization_id = $1 AND school_id = $2
       AND updated_at >= now() - interval '${CURRENT_ACADEMIC_YEAR_INTERVAL}'`,
    [orgId, schoolId],
  );
  const [funnel] = await db.queryObject<{
    inquiries: number;
    applications: number;
    enrolled: number;
  }>(
    `SELECT
       (SELECT count(*)::int FROM admissions_leads
          WHERE organization_id = $1 AND school_id = $2) AS inquiries,
       (SELECT count(*)::int FROM admissions_applications
          WHERE organization_id = $1 AND school_id = $2 AND status <> 'draft') AS applications,
       (SELECT count(*)::int FROM admissions_enrollments
          WHERE organization_id = $1 AND school_id = $2) AS enrolled`,
    [orgId, schoolId],
  );

  const billed = Math.round(billing?.billed ?? 0);
  const collected = Math.round(billing?.collected ?? 0);
  const outstandingInr = Math.max(0, billed - collected);
  const feeCollectionPercent = pct(collected, billed);
  const attendancePercent = pct(attendance?.attended ?? 0, attendance?.denom ?? 0);
  const passPercent = pct(academic?.pass ?? 0, academic?.total ?? 0);
  const inquiries = funnel?.inquiries ?? 0;
  const enrolled = funnel?.enrolled ?? 0;

  // Health mirrors getSchoolRows: a weighted index of the signals with data.
  const parts: { v: number; w: number }[] = [];
  if (billed > 0) parts.push({ v: feeCollectionPercent, w: 0.4 });
  if ((attendance?.denom ?? 0) > 0) parts.push({ v: attendancePercent, w: 0.3 });
  if ((academic?.total ?? 0) > 0) parts.push({ v: passPercent, w: 0.3 });
  const weight = parts.reduce((sum, p) => sum + p.w, 0);
  const healthScore = weight > 0
    ? Math.round(parts.reduce((sum, p) => sum + p.v * p.w, 0) / weight)
    : 75;

  return {
    schoolId,
    schoolName: owned[0].name,
    location: owned[0].location,
    students: students?.cnt ?? 0,
    attendancePercent,
    feeCollectionPercent,
    billedInr: billed,
    collectedInr: collected,
    outstandingInr,
    admissions: {
      inquiries,
      applications: funnel?.applications ?? 0,
      enrolled,
      conversionPercent: pct(enrolled, inquiries),
    },
    academic: {
      passPercent,
      gradedEntries: academic?.total ?? 0,
    },
    healthScore,
    status: statusForHealth(healthScore),
  };
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

// ─── Board pack (the real export payload) ───────────────────────────────────
// A real, board-ready document built entirely from live org-wide aggregates.
// The client renders this into a PDF — there is nothing fabricated here, and no
// student/parent PII (school-level aggregates only). Returned by the export
// endpoint so "Export" produces an actual document, not just a stamp.

export interface DirectorBoardPack {
  reportId: string;
  title: string;
  description: string;
  fileType: string;
  generatedAt: string;
  executiveSummary: string;
  kpis: { label: string; value: string }[];
  schools: {
    schoolName: string;
    location: string;
    students: number;
    revenueCr: number;
    feeCollectionPercent: number;
    healthScore: number;
    status: DirectorSchoolStatus;
  }[];
  revenue: {
    chainRevenueCr: number;
    expensesCr: number;
    netCr: number;
    marginPercent: number;
    forecastCr: number;
  };
  growth: { yoyGrowthPercent: number; newEnrollments: number; withdrawals: number; netGrowth: number; capacityPercent: number };
  admissions: { inquiries: number; applications: number; interviews: number; enrolled: number; conversionPercent: number };
  marketing: { totalSpendLakhs: number; totalLeads: number; cplInr: number; roiPercent: number };
  compliance: { total: number; compliant: number; dueSoon: number; overdue: number };
}

export async function buildBoardPack(
  db: TenantQueryClient,
  orgId: string,
  reportId: string,
  now: Date,
): Promise<DirectorBoardPack | null> {
  const reportRows = await db.queryObject<ReportRow>(
    `SELECT id, title, description, file_type, last_generated_at
     FROM director_reports WHERE organization_id = $1 AND id = $2`,
    [orgId, reportId],
  );
  if (reportRows.length === 0) return null;
  const report = reportRows[0];

  const schoolRows = await getSchoolRows(db, orgId);
  const revenue = await getRevenue(db, orgId, now);
  const growth = await getGrowth(db, orgId, now);
  const marketing = await getMarketing(db, orgId);
  const admissions = await getAdmissions(db, orgId);
  const compliance = await getCompliance(db, orgId);

  const totalStudents = schoolRows.reduce((sum, s) => sum + s.students, 0);
  const atRisk = schoolRows.filter((s) => s.status === "atRisk" || s.status === "critical").length;
  const newAdmissions = schoolRows.reduce((sum, s) => sum + s.admissionsQtd, 0);

  return {
    reportId: report.id,
    title: report.title,
    description: report.description,
    fileType: report.file_type,
    generatedAt: now.toISOString(),
    executiveSummary: buildExecutiveSummary("strategic_reports", schoolRows, revenue, admissions),
    kpis: [
      { label: "Total Schools", value: String(schoolRows.length) },
      { label: "Total Students", value: totalStudents.toLocaleString("en-IN") },
      { label: "Combined Revenue", value: `₹${revenue.chainRevenueCr} Cr` },
      { label: "New Admissions QTD", value: String(newAdmissions) },
      { label: "Schools at Risk", value: String(atRisk) },
    ],
    schools: schoolRows.map((s) => ({
      schoolName: s.schoolName,
      location: s.location,
      students: s.students,
      revenueCr: s.revenueCr,
      feeCollectionPercent: s.feeCollectionPercent,
      healthScore: s.healthScore,
      status: s.status,
    })),
    revenue: {
      chainRevenueCr: revenue.chainRevenueCr,
      expensesCr: revenue.expensesCr,
      netCr: revenue.netCr,
      marginPercent: revenue.marginPercent,
      forecastCr: revenue.forecastCr,
    },
    growth: {
      yoyGrowthPercent: growth.yoyGrowthPercent,
      newEnrollments: growth.newEnrollments,
      withdrawals: growth.withdrawals,
      netGrowth: growth.netGrowth,
      capacityPercent: growth.capacityPercent,
    },
    admissions: {
      inquiries: admissions.inquiries,
      applications: admissions.applications,
      interviews: admissions.interviews,
      enrolled: admissions.enrolled,
      conversionPercent: admissions.conversionPercent,
    },
    marketing: {
      totalSpendLakhs: marketing.totalSpendLakhs,
      totalLeads: marketing.totalLeads,
      cplInr: marketing.cplInr,
      roiPercent: marketing.roiPercent,
    },
    compliance: {
      total: compliance.length,
      compliant: compliance.filter((c) => c.status === "compliant").length,
      dueSoon: compliance.filter((c) => c.status === "dueSoon").length,
      overdue: compliance.filter((c) => c.status === "overdue").length,
    },
  };
}
