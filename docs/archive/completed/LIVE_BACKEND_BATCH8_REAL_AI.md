# Live Backend — Batch 8: Real AI (Claude)

**Goal:** turn Akshara's AI surfaces from canned stubs into real, live AI, using
**Claude (Anthropic)** — owner's chosen provider (2026-06-24). Safe-by-default:
with no API key the app keeps its existing stub/deterministic behaviour, so
nothing breaks before the key is provisioned and nothing is ever fabricated.

## What shipped

### Shared Claude client — `supabase/functions/_shared/ai/anthropic_client.ts`
One reusable module every AI surface calls, so request shape, refusal handling,
and model/key config live in one place. Raw `fetch` against
`POST https://api.anthropic.com/v1/messages` (Deno edge function, no SDK).
- `callClaude({system, messages, maxTokens, model, apiKey})` → `{text, model, refused, usage}`.
- Top-level `system` + `messages[]` (Claude shape, not OpenAI's system-as-message).
- **No `temperature`/`top_p`/`top_k`** — those 400 on Opus 4.8 / 4.7 / Fable.
- `stop_reason: "refusal"` surfaces as `refused: true` (no throw); non-2xx throws.
- `anthropicApiKey()` (trimmed, undefined when unset) + `claudeModel()`
  (`ANTHROPIC_MODEL`, default `claude-opus-4-8`).

### Copilot → live Claude
`copilot_openai_client.ts` → renamed `copilot_llm_client.ts`, now backed by the
shared client. `generateCopilotResponse` keeps its signature and its
deterministic read-only **stub fallback** when no key is set. Handler passes
`anthropicApiKey()` (was `OPENAI_API_KEY`). Refusals return a safe read-only
message. All existing context-engine system prompts, RBAC, session storage, and
audit events are unchanged.

### Parent insights → live Claude (enrichment)
New `parent_insights_ai.ts`. The deterministic snapshot still computes **every
number** (attendance/homework/marks) from real data; Claude only **rewrites the
parent-facing prose** — warm, plain, and **in the parent's chosen language**
(Telugu etc.). Strictly additive: no key / refusal / bad JSON / transport error
→ the deterministic snapshot is returned unchanged. The model is instructed
never to change or invent numbers. Wired into `handleGenerateParentInsights`
before the DB insert, so the stored snapshot is the enriched one.

### Config — `deploy/akshara-vps/.env.akshara.example`
Added `ANTHROPIC_API_KEY` (live key, `.env.akshara` chmod 600 only, never git)
and optional `ANTHROPIC_MODEL` (default opus-4-8; sonnet/haiku for cheaper
high-volume chat).

## Certification
- `deno check` clean on all changed files **and** `api/index.ts` end-to-end.
- New tests: `anthropic_client_test.ts` (6) + `parent_insights_ai_test.ts` (4) —
  fetch stubbed, network-free: assert request shape (no temperature sent),
  text/refusal/error parsing, no-key passthrough, junk/refusal fallback.
- Existing copilot + parent_insights suites green (no regressions from rename).

## OPEN — owner action required to go live
1. **Provision `ANTHROPIC_API_KEY`** in `/opt/akshara/.env.akshara` (chmod 600)
   and restart the edge container. Until then AI runs in safe stub/deterministic
   mode. This is the one blocker to live AI; everything else is shipped.
2. **(Optional) `ANTHROPIC_MODEL`** if cost-tuning high-volume chat.

## DEFERRED — Question-paper AI (Batch 8b)
Owner asked for "all three" AI surfaces, but the **Question Intelligence
Platform has no question-bank schema or data yet** — only a plan
(`docs/plans/QUESTION_PAPER_FOUNDATION_MASTER_PLAN.md`), which itself mandates
**bank-first, constrained AI gap-fill last**. Building "real AI" there now would
be a stub with nothing to ground it (fails the production bar). The shared
Claude client is ready for it; QP-AI is gated on first building the bank +
blueprint engine. Tracked as Batch 8b.
