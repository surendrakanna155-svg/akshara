import {
  balanceDifficultyMix,
  buildPaperBlueprint,
  defaultQuestionTypeMix,
  generateStubQuestion,
  type GeneratedQuestion,
} from "./education_generator.ts";
import {
  listQuestionBankItems,
  type QuestionBankListFilters,
} from "./education_repository.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import type {
  EduDifficulty,
  EduExamType,
  EduQuestionType,
  GenerateQuestionPaperInput,
  QuestionBankItemRow,
} from "./education_types.ts";

export interface PaperGenerationItem extends GeneratedQuestion {
  bankItemId?: string;
  source: "bank" | "ai_generated";
}

export interface PaperGenerationResult {
  title: string;
  blueprint: Record<string, unknown>;
  answerKey: Array<{ questionNumber: number; answer: string; marks: number }>;
  items: PaperGenerationItem[];
  bankReuseCount: number;
  aiGeneratedCount: number;
}

function examTypeLabel(examType: EduExamType): string {
  return examType.replaceAll("_", " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

function marksPerQuestion(totalMarks: number, count: number): number {
  const base = Math.max(1, Math.floor(totalMarks / Math.max(count, 1)));
  return base;
}

function pickBankItems(
  bankItems: QuestionBankItemRow[],
  neededMarks: number,
): { picked: QuestionBankItemRow[]; remainingMarks: number } {
  const picked: QuestionBankItemRow[] = [];
  let remaining = neededMarks;
  for (const item of bankItems) {
    if (remaining <= 0) break;
    if (item.marks <= remaining) {
      picked.push(item);
      remaining -= item.marks;
    }
  }
  return { picked, remainingMarks: remaining };
}

export async function generateQuestionPaper(
  client: TenantQueryClient,
  input: GenerateQuestionPaperInput,
): Promise<PaperGenerationResult> {
  const questionTypes = input.questionTypeMix
    ? (Object.keys(input.questionTypeMix) as EduQuestionType[])
    : defaultQuestionTypeMix();

  const targetCount = Math.max(4, Math.min(20, Math.ceil(input.totalMarks / 5)));
  const marksEach = marksPerQuestion(input.totalMarks, targetCount);

  const filters: QuestionBankListFilters = {
    subjectName: input.subjectName,
    chapters: input.chapters,
    difficulty: input.difficulty === "mixed" ? undefined : input.difficulty,
    status: "active",
    page: 1,
    pageSize: 100,
  };

  const bankPage = await listQuestionBankItems(client, filters);
  const { picked, remainingMarks } = pickBankItems(bankPage.items, input.totalMarks);

  const items: PaperGenerationItem[] = picked.map((row) => ({
    bankItemId: row.id,
    source: "bank" as const,
    questionType: row.question_type as EduQuestionType,
    marks: row.marks,
    questionText: row.question_text,
    answerText: row.answer_text ?? "",
    options: Array.isArray(row.options) ? row.options as string[] : [],
  }));

  let aiCount = 0;
  let remaining = remainingMarks;
  let typeIndex = 0;
  const chapters = input.chapters.length > 0 ? input.chapters : ["General"];
  const difficultyMix = input.difficulty === "mixed"
    ? balanceDifficultyMix(targetCount + 5)
    : Array.from({ length: targetCount + 5 }, () => input.difficulty);

  while (remaining > 0 && items.length < targetCount + 5) {
    const chapter = chapters[items.length % chapters.length]!;
    const qType = questionTypes[typeIndex % questionTypes.length]!;
    typeIndex += 1;
    const marks = Math.min(remaining, marksEach);
    const difficulty = difficultyMix[items.length] ?? "medium";
    const generated = generateStubQuestion(
      input.subjectName,
      chapter,
      difficulty,
      qType,
      marks,
    );
    items.push({ ...generated, source: "ai_generated" });
    remaining -= marks;
    aiCount += 1;
  }

  const title =
    `${input.className}${input.sectionName ? ` ${input.sectionName}` : ""} — ` +
    `${input.subjectName} ${examTypeLabel(input.examType)} (${input.totalMarks} marks)`;

  const answerKey = items.map((item, index) => ({
    questionNumber: index + 1,
    answer: item.answerText,
    marks: item.marks,
  }));

  const blueprint = {
    examType: input.examType,
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
  };

  return {
    title,
    blueprint,
    answerKey,
    items,
    bankReuseCount: picked.length,
    aiGeneratedCount: aiCount,
  };
}
