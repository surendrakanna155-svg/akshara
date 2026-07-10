// Adaptive AI — P3-AI-2 / W2.0a: Priority Engine taxonomy (design doc 04 §3).
//
// The typed "what matters now" vocabulary shared by every persona feed. Ground
// truth: doc 04 §3.1 item taxonomy + §3.2 scoring formula
// (score = urgency × impact × age_boost × learned_weight), all deterministic,
// all explainable, ZERO model calls. This file is types + constants only; the
// pure scorer lives in priority_engine.ts and the deterministic generators in
// priority_sources.ts.

/** doc 04 §3.1 — every actionable thing is one of these five typed items. */
export type PriorityItemType =
  | "approval" // leave / admission / refund / PO awaiting a decision
  | "deadline" // marks due, fee due, doc expiry, PTM
  | "exception" // unmarked attendance, not-submitted, low stock, at-risk
  | "follow_up" // lead call due, defaulter call, overdue book
  | "opportunity"; // at-risk student improving, idle capacity, hot lead

/** Personas that consume a feed. W2.0 platform ships the school/aggregate
 * personas (principal/finance/director/admin — all school-operational or
 * aggregate scope). Per-user-scoped personas (teacher's classes, parent's
 * children, student) arrive in their rollout waves (doc 07), so they are named
 * here for the taxonomy but not accepted by the W2.0a route. */
export type Persona =
  | "teacher"
  | "parent"
  | "student"
  | "principal"
  | "director"
  | "finance"
  | "admin";

/** Personas the W2.0a feed route serves today (school-scoped / aggregate). */
export const W2_0_SUPPORTED_PERSONAS: readonly Persona[] = [
  "principal",
  "finance",
  "director",
  "admin",
] as const;

/** Compliance / impact class — the qualitative severity axis (doc 04 §3.2). */
export type ImpactClass = "routine" | "elevated" | "serious" | "critical";

/** The deterministic factor inputs a generator supplies per item. The engine
 * derives the score from these — a generator never scores, it only measures. */
export interface PriorityFactors {
  /** Days until the obligation is due; ≤0 = due/overdue. Undefined = no clock. */
  dueInDays?: number;
  /** How long this has already been waiting (approval age, unmarked age). */
  waitingDays?: number;
  /** Money at stake in minor units (paise) — sizes financial impact. */
  moneyAtStakeMinor?: number;
  /** Count of students/people affected — sizes operational impact. */
  peopleAffected?: number;
  /** Qualitative severity when there is no money/people number to size by. */
  impactClass?: ImpactClass;
}

/** What a generator emits — measured, not yet scored. */
export interface RawPriorityItem {
  /** Stable dedupe/learning key, e.g. `risk:student:<uuid>` or `fee:collection`.
   * Two generators emitting the same real-world item MUST share this key. */
  itemKey: string;
  type: PriorityItemType;
  title: string;
  detail: string;
  /** Which personas this item is relevant to (RBAC is enforced separately at
   * load time — this is relevance, not authorization). */
  personas: Persona[];
  /** Cache-invalidation / linkage tags (doc 03 §3.5), e.g. `student:<id>:fees`. */
  entityTags: string[];
  factors: PriorityFactors;
  /** Where it came from (telemetry / grouping). */
  source: string;
}

/** The four scoring factors, each exposed so the UI can always answer
 * "why is this first?" (explainability rail, doc 01 §6). */
export interface PriorityFactorBreakdown {
  urgency: number;
  impact: number;
  ageBoost: number;
  learnedWeight: number;
}

/** A scored, explainable item ready for a persona feed. */
export interface ScoredPriorityItem extends RawPriorityItem {
  /** Raw multiplicative score (urgency × impact × ageBoost × learnedWeight). */
  rawScore: number;
  /** 0–100 normalized score for display / thresholds (deterministic mapping). */
  score: number;
  factorBreakdown: PriorityFactorBreakdown;
  /** Human-readable "why is this first?" one-liner. */
  reason: string;
}

/** Per-(school, persona, item_type) multiplier learned from accept/dismiss
 * behaviour (doc 04 §3.2 · doc 03 §2.2/§2.5). W2.0a uses defaults; W2.0b
 * (Recommendation Engine) populates these from ai_persona_memory. */
export type LearnedWeights = Partial<Record<PriorityItemType, number>>;

export interface PriorityFeed {
  persona: Persona;
  generatedAt: string;
  items: ScoredPriorityItem[];
  counts: {
    total: number;
    byType: Partial<Record<PriorityItemType, number>>;
    critical: number; // score >= 75
  };
  /** True when a generator was skipped for lack of permission (feed is a subset
   * of what a fully-permitted caller would see) — honest partial signal. */
  degraded: boolean;
}

export function isPersona(value: string): value is Persona {
  return (
    value === "teacher" ||
    value === "parent" ||
    value === "student" ||
    value === "principal" ||
    value === "director" ||
    value === "finance" ||
    value === "admin"
  );
}
