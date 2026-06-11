import type { TenantQueryClient } from "../tenant_db.ts";

export interface CollectionTrendPoint {
  month: string;
  collected: number;
  expected: number;
}

export interface DefaulterPrediction {
  studentId: string;
  studentName: string;
  className: string;
  outstandingAmount: number;
  riskScore: number;
  daysOverdue: number;
}

export interface CollectionRiskAlert {
  id: string;
  severity: "low" | "medium" | "high";
  title: string;
  detail: string;
}

export interface FinanceCopilotSnapshot {
  feeCollectionForecast: number;
  forecastConfidence: number;
  monthlyRevenueForecast: number;
  defaulterPredictions: DefaulterPrediction[];
  collectionTrend: CollectionTrendPoint[];
  riskAlerts: CollectionRiskAlert[];
  generatedAt: string;
}

export interface FinanceExecutiveSnapshot {
  expectedCollections: number;
  outstandingCollections: number;
  collectionHealthScore: number;
  riskStudents: DefaulterPrediction[];
  generatedAt: string;
}

function monthKey(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
}

export async function computeFinanceCopilot(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
): Promise<FinanceCopilotSnapshot> {
  const trendRows = await db.queryObject<{ month: string; collected: string }>(
    `SELECT to_char(date_trunc('month', collection_date), 'YYYY-MM') AS month,
            COALESCE(SUM(amount_collected), 0)::text AS collected
     FROM finance_collections
     WHERE organization_id = $1 AND school_id = $2
       AND collection_status IN ('completed', 'partially_refunded', 'refunded')
       AND collection_date >= (CURRENT_DATE - INTERVAL '6 months')
     GROUP BY 1
     ORDER BY 1`,
    [orgId, schoolId],
  );

  const collectionTrend: CollectionTrendPoint[] = trendRows.map((r) => {
    const collected = parseFloat(r.collected);
    return { month: r.month, collected, expected: Math.round(collected * 1.05) };
  });

  const avgMonthly = collectionTrend.length
    ? collectionTrend.reduce((s, p) => s + p.collected, 0) / collectionTrend.length
    : 0;
  const lastMonth = collectionTrend.at(-1)?.collected ?? avgMonthly;
  const feeCollectionForecast = Math.round(lastMonth * 1.08);
  const forecastConfidence = collectionTrend.length >= 3 ? 85 : 62;

  const defaulterRows = await db.queryObject<{
    student_id: string;
    student_name: string;
    outstanding: string;
    days_overdue: string;
  }>(
    `SELECT fsa.student_id,
            COALESCE(s.display_name, 'Student') AS student_name,
            COALESCE(fsa.outstanding_amount, 0)::text AS outstanding,
            COALESCE(MAX(EXTRACT(day FROM now() - fi.due_date)), 0)::text AS days_overdue
     FROM finance_student_accounts fsa
     LEFT JOIN students s ON s.id = fsa.student_id
     LEFT JOIN finance_invoices fi ON fi.student_id = fsa.student_id
       AND fi.organization_id = fsa.organization_id
       AND fi.invoice_status IN ('issued', 'partially_paid')
       AND fi.due_date < CURRENT_DATE
     WHERE fsa.organization_id = $1 AND fsa.school_id = $2
       AND fsa.status = 'open'
       AND fsa.outstanding_amount > 0
     GROUP BY fsa.student_id, s.display_name, fsa.outstanding_amount
     ORDER BY fsa.outstanding_amount DESC
     LIMIT 20`,
    [orgId, schoolId],
  );

  const defaulterPredictions: DefaulterPrediction[] = defaulterRows.map((r) => {
    const outstanding = parseFloat(r.outstanding);
    const daysOverdue = parseInt(r.days_overdue, 10) || 0;
    const riskScore = Math.min(100, Math.round(40 + daysOverdue * 1.5 + outstanding / 1000));
    return {
      studentId: r.student_id,
      studentName: r.student_name,
      className: "",
      outstandingAmount: outstanding,
      riskScore,
      daysOverdue,
    };
  });

  const riskAlerts: CollectionRiskAlert[] = [];
  const highRisk = defaulterPredictions.filter((d) => d.riskScore >= 75);
  if (highRisk.length > 0) {
    riskAlerts.push({
      id: "alert_high_defaulters",
      severity: "high",
      title: `${highRisk.length} high-risk defaulters`,
      detail: "Immediate follow-up recommended for fee recovery",
    });
  }
  if (collectionTrend.length >= 2) {
    const prev = collectionTrend.at(-2)!.collected;
    const curr = collectionTrend.at(-1)!.collected;
    if (curr < prev * 0.9) {
      riskAlerts.push({
        id: "alert_collection_drop",
        severity: "medium",
        title: "Collection trend declining",
        detail: `Last month ${Math.round((1 - curr / prev) * 100)}% below prior month`,
      });
    }
  }

  return {
    feeCollectionForecast,
    forecastConfidence,
    monthlyRevenueForecast: Math.round(avgMonthly * 1.06),
    defaulterPredictions,
    collectionTrend,
    riskAlerts,
    generatedAt: new Date().toISOString(),
  };
}

