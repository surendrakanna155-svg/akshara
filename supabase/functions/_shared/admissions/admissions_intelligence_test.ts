import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AdmissionsDashboardSnapshot } from "./admissions_dashboard_repository.ts";
import { buildAdmissionsIntelligence } from "./admissions_intelligence.ts";

function snapshot(
  overrides: Partial<AdmissionsDashboardSnapshot> = {},
): AdmissionsDashboardSnapshot {
  return {
    totalLeads: 20,
    hotLeads: 3,
    visitsScheduled: 2,
    confirmed: 1,
    joined: 1,
    conversionRate: 5,
    stageCounts: {
      new_enquiry: 6,
      contacted: 4,
      school_visit: 2,
      demo_class: 1,
      application: 1,
      confirmed: 1,
      joined: 1,
    },
    sourceCounts: { website: 12, walk_in: 8 },
    counselorStats: [],
    followUps: [],
    pipelineLeads: [],
    ...overrides,
  };
}

Deno.test("empty pipeline yields a single add-lead action", () => {
  const result = buildAdmissionsIntelligence({
    dashboard: snapshot({ totalLeads: 0, hotLeads: 0, stageCounts: {}, sourceCounts: {} }),
    pendingFollowUps: 0,
    unassignedLeads: 0,
    unassignedSample: [],
  });
  assertEquals(result.nextBestActions.length, 1);
  assertEquals(result.nextBestActions[0].kind, "empty_pipeline");
  assertEquals(result.funnel.totalLeads, 0);
});

Deno.test("stalled hot leads surface as urgent, sorted by age, capped", () => {
  const result = buildAdmissionsIntelligence({
    dashboard: snapshot({
      pipelineLeads: [
        { id: "a", stage: "contacted", studentName: "Aarav", classLabel: "5", score: "hot", source: "website", daysInStage: 3 },
        { id: "b", stage: "school_visit", studentName: "Bhavya", classLabel: "5", score: "hot", source: "website", daysInStage: 9 },
        { id: "c", stage: "joined", studentName: "Chetan", classLabel: "5", score: "hot", source: "website", daysInStage: 30 },
        { id: "d", stage: "contacted", studentName: "Diya", classLabel: "5", score: "warm", source: "website", daysInStage: 12 },
        { id: "e", stage: "new_enquiry", studentName: "Esha", classLabel: "5", score: "hot", source: "website", daysInStage: 1 },
      ],
    }),
    pendingFollowUps: 0,
    unassignedLeads: 0,
    unassignedSample: [],
  });
  const urgent = result.nextBestActions.filter((a) => a.priority === "urgent");
  // b (9d) and a (3d) qualify; c is terminal (joined), e is below threshold, d is warm.
  assertEquals(urgent.map((a) => a.leadId), ["b", "a"]);
  assertEquals(urgent[0].kind, "stalled_hot_lead");
});

Deno.test("pending follow-ups and unassigned leads produce high-priority actions", () => {
  const result = buildAdmissionsIntelligence({
    dashboard: snapshot(),
    pendingFollowUps: 4,
    unassignedLeads: 2,
    unassignedSample: [
      { id: "u1", studentName: "Uma", score: "hot" },
      { id: "u2", studentName: "Vivaan", score: "cold" },
    ],
  });
  const kinds = result.nextBestActions.map((a) => a.kind);
  assertEquals(kinds.includes("pending_follow_ups"), true);
  assertEquals(kinds.includes("unassigned_leads"), true);
  assertEquals(kinds.includes("assign_lead"), true);
  assertEquals(result.funnel.pendingFollowUps, 4);
  assertEquals(result.funnel.unassignedLeads, 2);
});

Deno.test("stage bottleneck triggers above threshold", () => {
  const result = buildAdmissionsIntelligence({
    dashboard: snapshot({ stageCounts: { new_enquiry: 6, contacted: 2 } }),
    pendingFollowUps: 0,
    unassignedLeads: 0,
    unassignedSample: [],
  });
  const bottleneck = result.nextBestActions.find((a) => a.kind === "stage_bottleneck");
  assertEquals(bottleneck?.count, 6);
  assertEquals(bottleneck?.id, "stage_bottleneck:new_enquiry");
});

Deno.test("actions are ranked urgent>high>medium>low and capped at 8", () => {
  const result = buildAdmissionsIntelligence({
    dashboard: snapshot({
      stageCounts: { new_enquiry: 8, contacted: 6 },
      pipelineLeads: [
        { id: "a", stage: "contacted", studentName: "A", classLabel: "5", score: "hot", source: "website", daysInStage: 5 },
        { id: "w", stage: "new_enquiry", studentName: "W", classLabel: "5", score: "warm", source: "website", daysInStage: 10 },
      ],
    }),
    pendingFollowUps: 3,
    unassignedLeads: 1,
    unassignedSample: [{ id: "u1", studentName: "U", score: "hot" }],
  });
  const ranks = result.nextBestActions.map((a) => a.priority);
  const order = ["urgent", "high", "medium", "low"];
  let last = -1;
  for (const r of ranks) {
    const idx = order.indexOf(r);
    assertEquals(idx >= last, true);
    last = idx;
  }
  assertEquals(result.nextBestActions.length <= 8, true);
});

Deno.test("top source is computed in the funnel summary", () => {
  const result = buildAdmissionsIntelligence({
    dashboard: snapshot({ sourceCounts: { website: 12, walk_in: 8, referral: 20 } }),
    pendingFollowUps: 0,
    unassignedLeads: 0,
    unassignedSample: [],
  });
  assertEquals(result.funnel.topSource, { source: "referral", count: 20 });
});
