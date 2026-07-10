// Organization Builder — interview recommendations.
//
// Each interview step yields one recommendation. A deterministic baseline always
// produces a sensible, PII-free suggestion (so the feature works with no AI key);
// Claude then optionally sharpens the wording for the vertical and the answers so
// far. Any failure (no key, refusal, bad JSON, transport error) returns the
// deterministic baseline unchanged — refinement is strictly additive and safe.

import { type Governance, governedTextFor } from "../ai/model_gateway.ts";
import type { InterviewRecommendation } from "./organization_builder_repository.ts";

const RECOMMEND_MAX_TOKENS = 320;

const SYSTEM_PROMPT = `
You are Akshara's Organization Builder assistant. A founder is configuring a new
organization through a short interview. Given the vertical and the answers so far,
suggest ONE concrete, actionable configuration recommendation.

Strict rules:
- Output ONLY a JSON object: {"title": string, "detail": string}.
- "title" is a short label (≤ 6 words). "detail" is one concise sentence.
- Recommend a module, role, workflow, or setting appropriate to the vertical.
- Never include names, phone numbers, addresses, or any personal data.
- Do not invent numbers that were not provided.
`.trim();

const STEP_FOCUS: Record<number, string> = {
  0: "the organization identity and the right starter modules",
  1: "scale and capacity planning",
  2: "which modules to enable",
  3: "key automated workflows",
  4: "notification channels (WhatsApp, SMS, email)",
  5: "payment and billing configuration",
  6: "a final readiness check before provisioning",
};

/** Deterministic, always-valid recommendation for a step + vertical. */
export function baselineRecommendation(
  packId: string,
  packType: string,
  stepIndex: number,
): InterviewRecommendation {
  const byVertical: Record<string, { title: string; detail: string }> = {
    salon: {
      title: "Enable loyalty module",
      detail: "Salons with repeat clients benefit from a cross-branch loyalty programme.",
    },
    hospital: {
      title: "Insurance claim workflow",
      detail: "Add an insurance-claim workflow triggered when billing is finalized.",
    },
    restaurant: {
      title: "Kitchen ticket routing",
      detail: "Route placed orders to kitchen stations to keep ticket times low.",
    },
    school: {
      title: "Fee reminder workflow",
      detail: "Automate fee reminders three days before each due date to lift collections.",
    },
  };
  const base = byVertical[packType] ?? byVertical.school;
  return {
    id: `rec_${packId}_${stepIndex}`,
    title: base.title,
    detail: base.detail,
    confidence: 0.8,
  };
}

interface ParsedRec {
  title?: unknown;
  detail?: unknown;
}

function parseJsonObject(text: string): ParsedRec | null {
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start === -1 || end === -1 || end <= start) return null;
  try {
    return JSON.parse(text.slice(start, end + 1)) as ParsedRec;
  } catch {
    return null;
  }
}

export interface RecommendInput {
  packId: string;
  packType: string;
  packName: string;
  organizationName: string;
  stepIndex: number;
  answers: Record<string, string>;
}

/**
 * Returns one recommendation for the step, refined by Claude when a key is
 * configured, else the deterministic baseline. Always returns a valid rec.
 */
export async function recommendForStep(
  input: RecommendInput,
  governance: Governance,
): Promise<InterviewRecommendation> {
  const baseline = baselineRecommendation(input.packId, input.packType, input.stepIndex);

  const focus = STEP_FOCUS[input.stepIndex] ?? "the configuration so far";
  const userMessage = [
    `Vertical: ${input.packName} (${input.packType}).`,
    `Interview focus for this step: ${focus}.`,
    "Answers so far (no PII — generic configuration values only):",
    JSON.stringify(input.answers),
    "Return the recommendation JSON now.",
  ].join("\n");

  const applyRecommendation = (text: string): InterviewRecommendation => {
    const parsed = parseJsonObject(text);
    if (!parsed) return baseline;
    const title = typeof parsed.title === "string" ? parsed.title.trim() : "";
    const detail = typeof parsed.detail === "string" ? parsed.detail.trim() : "";
    if (!title || !detail) return baseline;
    return { id: baseline.id, title: title.slice(0, 80), detail: detail.slice(0, 280), confidence: 0.82 };
  };

  const text = await governedTextFor(governance, "org_builder", {
    system: SYSTEM_PROMPT,
    messages: [{ role: "user", content: userMessage }],
    maxTokens: RECOMMEND_MAX_TOKENS,
  });
  return text ? applyRecommendation(text) : baseline;
}
