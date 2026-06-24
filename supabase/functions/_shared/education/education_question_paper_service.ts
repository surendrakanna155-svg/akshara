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
import { generateAiCandidatesForGaps } from "./education_ai_question_gapfill.ts";
import { aiApiKey, aiProvider, claudeModel } from "../ai/anthropic_client.ts";
import type { AiRuntimeConfig } from "../ai/ai_settings.ts";
import { listQuestionBankItems, type QuestionBankListFilters } from "./education_repository.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import type {
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
  /** Blueprint slots left unfilled (bank empty + AI off/declined). */
  unfilledGapCount: number;
  gaps: PaperGap[];
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
): Promise<PaperGenerationResult> {
  const programTrack: EduProgramTrack = input.programTrack ?? "board";

  const filters: QuestionBankListFilters = {
    subjectName: input.subjectName,
    chapters: input.chapters,
    difficulty: input.difficulty === "mixed" ? undefined : input.difficulty,
    status: "active",
    reviewStatus: "approved",
    programTrack,
    page: 1,
    pageSize: 100,
  };

  const bankPage = await listQuestionBankItems(client, filters);
  const bank = sortBank(bankPage.items);

  const solution = solveBlueprint(
    {
      subjectName: input.subjectName,
      totalMarks: input.totalMarks,
      difficulty: input.difficulty,
      chapters: input.chapters,
      questionTypeMix: input.questionTypeMix,
    },
    bank,
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
  const allowAi = input.allowAiGapFill !== false;
  // Admin-saved panel config (provider/model/key) wins; else env fallback.
  const aiConfig: AiRuntimeConfig = ai ??
    { provider: aiProvider(), model: claudeModel(), apiKey: aiApiKey(), source: "env" };
  if (allowAi && aiConfig.apiKey && solution.gaps.length > 0) {
    const candidates = await generateAiCandidatesForGaps(
      solution.gaps,
      {
        subjectName: input.subjectName,
        className: input.className,
        programTrack,
        examType: input.examType,
        chapters: input.chapters,
      },
      aiConfig.apiKey,
      { provider: aiConfig.provider, model: aiConfig.model },
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
    unfilledGapCount: gaps.length,
    gaps,
  };
}
