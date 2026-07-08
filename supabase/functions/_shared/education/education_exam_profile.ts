// CI-C7 — Exam Profile Engine (spec Parts 13–14 / v3.0 Layer 4). ADDITIVE +
// profile-gated. Pure, deterministic, ZERO runtime AI.
//
// An Exam Profile controls HOW questions are SELECTED over the SAME unchanged
// curriculum Knowledge Base — difficulty / Bloom / cognitive emphasis, reasoning
// depth, diagram requirement, question-family distribution, time allocation.
// The curriculum never changes; only the profile changes (spec Part 13). The
// solver stays the certified engine: profiles are INPUTS that bias its bank-first
// selection, never a second selection path (invariant I1). With NO profile
// supplied every function here is un-called and generation is byte-identical.
//
// Two hard rules this module enforces:
//   • A1-3 depth-not-scope (spec Part 14 Rule 6, BINDING): a foundation /
//     competitive profile may RAISE reasoning depth / Bloom / difficulty but must
//     NEVER widen curriculum scope (chapters beyond the class syllabus) unless a
//     field explicitly configures it. Enforced in compatibility validation.
//   • Never silently downgrade: a profile is validated against the bank BEFORE
//     generation. Insufficiencies (too few HOTS for the required depth, missing
//     diagram/family items) are surfaced as EXPLICIT incompatibilities rather than
//     silently producing a weaker paper.
//
// B7 gating is DEFAULT-ALLOW: a profile is blocked only by an EXPLICIT deny —
// absence of a grant never blocks (never break existing generation).

import { EDU_COGNITIVE_LEVELS } from "./education_types.ts";
import type {
  EduCognitiveLevel,
  EduDifficulty,
  EduProgramTrack,
  EduQuestionType,
  QuestionBankItemRow,
} from "./education_types.ts";

type ConcreteDifficulty = Exclude<EduDifficulty, "mixed">;

// ═════════════════════════════════════════════════════════════════════════════
// Profile config entity (mirrors the dormant `edu_exam_profiles` table shape).
// ═════════════════════════════════════════════════════════════════════════════

/** Selection weighting — biases (never overrides) bank-first selection. */
export interface ExamProfileWeighting {
  /** Per-chapter emphasis: items from a higher-weighted chapter sort earlier. */
  chapterEmphasis?: Record<string, number>;
  /** Per-difficulty emphasis. */
  difficultyEmphasis?: Partial<Record<ConcreteDifficulty, number>>;
  /** Per-cognitive-level emphasis (e.g. foundation lifts apply/analyze/hots). */
  cognitiveEmphasis?: Partial<Record<EduCognitiveLevel, number>>;
}

/**
 * Reasoning-depth requirement (A1-11): at least `minCount` answered items must
 * reach `minLevel` or above on the cognitive ladder (remember→…→hots). This is
 * how a foundation profile RAISES depth — a hard pre-generation check, not a
 * silent bias.
 */
export interface ReasoningDepthRequirement {
  minLevel: EduCognitiveLevel;
  minCount: number;
}

/** The Exam Profile config (A1-11 enriched; A1-3 depth-not-scope aware). */
export interface ExamProfile {
  /** e.g. 'standard_board' | 'advanced_board' | 'foundation' | 'jee_foundation' | 'olympiad' | 'custom'. */
  code: string;
  title?: string;
  programTrack?: EduProgramTrack;

  // Scope binding (independently configurable — Part 14).
  boardCode?: string;
  classLabel?: string;
  subjectName?: string;

  // A1-11 config enrichment.
  weighting?: ExamProfileWeighting;
  /** Total paper duration target (minutes). */
  timeAllocationMinutes?: number;
  /** Higher-order minimum — how depth is RAISED (A1-3 allows this). */
  reasoningDepth?: ReasoningDepthRequirement;
  /** Diagram-question requirement. */
  diagramRequirement?: { minCount: number };
  /** Per question_type minimum count target (question-family distribution). */
  questionFamilyDistribution?: Partial<Record<EduQuestionType, number>>;

