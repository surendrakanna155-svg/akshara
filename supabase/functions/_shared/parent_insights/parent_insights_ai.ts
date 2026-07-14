// Optional Claude enrichment for parent insight snapshots.
//
// The deterministic snapshot (parent_insights_service.ts) computes every NUMBER
// — attendance, homework, marks — from real data. This step only rewrites the
// parent-facing PROSE: warmer, plainer, and in the parent's chosen language.
// Numbers are passed through verbatim; the model is told never to invent them.
//
// Any failure (no key, refusal, bad JSON, transport error) returns the original
// deterministic snapshot unchanged — enrichment is strictly additive and safe.

import { type Governance, governedTextFor } from "../ai/model_gateway.ts";
import { fenceUntrusted, UNTRUSTED_DATA_PREAMBLE } from "../ai/prompt_safety.ts";
import type { ParentInsightSnapshot } from "./parent_insights_service.ts";

const ENRICH_MAX_TOKENS = 900;

/** The languages parent insights may be rendered in (full-name form, matching
 * parent_language_preferences). Anything else — the request body and the
 * stored preference are both free text — normalizes to English so no
 * uncontrolled string can reach the prompt as an instruction (P2-5). */
export const INSIGHT_LANGUAGES: readonly string[] = [
  "english",
  "telugu",
  "hindi",
  "tamil",
  "kannada",
  "malayalam",
  "urdu",
] as const;

export function normalizeInsightLanguage(raw: string | null | undefined): string {
  const v = (raw ?? "").trim().toLowerCase();
  return INSIGHT_LANGUAGES.includes(v) ? v : "english";
}

const SYSTEM_PROMPT = `
You are Akshara's parent-communication assistant for a school.
You rewrite an already-computed student progress snapshot so a parent can read
it easily. Strict rules:
- NEVER change, add, or invent any number (percentages, marks, counts). Use only
  the numbers present in the provided snapshot.
- NEVER invent attendance, fees, balances, or events not in the snapshot.
- Write warmly, simply, and respectfully — for a parent, not an educator.
- Write everything in the requested language.
- No medical, psychological, or behavioural diagnoses.
- Output ONLY a JSON object, no prose around it, with exactly these keys:
  progressSummary (string), strengths (string[]), weaknesses (string[]),
  attendanceInsights (string[]), homeworkInsights (string[]),
  improvementSuggestions (string[]), teacherRemarksSummary (string).
- Keep each list to at most 3 short items.

${UNTRUSTED_DATA_PREAMBLE}
`.trim();

interface EnrichedFields {
  progressSummary?: unknown;
  strengths?: unknown;
  weaknesses?: unknown;
  attendanceInsights?: unknown;
  homeworkInsights?: unknown;
  improvementSuggestions?: unknown;
  teacherRemarksSummary?: unknown;
}

function asStringArray(value: unknown, fallback: string[]): string[] {
  if (!Array.isArray(value)) return fallback;
  const items = value
    .filter((v): v is string => typeof v === "string" && v.trim().length > 0)
    .map((v) => v.trim())
    .slice(0, 3);
  return items.length > 0 ? items : fallback;
}

function asString(value: unknown, fallback: string): string {
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : fallback;
}

/** Extract the first JSON object from a model reply (tolerant of stray text). */
function parseJsonObject(text: string): EnrichedFields | null {
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start === -1 || end === -1 || end <= start) return null;
  try {
    return JSON.parse(text.slice(start, end + 1)) as EnrichedFields;
  } catch {
    return null;
  }
}

/**
 * Returns a snapshot with parent-facing prose rewritten by Claude in the
 * snapshot's language. Returns the input unchanged on any failure.
 */
export async function enrichParentInsightWithClaude(
  snapshot: ParentInsightSnapshot,
  governance: Governance,
): Promise<ParentInsightSnapshot> {
  // The language line is an INSTRUCTION, so it must never carry free text —
  // normalize to the fixed catalog. The snapshot carries teacher-authored
  // remarks and name-bearing prose → fenced as data (P2-5 / AI-5).
  const userMessage = [
    `Rewrite this student progress snapshot in language: ${
      normalizeInsightLanguage(snapshot.language)
    }.`,
    `Period: ${snapshot.period}.`,
    "Snapshot (numbers are final — do not change them):",
    fenceUntrusted("Snapshot", {
      progressSummary: snapshot.progressSummary,
      strengths: snapshot.strengths,
      weaknesses: snapshot.weaknesses,
      attendanceInsights: snapshot.attendanceInsights,
      homeworkInsights: snapshot.homeworkInsights,
      improvementSuggestions: snapshot.improvementSuggestions,
      teacherRemarksSummary: snapshot.teacherRemarksSummary,
    }),
  ].join("\n");

  // Parse the model text and overlay only the prose fields (numbers untouched);
  // any parse failure returns the deterministic snapshot unchanged.
  const applyEnrichment = (text: string): ParentInsightSnapshot => {
    const parsed = parseJsonObject(text);
    if (!parsed) return snapshot;
    return {
      ...snapshot,
      progressSummary: asString(parsed.progressSummary, snapshot.progressSummary),
      strengths: asStringArray(parsed.strengths, snapshot.strengths),
      weaknesses: asStringArray(parsed.weaknesses, snapshot.weaknesses),
      attendanceInsights: asStringArray(parsed.attendanceInsights, snapshot.attendanceInsights),
      homeworkInsights: asStringArray(parsed.homeworkInsights, snapshot.homeworkInsights),
      improvementSuggestions: asStringArray(
        parsed.improvementSuggestions,
        snapshot.improvementSuggestions,
      ),
      teacherRemarksSummary: asString(
        parsed.teacherRemarksSummary,
        snapshot.teacherRemarksSummary,
      ),
    };
  };

  const text = await governedTextFor(governance, "parent_insights", {
    system: SYSTEM_PROMPT,
    messages: [{ role: "user", content: userMessage }],
    maxTokens: ENRICH_MAX_TOKENS,
    // RT-4-1: enforce the determinism-first number rail on this parent-facing
    // surface. `guard: true` discards any model reply that introduces a currency
    // or percentage NOT present verbatim in the injected snapshot (the userMessage
    // carries the real marks/attendance/homework %), so a disobeyed "never change
    // numbers" instruction can never serve a fabricated figure to a parent — the
    // reply is dropped and the accurate deterministic snapshot stands. Strict (no
    // allowDerivedPercents) is correct here: the model is only restating, never
    // deriving, and a false-drop simply falls back to the correct numbers.
    guard: true,
  });
  return text ? applyEnrichment(text) : snapshot;
}
