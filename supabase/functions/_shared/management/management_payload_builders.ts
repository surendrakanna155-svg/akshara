import type { ManagementAggregate } from "./management_aggregate_repository.ts";
import { formatInr, formatPercent } from "./management_aggregate_repository.ts";

// MJ-C8 (PRINC-1): build each management read endpoint's payload from a live
// aggregate. Field names and envelope shape are preserved EXACTLY as the old
// seed / the Flutter ManagementMapper expects (lib/core/repositories/api/
// management/mapper/management_mapper.dart). aiInsight is a deterministic
// template derived from the computed numbers (no Claude path exists in this
// module), and reads honestly ("No data yet") when a source is empty.

function honest(insight: string, hasData: boolean, emptyInsight: string): string {
  return hasData ? insight : emptyInsight;
}

// ---------------------------------------------------------------------------
// /management/dashboard
// ---------------------------------------------------------------------------

export function buildDashboardPayload(agg: ManagementAggregate): Record<string, unknown> {
  const { finance, admissions } = agg;
  const hasFinance = finance.totalInvoiced > 0 || finance.totalCollected > 0;
  const hasAdmissions = admissions.totalLeads > 0;

  const kpis = [
    {
      id: "revenue",
      // PRA-P0-23 (S4): "Revenue MTD" must be month-to-date collections, not the
      // all-time total (formula was fine, the period was wrong).
      value: formatInr(agg.collectedThisMonth),
      label: "Revenue MTD",
      accentName: "primary",
    },
    {
      id: "outstanding",
      value: formatInr(finance.totalOutstanding),
      label: "Outstanding",
      accentName: "warning",
    },
    {
      id: "students",
      value: String(agg.activeStudents),
      label: "Active Students",
      accentName: "info",
    },
    {
      id: "admissions",
      value: String(admissions.totalLeads),
      label: "Admission Leads",
      accentName: "success",
    },
  ];

  const aiInsight = hasFinance || hasAdmissions
    ? `Collected ${formatInr(finance.totalCollected)} (${formatPercent(finance.collectionRate)} of invoiced). ` +
      `${formatInr(finance.totalOutstanding)} outstanding across ${agg.defaulterCount} defaulters. ` +
      `${admissions.totalLeads} admission leads, ${admissions.joined} joined.`
    : "No revenue, fee, or admissions activity recorded yet.";

  // PRA-P1-48 (S4): recent admissions conversions from the real pipeline.
  const CONVERTED_STAGES = new Set(["joined", "confirmed", "admission_confirmed"]);
  const recentConversions = admissions.pipelineLeads
    .filter((l) => CONVERTED_STAGES.has(l.stage))
    .slice(0, 10)
    .map((l) => ({
      id: l.id,
      studentName: l.studentName,
      classLabel: l.classLabel,
      stage: l.stage,
      source: l.source,
    }));

  return {
    aiInsight,
    kpis,
    // PRA-P1-48 (S4): no monthly revenue-series or expense-ledger table exists
    // yet, so these stay HONESTLY empty (not a fabricated trend) — wire them when
    // those sources land. The approval queue and recent conversions DO have real
    // sources and are now populated.
    revenueTrend: [],
    expenseBreakdown: [],
    approvalQueue: agg.pendingApprovals,
    admissionsSnapshot: {
      leadsMtd: admissions.totalLeads,
      confirmed: admissions.confirmed,
      joined: admissions.joined,
      conversionRate: formatPercent(admissions.conversionRate),
      recentConversions,
    },
    feeSnapshot: {
      // PRA-P0-23 (S4): month-to-date, not all-time.
      collectedMtd: formatInr(agg.collectedThisMonth),
      outstanding: formatInr(finance.totalOutstanding),
      collectionRate: formatPercent(finance.collectionRate),
      // NOTE: Flutter mapper reads `defaulters` (the old seed key
      // `defaulterCount` was never read). Emit both for safety.
      defaulters: agg.defaulterCount,
      defaulterCount: agg.defaulterCount,
    },
  };
}

// ---------------------------------------------------------------------------
// /management/analytics
// ---------------------------------------------------------------------------

