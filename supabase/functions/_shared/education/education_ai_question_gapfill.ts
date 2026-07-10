// Constrained question-paper AI (Batch 8b) — bank-first gap-fill ONLY.
//
// The deterministic blueprint solver selects approved bank questions first.
// Whatever the bank cannot supply comes here as precise gaps (exact type /
// difficulty / marks / chapter). Claude is asked to author ONLY those gaps,
// strictly inside the given syllabus scope, and its output is treated as
// MODERATION CANDIDATES — tagged source='ai_candidate', review_status='pending'.
// Candidates never auto-publish; a teacher must approve each one.
//
// Safe-by-default (same contract as the Batch 8 surfaces): no key, refusal,
// bad JSON, transport error, or any per-item validation failure yields fewer
// (or zero) candidates — never a fabricated or malformed question. No student
// data is ever sent; the prompt carries class-level syllabus scope only.

import { type Governance, governedTextFor } from "../ai/model_gateway.ts";
import { computeQuestionFingerprint } from "./education_fingerprint.ts";
import type { BlueprintSlot } from "./education_blueprint_solver.ts";
import {
  EDU_QUESTION_TYPES,
  type EduProgramTrack,
  type EduQuestionType,
} from "./education_types.ts";

const GAPFILL_MAX_TOKENS = 1600;
const MAX_GAPS_PER_CALL = 20;

export interface GapFillScope {
  subjectName: string;
  className: string;
  programTrack: EduProgramTrack;
  examType: string;
  chapters: string[];
}

export interface AiQuestionCandidate {
  slotIndex: number;
  questionType: EduQuestionType;
  difficulty: string;
  marks: number;
  chapter: string;
  questionText: string;
  answerText: string;
  options: string[];
  fingerprint: string;
}

const SYSTEM_PROMPT = `
You are Akshara's exam-question author for an Indian school. You write ONLY the
specific questions you are asked for, strictly inside the given subject, class,
and chapter scope. Hard rules:
- Stay within the listed chapters. Never introduce out-of-syllabus content.
- Produce exactly one question per requested slot, honouring its questionType,
  marks, and difficulty.
- For "mcq": provide exactly 4 plausible options and set answerText to the full
  text of the single correct option.
- For non-mcq types: options must be an empty array; answerText is a correct,
  concise model answer / solution.
- Curriculum-accurate, original wording. No copyrighted passages. No diagrams
  that cannot be expressed in text (avoid 'diagram' content unless asked).
- No student names or personal data — this is generic class-level content.
- Output ONLY a JSON object: {"questions":[ ... ]}. Each element has keys:
  slotIndex (number, echo the slot's index), questionType (string), marks
  (number), difficulty (string), chapter (string), questionText (string),
  answerText (string), options (string[]). No prose around the JSON.
`.trim();

interface RawCandidate {
  slotIndex?: unknown;
  questionType?: unknown;
  marks?: unknown;
  difficulty?: unknown;
  chapter?: unknown;
  questionText?: unknown;
  answerText?: unknown;
  options?: unknown;
}

function parseQuestionsArray(text: string): RawCandidate[] | null {
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start === -1 || end === -1 || end <= start) return null;
  try {
    const obj = JSON.parse(text.slice(start, end + 1)) as { questions?: unknown };
    return Array.isArray(obj.questions) ? obj.questions as RawCandidate[] : null;
  } catch {
    return null;
  }
}

function asString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function asStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .filter((v): v is string => typeof v === "string" && v.trim().length > 0)
    .map((v) => v.trim());
}

/**
 * Validate one raw model question against the gap it must fill. Returns a clean
 * candidate or null (which drops it — the gap simply stays unfilled).
 */
function validateCandidate(
  raw: RawCandidate,
  gap: BlueprintSlot,
  scope: GapFillScope,
): AiQuestionCandidate | null {
  const questionType = asString(raw.questionType) as EduQuestionType;
  if (!EDU_QUESTION_TYPES.includes(questionType)) return null;
  // Must match the gap it was asked to fill — the bank-first contract.
  if (questionType !== gap.questionType) return null;
  if (typeof raw.marks === "number" && raw.marks !== gap.marks) return null;

  const questionText = asString(raw.questionText);
  const answerText = asString(raw.answerText);
  if (!questionText || !answerText) return null;

  let options = asStringArray(raw.options);
  if (questionType === "mcq") {
    if (options.length < 2) return null;
    options = options.slice(0, 6);
    // The correct answer must be present among the options.
    if (!options.some((o) => o.toLowerCase() === answerText.toLowerCase())) return null;
  } else {
    options = [];
  }

  return {
    slotIndex: gap.index,
    questionType,
    difficulty: gap.difficulty,
    marks: gap.marks,
    chapter: gap.chapter,
    questionText,
    answerText,
    options,
    fingerprint: computeQuestionFingerprint({
      subjectName: scope.subjectName,
      chapter: gap.chapter,
      questionType,
      questionText,
    }),
  };
}

function buildUserMessage(gaps: BlueprintSlot[], scope: GapFillScope): string {
  return [
    `Subject: ${scope.subjectName}`,
    `Class: ${scope.className}`,
    `Program track: ${scope.programTrack}`,
    `Exam type: ${scope.examType}`,
    `Allowed chapters (stay strictly within these): ${scope.chapters.join(", ") || "General"}`,
    "",
    "Author exactly one question for each of these slots:",
    JSON.stringify(
      gaps.map((g) => ({
        slotIndex: g.index,
        questionType: g.questionType,
        marks: g.marks,
        difficulty: g.difficulty,
        chapter: g.chapter,
      })),
    ),
  ].join("\n");
}

/**
 * Returns validated AI candidates for the supplied gaps. Empty array on any
 * failure mode (no key / refusal / bad JSON / transport error). At most
 * {@link MAX_GAPS_PER_CALL} gaps are sent in one call to keep the response
 * bounded; surplus gaps are simply left for a teacher to fill.
 */
export async function generateAiCandidatesForGaps(
  gaps: BlueprintSlot[],
  scope: GapFillScope,
  governance: Governance,
): Promise<AiQuestionCandidate[]> {
  if (gaps.length === 0) return [];

  const batch = gaps.slice(0, MAX_GAPS_PER_CALL);
  const byIndex = new Map(batch.map((g) => [g.index, g]));

  // Validate the model text into bank-safe candidates (hallucinated slots and
  // per-item validation failures are dropped, never fabricated).
  const buildCandidates = (text: string): AiQuestionCandidate[] => {
    const rawList = parseQuestionsArray(text);
    if (!rawList) return [];
    const seen = new Set<string>();
    const candidates: AiQuestionCandidate[] = [];
    for (const raw of rawList) {
      const slotIndex = typeof raw.slotIndex === "number" ? raw.slotIndex : NaN;
      const gap = byIndex.get(slotIndex);
      if (!gap) continue; // unknown / hallucinated slot → drop
      if (seen.has(String(slotIndex))) continue; // one candidate per slot
      const validated = validateCandidate(raw, gap, scope);
      if (!validated) continue;
      seen.add(String(slotIndex));
      candidates.push(validated);
    }
    return candidates;
  };

  const text = await governedTextFor(governance, "education_gapfill", {
    system: SYSTEM_PROMPT,
    messages: [{ role: "user", content: buildUserMessage(batch, scope) }],
    maxTokens: GAPFILL_MAX_TOKENS,
  });
  return text ? buildCandidates(text) : [];
}
