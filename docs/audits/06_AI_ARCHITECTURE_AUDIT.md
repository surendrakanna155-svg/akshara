# Akshara ERP — AI Architecture Audit

**Auditor:** Fable (independent) · **Date:** 2026-07-03 · **HEAD:** `68f15cb`
**Scope:** all AI surfaces, the Claude integration, prompt safety, cost/caching, comms-localization determinism, the "Adaptive AI" vision.
**Confidence:** High.

---

## 1. Executive summary

1. **The Claude integration is REAL, single-sourced, and well-designed.** `_shared/ai/anthropic_client.ts` makes a real HTTPS call to `api.anthropic.com/v1/messages`, default model `claude-opus-4-8`, key from `ANTHROPIC_API_KEY` or an encrypted Control-Center vault (DB-first). It also supports OpenRouter via one env switch. No other LLM provider is wired.
2. **The architecture is "additive AI over a deterministic spine" — the right pattern for an ERP.** Every AI surface computes all numbers/facts deterministically from real DB data first, then optionally asks Claude to *rewrite the prose*; the model is forbidden (in the system prompt) from inventing numbers, the output is re-validated, and on any failure/timeout/no-key the deterministic baseline is returned. AI is never on a finance/exam-marks/admissions **write** path.
3. **Half the "AI" surfaces aren't AI.** The entire `_shared/intelligence/` suite (exam/homework/student-risk/success/teacher-effectiveness) is **deterministic SQL aggregation** — "Intelligence" is branding. ~9 surfaces make real model calls (copilot, predictions narrative, parent insights, director summary, HR insight, question gap-fill, school builder, org builder, marketing captions).
4. **Comms localization is correctly deterministic (NO LLM)** — `parent_comms_localization.ts` is a static catalog + placeholder substitution. This satisfies the frozen governance requirement.
5. **Three real pilot-grade gaps: no caching, no rate-limit/spend-cap, no request timeout — on any AI endpoint.** The owner's "Adaptive AI (minimize API calls via reuse+caching)" vision has **zero existing infrastructure to build on**.
6. **A silent-degradation trap:** with no key configured, *every* AI surface returns deterministic output with no error. If the pilot VPS lacks `ANTHROPIC_API_KEY`, "AI" is silently 100% deterministic and no one is told.

---

## 2. AI surface matrix

| Surface | Real Claude call? | Fallback | Cached? | Rate-limited? |
|---|:--:|---|:--:|:--:|
| Copilot (finance/admissions/SIS/teacher/principal/parent-guidance) | ✅ | deterministic stub reply | ❌ | ❌ |
| Advanced Predictions narrative | ✅ | deterministic baseline | ❌ | ❌ |
| Parent Insights enrichment (in parent's language) | ✅ | unchanged snapshot | ❌ | ❌ |
| Director executive summary | ✅ | deterministic summary | ❌ | ❌ |
| HR dashboard insight | ✅ | deterministic | ❌ | ❌ |
| Question-paper AI gap-fill (moderation-gated, never auto-published) | ✅ | `[]` (teacher fills) | ❌ | ❌ |
| AI School Builder blueprint refine | ✅ | deterministic baseline (re-validated) | ❌ | ❌ |
| Organization Builder recommendations | ✅ | per-vertical baseline | ❌ | ❌ |
| Marketing/publisher captions | ✅ | deterministic assets | ❌ | ❌ |
| `intelligence/*` suite (exam/homework/risk/success/effectiveness) | ❌ deterministic SQL | n/a | in-mem widget cache | n/a |
| Parent-comms localization | ❌ deterministic catalog | English fallback | n/a | n/a |

---

## 3. Findings

| ID | Sev | Finding | Evidence | Recommendation |
|---|---|---|---|---|
| AI-1 | **P1** | No rate-limit / spend-cap on any AI endpoint (only OTP is rate-limited) | `otp_rate_limit.ts` is the only limiter; no throttle on AI routes | Add per-user/per-org token-bucket + a monthly spend cap before pilot. A looping client or abusive user can run unbounded Claude spend. |
| AI-2 | **P1** | No AI-response caching anywhere — the "Adaptive AI minimize-API-calls" vision starts from zero | no cache table; copilot re-sends full history + context every turn | Add a response/semantic cache keyed on (surface, inputs-hash, school, language) with TTL. Foundational for the Adaptive-AI wave. |
| AI-3 | **P1** | No request timeout / AbortController on the provider `fetch` | `anthropic_client.ts:134,185` | Add a per-request deadline (e.g. 15–20s) → deterministic fallback on timeout. A hung provider connection otherwise stalls the isolate. |
| AI-4 | **P1** | Silent degradation to deterministic when no key is configured — no signal to operator or user | `hr_dashboard_ai.ts:43` pattern (`if (!apiKey) return deterministic`) across all surfaces | Emit a startup/health signal when no AI key is present; surface an "AI unavailable" state rather than silently substituting. Confirm the pilot VPS has `ANTHROPIC_API_KEY`. |
| AI-5 | **P2** | Prompt-injection surface in the copilot (user text + DB-derived names concatenated un-delimited into the prompt) | `copilot_prompt_orchestrator.ts:70-80`; `copilot_handlers.ts:285` | Delimit/label untrusted context; add an output-side guard. **Low blast radius today** (copilot is read-only, no tools/function-calling, RBAC-scoped context) — can manipulate generated text but cannot write or exceed RBAC scope. |
| AI-6 | **P3** | "Intelligence" naming implies AI where the suite is deterministic SQL | `_shared/intelligence/*` | Consider renaming to "Analytics" to avoid overstating AI capability to buyers. |

---

## 4. Safety verdict

- **SQL injection:** not present — all context loaders use parameterized queries.
- **AI on write paths:** none — AI is advisory-only; deterministic fallback everywhere; refusals handled explicitly.
- **Comms translation LLM ban:** honoured — deterministic catalog, zero AI imports (`parent_comms_localization.ts`). (Parent-Insights AI *generates* natively in-language, which is the allowed split — generation ≠ translation.)
- **Prompt injection:** real but low blast radius (AI-5).

## 5. Genuine strengths

- Determinism-first design with validated baselines + try/catch fallback is exactly right for an ERP — it means a bad/absent model never corrupts data or fabricates numbers.
- Single shared client, provider-swappable, DB-first key resolution with encrypted vault.
- Exam AI is moderation-gated and never auto-published — correct governance.
- Comms localization is deterministic and compliant.

## 6. Strategic note on the "Adaptive AI" wave

The owner's Adaptive-AI vision (adapt per school; minimize API calls via reuse + caching; proactive role-based dashboards) is **buildable but greenfield on the cost/caching side** (AI-2). Recommended prerequisites before that wave: (1) the caching layer, (2) rate-limit + spend-cap, (3) request timeouts, (4) a per-school AI-config surface (the vault already exists). Sequence Adaptive-AI *after* these foundations, not before.

## 7. Unknowns

- Whether the live VPS actually has an AI key configured (AI-4) — determines whether AI is exercised at all in the pilot.
- Real per-call latency/cost distribution (no telemetry/caching to measure it today).