export function buildAnalyticsPayload(agg: ManagementAggregate): Record<string, unknown> {
  const { academic, admissions, finance } = agg;

  const kpis = [
    {
      id: "enrollment",
      value: String(agg.activeStudents),
      label: "Enrollment",
      accentName: "primary",
    },
    {
      id: "attendance",
      value: formatPercent(academic.avgAttendancePercent),
      label: "Avg Attendance",
      accentName: academic.avgAttendancePercent >= 85 ? "success" : "warning",
    },
    {
      id: "collection",
      value: formatPercent(finance.collectionRate),
      label: "Fee Collection",
      accentName: "info",
    },
  ];

  // PRA-P2-22 (S4): the per-class attendance column must show EACH class's real
  // attendance, not the school-wide scalar (and the "attendanceByClass" chart was
  // wrongly built from exam performance, not attendance at all).
  const attByClass = new Map(
    academic.attendanceByClass.map((a) => [a.classLabel, a.attendancePercent]),
  );
  const attendanceByClass = academic.attendanceByClass.map((a) => ({
    label: a.classLabel,
    value: a.attendancePercent,
    percent: a.attendancePercent,
  }));

  const classSummary = academic.classPerformance.map((c) => ({
    classLabel: c.classLabel,
    students: c.students,
    attendancePercent: formatPercent(attByClass.get(c.classLabel) ?? 0),
    avgMarks: formatPercent(c.avgPercent),
    feeCollectionPercent: formatPercent(finance.collectionRate),
    teachers: 0,
  }));

  const hasData = agg.activeStudents > 0 || academic.hasAttendance ||
    academic.hasExams || admissions.totalLeads > 0;
  const aiInsight = honest(
    `${agg.activeStudents} active students, ${formatPercent(academic.avgAttendancePercent)} average attendance, ` +
      `${formatPercent(finance.collectionRate)} fee collection.`,
    hasData,
    "No enrollment, attendance, or exam data recorded yet.",
  );

  return {
    kpis,
    // No historical enrollment trend table exists yet -> honest empty series.
    enrollmentTrend: [],
    attendanceByClass,
    classSummary,
    aiInsight,
  };
}

// ---------------------------------------------------------------------------
// /management/admissions-funnel
// ---------------------------------------------------------------------------

const FUNNEL_STAGE_ORDER: Array<{ key: string; label: string }> = [
  { key: "new_enquiry", label: "New Enquiry" },
  { key: "contacted", label: "Contacted" },
  { key: "school_visit", label: "School Visit" },
  { key: "demo_class", label: "Demo Class" },
  { key: "application", label: "Application" },
  { key: "confirmed", label: "Confirmed" },
  { key: "joined", label: "Joined" },
];

export function buildAdmissionsFunnelPayload(agg: ManagementAggregate): Record<string, unknown> {
  const { admissions } = agg;
  const total = admissions.totalLeads;

  const funnelStages = FUNNEL_STAGE_ORDER.map((stage) => {
    const count = admissions.stageCounts[stage.key] ?? 0;
    return {
      label: stage.label,
      count,
      percent: total > 0 ? Math.round((count / total) * 10000) / 100 : 0,
    };
  });

  const sourcePerformance = Object.entries(admissions.sourceCounts).map(
    ([source, count]) => ({
      label: source,
      value: count,
      percent: total > 0 ? Math.round((count / total) * 10000) / 100 : 0,
    }),
  );

  const kpis = [
    {
      id: "leads",
      value: String(total),
      label: "Total Leads",
      accentName: "primary",
    },
    {
      id: "confirmed",
      value: String(admissions.confirmed),
      label: "Confirmed",
      accentName: "info",
    },
    {
      id: "joined",
      value: String(admissions.joined),
      label: "Joined",
      accentName: "success",
    },
    {
      id: "conversion",
      value: formatPercent(admissions.conversionRate),
      label: "Conversion",
      accentName: "warning",
    },
  ];

  const aiInsight = honest(
    `${total} leads in the funnel, ${admissions.confirmed} confirmed and ${admissions.joined} joined ` +
      `(${formatPercent(admissions.conversionRate)} conversion).`,
    total > 0,
    "No admission leads recorded yet.",
  );

  return {
    kpis,
    funnelStages,
    sourcePerformance,
    recentConversions: [],
    aiInsight,
    admissionsReportsRoute: "/admissions/reports",
    // Preserve the legacy keys the original seed used as well.
    stages: funnelStages.map((s) => ({ stage: s.label, count: s.count })),
    conversionRate: formatPercent(admissions.conversionRate),
  };
}

// ---------------------------------------------------------------------------
// /management/financial-health
// ---------------------------------------------------------------------------

