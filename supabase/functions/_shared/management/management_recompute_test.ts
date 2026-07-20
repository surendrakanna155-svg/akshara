import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  formatInr,
  formatPercent,
  getAcademicAggregate,
  type ManagementAggregate,
} from "./management_aggregate_repository.ts";
import {
  buildAcademicHealthPayload,
  buildAdmissionsFunnelPayload,
  buildAnalyticsPayload,
  buildDashboardPayload,
  buildFinancialHealthPayload,
  buildSchoolPerformancePayload,
} from "./management_payload_builders.ts";
// W4: the dashboard's expenseBreakdown is now live off the canonical Expense Ledger.
import { buildExpenseBreakdown } from "../expense_ledger/expense_ledger_breakdown.ts";
import { currentMonthPeriod } from "./management_handlers.ts";

// MJ-C8 (PRINC-1) recompute tests. We verify (a) the academic aggregate SQL
// mapping (empty => zeros, seeded rows => computed), and (b) the payload
// builders turn an aggregate into the exact JSON the Flutter mapper reads,
// returning honest zeros/empties for a fresh school and computed values when
// real rows exist. Finance/admissions aggregation is covered by their own
// repository tests; here we feed builders a fixture aggregate.

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";

// ---------------------------------------------------------------------------
// Mock TenantQueryClient that dispatches on the SQL the aggregate repo emits.
// ---------------------------------------------------------------------------

interface MockRows {
  // PRA-P0-22/P2-22 (S4): the attendance query is now grouped per class and
  // returns the canonical attended/denominator components.
  attendance: Array<
    { class_label: string; attended: string; denominator: string; total: string }
  >;
  marksOverall: { passed: string; total: string; avg_percent: string };
  marksByClass: Array<{
    class_label: string;
    students: string;
    passed: string;
    total: string;
    avg_percent: string;
  }>;
  marksBySubject: Array<{
    subject: string;
    passed: string;
    total: string;
    at_risk: string;
    avg_percent: string;
  }>;
}

function mockClient(rows: MockRows): TenantQueryClient {
  // deno-lint-ignore no-explicit-any
  const client: any = {
    queryObject<T>(sql: string, _args: unknown[] = []): Promise<T[]> {
      if (sql.includes("FROM attendance_records")) {
        return Promise.resolve(rows.attendance as T[]);
      }
      if (sql.includes("FROM exam_mark_entries") && sql.includes("GROUP BY") && sql.includes("class_label")) {
        return Promise.resolve(rows.marksByClass as T[]);
      }
      if (sql.includes("JOIN exam_sessions") && sql.includes("GROUP BY")) {
        return Promise.resolve(rows.marksBySubject as T[]);
      }
      if (sql.includes("FROM exam_mark_entries")) {
        return Promise.resolve([rows.marksOverall] as T[]);
      }
      return Promise.resolve([] as T[]);
    },
  };
  return client as TenantQueryClient;
}

const EMPTY_ROWS: MockRows = {
  attendance: [],
  marksOverall: { passed: "0", total: "0", avg_percent: "0" },
  marksByClass: [],
  marksBySubject: [],
};

// ---------------------------------------------------------------------------
// formatters
// ---------------------------------------------------------------------------

Deno.test("formatInr renders Cr / L / plain like the seed", () => {
  assertEquals(formatInr(24000000), "₹2.4Cr");
  assertEquals(formatInr(4500000), "₹45L");
  assertEquals(formatInr(0), "₹0");
  assertEquals(formatInr(1200), "₹1,200");
});

Deno.test("formatPercent rounds to a whole percent", () => {
  assertEquals(formatPercent(87.4), "87%");
  assertEquals(formatPercent(0), "0%");
});

// ---------------------------------------------------------------------------
// getAcademicAggregate
// ---------------------------------------------------------------------------

Deno.test("getAcademicAggregate returns honest zeros for an empty school", async () => {
  const agg = await getAcademicAggregate(mockClient(EMPTY_ROWS), ORG, SCHOOL);
  assertEquals(agg.avgAttendancePercent, 0);
  assertEquals(agg.passRate, 0);
  assertEquals(agg.avgScorePercent, 0);
  assertEquals(agg.hasAttendance, false);
  assertEquals(agg.hasExams, false);
  assertEquals(agg.classPerformance, []);
  assertEquals(agg.subjectPerformance, []);
  assertEquals(agg.attendanceByClass, []);
});

