// Optional Claude narrative for an Advanced AI Predictions list.
//
// predictions_service.ts computes every NUMBER (risk scores, likelihoods,
// amounts) from real data. This step only turns the already-computed top items
// into a short, action-oriented narrative for a school leader. Numbers and names
// are passed through verbatim; the model is told never to invent them.
//
// Any failure (no key, refusal, empty/odd output, transport error) returns the
// deterministic baseline unchanged — the narrative is strictly additive and safe.

import { type Governance, governedTextFor } from "../ai/model_gateway.ts";
import { fenceUntrusted, UNTRUSTED_DATA_PREAMBLE } from "../ai/prompt_safety.ts";

const NARRATIVE_MAX_TOKENS = 500;

const SYSTEM_PROMPT = `
You are NIKSHA's predictions assistant for a school leader. You are given an
already-computed prediction summary whose numbers and names are final. Write a
short, action-oriented narrative (2 to 4 sentences). Strict rules:
- NEVER change, add, or invent any number (scores, likelihoods, ₹ amounts, counts).
- Only reference the names/items present in the provided summary.
- Be practical: say who to act on first and the single most useful next step.
- No medical, psychological, or behavioural diagnoses; no PII beyond the names given.
- Output ONLY the narrative prose. No headings, no JSON, no preamble.

${UNTRUSTED_DATA_PREAMBLE}
`.trim();

export interface PredictionsNarrativeContext {
  kind: "fee-default" | "admission-conversion" | "student-risk";
  total: number;
  high: number;
  topItems: { name: string; metric: string }[];
}

/** Returns an AI-written narrative, or the deterministic baseline on any failure. */
export async function narratePredictionsWithClaude(
  baseline: string,
  context: PredictionsNarrativeContext,
  governance: Governance,
): Promise<string> {
  // topItems carry user-authored names (students/leads) and the baseline
  // embeds them — fenced as data (P2-5 / AI-5). `kind` is a typed enum.
  const userMessage = [
    `Prediction type: ${context.kind}.`,
    `Counts (final): ${context.total} analysed, ${context.high} high-priority.`,
    "Top items (final — do not change names or metrics):",
    fenceUntrusted("Top items", context.topItems),
    "",
    fenceUntrusted(
      "Deterministic baseline to rewrite into a leader-facing narrative",
      baseline,
    ),
  ].join("\n");

  const text = await governedTextFor(governance, `predictions_${context.kind}`, {
    system: SYSTEM_PROMPT,
    messages: [{ role: "user", content: userMessage }],
    maxTokens: NARRATIVE_MAX_TOKENS,
    guard: { allowDerivedPercents: true },
  });
  const trimmed = (text ?? "").trim();
  return trimmed.length > 0 ? trimmed : baseline;
}
