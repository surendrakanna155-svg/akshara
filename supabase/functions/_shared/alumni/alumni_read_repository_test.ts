import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  type AlumniLiveRows,
  alumniDetailToApi,
  computeAlumniDashboard,
  computeAlumniReports,
  formatRupees,
  parseRupees,
} from "./alumni_read_repository.ts";

function emptyRows(): AlumniLiveRows {
  return { alumni: [], events: [], campaigns: [], donations: [], mentorship: [] };
}

Deno.test("parseRupees handles lakh shorthand, commas, plain and empty", () => {
  assertEquals(parseRupees("₹12.4L"), 1_240_000);
  assertEquals(parseRupees("₹25,000"), 25_000);
  assertEquals(parseRupees("1500"), 1500);
  assertEquals(parseRupees("₹0"), 0);
  assertEquals(parseRupees("—"), 0);
  assertEquals(parseRupees(""), 0);
  assertEquals(parseRupees(5000), 5000);
});

Deno.test("formatRupees uses lakh suffix above 1L and grouped rupees below", () => {
  assertEquals(formatRupees(1_240_000), "₹12.4L");
  assertEquals(formatRupees(45_000), "₹45,000");
  assertEquals(formatRupees(0), "₹0");
});

Deno.test("dashboard: empty school => zero registered, ₹0 donations, empty lists", () => {
  const d = computeAlumniDashboard(emptyRows());
  assertEquals((d.kpis as Array<Record<string, unknown>>)[0]?.value, "0");
  assertEquals((d.kpis as Array<Record<string, unknown>>)[0]?.label, "Registered Alumni");
  assertEquals(d.recentGraduates, []);
  assertEquals(d.upcomingEvents, []);
  assertEquals(d.donationSummary, {
    totalReceived: "₹0",
    pledgedAmount: "₹0",
    pendingAmount: "₹0",
  });
  assertEquals((d.engagement as Record<string, unknown>).activeAlumni, 0);
  assertEquals((d.engagement as Record<string, unknown>).mentorshipPairs, 0);
});

Deno.test("dashboard: aggregates registered count, donations by status, engagement", () => {
  const rows: AlumniLiveRows = {
    alumni: [
      { id: "a1", name: "Priya", batchYear: "2018", engagementStatus: "active" },
      { id: "a2", name: "Ravi", batchYear: "2020", engagementStatus: "inactive" },
      { id: "a3", name: "Sara", batchYear: "2019", engagementStatus: "active" },
    ],
    events: [
      { id: "e1", title: "Reunion", date: "2026-08-01", status: "upcoming", registrations: 40, capacity: 100 },
      { id: "e2", title: "Old Gala", date: "2024-01-01", status: "completed", registrations: 10, capacity: 20 },
    ],
    campaigns: [{ id: "c1", name: "Library", donorCount: 3 }],
    donations: [
      { id: "d1", alumniId: "a1", amount: "₹25,000", status: "received", date: "2026-06-01" },
      { id: "d2", alumniId: "a2", amount: "₹10,000", status: "pledged", date: "2026-06-02" },
      { id: "d3", alumniId: "a3", amount: "₹5,000", status: "pending", date: "2026-06-03" },
      { id: "d4", alumniId: "a1", amount: "₹1,000", status: "refunded", date: "2026-06-04" },
    ],
    mentorship: [{ id: "m1" }, { id: "m2" }],
  };

  const d = computeAlumniDashboard(rows);

  assertEquals((d.kpis as Array<Record<string, unknown>>)[0]?.value, "3");
  assertEquals(d.donationSummary, {
    totalReceived: "₹25,000",
    pledgedAmount: "₹10,000",
    pendingAmount: "₹5,000",
  });

  const eng = d.engagement as Record<string, unknown>;
  assertEquals(eng.activeAlumni, 2);
  assertEquals(eng.mentorshipPairs, 2);
  assertEquals(eng.eventAttendanceRate, "42%"); // (40+10)/(100+20)=41.6 -> 42
  assertEquals(eng.campaignParticipation, "100%"); // 3 donors / 3 alumni

  // recentGraduates sorted by batchYear desc
  const grads = d.recentGraduates as Array<Record<string, unknown>>;
  assertEquals(grads.map((g) => g.id), ["a2", "a3", "a1"]);

  // only upcoming/ongoing events surfaced
  const upcoming = d.upcomingEvents as Array<Record<string, unknown>>;
  assertEquals(upcoming.map((e) => e.id), ["e1"]);
});

// P2 (gap-remediation): registrations has no write path yet, so real events
// always have registrations:0 in production. Assert the dashboard says so
// honestly instead of reporting a fabricated "0%" attendance rate.
Deno.test("dashboard: events with capacity but untracked registrations => 'Not yet tracked', not a fabricated 0%", () => {
  const rows: AlumniLiveRows = {
    alumni: [],
    events: [
      { id: "e1", title: "Reunion", date: "2026-08-01", status: "upcoming", registrations: 0, capacity: 100 },
    ],
    campaigns: [],
    donations: [],
    mentorship: [],
  };

  const d = computeAlumniDashboard(rows);
  const eng = d.engagement as Record<string, unknown>;
  assertEquals(eng.eventAttendanceRate, "Not yet tracked");
});

