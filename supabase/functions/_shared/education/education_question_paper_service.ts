// Paper generation orchestration (Batch 8b) — bank-first, constrained AI.
//
// Pipeline:
//   1. Load APPROVED, active bank questions for the subject/track/chapters.
//   2. Deterministic blueprint solver fills the plan bank-first (exact match).
//   3. Gaps the bank cannot cover go to constrained Claude as moderation
//      candidates (source='ai_candidate', review_status='pending') — only when
//      enabled and a key is configured. Otherwise gaps are reported, not faked.
//   4. The paper is always created as review_status='draft'. It cannot be
//      published until it is approved AND has no pending AI candidates (gate
//      lives in the repository / publish handler).
//
// No placeholder/stub question text is ever written into a paper here — that
// was the old behaviour this batch removes.

import { buildPaperBlueprint } from "./education_generator.ts";
import { solveBlueprint } from "./education_blueprint_solver.ts";
import {
  type ExamProfile,
  orderBankForProfile,
  type ProfileCompatibilityResult,
  validateProfileCompatibility,
} from "./education_exam_profile.ts";
import { generateAiCandidatesForGaps } from "./education_ai_question_gapfill.ts";
import { orderBankForRotation, type RotationPolicy } from "./education_item_rotation.ts";
import { aiApiKey, aiProvider, claudeModel } from "../ai/anthropic_client.ts";
import type { Governance } from "../ai/model_gateway.ts";
import type { AiRuntimeConfig } from "../ai/ai_settings.ts";
import {
  applyRegeneratedPaperItem,
  getPaperItem,
  listQuestionBankItems,
  type QuestionBankListFilters,
  type UpdatePaperItemResult,
} from "./education_repository.ts";
import type { BlueprintSlot } from "./education_blueprint_solver.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import type {
  EduDifficulty,
  EduExamType,
  EduPaperItemSource,
  EduProgramTrack,
  EduQuestionType,
  EduReviewStatus,
  GenerateQuestionPaperInput,
  QuestionBankItemRow,
} from "./education_types.ts";

export interface PaperGenerationItem {
  bankItemId?: string;
  source: EduPaperItemSource;
  reviewStatus: EduReviewStatus;
  questionType: EduQuestionType;
  marks: number;
  questionText: string;
  answerText: string;
  options: string[];
}

export interface PaperGap {
  questionType: EduQuestionType;
  difficulty: string;
  marks: number;
  chapter: string;
}

export interface PaperGenerationResult {
  title: string;
  programTrack: EduProgramTrack;
  reviewStatus: "draft";
  blueprint: Record<string, unknown>;
  answerKey: Array<{ questionNumber: number; answer: string; marks: number }>;
  items: PaperGenerationItem[];
  bankReuseCount: number;
  /** Count of AI moderation candidates (also surfaced as aiGeneratedCount). */
  aiCandidateCount: number;
  aiGeneratedCount: number;
  /**
   * Program D · M3.2 — the measured request-path AI rate: aiCandidateCount / total blueprint
   * slots (0 when there are no slots). This is the "≈0% live-AI at request time" METRIC —
   * observable per generation, trending down as certified coverage grows. Not an assertion.
   */
  aiCandidateRate: number;
  /** Program D · M3.1 — which bank the pool was read from ('own_bank' | 'certified_union'). */
  bankSource: "own_bank" | "certified_union";
  /** Blueprint slots left unfilled (bank empty + AI off/declined). */
  unfilledGapCount: number;
  gaps: PaperGap[];
  /**
   * CI-C7 (ADDITIVE, opt-in): pre-generation Exam-Profile compatibility result.
   * Present ONLY when a profile was supplied — surfaces explicit incompatibilities
   * ("never silently downgrade"). Absent (undefined key) on the certified path.
   */
  profileCompatibility?: ProfileCompatibilityResult;
}