  // A1-3 depth-not-scope.
  /** Foundation / competitive profile — may raise depth, never scope (Rule 6). */
  foundation?: boolean;
  /** Explicit escape hatch: permit `additionalChapters` beyond the class syllabus. */
  allowScopeExtension?: boolean;
  /** Extra chapters the profile pulls in — honoured ONLY with allowScopeExtension. */
  additionalChapters?: string[];

  // B7 capability gating (default-allow).
  /** OPTIONAL gated-capability slug; undefined ⇒ ungated. Only an explicit deny blocks. */
  entitlementSlug?: string;
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers.
// ─────────────────────────────────────────────────────────────────────────────

/** Cognitive ladder ordinal (remember=0 … hots=4); -1 for unknown/null. */
function cognitiveOrdinal(level: string | null | undefined): number {
  if (!level) return -1;
  return EDU_COGNITIVE_LEVELS.indexOf(level as EduCognitiveLevel);
}

/** Normalise a chapter name for tolerant comparison (mirrors the boundary check). */
function normChapter(value: string): string {
  return value.trim().toLowerCase().replace(/\s+/g, " ");
}

/** Only active + approved bank items are ever selectable (mirrors the solver). */
function isSelectable(item: QuestionBankItemRow): boolean {
  return item.status === "active" && item.review_status === "approved";
}

/**
 * Canonical bank comparator — IDENTICAL to `sortBank` in the paper service
 * (chapter, then marks, then id). Used as the deterministic tiebreak so an EMPTY
 * profile reproduces the certified ordering exactly.
 */
function canonicalCompare(a: QuestionBankItemRow, b: QuestionBankItemRow): number {
  if (a.chapter !== b.chapter) return a.chapter.localeCompare(b.chapter);
  if (a.marks !== b.marks) return a.marks - b.marks;
  return a.id.localeCompare(b.id);
}

// ═════════════════════════════════════════════════════════════════════════════
// (3) Profile-driven selection weighting — biases the solver's selection.
//
// PURE + DETERMINISTIC. Returns a re-ordered COPY of the bank so that, when the
// certified solver walks it bank-first, profile-emphasised items are reached
// first. The solver itself is untouched (invariant I1). With an EMPTY weighting
// (or a profile carrying none) every score is 0 and the canonical tiebreak
// reproduces the certified `sortBank` order — i.e. the solver picks IDENTICALLY.
// ═════════════════════════════════════════════════════════════════════════════

/** Additive emphasis score for one item under a profile's weighting. */
export function scoreItemForProfile(
  profile: ExamProfile,
  item: QuestionBankItemRow,
): number {
  const w = profile.weighting;
  if (!w) return 0;
  let score = 0;
  if (w.chapterEmphasis) score += w.chapterEmphasis[item.chapter] ?? 0;
  if (w.difficultyEmphasis) {
    score += w.difficultyEmphasis[item.difficulty as ConcreteDifficulty] ?? 0;
  }
  if (w.cognitiveEmphasis && item.cognitive_level) {
    score += w.cognitiveEmphasis[item.cognitive_level as EduCognitiveLevel] ?? 0;
  }
  return score;
}

/**
 * Re-order the bank by profile emphasis (higher score first), breaking ties on
 * the canonical (chapter, marks, id) order. Pure — never mutates the input.
 * The caller passes the result straight to the certified `solveBlueprint` /
 * `solveTemplateBlueprint`; nothing else in the pipeline changes.
 */
export function orderBankForProfile(
  profile: ExamProfile,
  bank: QuestionBankItemRow[],
): QuestionBankItemRow[] {
  return [...bank].sort((a, b) => {
    const diff = scoreItemForProfile(profile, b) - scoreItemForProfile(profile, a);
    if (diff !== 0) return diff;
    return canonicalCompare(a, b);
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// (4) Pre-generation compatibility validation — "never silently downgrade".
//
// Validate a profile against the class-syllabus scope + the approved bank BEFORE
// generation. Surfaces EXPLICIT incompatibilities instead of quietly producing a
// weaker paper. Enforces A1-3 foundation depth-not-scope here.
// ═════════════════════════════════════════════════════════════════════════════

export type ProfileIncompatibilityCode =
  | "SCOPE_WIDENING_FORBIDDEN"
  | "INSUFFICIENT_REASONING_DEPTH"
  | "INSUFFICIENT_DIAGRAM_ITEMS"
  | "INSUFFICIENT_QUESTION_FAMILY";

export interface ProfileIncompatibility {
  code: ProfileIncompatibilityCode;
  message: string;
  detail?: Record<string, unknown>;
}

export interface ProfileCompatibilityResult {
  compatible: boolean;
  incompatibilities: ProfileIncompatibility[];
}

/** Context for validation — the ALLOWED curriculum scope (the class syllabus). */
export interface ProfileValidationContext {
  /** Chapters the request is allowed to draw from (the selected class syllabus). */
  syllabusChapters: string[];
}

/**
 * A1-3 depth-not-scope: the chapters a profile's `additionalChapters` would add
 * that lie OUTSIDE the class syllabus scope. Empty when the profile adds nothing
 * (or only re-lists in-scope chapters). Raising DEPTH never appears here — only
 * SCOPE widening does.
 */
export function profileScopeWidening(
  profile: ExamProfile,
  syllabusChapters: string[],
): string[] {
  const allowed = new Set(syllabusChapters.map(normChapter));
  const extra = profile.additionalChapters ?? [];
  return extra.filter((ch) => ch.trim().length > 0 && !allowed.has(normChapter(ch)));
}

/** Count approved+active bank items reaching `minLevel` or above (higher-order). */
function countAtOrAboveLevel(
  bank: QuestionBankItemRow[],
  minLevel: EduCognitiveLevel,
): number {
  const floor = cognitiveOrdinal(minLevel);
  return bank.filter(
    (i) => isSelectable(i) && cognitiveOrdinal(i.cognitive_level) >= floor,
  ).length;
}

/**
 * Validate a profile against the syllabus scope + approved bank. Returns every
 * incompatibility found (does NOT throw) so the caller can surface them all and
 * refuse to silently downgrade.
 */
export function validateProfileCompatibility(
  profile: ExamProfile,
  ctx: ProfileValidationContext,
  bank: QuestionBankItemRow[],
): ProfileCompatibilityResult {
  const incompatibilities: ProfileIncompatibility[] = [];

  // ── A1-3 depth-not-scope (BINDING) ──────────────────────────────────────────
  // A profile may raise depth freely; widening scope is forbidden unless the
  // profile explicitly opts in via allowScopeExtension. Enforced for ANY profile
  // (foundation is the documented case) — safe-by-default.
  const widening = profileScopeWidening(profile, ctx.syllabusChapters);
  if (widening.length > 0 && profile.allowScopeExtension !== true) {
    incompatibilities.push({
      code: "SCOPE_WIDENING_FORBIDDEN",
      message:
        `Profile '${profile.code}' would add chapter(s) outside the class ` +
        `syllabus (${widening.join(", ")}). A ${profile.foundation ? "foundation " : ""}` +
        `profile may raise reasoning depth but must not widen curriculum scope ` +
        `unless 'allowScopeExtension' is explicitly set.`,
      detail: { addedChapters: widening, allowScopeExtension: false },
    });
  }

  // ── Reasoning depth (never silently downgrade) ──────────────────────────────
  if (profile.reasoningDepth && profile.reasoningDepth.minCount > 0) {
    const { minLevel, minCount } = profile.reasoningDepth;
    const available = countAtOrAboveLevel(bank, minLevel);
    if (available < minCount) {
      incompatibilities.push({
        code: "INSUFFICIENT_REASONING_DEPTH",
        message:
          `Profile '${profile.code}' requires at least ${minCount} item(s) at ` +
          `cognitive level '${minLevel}' or above, but only ${available} are ` +
          `available in the approved bank.`,
        detail: { minLevel, required: minCount, available },
      });
    }
  }

  // ── Diagram requirement ─────────────────────────────────────────────────────
  if (profile.diagramRequirement && profile.diagramRequirement.minCount > 0) {
    const required = profile.diagramRequirement.minCount;
    const available = bank.filter(
      (i) => isSelectable(i) && i.question_type === "diagram",
    ).length;
    if (available < required) {
      incompatibilities.push({
        code: "INSUFFICIENT_DIAGRAM_ITEMS",
        message:
          `Profile '${profile.code}' requires at least ${required} diagram ` +
          `question(s), but only ${available} are available in the approved bank.`,
        detail: { required, available },
      });
    }
  }

  // ── Question-family distribution ────────────────────────────────────────────
  if (profile.questionFamilyDistribution) {
    for (const [type, need] of Object.entries(profile.questionFamilyDistribution)) {
      if (typeof need !== "number" || need <= 0) continue;
      const available = bank.filter(
        (i) => isSelectable(i) && i.question_type === type,
      ).length;
      if (available < need) {
        incompatibilities.push({
          code: "INSUFFICIENT_QUESTION_FAMILY",
          message:
            `Profile '${profile.code}' requires at least ${need} '${type}' ` +
            `question(s), but only ${available} are available in the approved bank.`,
          detail: { questionType: type, required: need, available },
        });
      }
    }
  }

  return { compatible: incompatibilities.length === 0, incompatibilities };
}

// ═════════════════════════════════════════════════════════════════════════════
// (5) Capability gating — DEFAULT-ALLOW (invariant B7).
//
// A profile carries an OPTIONAL `entitlementSlug`. Gating resolves to ALLOW by
// default and blocks ONLY when that slug is EXPLICITLY denied for the org. A
// missing grant NEVER blocks — that is the whole point of B7: never silently
// break existing generation for the pilot school. Entitlement checks sit BESIDE
// RBAC (they never replace it).
// ═════════════════════════════════════════════════════════════════════════════

export interface ExamProfileGatingInput {
  /** Slugs the org's plan grants (from plan_entitlements). Informational under default-allow. */
  grantedEntitlements?: string[];
  /** Slugs EXPLICITLY denied for this org (enterprise revoke / deny-list). Only these block. */
  deniedEntitlements?: string[];
}

export type ExamProfileGatingReason =
  | "no_entitlement_required"
  | "explicitly_granted"
  | "default_allow"
  | "explicitly_denied";

export interface ExamProfileGatingResult {
  allowed: boolean;
  reason: ExamProfileGatingReason;
  entitlementSlug?: string;
}

/**
 * Resolve whether a profile is permitted for an org. DEFAULT-ALLOW: only an
 * explicit deny of the profile's `entitlementSlug` blocks; a profile with no
 * slug, or a slug that is simply not granted, is allowed.
 */
export function resolveExamProfileGating(
  profile: ExamProfile,
  input: ExamProfileGatingInput = {},
): ExamProfileGatingResult {
  const slug = profile.entitlementSlug;
  if (!slug) return { allowed: true, reason: "no_entitlement_required" };

  const denied = new Set(input.deniedEntitlements ?? []);
  if (denied.has(slug)) {
    return { allowed: false, reason: "explicitly_denied", entitlementSlug: slug };
  }

  const granted = new Set(input.grantedEntitlements ?? []);
  if (granted.has(slug)) {
    return { allowed: true, reason: "explicitly_granted", entitlementSlug: slug };
  }

  // No grant, no deny → ALLOW (B7 default-allow).
  return { allowed: true, reason: "default_allow", entitlementSlug: slug };
}

/** Convenience boolean — true unless the profile's slug is explicitly denied. */
export function isExamProfileAllowed(
  profile: ExamProfile,
  input: ExamProfileGatingInput = {},
): boolean {
  return resolveExamProfileGating(profile, input).allowed;
}
