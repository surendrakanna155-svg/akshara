// B4 AI Admissions Assistant — deterministic next-best-action advisor.
//
// Pure, side-effect-free intelligence over the B1 CRM funnel. Given the
// already-aggregated admissions dashboard snapshot plus a couple of extra
// CRM signals (pending follow-ups, unassigned leads), it produces a ranked,
// deep-linkable list of recommended actions. The same output grounds the
// live Copilot `admissions` persona (so the AI stops guessing) and powers the
// "Next best actions" card in the app. Read-only: it never mutates anything.

import type { AdmissionsDashboardSnapshot } from "./admissions_dashboard_repository.ts";

export type AdmissionsActionPriority = "urgent" | "high" | "medium" | "low";

export interface AdmissionsNextBestAction {
  /** Stable, deterministic key (safe for list diffing / analytics). */
  id: string;
  /** Category of the recommendation. */
  kind: string;
  priority: AdmissionsActionPriority;
  title: string;
  detail: string;
  /** Short call-to-action verb, e.g. "Call now", "Assign counselor". */
  cta: string;
  /** Number of entities this action covers, when meaningful. */
  count?: number;
  /** Lead id for deep-linking to the lead detail screen, when single-lead. */
  leadId?: string;
}

export interface AdmissionsAgingLead {
  id: string;
  studentName: string;
  stage: string;
  score: string;
  daysInStage: number;
}

export interface AdmissionsIntelligenceInput {
  dashboard: AdmissionsDashboardSnapshot;
  /** Open (status='pending') rows in admissions_lead_follow_ups. */
  pendingFollowUps: number;
  /** Leads with no counselor assigned (counselor = ''). */
  unassignedLeads: number;
  /** A few highest-value unassigned leads for per-lead assignment actions. */
  unassignedSample: Array<{ id: string; studentName: string; score: string }>;
}

export interface AdmissionsFunnelSummary {
  totalLeads: number;
  hotLeads: number;
  conversionRate: number;
  pendingFollowUps: number;
  unassignedLeads: number;
  stageCounts: Record<string, number>;
  topSource: { source: string; count: number } | null;
}

export interface AdmissionsIntelligence {
  funnel: AdmissionsFunnelSummary;
  nextBestActions: AdmissionsNextBestAction[];
}

// Stages a lead has effectively "converted" past — no chasing needed.
const TERMINAL_STAGES = new Set(["confirmed", "joined"]);
// Early stages where a stalled lead is a problem.
const EARLY_STAGES = new Set(["new_enquiry", "contacted"]);

const PRIORITY_RANK: Record<AdmissionsActionPriority, number> = {
  urgent: 0,
  high: 1,
  medium: 2,
  low: 3,
};

const MAX_ACTIONS = 8;
const MAX_HOT_LEAD_ACTIONS = 4;
const MAX_UNASSIGNED_ACTIONS = 2;

// Aging thresholds (days since last stage movement).
const HOT_LEAD_AGING_DAYS = 2;
const WARM_LEAD_AGING_DAYS = 7;
const STAGE_BOTTLENECK_MIN = 5;
const LOW_CONVERSION_PCT = 15;
const CONVERSION_MIN_SAMPLE = 10;

function stageLabel(stage: string): string {
  return stage
    .split("_")
    .map((part) => (part.length > 0 ? part[0].toUpperCase() + part.slice(1) : part))
    .join(" ");
}

function topSource(
  sourceCounts: Record<string, number>,
): { source: string; count: number } | null {
  let best: { source: string; count: number } | null = null;
  for (const [source, count] of Object.entries(sourceCounts)) {
    if (best === null || count > best.count) best = { source, count };
  }
  return best;
}

/**
 * Compute the ranked next-best-actions and a compact funnel summary.
 * Deterministic for a given input (stable ordering + stable ids).
 */
