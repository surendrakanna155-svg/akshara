// Adaptive AI — P3-AI-2 / W2.0a: deterministic priority-item generators.
//
// Each generator converts an EXISTING deterministic intelligence output (the
// analytics bundle, the student-risk snapshots) into typed RawPriorityItems —
// no new computation, no model calls, no clock. This is the "consolidate the
// siloed per-module priority lists into one taxonomy" step (readiness report
// §3 G1): the numbers already exist; we only classify + tag them so the one
// Priority Engine can score every persona's feed the same way.
//
// PRIVACY BY CONSTRUCTION (doc 07 §5): per-student items never list `director`
// in their personas, so the aggregate-only director feed cannot surface child
// rows even before RBAC — the manifest rule is enforced at the source.

import type { ImpactClass, Persona, RawPriorityItem } from "./priority_types.ts";

// ─── Structural inputs (the handler maps loader outputs onto these) ───────────

export interface RiskMetricInput {
  key?: string;
  label: string;
  score: number;
  level: "low" | "medium" | "high";
  detail: string;
}

export interface DashboardInput {
  attendanceRiskScore: number;
  feeCollectionRisk: number;
  timetableHealthScore: number;
}

export interface RiskSnapshotInput {
  studentId: string;
  className: string;
  sectionName?: string | null;
  riskScore: number;
  riskLevel: string; // "critical" | "high" | "medium" | "low"
}

export interface PrioritySourceInputs {
  /** Present only when the caller holds viewAnalytics. */
  analytics?: { dashboard: DashboardInput; risks: RiskMetricInput[] };
  /** Present only when the caller holds a risk-read permission. */
  riskSnapshots?: RiskSnapshotInput[];
}

// School-level exceptions are relevant to the operational leadership personas.
const SCHOOL_LEADERSHIP: Persona[] = ["principal", "admin"];
const FINANCE_LEADERSHIP: Persona[] = ["finance", "principal", "admin"];
// Aggregate signals are additionally safe for the director (no PII).
const AGGREGATE_PERSONAS: Persona[] = ["principal", "admin", "director"];

/** Deterministic slug for a stable itemKey. */
function slug(s: string): string {
  return s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "");
}

function isFinanceRisk(label: string, key?: string): boolean {
  return /fee|finance|collection|defaulter|payment/i.test(`${key ?? ""} ${label}`);
}

function riskLevelToImpact(level: RiskMetricInput["level"]): ImpactClass {
  return level === "high" ? "serious" : "elevated";
}

/** (1) School-level analytics risk metrics → aggregate exception items.
 * Only medium/high surface (low is not a "priority"). Director-safe. */
export function riskMetricItems(risks: RiskMetricInput[]): RawPriorityItem[] {
  return risks
    .filter((r) => r.level === "high" || r.level === "medium")
    .map((r) => {
      const finance = isFinanceRisk(r.label, r.key);
      return {
        itemKey: `analytics-risk:${slug(r.key ?? r.label)}`,
        type: "exception" as const,
        title: r.label,
        detail: r.detail,
        personas: finance
          ? [...new Set([...AGGREGATE_PERSONAS, "finance" as Persona])]
          : AGGREGATE_PERSONAS,
        entityTags: [finance ? "school:fees" : "school:analytics"],
        factors: { impactClass: riskLevelToImpact(r.level) },
        source: "analytics_risk",
      };
    });
}

/** (2) At-risk student snapshots → per-student exception items (critical/high
 * only, capped). NOT director-visible (PII). Real student entity tags. */
export function atRiskStudentItems(
  snapshots: RiskSnapshotInput[],
  opts: { limit?: number } = {},
): RawPriorityItem[] {
  const limit = Math.min(50, Math.max(1, Math.trunc(opts.limit ?? 10)));
  return snapshots
    .filter((s) => s.riskLevel === "critical" || s.riskLevel === "high")
    // Highest risk first so the cap keeps the most severe (stable tie-break by id).
    .sort((a, b) => (b.riskScore - a.riskScore) || a.studentId.localeCompare(b.studentId))
    .slice(0, limit)
    .map((s) => {
      const cohort = s.sectionName ? `${s.className}-${s.sectionName}` : s.className;
      return {
      itemKey: `risk:student:${s.studentId}`,
      type: "exception" as const,
      title: `At-risk student in ${cohort}`,
      detail: `Risk score ${s.riskScore}/100 (${s.riskLevel}). Review interventions — no automated action taken.`,
      personas: SCHOOL_LEADERSHIP,
      entityTags: [`student:${s.studentId}:risk`, "school:risk"],
      factors: {
        peopleAffected: 1,
        impactClass: s.riskLevel === "critical" ? ("critical" as const) : ("serious" as const),
      },
      source: "student_risk",
      };
    });
}

/** (3) Fee-collection pressure → a follow-up item for finance leadership.
 * Aggregate (no student rows) so it is director-safe too. */
export function feeCollectionItems(dashboard: DashboardInput): RawPriorityItem[] {
  const risk = dashboard.feeCollectionRisk;
  if (risk < 50) return [];
  const impactClass: ImpactClass = risk >= 75 ? "serious" : "elevated";
  return [{
    itemKey: "fee:collection",
    type: "follow_up",
    title: "Fee collection pressure elevated",
    detail:
      `Open-invoice pressure is at ${Math.round(risk)}/100. Review the defaulter list and collection cadence.`,
    personas: [...new Set([...FINANCE_LEADERSHIP, "director" as Persona])],
    entityTags: ["school:fees"],
    factors: { impactClass },
    source: "fee_collection",
  }];
}

/** (4) Timetable health below target → an operations exception. */
export function timetableItems(dashboard: DashboardInput): RawPriorityItem[] {
  if (dashboard.timetableHealthScore >= 70) return [];
  return [{
    itemKey: "ops:timetable",
    type: "exception",
    title: "Review timetable conflicts",
    detail:
      `Timetable health is ${Math.round(dashboard.timetableHealthScore)}/100 (below target). Run the Smart Timetable conflict review before the next publish.`,
    personas: SCHOOL_LEADERSHIP,
    entityTags: ["school:timetable"],
    factors: { impactClass: "elevated" },
    source: "timetable_health",
  }];
}

/** (5) Attendance risk elevated → an aggregate exception. Director-safe. */
export function attendanceItems(dashboard: DashboardInput): RawPriorityItem[] {
  if (dashboard.attendanceRiskScore < 50) return [];
  const impactClass: ImpactClass = dashboard.attendanceRiskScore >= 75 ? "serious" : "elevated";
  return [{
    itemKey: "attendance:risk",
    type: "exception",
    title: "Attendance risk elevated",
    detail:
      `School attendance risk is ${Math.round(dashboard.attendanceRiskScore)}/100. Review chronic-absentee classes.`,
    personas: AGGREGATE_PERSONAS,
    entityTags: ["school:attendance"],
    factors: { impactClass },
    source: "attendance_risk",
  }];
}

/** Assemble every generator's output from whatever inputs the handler was
 * permitted to load. Order is irrelevant — buildFeed sorts deterministically. */
export function collectRawItems(inputs: PrioritySourceInputs): RawPriorityItem[] {
  const items: RawPriorityItem[] = [];
  if (inputs.analytics) {
    items.push(...riskMetricItems(inputs.analytics.risks));
    items.push(...feeCollectionItems(inputs.analytics.dashboard));
    items.push(...timetableItems(inputs.analytics.dashboard));
    items.push(...attendanceItems(inputs.analytics.dashboard));
  }
  if (inputs.riskSnapshots) {
    items.push(...atRiskStudentItems(inputs.riskSnapshots));
  }
  return items;
}