Deno.test("getAcademicAggregate computes attendance, pass rate and per-class/subject from real rows", async () => {
  const rows: MockRows = {
    // Canonical: 10-A attended 27 of 30 (denominator excludes excused) = 90%;
    // 9-B attended 40 of 50 = 80%. School = (27+40)/(30+50) = 67/80 ≈ 84%.
    attendance: [
      { class_label: "10-A", attended: "27", denominator: "30", total: "32" },
      { class_label: "9-B", attended: "40", denominator: "50", total: "55" },
    ],
    marksOverall: { passed: "8", total: "10", avg_percent: "72" }, // 80% pass
    marksByClass: [
      { class_label: "10-A", students: "30", passed: "27", total: "30", avg_percent: "75" },
      { class_label: "9-B", students: "25", passed: "20", total: "25", avg_percent: "60" },
    ],
    marksBySubject: [
      { subject: "Math", passed: "5", total: "10", at_risk: "5", avg_percent: "55" },
      { subject: "English", passed: "9", total: "10", at_risk: "1", avg_percent: "80" },
    ],
  };
  const agg = await getAcademicAggregate(mockClient(rows), ORG, SCHOOL);
  assertEquals(agg.avgAttendancePercent, 84); // 67/80 canonical, not 90
  assertEquals(agg.attendanceByClass, [
    { classLabel: "10-A", attendancePercent: 90 },
    { classLabel: "9-B", attendancePercent: 80 },
  ]);
  assertEquals(agg.passRate, 80);
  assertEquals(agg.avgScorePercent, 72);
  assertEquals(agg.hasAttendance, true);
  assertEquals(agg.hasExams, true);
  // class performance sorted by pass rate desc: 10-A (90%) before 9-B (80%)
  assertEquals(agg.classPerformance[0].classLabel, "10-A");
  assertEquals(agg.classPerformance[0].passPercent, 90);
  assertEquals(agg.classPerformance[1].passPercent, 80);
  // subject performance sorted by pass rate asc: Math (50%) before English (90%)
  assertEquals(agg.subjectPerformance[0].subject, "Math");
  assertEquals(agg.subjectPerformance[0].passPercent, 50);
  assertEquals(agg.subjectPerformance[0].atRiskCount, 5);
});

// ---------------------------------------------------------------------------
// payload builders — fixtures
// ---------------------------------------------------------------------------

function emptyAggregate(): ManagementAggregate {
  return {
    finance: {
      totalStudents: 0,
      activeFeeAssignments: 0,
      totalInvoiced: 0,
      totalCollected: 0,
      totalOutstanding: 0,
      collectionRate: 0,
      pendingInvoices: 0,
      partiallyPaidInvoices: 0,
      paidInvoices: 0,
      pendingRefunds: 0,
      processedRefunds: 0,
      todayCollections: 0,
      todayCollectionCount: 0,
      recentCollections: [],
      recentRefunds: [],
    },
    admissions: {
      totalLeads: 0,
      hotLeads: 0,
      visitsScheduled: 0,
      confirmed: 0,
      joined: 0,
      conversionRate: 0,
      stageCounts: {},
      sourceCounts: {},
      counselorStats: [],
      followUps: [],
      pipelineLeads: [],
    },
    academic: {
      avgAttendancePercent: 0,
      passRate: 0,
      avgScorePercent: 0,
      hasAttendance: false,
      hasExams: false,
      classPerformance: [],
      subjectPerformance: [],
      attendanceByClass: [],
    },
    activeStudents: 0,
    defaulterCount: 0,
    collectedThisMonth: 0,
    pendingApprovals: [],
  };
}

