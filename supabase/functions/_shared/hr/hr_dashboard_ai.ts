// Optional Claude-generated insight for the HR dashboard (MJ-H17 / HR-5).
//
// hr_read_repository.ts computes every NUMBER from the real HR tables for this
// school (employee counts, present-today, on-leave, open positions, pending
// approvals). This step turns those final facts into a short, decision-oriented
// HR insight for a school admin. Numbers are passed through verbatim; the model
// is told never to invent figures or name a staff member not present in the
// facts.
//
// Any failure (no key, refusal, empty/odd output, transport error) returns the
// deterministic insight unchanged — the AI is strictly additive and safe. The
// cert environment may have no key configured, so the deterministic fallback
// (buildDeterministicInsight) must always produce a sensible, honest insight.

import { type Governance, governedTextFor } from "../ai/model_gateway.ts";
import { fenceUntrusted, UNTRUSTED_DATA_PREAMBLE } from "../ai/prompt_safety.ts";
import { type DashboardKpiFacts } from "./hr_read_repository.ts";

const INSIGHT_MAX_TOKENS = 400;

const SYSTEM_PROMPT = `
You are Akshara's HR assistant for a single school.
You are given the school's already-computed HR facts; every number is final.
Write one short, decision-oriented insight for the school's HR admin. Strict rules:
- NEVER change, add, or invent any number (counts, percentages). Use only the
  facts provided.
- NEVER name or invent a staff member; you are given aggregate counts only.
- If a department is the largest team, you may mention it by name with its count.
- Be specific and actionable — point at attendance, pending leave, or hiring when
  the facts warrant it. 1 to 3 sentences.
- Output ONLY the insight prose. No headings, no JSON, no preamble.

${UNTRUSTED_DATA_PREAMBLE}
`.trim();

/**
 * Returns a real-AI HR insight grounded in the computed facts, or the supplied
 * deterministic fallback unchanged on any failure (including a missing key).
 */
export async function generateHrInsightWithClaude(
  facts: DashboardKpiFacts,
  deterministic: string,
  governance: Governance,
): Promise<string> {
  // Department names are user-authored and the deterministic insight embeds
  // them — fenced as data so embedded text can never be read as instructions
  // (P2-5 / AI-5).
  const userMessage = [
    "School HR facts (final — do not change them):",
    fenceUntrusted("HR facts", {
      totalEmployees: facts.totalEmployees,
      activeEmployees: facts.activeEmployees,
      presentToday: facts.presentToday,
      onLeaveToday: facts.onLeaveToday,
      openPositions: facts.openPositions,
      pendingLeaveApprovals: facts.pendingLeaveCount,
      largestDepartment: facts.topDepartment || null,
      largestDepartmentCount: facts.topDepartmentCount,
    }),
    "",
    fenceUntrusted("Deterministic insight to improve (keep its numbers)", deterministic),
  ].join("\n");

  const text = await governedTextFor(governance, "hr_dashboard", {
    system: SYSTEM_PROMPT,
    messages: [{ role: "user", content: userMessage }],
    maxTokens: INSIGHT_MAX_TOKENS,
    guard: { allowDerivedPercents: true },
  });
  const trimmed = (text ?? "").trim();
  return trimmed.length > 0 ? trimmed : deterministic;
}
