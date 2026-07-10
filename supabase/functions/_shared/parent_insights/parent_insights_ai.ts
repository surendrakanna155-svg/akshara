// Optional Claude enrichment for parent insight snapshots.
//
// The deterministic snapshot (parent_insights_service.ts) computes every NUMBER
// — attendance, homework, marks — from real data. This step only rewrites the
// parent-facing PROSE: warmer, plainer, and in the parent's chosen language.
// Numbers are passed through verbatim; the model is told never to invent them.
//
// Any failure (no key, refusal, bad JSON, transport error) returns the original
// deterministic snapshot unchanged — enrichment is strictly additive and safe.

import { type AiProvider, callClaude, claudeModel } from "../ai/anthropic_client.ts";
import { type Governance, governedTextFor } from "../ai/model_gateway.ts";
import type { ParentInsightSnapshot } from "./parent_insights_service.ts";

const ENRICH_MAX_TOKENS = 900;

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
  apiKey?: string,
  opts?: { provider?: AiProvider; model?: string },
  governance?: Governance,
): Promise<ParentInsightSnapshot> {
  const userMessage = [
    `Rewrite this student progress snapshot in language: ${snapshot.language}.`,
    `Period: ${snapshot.period}.`,
    "Snapshot (numbers are final — do not change them):",
    JSON.stringify({
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

  if (governance) {
    const text = await governedTextFor(governance, "parent_insights", {
      system: SYSTEM_PROMPT,
      messages: [{ role: "user", content: userMessage }],
      maxTokens: ENRICH_MAX_TOKENS,
    });
    return text ? applyEnrichment(text) : snapshot;
  }

  if (!apiKey) return snapshot;

  try {
    const result = await callClaude({
      apiKey,
      provider: opts?.provider,
      model: opts?.model ?? claudeModel(),
      maxTokens: ENRICH_MAX_TOKENS,
      system: SYSTEM_PROMPT,
      messages: [{ role: "user", content: userMessage }],
    });
    if (result.refused) return snapshot;
    return applyEnrichment(result.text);
  } catch {
    return snapshot;
  }
}