function seededAggregate(): ManagementAggregate {
  const agg = emptyAggregate();
  agg.finance = {
    ...agg.finance,
    totalInvoiced: 30000000,
    totalCollected: 24000000,
    totalOutstanding: 4500000,
    collectionRate: 80,
  };
  agg.admissions = {
    ...agg.admissions,
    totalLeads: 120,
    confirmed: 45,
    joined: 38,
    conversionRate: 31.67,
    stageCounts: { new_enquiry: 50, confirmed: 45, joined: 38 },
    sourceCounts: { referral: 70, walk_in: 50 },
    pipelineLeads: [
      { stage: "joined", id: "l1", studentName: "Asha", classLabel: "1-A", score: "hot", source: "referral", daysInStage: 2 },
      { stage: "new_enquiry", id: "l2", studentName: "Ravi", classLabel: "1-A", score: "warm", source: "walk_in", daysInStage: 5 },
    ],
  };
  agg.academic = {
    avgAttendancePercent: 94,
    passRate: 98,
    avgScorePercent: 76,
    hasAttendance: true,
    hasExams: true,
    classPerformance: [
      { classLabel: "10-A", students: 30, passPercent: 98, avgPercent: 80 },
    ],
    subjectPerformance: [
      { subject: "Math", passPercent: 90, avgPercent: 70, atRiskCount: 3 },
    ],
    attendanceByClass: [
      { classLabel: "10-A", attendancePercent: 94 },
    ],
  };
  agg.activeStudents = 540;
  agg.defaulterCount = 12;
  // PRA-P0-23: month-to-date collections are DISTINCT from all-time totalCollected
  // (₹2.4Cr) — proves the "Revenue MTD" KPI uses the MTD figure, not the total.
  agg.collectedThisMonth = 4500000; // ₹45L
  agg.pendingApprovals = [
    {
      id: "ap1",
      type: "fee_concession",
      title: "Fee concession",
      summary: "10% for Asha",
      requesterName: "Clerk",
      createdAt: "2026-07-01T00:00:00Z",
    },
  ];
  return agg;
}

Deno.test("dashboard payload: empty school => zeros + honest insight", () => {
  const p = buildDashboardPayload(emptyAggregate());
  const fee = p.feeSnapshot as Record<string, unknown>;
  assertEquals(fee.collectedMtd, "₹0");
  assertEquals(fee.outstanding, "₹0");
  assertEquals(fee.collectionRate, "0%");
  assertEquals(fee.defaulters, 0);
  const adm = p.admissionsSnapshot as Record<string, unknown>;
  assertEquals(adm.leadsMtd, 0);
  assertEquals(p.aiInsight, "No revenue, fee, or admissions activity recorded yet.");
});

Deno.test("dashboard payload: seeded school => computed values", () => {
  const p = buildDashboardPayload(seededAggregate());
  const fee = p.feeSnapshot as Record<string, unknown>;
  // PRA-P0-23: month-to-date (₹45L), NOT the all-time totalCollected (₹2.4Cr).
  assertEquals(fee.collectedMtd, "₹45L");
  assertEquals(fee.outstanding, "₹45L");
  assertEquals(fee.collectionRate, "80%");
  assertEquals(fee.defaulters, 12);
  const adm = p.admissionsSnapshot as Record<string, unknown>;
  assertEquals(adm.leadsMtd, 120);
  assertEquals(adm.confirmed, 45);
  assertEquals(adm.joined, 38);
  // KPI keys preserved; Revenue MTD KPI shows the MTD figure.
  const kpis = p.kpis as Array<Record<string, unknown>>;
  assertEquals(kpis[0].id, "revenue");
  assertEquals(kpis[0].value, "₹45L");
  // PRA-P1-48: the approval queue + recent conversions are now REAL (not []).
  const queue = p.approvalQueue as Array<Record<string, unknown>>;
  assertEquals(queue.length, 1);
  assertEquals(queue[0].title, "Fee concession");
  const conversions = adm.recentConversions as Array<Record<string, unknown>>;
  assertEquals(conversions.length, 1); // only the 'joined' lead, not new_enquiry
  assertEquals(conversions[0].studentName, "Asha");
});

// ---------------------------------------------------------------------------
// W4: dashboard expenseBreakdown is LIVE off the canonical Expense Ledger.
// ---------------------------------------------------------------------------

Deno.test("dashboard payload: expenseBreakdown defaults to [] — honest empty, never fabricated", () => {
  // revenueTrend stays honestly empty (no source); expenseBreakdown is empty ONLY
  // because the caller passed no ledger entries — it is not a fabricated series.
  const p = buildDashboardPayload(seededAggregate());
  assertEquals(p.revenueTrend, []);
  assertEquals(p.expenseBreakdown, []);
});