export function buildAdmissionsIntelligence(
  input: AdmissionsIntelligenceInput,
): AdmissionsIntelligence {
  const { dashboard, pendingFollowUps, unassignedLeads, unassignedSample } = input;
  const actions: AdmissionsNextBestAction[] = [];

  // Empty pipeline: nothing to optimize — point staff at lead capture.
  if (dashboard.totalLeads === 0) {
    actions.push({
      id: "empty_pipeline",
      kind: "empty_pipeline",
      priority: "high",
      title: "No leads yet",
      detail:
        "The admissions pipeline is empty. Add your first enquiry or import existing leads to start tracking conversions.",
      cta: "Add lead",
    });
    return { funnel: summarize(dashboard, pendingFollowUps, unassignedLeads), nextBestActions: actions };
  }

  // 1. URGENT — hot leads going stale in non-terminal stages (one per lead).
  const stalledHotLeads = dashboard.pipelineLeads
    .filter(
      (lead) =>
        lead.score === "hot" &&
        !TERMINAL_STAGES.has(lead.stage) &&
        lead.daysInStage >= HOT_LEAD_AGING_DAYS,
    )
    .sort((a, b) => b.daysInStage - a.daysInStage)
    .slice(0, MAX_HOT_LEAD_ACTIONS);

  for (const lead of stalledHotLeads) {
    actions.push({
      id: `urgent_hot_lead:${lead.id}`,
      kind: "stalled_hot_lead",
      priority: "urgent",
      title: `Hot lead cooling: ${lead.studentName}`,
      detail:
        `${lead.studentName} is a hot lead stuck at "${stageLabel(lead.stage)}" for ` +
        `${lead.daysInStage} day${lead.daysInStage === 1 ? "" : "s"}. Reach out today before interest fades.`,
      cta: "Call now",
      leadId: lead.id,
    });
  }

  // 2. HIGH — open follow-ups waiting to be actioned.
  if (pendingFollowUps > 0) {
    actions.push({
      id: "pending_follow_ups",
      kind: "pending_follow_ups",
      priority: "high",
      title: `${pendingFollowUps} follow-up${pendingFollowUps === 1 ? "" : "s"} pending`,
      detail:
        `${pendingFollowUps} scheduled follow-up${pendingFollowUps === 1 ? " is" : "s are"} ` +
        "still open. Clear them today to keep leads moving through the funnel.",
      cta: "Review follow-ups",
      count: pendingFollowUps,
    });
  }

  // 3. HIGH — unassigned leads have no owner; assign the most valuable first.
  if (unassignedLeads > 0) {
    actions.push({
      id: "unassigned_leads",
      kind: "unassigned_leads",
      priority: "high",
      title: `${unassignedLeads} lead${unassignedLeads === 1 ? "" : "s"} unassigned`,
      detail:
        `${unassignedLeads} lead${unassignedLeads === 1 ? " has" : "s have"} no counselor. ` +
        "Assign an owner so follow-ups don't slip through the cracks.",
      cta: "Assign counselor",
      count: unassignedLeads,
    });
    for (const lead of unassignedSample.slice(0, MAX_UNASSIGNED_ACTIONS)) {
      actions.push({
        id: `assign_lead:${lead.id}`,
        kind: "assign_lead",
        priority: lead.score === "hot" ? "high" : "medium",
        title: `Assign owner: ${lead.studentName}`,
        detail:
          `${lead.studentName} (${lead.score} lead) has no counselor. Assign an owner to start the follow-up loop.`,
        cta: "Assign counselor",
        leadId: lead.id,
      });
    }
  }

  // 4. MEDIUM — stage bottleneck: largest early-stage pile-up.
  let bottleneck: { stage: string; count: number } | null = null;
  for (const stage of EARLY_STAGES) {
    const count = dashboard.stageCounts[stage] ?? 0;
    if (count >= STAGE_BOTTLENECK_MIN && (bottleneck === null || count > bottleneck.count)) {
      bottleneck = { stage, count };
    }
  }
  if (bottleneck !== null) {
    actions.push({
      id: `stage_bottleneck:${bottleneck.stage}`,
      kind: "stage_bottleneck",
      priority: "medium",
      title: `${bottleneck.count} leads stuck at ${stageLabel(bottleneck.stage)}`,
      detail:
        `${bottleneck.count} leads are sitting at "${stageLabel(bottleneck.stage)}". ` +
        "Schedule calls or visits to advance them to the next stage.",
      cta: "Advance pipeline",
      count: bottleneck.count,
    });
  }

  // 5. MEDIUM — warm leads going cold (aging in early stages).
  const coldingWarmLeads = dashboard.pipelineLeads.filter(
    (lead) =>
      lead.score === "warm" &&
      EARLY_STAGES.has(lead.stage) &&
      lead.daysInStage >= WARM_LEAD_AGING_DAYS,
  );
  if (coldingWarmLeads.length > 0) {
    actions.push({
      id: "warm_leads_cooling",
      kind: "warm_leads_cooling",
      priority: "medium",
      title: `${coldingWarmLeads.length} warm lead${coldingWarmLeads.length === 1 ? "" : "s"} going cold`,
      detail:
        `${coldingWarmLeads.length} warm lead${coldingWarmLeads.length === 1 ? " has" : "s have"} had no ` +
        `movement in over ${WARM_LEAD_AGING_DAYS} days. A timely nudge can re-engage them.`,
      cta: "Re-engage",
      count: coldingWarmLeads.length,
    });
  }

  // 6. LOW — conversion-rate insight (only with a meaningful sample).
  if (dashboard.totalLeads >= CONVERSION_MIN_SAMPLE && dashboard.conversionRate < LOW_CONVERSION_PCT) {
    actions.push({
      id: "low_conversion",
      kind: "low_conversion",
      priority: "low",
      title: `Conversion at ${dashboard.conversionRate}%`,
      detail:
        `Only ${dashboard.conversionRate}% of ${dashboard.totalLeads} leads have joined. ` +
        "Focus on the school-visit → confirmation steps where most drop-off happens.",
      cta: "Review pipeline",
    });
  }

  const ranked = actions
    .map((action, index) => ({ action, index }))
    .sort((a, b) => {
      const byPriority = PRIORITY_RANK[a.action.priority] - PRIORITY_RANK[b.action.priority];
      return byPriority !== 0 ? byPriority : a.index - b.index;
    })
    .map((entry) => entry.action)
    .slice(0, MAX_ACTIONS);

  return {
    funnel: summarize(dashboard, pendingFollowUps, unassignedLeads),
    nextBestActions: ranked,
  };
}

function summarize(
  dashboard: AdmissionsDashboardSnapshot,
  pendingFollowUps: number,
  unassignedLeads: number,
): AdmissionsFunnelSummary {
  return {
    totalLeads: dashboard.totalLeads,
    hotLeads: dashboard.hotLeads,
    conversionRate: dashboard.conversionRate,
    pendingFollowUps,
    unassignedLeads,
    stageCounts: dashboard.stageCounts,
    topSource: topSource(dashboard.sourceCounts),
  };
}
