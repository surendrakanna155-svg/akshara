# Akshara Adaptive AI — Complete Platform Design (Suite Index)

**Status:** 🟢 Design-complete (no code) · **Author:** Fable · **Date:** 2026-07-03
**Executes as:** Master Roadmap **Phase 3** (`P3-AI-1` → `P3-AI-2`) per [`../../roadmap/FINAL_EXECUTION_MASTER_ROADMAP.md`](../../roadmap/FINAL_EXECUTION_MASTER_ROADMAP.md), by Opus 4.8 under [`../../roadmap/AUTONOMOUS_EXECUTION_PLAN.md`](../../roadmap/AUTONOMOUS_EXECUTION_PLAN.md) (one wave → one `/eos` PASS → one commit).
**Strategy anchor:** [`../../strategy/ADAPTIVE_AI_MASTER_BLUEPRINT.md`](../../strategy/ADAPTIVE_AI_MASTER_BLUEPRINT.md) — this suite is that blueprint's **implementation-ready design layer**. Ground truth: [`../../audits/06_AI_ARCHITECTURE_AUDIT.md`](../../audits/06_AI_ARCHITECTURE_AUDIT.md).

> **Philosophy (one paragraph).** Akshara's Adaptive AI is **deterministic-first, trustworthy,
> low-cost, event-driven, and adaptive per school**. Numbers, lists, priorities, and thresholds are
> always computed from the tenant database; templates and rules carry all routine communication; a
> model is consulted only for genuinely novel language work — and its answer is cached, shared, and
> reused. Target: **≥90% of AI-surface impressions cost zero model calls**, while every persona's
> day feels proactively, personally intelligent. The moat is the architecture, not the API bill.

---

## The documents (read in order)

| # | Document | What it defines |
|---|---|---|
| **01** | [`01_AI_DECISION_FRAMEWORK.md`](01_AI_DECISION_FRAMEWORK.md) | **The law of the suite.** Serving Ladder T0–T3, the placement test, where LLMs earn their cost (and never do), patterns P1–P12, the recommendation rubric, hard governance rails. |
| **02** | [`02_CONTEXT_ENGINE_DESIGN.md`](02_CONTEXT_ENGINE_DESIGN.md) | The Context Engine — eleven context dimensions (school, academic, role, permissions, language, activity, preferences, calendar, deadlines, alerts, history), surface manifests, cache-key minting, injection hardening (AI-5). |
| **03** | [`03_MEMORY_AND_CACHING_STRATEGY.md`](03_MEMORY_AND_CACHING_STRATEGY.md) | The cost moat — four memory stores (School Profile · Persona · Interaction · Fact/Signal), learned per-school defaults, response/semantic/shared/pre-warmed caches, rate-limit + spend-cap + telemetry (AI-1/2/3/4), economics model (~99% call reduction). |
| **04** | [`04_EVENT_INTELLIGENCE_AND_PRIORITY_ENGINE.md`](04_EVENT_INTELLIGENCE_AND_PRIORITY_ENGINE.md) | The proactive half — Signal Refinery consumer on `domain_events` (157 types, currently consumer-less), explainable Priority Engine, Recommendation Engine with one-click pre-staged actions, bounded adaptive dashboard reordering, T0 notification rules & digests, predictive pre-staging. |
| **05** | [`05_MODULE_AI_DESIGN_ACADEMIC.md`](05_MODULE_AI_DESIGN_ACADEMIC.md) | Module designs: **Admissions · SIS · Attendance · Exams · Homework · Communication** — per module: surface map (tier + pattern), the eleven design dimensions, rubric-scored recommendations. |
| **06** | [`06_MODULE_AI_DESIGN_OPERATIONS.md`](06_MODULE_AI_DESIGN_OPERATIONS.md) | Module designs: **Finance · HR · Library · Transport · Inventory** — same treatment; Fee-Recovery CRM (FIN-R1–R5) as the flagship deterministic worklist. |
| **07** | [`07_PERSONA_AI_DESIGN.md`](07_PERSONA_AI_DESIGN.md) | Persona routers: **Teacher · Parent · Student · Principal · Director** — the adaptive day, copilot tiering (deterministic intents → caches → rare model), memory, dashboards, proactive cadence; rollout order. |
| **08** | [`08_NOVEL_ADAPTIVE_AI_IDEAS.md`](08_NOVEL_ADAPTIVE_AI_IDEAS.md) | Twelve first-in-market ideas (N1–N12) — self-calibrating thresholds, the School's Own Answer Book, family intelligence, promise graph, timetable self-healing, cost-honest AI, … 10 of 12 need ~zero model calls. |
| **09** | [`09_IMPLEMENTATION_WAVES_AND_METRICS.md`](09_IMPLEMENTATION_WAVES_AND_METRICS.md) | **The execution contract.** W1 (P3-AI-1 foundation: gateway hardening, memory+cache, context engine, Signal Refinery) → W2 (P3-AI-2: engines + persona rollouts) → W3 (post-GA), with done-when, evidence, EOS gates, metrics, standing test assets, AI-1…AI-6 traceability. |

---

## How to execute (for the Opus 4.8 session)

1. **Preconditions first** — doc 09 §0 (Phase 0, XCT-1/2, HWK-1, COM-1, live AI key). Verify, don't build here.
2. **W1 before any W2 item** (roadmap hard gate). Sub-waves W1.1→W1.5, each: implement → validate (doc 09 standing test assets) → `/eos` AI scope → PASS → commit.
3. **W2 needs the owner's timing decision** (👤 P3-AI-2 in the roadmap register). Then W2.0/W2.1 platform engines → persona rollouts Teacher → Parent → Principal → Director → Student, module surfaces shipping inside the persona wave that consumes them.
4. **Never violate the rails** (doc 01 §6): no AI on writes/money/approvals; deterministic comms translation; RLS-scoped memory/cache; every model call logged, capped, timeout-fallbacked; explainability everywhere.
5. **Measure the moat** — the EOS AI gate checks the zero-call ratio (≥90%), cache hit-rates, spend vs cap, latency, adaptivity evidence, and safety suites (doc 09 §Metrics).

## Frozen decisions this suite respects (do not re-litigate)

English-first + deterministic parent-comms catalog · identity architecture (PSID/UUID) freeze ·
attendance-auth design · maker-checker governance (FIN-D4, inventory) · O1–O10 scope decisions ·
North Star ("easiest mobile-first school ERP") · PRODUCT_ENHANCEMENT_BACKLOG rev 5 as the frozen
product-scope source (this suite layers intelligence on it; it re-scopes nothing).

---

*One standard, one gate: designs here; the Constitution + `/eos` decide "done."*
