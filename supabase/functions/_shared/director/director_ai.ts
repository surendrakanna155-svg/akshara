// Optional Claude refinement for the Director executive summary.
//
// buildExecutiveSummary (director_repository.ts) computes every NUMBER from real
// org-wide aggregates. This step only rewrites that one-paragraph brief into a
// warmer, board-ready narrative for a chain owner. Numbers are passed through
// verbatim; the model is told never to invent figures, and never to name a
// student or parent (school-level aggregates only).
//
// Any failure (no key, refusal, empty/odd output, transport error) returns the
// deterministic summary unchanged — refinement is strictly additive and safe.

import { type Governance, governedTextFor } from "../ai/model_gateway.ts";
import { fenceUntrusted, UNTRUSTED_DATA_PREAMBLE } from "../ai/prompt_safety.ts";

const REFINE_MAX_TOKENS = 600;

const SYSTEM_PROMPT = `
You are Akshara's executive assistant to a school-chain director (franchise owner).
You are given a one-paragraph portfolio brief whose numbers are already final.
Rewrite it into a concise, board-ready narrative. Strict rules:
- NEVER change, add, or invent any number (counts, percentages, ₹ amounts, school
  names). Use only the facts present in the provided brief.
- NEVER name or imply any individual student, parent, or staff member — this is a
  school-level portfolio summary only.
- Be direct and decision-oriented, suitable for a board meeting. 3 to 5 sentences.
- Output ONLY the narrative prose. No headings, no JSON, no preamble.

${UNTRUSTED_DATA_PREAMBLE}
`.trim();

export interface ExecutiveSummaryContext {
  focusArea: string;
  schoolCount: number;
  totalStudents: number;
  chainRevenueCr: number;
  marginPercent: number;
  enrolled: number;
  inquiries: number;
  conversionPercent: number;
  atRiskSchools: string[];
}

/**
 * Returns a board-ready narrative refined by Claude, or the deterministic
 * summary unchanged on any failure. The governed Model Gateway (timeout +
 * rate-limit + spend-cap + ai_call_log) is the only structural path to a live
 * model call — see model_gateway.ts.
 */
export async function refineExecutiveSummaryWithClaude(
  deterministicSummary: string,
  context: ExecutiveSummaryContext,
  governance: Governance,
): Promise<string> {
  // focusArea comes verbatim from the request body and school names are
  // user-authored — fence everything that is not our own trusted instruction
  // so embedded text can never be read as instructions (P2-5 / AI-5).
  const userMessage = [
    fenceUntrusted("Focus area", context.focusArea),
    "Portfolio facts (final — do not change them):",
    fenceUntrusted("Portfolio facts", {
      schools: context.schoolCount,
      totalStudents: context.totalStudents,
      chainRevenueCr: context.chainRevenueCr,
      netMarginPercent: context.marginPercent,
      enrolled: context.enrolled,
      enquiries: context.inquiries,
      conversionPercent: context.conversionPercent,
      schoolsNeedingAttention: context.atRiskSchools,
    }),
    "",
    fenceUntrusted("Deterministic brief to rewrite", deterministicSummary),
  ].join("\n");

  const text = await governedTextFor(governance, "director_summary", {
    system: SYSTEM_PROMPT,
    messages: [{ role: "user", content: userMessage }],
    maxTokens: REFINE_MAX_TOKENS,
    // Output-side twin (F3): a reply that echoes injection or fabricates
    // numbers is discarded — the deterministic summary is served instead.
    guard: true,
  });
  const trimmed = (text ?? "").trim();
  return trimmed.length > 0 ? trimmed : deterministicSummary;
}
