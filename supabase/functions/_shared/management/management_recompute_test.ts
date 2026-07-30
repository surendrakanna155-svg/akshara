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

// ICA-H3 regression: a class with a zero attendance denominator must report
// `null` ("no data" / "—"), NEVER a fabricated 0% — matching the canonical
// attendance_percentage null-on-zero-denominator contract.
Deno.test("getAcademicAggregate (ICA-H3): a zero-denominator class -> attendancePercent is null, not 0", async () => {
  const rows: MockRows = {
    // 10-A attended 8 of 10 = 80%. 9-B has a zero denominator (every marked day
    // was excused): "no data" -> null, NOT a catastrophic 0% for an unmarked class.
    attendance: [
      { class_label: "10-A", attended: "8", denominator: "10", total: "10" },
      { class_label: "9-B", attended: "0", denominator: "0", total: "4" },
    ],
    marksOverall: { passed: "0", total: "0", avg_percent: "0" },
    marksByClass: [],
    marksBySubject: [],
  };
  const agg = await getAcademicAggregate(mockClient(rows), ORG, SCHOOL);
  assertEquals(agg.attendanceByClass, [
    { classLabel: "10-A", attendancePercent: 80 },
    { classLabel: "9-B", attendancePercent: null }, // null, never 0
  ]);
});

// ICA-H3 regression: the school-wide average is a pooled ratio, so a null
// (zero-denominator) class is excluded from BOTH numerator and denominator and
// can NEVER drag the school figure down. {A=80%, B=null} => 80%, NOT 40%.
Deno.test("getAcademicAggregate (ICA-H3): school-wide average excludes null classes (80%, not 40%)", async () => {
  const rows: MockRows = {
    attendance: [
      { class_label: "A", attended: "8", denominator: "10", total: "10" }, // 80%
      { class_label: "B", attended: "0", denominator: "0", total: "3" }, // null
    ],
    marksOverall: { passed: "0", total: "0", avg_percent: "0" },
    marksByClass: [],
    marksBySubject: [],
  };
  const agg = await getAcademicAggregate(mockClient(rows), ORG, SCHOOL);
  assertEquals(agg.avgAttendancePercent, 80); // null class excluded, not (80+0)/2=40
  assertEquals(agg.attendanceByClass[1].attendancePercent, null);
});

// ICA-H3 regression: when every class has a zero denominator there is genuinely
// no attendance data — every per-class value is null (no fabricated 0%).
Deno.test("getAcademicAggregate (ICA-H3): all-classes-null -> every per-class value is null", async () => {
  const rows: MockRows = {
    attendance: [
      { class_label: "A", attended: "0", denominator: "0", total: "5" },
      { class_label: "B", attended: "0", denominator: "0", total: "2" },
    ],
    marksOverall: { passed: "0", total: "0", avg_percent: "0" },
    marksByClass: [],
    marksBySubject: [],
  };
  const agg = await getAcademicAggregate(mockClient(rows), ORG, SCHOOL);
  // No class shows a fabricated 0% — every per-class value is null ("no data").
  assertEquals(agg.attendanceByClass.map((c) => c.attendancePercent), [null, null]);
  // School scalar: the pooled denominator is 0, so there is genuinely no
  // attendance data. It stays a non-null number (0) so the management payload
  // builders keep compiling; the honest "no data" signal is that EVERY per-class
  // value is null. Rendering the all-null school scalar as "—" is a client follow-up.
  assertEquals(agg.avgAttendancePercent, 0);
});

// ICA-C2 (perf): the academic aggregates (attendance %, pass rate, per-class /
// per-subject performance) used to scan attendance_records and exam_mark_entries
// ALL-TIME, so every management dashboard load recomputed over the school's entire
// history. They are now bounded to a trailing 12-month window (the current academic
// year). This mock returns ONLY the recent bucket when the SQL carries the
// current-year bound and recent+old when it does not — so removing the bound both
// changes the numbers AND flips the window flags, failing this test.
Deno.test("getAcademicAggregate (ICA-C2): attendance + marks bounded to the current academic year", async () => {
  const ATT_BOUND = "s.session_date >= CURRENT_DATE - interval '365 days'";
  const MARK_BOUND = "m.updated_at >= now() - interval '365 days'";

  // Attendance: recent 10-A (8/10 = 80%); a stale class that, if folded in, would
  // crater the pooled ratio to 8/100 = 8% and add a second per-class row.
  const recentAttendance = [{ class_label: "10-A", attended: "8", denominator: "10", total: "10" }];
  const staleAttendance = [{ class_label: "OLD-9", attended: "0", denominator: "90", total: "90" }];

  let sawAttWindow = false;
  let examQueriesSeen = 0;
  let examQueriesWindowed = 0;

  // deno-lint-ignore no-explicit-any
  const client: any = {
    queryObject<T>(sql: string, _args: unknown[] = []): Promise<T[]> {
      if (sql.includes("FROM attendance_records")) {
        sawAttWindow = sql.includes(ATT_BOUND);
        const rows = sawAttWindow ? recentAttendance : [...recentAttendance, ...staleAttendance];
        return Promise.resolve(rows as T[]);
      }
      // per-class marks
      if (sql.includes("FROM exam_mark_entries") && sql.includes("GROUP BY") && sql.includes("class_label")) {
        examQueriesSeen++;
        if (sql.includes(MARK_BOUND)) examQueriesWindowed++;
        return Promise.resolve([] as T[]);
      }
      // per-subject marks
      if (sql.includes("JOIN exam_sessions") && sql.includes("GROUP BY")) {
        examQueriesSeen++;
        if (sql.includes(MARK_BOUND)) examQueriesWindowed++;
        return Promise.resolve([] as T[]);
      }
      // overall marks
      if (sql.includes("FROM exam_mark_entries")) {
        examQueriesSeen++;
        const windowed = sql.includes(MARK_BOUND);
        if (windowed) examQueriesWindowed++;
        // recent: 8/10 pass = 80%. stale-inclusive: 8/100 = 8%.
        return Promise.resolve(
          [windowed
            ? { passed: "8", total: "10", avg_percent: "72" }
            : { passed: "8", total: "100", avg_percent: "12" }] as T[],
        );
      }
      return Promise.resolve([] as T[]);
    },
  };

  const agg = await getAcademicAggregate(client as TenantQueryClient, ORG, SCHOOL);
  // Every academic query carries the current-year bound (attendance on session_date,
  // all three mark queries on updated_at).
  assertEquals(sawAttWindow, true);
  assertEquals(examQueriesSeen, 3);
  assertEquals(examQueriesWindowed, 3);
  // ...and the numbers reflect ONLY the current year: the stale OLD-9 class is gone,
  // the pooled attendance is 80% (not 8%), and the pass rate is 80% (not 8%).
  assertEquals(agg.attendanceByClass, [{ classLabel: "10-A", attendancePercent: 80 }]);
  assertEquals(agg.avgAttendancePercent, 80);
  assertEquals(agg.passRate, 80);
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