/**
 * Program D per-generation config (M3.1 / M3.3). ABSENT ⇒ exact current behaviour
 * (own-bank pool, marked-unpublishable gap-fill). Resolved from `edu_program_d_settings`
 * by the handler; the pure solver is never touched — only its input pool + the pre-existing
 * gap-fill gate change.
 */
export interface ProgramDPaperConfig {
  /** M3.1: read the certified/adopted union pool instead of own-bank-only. Default 'own_bank'. */
  bankSource?: "own_bank" | "certified_union";
  /**
   * M3.3: request-path gap-fill policy for the PRE-EXISTING constrained-AI gap-fill.
   * 'marked_unpublishable' (default) = today's behaviour (ai_candidate/pending, unpublishable);
   * 'hard_off' = no AI candidates at all — an under-fill becomes an HONEST shortfall (never a
   * live-AI expansion). Owner-flipped per tenant; Program D adds no new AI path.
   */
  gapFillPolicy?: "marked_unpublishable" | "hard_off";
  /**
   * M4.2: prefer-unseen selection. When true, the pool is ordered by the deterministic
   * rotation helper (least-used / least-recently-used first) before the UNCHANGED solver
   * walks it. With no exposure data + no cooldown, this collapses to the canonical order —
   * byte-identical to today (invariant I1). Default off.
   */
  preferUnseen?: boolean;
  /** Optional rotation policy (cooldown/cap). Empty policy ⇒ soft prefer-unseen only. */
  rotationPolicy?: RotationPolicy;
  /** Explicit reference instant (ISO) for cooldown math — passed in so selection stays pure. */
  referenceAt?: string;
}

export type RegeneratePaperItemResult =
  | { ok: true; result: Extract<UpdatePaperItemResult, { ok: true }> }
  | { ok: false; reason: "not_found" | "not_editable" | "ai_unavailable" | "no_candidate" };

/**
 * Regenerate ONE question slot with constrained AI (Feature B — spends tokens).
 * Rebuilds the slot spec from the existing item + parent paper, asks Claude for
 * a single replacement inside the syllabus scope, validates it, and writes it
 * back as a fresh moderation candidate (pending). Safe-by-default: no key or no
 * valid candidate returns a typed failure — the original item is left intact.
 */
export async function regeneratePaperItem(
  client: TenantQueryClient,
  paperId: string,
  itemId: string,
  opts: { chapter?: string; ai?: AiRuntimeConfig; governance?: Governance },
): Promise<RegeneratePaperItemResult> {
  const found = await getPaperItem(client, paperId, itemId);
  if (!found) return { ok: false, reason: "not_found" };
  const { paper, item } = found;
  if (paper.review_status === "published" || paper.review_status === "archived") {
    return { ok: false, reason: "not_editable" };
  }

  const aiConfig: AiRuntimeConfig = opts.ai ??
    { provider: aiProvider(), model: claudeModel(), apiKey: aiApiKey(), source: "env" };
  if (!aiConfig.apiKey) return { ok: false, reason: "ai_unavailable" };
  if (!opts.governance) return { ok: false, reason: "ai_unavailable" };

  const paperChapters = Array.isArray(paper.chapters) ? paper.chapters as string[] : [];
  const chapter = opts.chapter ?? paperChapters[0] ?? "General";
  const difficulty: EduDifficulty =
    paper.difficulty === "mixed" ? "medium" : (paper.difficulty as EduDifficulty);

  const slot: BlueprintSlot = {
    index: 0,
    questionType: item.question_type as EduQuestionType,
    difficulty,
    marks: item.marks,
    chapter,
  };

  const candidates = await generateAiCandidatesForGaps(
    [slot],
    {
      subjectName: paper.subject_name,
      className: paper.class_name,
      programTrack: paper.program_track as EduProgramTrack,
      examType: paper.exam_type,
      chapters: [chapter],
    },
    opts.governance,
  );
  const candidate = candidates[0];
  if (!candidate) return { ok: false, reason: "no_candidate" };

  const applied = await applyRegeneratedPaperItem(client, paperId, itemId, {
    questionType: candidate.questionType,
    marks: candidate.marks,
    questionText: candidate.questionText,
    answerText: candidate.answerText,
    options: candidate.options,
  });
  if (!applied.ok) return { ok: false, reason: applied.reason };
  return { ok: true, result: applied };
}