export async function computeFinanceExecutive(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
): Promise<FinanceExecutiveSnapshot> {
  const kpiRows = await db.queryObject<{
    expected: string;
    outstanding: string;
    collected: string;
    invoiced: string;
  }>(
    `SELECT
       (SELECT COALESCE(SUM(outstanding_amount), 0)::text
        FROM finance_invoices
        WHERE organization_id = $1 AND school_id = $2
          AND invoice_status IN ('issued', 'partially_paid')
          AND due_date >= CURRENT_DATE) AS expected,
       (SELECT COALESCE(SUM(outstanding_amount), 0)::text
        FROM finance_invoices
        WHERE organization_id = $1 AND school_id = $2
          AND invoice_status IN ('issued', 'partially_paid')) AS outstanding,
       (SELECT COALESCE(SUM(amount_collected), 0)::text
        FROM finance_collections
        WHERE organization_id = $1 AND school_id = $2
          AND collection_status IN ('completed', 'partially_refunded')) AS collected,
       (SELECT COALESCE(SUM(total_amount), 0)::text
        FROM finance_invoices
        WHERE organization_id = $1 AND school_id = $2
          AND invoice_status != 'cancelled') AS invoiced`,
    [orgId, schoolId],
  );

  const kpi = kpiRows[0] ?? { expected: "0", outstanding: "0", collected: "0", invoiced: "0" };
  const collected = parseFloat(kpi.collected);
  const invoiced = parseFloat(kpi.invoiced);
  const collectionRate = invoiced > 0 ? (collected / invoiced) * 100 : 0;
  const collectionHealthScore = Math.min(100, Math.round(collectionRate * 0.7 + (100 - Math.min(100, parseFloat(kpi.outstanding) / Math.max(invoiced, 1) * 100)) * 0.3));

  const copilot = await computeFinanceCopilot(db, orgId, schoolId);

  return {
    expectedCollections: parseFloat(kpi.expected),
    outstandingCollections: parseFloat(kpi.outstanding),
    collectionHealthScore,
    riskStudents: copilot.defaulterPredictions.filter((d) => d.riskScore >= 60),
    generatedAt: new Date().toISOString(),
  };
}

export function computeFinanceCopilotFromSeed(): FinanceCopilotSnapshot {
  return {
    feeCollectionForecast: 842000,
    forecastConfidence: 82,
    monthlyRevenueForecast: 810000,
    defaulterPredictions: [
      {
        studentId: "stu_1",
        studentName: "Rahul Sharma",
        className: "8-A",
        outstandingAmount: 12500,
        riskScore: 88,
        daysOverdue: 45,
      },
    ],
    collectionTrend: [
      { month: "2026-01", collected: 720000, expected: 756000 },
      { month: "2026-02", collected: 780000, expected: 819000 },
      { month: "2026-03", collected: 810000, expected: 850500 },
    ],
    riskAlerts: [
      {
        id: "seed_alert",
        severity: "medium",
        title: "Term 2 collection pace below target",
        detail: "Follow up with 12 pending accounts",
      },
    ],
    generatedAt: new Date().toISOString(),
  };
}