Deno.test("profile detail: real donations surfaced, employment/events honest empty (no Tech Corp)", () => {
  const alumni = {
    id: "a1",
    name: "Priya",
    batchYear: "2018",
    currentRole: "Engineer",
    engagementStatus: "active",
  };
  const donations = [
    { id: "d1", alumniId: "a1", amount: "₹25,000", campaign: "Library", status: "received", date: "2026-06-01", financeReceiptId: "RC-1" },
    { id: "d2", alumniId: "a2", amount: "₹5,000", campaign: "Sports", status: "received", date: "2026-06-02", financeReceiptId: "RC-2" },
  ];

  const api = alumniDetailToApi(alumni, donations);

  assertEquals(api.employmentHistory, []);
  assertEquals(api.eventsAttended, []);
  assertEquals(api.mentorshipRole, "Mentor available");

  const history = api.donationHistory as Array<Record<string, unknown>>;
  assertEquals(history.length, 1); // only a1's donation
  assertEquals(history[0]?.id, "d1");
  assertEquals(history[0]?.amount, "₹25,000");
  assertEquals(history[0]?.campaign, "Library");
  assertEquals(history[0]?.financeReceiptId, "RC-1");

  // Never the fabricated constant
  const serialized = JSON.stringify(api);
  assertEquals(serialized.includes("Tech Corp"), false);
  assertEquals(serialized.includes("Annual Reunion"), false);
});

Deno.test("profile detail: inactive alumnus => Not enrolled, no donations => empty", () => {
  const api = alumniDetailToApi(
    { id: "a9", name: "Ravi", engagementStatus: "inactive" },
    [],
  );
  assertEquals(api.mentorshipRole, "Not enrolled");
  assertEquals(api.donationHistory, []);
});

Deno.test("profile detail: real employment/events fields surfaced when persisted", () => {
  const api = alumniDetailToApi(
    {
      id: "a1",
      engagementStatus: "active",
      employmentHistory: [{ organization: "Infosys", role: "SDE", period: "2018 — Present" }],
      eventsAttended: ["Reunion 2024", "Tech Talk 2025"],
    },
    [],
  );
  assertEquals(api.employmentHistory, [
    { organization: "Infosys", role: "SDE", period: "2018 — Present" },
  ]);
  assertEquals(api.eventsAttended, ["Reunion 2024", "Tech Talk 2025"]);
});

Deno.test("reports: empty => empty trends, catalog preserved", () => {
  const catalog = [{ id: "rpt_eng", title: "Engagement Report" }];
  const r = computeAlumniReports({ alumni: [], donations: [], events: [] }, catalog);
  assertEquals(r.catalog, catalog);
  assertEquals(r.donationTrend, []);
  assertEquals(r.engagementByBatch, []);
  assertEquals(r.eventAttendanceTrend, []);
});

// #5: the client mapper (toReports) reads `eventAttendanceTrend` (generic
// AlumniTrendPoint: label+amountLakhs) and `engagementByBatch` (AlumniSegment:
// label+value+percent) — this proves both keys are now emitted with real data
// computed from live rows, replacing the old `eventAttendance` key the client
// never read.
Deno.test("reports: donation trend grouped by month in lakhs, attendance-rate per event", () => {
  const r = computeAlumniReports({
    alumni: [],
    donations: [
      { id: "d1", amount: "₹1,00,000", status: "received", date: "2026-06-01" },
      { id: "d2", amount: "₹50,000", status: "received", date: "2026-06-15" },
      { id: "d3", amount: "₹2,00,000", status: "received", date: "2026-07-01" },
      { id: "d4", amount: "₹9,999", status: "refunded", date: "2026-07-02" },
    ],
    events: [
      { id: "e1", title: "Reunion", date: "2026-08-01", registrations: 40, capacity: 100 },
      { id: "e2", title: "Alumni Meet", date: "2026-09-01", registrations: 30, capacity: 40 },
    ],
  }, []);

  const trend = r.donationTrend as Array<Record<string, unknown>>;
  assertEquals(trend, [
    { label: "Jun 2026", amountLakhs: 1.5 }, // 150000 -> 1.5L
    { label: "Jul 2026", amountLakhs: 2 }, // refunded excluded
  ]);

  // Most recent event first; amountLakhs carries the attendance-rate percent.
  assertEquals(r.eventAttendanceTrend, [
    { label: "Alumni Meet", amountLakhs: 75 }, // 30/40 = 75%
    { label: "Reunion", amountLakhs: 40 }, // 40/100 = 40%
  ]);
});

Deno.test("reports: engagementByBatch groups active alumni by batch year with share-of-total percent", () => {
  const r = computeAlumniReports({
    alumni: [
      { id: "a1", batchYear: "2020", engagementStatus: "active" },
      { id: "a2", batchYear: "2020", engagementStatus: "active" },
      { id: "a3", batchYear: "2019", engagementStatus: "active" },
      { id: "a4", batchYear: "2019", engagementStatus: "inactive" }, // excluded
    ],
    donations: [],
    events: [],
  }, []);

  assertEquals(r.engagementByBatch, [
    { label: "2019", value: 1, percent: 33.3 },
    { label: "2020", value: 2, percent: 66.7 },
  ]);
});