export function buildFinancialHealthPayload(agg: ManagementAggregate): Record<string, unknown> {
  const { finance } = agg;
  const hasFinance = finance.totalInvoiced > 0 || finance.totalCollected > 0;

  const kpis = [
    {
      id: "collected",
      value: formatInr(finance.totalCollected),
      label: "Collected",
      accentName: "success",
    },
    {
      id: "outstanding",
      value: formatInr(finance.totalOutstanding),
      label: "Outstanding",
      accentName: "warning",
    },
    {
      id: "collection_rate",
      value: formatPercent(finance.collectionRate),
      label: "Collection Rate",
      accentName: "info",
    },
    {
      id: "defaulters",
      value: String(agg.defaulterCount),
      label: "Defaulters",
      accentName: "danger",
    },
  ];

  const drillLinks = [
    {
      id: "collections",
      title: "Collections",
      subtitle: `${formatInr(finance.totalCollected)} collected`,
      route: "/finance/collections",
      metric: formatPercent(finance.collectionRate),
    },
    {
      id: "defaulters",
      title: "Defaulters",
      subtitle: `${agg.defaulterCount} accounts overdue`,
      route: "/finance/defaulters",
      metric: formatInr(finance.totalOutstanding),
    },
  ];

  const aiInsight = honest(
    `${formatInr(finance.totalCollected)} collected of ${formatInr(finance.totalInvoiced)} invoiced ` +
      `(${formatPercent(finance.collectionRate)}); ${formatInr(finance.totalOutstanding)} outstanding ` +
      `across ${agg.defaulterCount} defaulters.`,
    hasFinance,
    "No invoices or fee collections recorded yet.",
  );

  return {
    // revenue/expenses/netProfit: only revenue (collected) has a real source.
    // No expense/payroll ledger table exists yet -> honest empty/zero.
    revenue: formatInr(finance.totalCollected),
    expenses: "",
    netProfit: "",
    kpis,
    plTrend: [],
    cashFlowTrend: [],
    drillLinks,
    aiInsight,
    // Legacy seed keys preserved.
    collectedMtd: formatInr(finance.totalCollected),
    outstanding: formatInr(finance.totalOutstanding),
    collectionRate: formatPercent(finance.collectionRate),
    expenseRatio: "",
  };
}

// ---------------------------------------------------------------------------
// /management/academic-health
// ---------------------------------------------------------------------------

export function buildAcademicHealthPayload(agg: ManagementAggregate): Record<string, unknown> {
  const { academic } = agg;

  const kpis = [
    {
      id: "attendance",
      value: formatPercent(academic.avgAttendancePercent),
      label: "Avg Attendance",
      accentName: academic.avgAttendancePercent >= 85 ? "success" : "warning",
    },
    {
      id: "pass_rate",
      value: formatPercent(academic.passRate),
      label: "Pass Rate",
      accentName: academic.passRate >= 80 ? "success" : "warning",
    },
    {
      id: "avg_score",
      value: formatPercent(academic.avgScorePercent),
      label: "Avg Score",
      accentName: "info",
    },
  ];

  const metrics = [
    {
      id: "attendance",
      label: "Average Attendance",
      value: formatPercent(academic.avgAttendancePercent),
      trend: academic.avgAttendancePercent >= 85 ? "up" : "flat",
      accentName: academic.avgAttendancePercent >= 85 ? "success" : "warning",
    },
    {
      id: "pass_rate",
      label: "Pass Rate",
      value: formatPercent(academic.passRate),
      trend: academic.passRate >= 80 ? "up" : "flat",
      accentName: academic.passRate >= 80 ? "success" : "warning",
    },
  ];

  const subjectPerformance = academic.subjectPerformance.map((s) => ({
    subject: s.subject,
    passPercent: formatPercent(s.passPercent),
    avgScore: formatPercent(s.avgPercent),
    atRiskCount: s.atRiskCount,
  }));

  const hasData = academic.hasAttendance || academic.hasExams;
  const aiInsight = honest(
    `${formatPercent(academic.avgAttendancePercent)} average attendance; ` +
      `${formatPercent(academic.passRate)} pass rate at ${formatPercent(academic.avgScorePercent)} average score.`,
    hasData,
    "No attendance or published exam results recorded yet.",
  );

  return {
    kpis,
    metrics,
    subjectPerformance,
    atRiskStudents: [],
    aiInsight,
    // Legacy seed keys preserved.
    avgAttendance: formatPercent(academic.avgAttendancePercent),
    passRate: formatPercent(academic.passRate),
    teacherShortage: 0,
  };
}

// ---------------------------------------------------------------------------
// /management/school-performance
// ---------------------------------------------------------------------------

export function buildSchoolPerformancePayload(agg: ManagementAggregate): Record<string, unknown> {
  const { academic } = agg;

  const classPerformance = academic.classPerformance.map((c, index) => ({
    classLabel: c.classLabel,
    students: c.students,
    passPercent: formatPercent(c.passPercent),
    avgMarks: formatPercent(c.avgPercent),
    attendance: formatPercent(academic.avgAttendancePercent),
    disciplineScore: "",
    rank: index + 1,
  }));

  const kpis = [
    {
      id: "classes",
      value: String(classPerformance.length),
      label: "Classes Assessed",
      accentName: "primary",
    },
    {
      id: "pass_rate",
      value: formatPercent(academic.passRate),
      label: "Overall Pass Rate",
      accentName: academic.passRate >= 80 ? "success" : "warning",
    },
  ];

  const aiInsight = honest(
    `${classPerformance.length} classes assessed; overall pass rate ${formatPercent(academic.passRate)}.`,
    academic.hasExams,
    "No published exam results to rank classes yet.",
  );

  return {
    kpis,
    classPerformance,
    atRiskStudents: [],
    aiInsight,
    // Legacy seed keys preserved (the old payload exposed `schools`).
    schools: academic.classPerformance.map((c, index) => ({
      name: c.classLabel,
      score: c.passPercent,
      rank: index + 1,
    })),
    benchmarkNote: "",
  };
}