function examTypeLabel(examType: EduExamType): string {
  return examType.replaceAll("_", " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

/** Stable bank ordering so the solver is fully deterministic. */
function sortBank(items: QuestionBankItemRow[]): QuestionBankItemRow[] {
  return [...items].sort((a, b) => {
    if (a.chapter !== b.chapter) return a.chapter.localeCompare(b.chapter);
    if (a.marks !== b.marks) return a.marks - b.marks;
    return a.id.localeCompare(b.id);
  });
}

export async function generateQuestionPaper(
  client: TenantQueryClient,
  input: GenerateQuestionPaperInput,
  ai?: AiRuntimeConfig,
  profile?: ExamProfile,
  governance?: Governance,
  programD?: ProgramDPaperConfig,
): Promise<PaperGenerationResult> {
  const programTrack: EduProgramTrack = input.programTrack ?? "board";

  // Program D · M3.1: source the pool from the certified/adopted union when enabled, else the
  // school's own bank (default — byte-identical to today). The solver is unchanged either way.
  const bankSource: "own_bank" | "certified_union" = programD?.bankSource ?? "own_bank";

  const filters: QuestionBankListFilters = {
    subjectName: input.subjectName,
    chapters: input.chapters,
    difficulty: input.difficulty === "mixed" ? undefined : input.difficulty,
    status: "active",
    reviewStatus: "approved",
    programTrack,
    bankSource,
    page: 1,
    pageSize: 100,
  };

  const bankPage = await listQuestionBankItems(client, filters);
  const bank = sortBank(bankPage.items);

  // ── CI-C7 exam-profile seam (ADDITIVE, opt-in, DORMANT) ─────────────────────
  // A supplied Exam Profile (a) runs a pre-generation compatibility check that
  // surfaces explicit incompatibilities ("never silently downgrade") and (b)
  // BIASES bank-first selection by re-ordering the bank the certified solver
  // walks. When ABSENT — the production path; the handler never supplies one —
  // this block is skipped, `solveBank === bank`, and generation is BYTE-IDENTICAL
  // to the certified path (invariant I1 / mitigation B7).
  let profileCompatibility: ProfileCompatibilityResult | undefined;
  let solveBank = bank;
  if (profile) {
    profileCompatibility = validateProfileCompatibility(
      profile,
      { syllabusChapters: input.chapters },
      bank,
    );
    solveBank = orderBankForProfile(profile, bank);
  }

  // Program D · M4.2: prefer-unseen ordering (deterministic; the solver is unchanged, only the pool
  // ORDER changes). Off by default; with no exposure data + no cooldown it reproduces the canonical
  // order exactly (rotation helper's byte-identity guarantee), so the certified path stays intact.
  if (programD?.preferUnseen) {
    solveBank = orderBankForRotation(
      programD.rotationPolicy ?? {},
      solveBank,
      { referenceAt: programD.referenceAt },
    );
  }

  const solution = solveBlueprint(
    {
      subjectName: input.subjectName,
      totalMarks: input.totalMarks,
      difficulty: input.difficulty,
      chapters: input.chapters,
      questionTypeMix: input.questionTypeMix,
    },
    solveBank,
  );

  // index → item, so the paper reads in blueprint-plan order.
  const byIndex = new Map<number, PaperGenerationItem>();
  for (const { slot, bankItem } of solution.selected) {
    byIndex.set(slot.index, {
      bankItemId: bankItem.id,
      source: "bank",
      reviewStatus: "approved",
      questionType: bankItem.question_type as EduQuestionType,
      marks: slot.marks,
      questionText: bankItem.question_text,
      answerText: bankItem.answer_text ?? "",
      options: Array.isArray(bankItem.options) ? bankItem.options as string[] : [],
    });
  }

  let aiCandidateCount = 0;
  // Program D · M3.3: 'hard_off' disables the PRE-EXISTING request-path gap-fill entirely, so an
  // under-fill becomes an honest shortfall — never a live-AI expansion. Default keeps today's flow.
  const gapFillPolicy = programD?.gapFillPolicy ?? "marked_unpublishable";
  const allowAi = input.allowAiGapFill !== false && gapFillPolicy !== "hard_off";
  // Admin-saved panel config (provider/model/key) wins; else env fallback.
  const aiConfig: AiRuntimeConfig = ai ??
    { provider: aiProvider(), model: claudeModel(), apiKey: aiApiKey(), source: "env" };
  if (allowAi && aiConfig.apiKey && governance && solution.gaps.length > 0) {
    const candidates = await generateAiCandidatesForGaps(
      solution.gaps,
      {
        subjectName: input.subjectName,
        className: input.className,
        programTrack,
        examType: input.examType,
        chapters: input.chapters,
      },
      governance,
    );
    for (const c of candidates) {
      byIndex.set(c.slotIndex, {
        source: "ai_candidate",
        reviewStatus: "pending",
        questionType: c.questionType,
        marks: c.marks,
        questionText: c.questionText,
        answerText: c.answerText,
        options: c.options,
      });
      aiCandidateCount++;
    }
  }

  // Compact to plan order; any slot still missing stays an unfilled gap.
  const items: PaperGenerationItem[] = solution.slots
    .map((slot) => byIndex.get(slot.index))
    .filter((item): item is PaperGenerationItem => item !== undefined);

  const filledIndexes = new Set(
    solution.slots.filter((s) => byIndex.has(s.index)).map((s) => s.index),
  );
  const gaps: PaperGap[] = solution.slots
    .filter((s) => !filledIndexes.has(s.index))
    .map((s) => ({
      questionType: s.questionType,
      difficulty: s.difficulty,
      marks: s.marks,
      chapter: s.chapter,
    }));

  const title =
    `${input.className}${input.sectionName ? ` ${input.sectionName}` : ""} — ` +
    `${input.subjectName} ${examTypeLabel(input.examType)} (${input.totalMarks} marks)`;

  const answerKey = items.map((item, index) => ({
    questionNumber: index + 1,
    answer: item.answerText,
    marks: item.marks,
  }));

  const placedMarks = items.reduce((sum, item) => sum + item.marks, 0);
  const blueprint = {
    examType: input.examType,
    programTrack,
    ...buildPaperBlueprint(
      input.totalMarks,
      items.map((item) => ({
        marks: item.marks,
        questionType: item.questionType,
        source: item.source,
      })),
      input.chapters,
    ),
    difficultyMode: input.difficulty,
    placedMarks,
    bankReuseCount: solution.selected.length,
    aiCandidateCount,
    unfilledGapCount: gaps.length,
    pendingApproval: aiCandidateCount > 0,
  };

  return {
    title,
    programTrack,
    reviewStatus: "draft",
    blueprint,
    answerKey,
    items,
    bankReuseCount: solution.selected.length,
    aiCandidateCount,
    aiGeneratedCount: aiCandidateCount,
    // M3.2: the measured request-path AI rate (0 when no slots). Trends to ≈0 as coverage grows.
    aiCandidateRate: solution.slots.length > 0 ? aiCandidateCount / solution.slots.length : 0,
    bankSource,
    unfilledGapCount: gaps.length,
    gaps,
    // Only attach when a profile was supplied; the certified shape is otherwise
    // unchanged (undefined key ⇒ absent).
    ...(profileCompatibility ? { profileCompatibility } : {}),
  };
}