Deno.test("dashboard payload: expenseBreakdown reflects the REAL by-category ledger mix", () => {
  // The exact rows listExpenseEntries returns (NUMERIC-as-string amounts).
  const breakdown = buildExpenseBreakdown([
    { category: "salary", amount: "500000.00" },
    { category: "procurement", amount: "25000.00" },
    { category: "fuel", amount: "2000.00" },
  ]);
  const p = buildDashboardPayload(seededAggregate(), breakdown);
  const eb = p.expenseBreakdown as Array<Record<string, unknown>>;
  assertEquals(eb.map((e) => e.label), ["salary", "procurement", "fuel"]);
  assertEquals(eb[0], { label: "salary", value: 500000, percent: 94.88, category: "salary", amount: 500000 });
  // The chart contract keys the Flutter reader consumes are all present.
  assertEquals(Object.keys(eb[0]).sort(), ["amount", "category", "label", "percent", "value"]);
});

Deno.test("currentMonthPeriod: first→last day of the month (matches the Revenue MTD window)", () => {
  const { from, to } = currentMonthPeriod(new Date(Date.UTC(2026, 6, 20))); // 2026-07-20
  assertEquals(from, "2026-07-01");
  assertEquals(to, "2026-07-31");
  // February of a non-leap year ends on the 28th.
  const feb = currentMonthPeriod(new Date(Date.UTC(2026, 1, 15)));
  assertEquals(feb, { from: "2026-02-01", to: "2026-02-28" });
  // Always a valid, non-empty range.
  assertEquals(from <= to, true);
});

Deno.test("financial-health payload: honest empty expenses, computed revenue", () => {
  const empty = buildFinancialHealthPayload(emptyAggregate());
  assertEquals(empty.revenue, "₹0");
  assertEquals(empty.expenses, "");
  assertEquals(empty.netProfit, "");
  assertEquals(empty.aiInsight, "No invoices or fee collections recorded yet.");

  const seeded = buildFinancialHealthPayload(seededAggregate());
  assertEquals(seeded.revenue, "₹2.4Cr");
  assertEquals(seeded.collectionRate, "80%");
  assertEquals(seeded.outstanding, "₹45L");
});

Deno.test("admissions-funnel payload: stage percents computed, legacy keys present", () => {
  const p = buildAdmissionsFunnelPayload(seededAggregate());
  const stages = p.funnelStages as Array<Record<string, unknown>>;
  const joined = stages.find((s) => s.label === "Joined")!;
  assertEquals(joined.count, 38);
  assertEquals(joined.percent, Math.round((38 / 120) * 10000) / 100);
  assertEquals(p.conversionRate, "32%");
  // empty school
  const empty = buildAdmissionsFunnelPayload(emptyAggregate());
  assertEquals(empty.aiInsight, "No admission leads recorded yet.");
});

Deno.test("academic-health payload: computed pass rate, honest empty", () => {
  const seeded = buildAcademicHealthPayload(seededAggregate());
  assertEquals(seeded.passRate, "98%");
  assertEquals(seeded.avgAttendance, "94%");
  const subjects = seeded.subjectPerformance as Array<Record<string, unknown>>;
  assertEquals(subjects[0].subject, "Math");
  assertEquals(subjects[0].passPercent, "90%");

  const empty = buildAcademicHealthPayload(emptyAggregate());
  assertEquals(empty.passRate, "0%");
  assertEquals(empty.aiInsight, "No attendance or published exam results recorded yet.");
});

Deno.test("analytics payload: enrollment & attendance computed, empty trend honest", () => {
  const seeded = buildAnalyticsPayload(seededAggregate());
  const kpis = seeded.kpis as Array<Record<string, unknown>>;
  assertEquals(kpis[0].value, "540");
  assertEquals(kpis[1].value, "94%");
  assertEquals(seeded.enrollmentTrend, []);

  const empty = buildAnalyticsPayload(emptyAggregate());
  assertEquals(empty.aiInsight, "No enrollment, attendance, or exam data recorded yet.");
});

Deno.test("school-performance payload: ranks classes, honest empty", () => {
  const seeded = buildSchoolPerformancePayload(seededAggregate());
  const classes = seeded.classPerformance as Array<Record<string, unknown>>;
  assertEquals(classes[0].classLabel, "10-A");
  assertEquals(classes[0].rank, 1);
  assertEquals(classes[0].passPercent, "98%");

  const empty = buildSchoolPerformancePayload(emptyAggregate());
  assertEquals(empty.aiInsight, "No published exam results to rank classes yet.");
  assertEquals(empty.classPerformance, []);
});
