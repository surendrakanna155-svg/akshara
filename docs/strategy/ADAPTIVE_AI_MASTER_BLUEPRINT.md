# Akshara ERP — Adaptive AI Master Blueprint

**Status:** Strategy / design-only (no code) · **Author:** Fable · **Date:** 2026-07-03
**Grounded in:** the Fable Final Audit (`docs/audits/06_AI_ARCHITECTURE_AUDIT.md`, `00`, `11`) and the owner's Adaptive-AI vision. **Source of truth = the audit reports** (not a fresh code read).
**Maps to:** the single authoritative roadmap **Phase 3** (`docs/roadmap/FINAL_EXECUTION_MASTER_ROADMAP.md` → P3-AI-1 foundation, P3-AI-2 adaptive wave).
**Implementation-ready design layer:** [`../design/adaptive-ai/00_ADAPTIVE_AI_DESIGN_INDEX.md`](../design/adaptive-ai/00_ADAPTIVE_AI_DESIGN_INDEX.md) (suite 00–09, 2026-07-03) — module/persona designs, Context Engine, memory/caching, event/priority engines, waves + EOS criteria. Execute Phase 3 from that suite; this blueprint remains the strategic anchor.

> **Thesis.** Akshara's biggest long-term differentiator is **not "an AI feature" — it is an AI that
> quietly adapts the whole ERP to each school**: its roles, language, board, size, branding, history and
> daily rhythm. The audit confirmed the *foundation is already the right one* — a **determinism-first
> spine** (numbers/facts from the DB; the model only phrases them; validated; safe fallback) with a real
> provider-swappable client. What is missing is the **adaptive + economic layer**: memory, a context
> engine, caching, event-driven updates, and per-persona intelligence. This blueprint designs that layer
> so Akshara delivers "a school-specific AI" at **near-zero marginal API cost**.

---

## 1. Design principles (non-negotiable)

1. **Determinism-first, AI-second.** Every number, status, list, and total is computed deterministically from the tenant DB. The model **rephrases, prioritizes, and explains** — it never invents facts. (Preserves the audit's confirmed strength; keeps AI off every write/money path.)
2. **Adapt, don't rebuild.** The same codebase serves every school; adaptation is **data + config + cache**, never a fork. (Honors the multi-tenant RLS model.)
3. **API-minimal by architecture.** The default answer is served from **deterministic compute + cache**; a live model call is the *exception*, triggered only when novelty/uncertainty warrants it. Target: **<10% of AI surface impressions cause a model call.**
4. **Per-tenant isolation of intelligence.** Memory, cache, embeddings, and context are **school-scoped** (RLS-enforced). No cross-tenant leakage of prompts, outputs, or learned patterns.
5. **Safe-by-construction.** Read-only AI, no tool/function-calling on write paths, RBAC-scoped context, delimited untrusted input, output validation, request timeout, spend cap. (Closes audit AI-1/2/3/5.)
6. **Explainable + auditable.** Every AI surface can show "why" (the deterministic evidence behind it); every model call is logged (surface, inputs-hash, tokens, cost, cache-hit).

---

## 2. Reference architecture (layers)

```
┌─────────────────────────────────────────────────────────────────────────┐
│  PRESENTATION — Dynamic role-aware dashboards (per persona, per school)   │
│  widgets · priority feed · recommendation cards · copilot · "explain"     │
├─────────────────────────────────────────────────────────────────────────┤
│  ORCHESTRATION — Context Engine · Priority Engine · Recommendation Engine │
│  Automation/Event router · Persona routers (Teacher/Parent/Principal/…)   │
├─────────────────────────────────────────────────────────────────────────┤
│  INTELLIGENCE CORE                                                        │
│  Deterministic Analytics (SQL) ── the spine ──┐                          │
│  Model Gateway (Claude via provider-swappable) ┤→ validated, fallback     │
│  Semantic + Response Cache · Embedding store ──┘                          │
├─────────────────────────────────────────────────────────────────────────┤
│  MEMORY — School Profile · Persona Memory · Interaction Memory · Facts    │
├─────────────────────────────────────────────────────────────────────────┤
│  DATA — tenant Postgres (RLS) · event stream (domain_events) · vault key  │
└─────────────────────────────────────────────────────────────────────────┘
```

The **spine already exists** (audit: `_shared/intelligence/*` deterministic SQL, `_shared/ai/anthropic_client.ts`, Dynamic Widget Platform, Copilot context engine). This blueprint adds **Memory · Context Engine · Cache · Priority/Recommendation/Automation engines** and formalizes the **per-persona routers**.

---

## 3. Memory architecture

Four scoped stores, all RLS-tenant-isolated, all deterministic-first (memory holds *facts and preferences*, not model hallucinations):

| Store | Holds | Scope | Source | Used by |
|---|---|---|---|---|
| **School Profile Memory** | board, size, sections, language mix, branding, enabled modules, term calendar, fee cadence, working hours, holiday pattern | school | onboarding + live config | every adaptive decision |
| **Persona Memory** | per-user role(s), preferences, dismissed suggestions, frequent actions, "don't show again", language | user (school-scoped) | interactions | dashboards, priority, recs |
| **Interaction Memory** | recent AI Q&A per user (short window), accepted/ignored recommendations, copilot threads | user | copilot/recs | context continuity, learning |
| **Fact/Signal Memory (materialized)** | pre-computed rollups: attendance %, fee-aging, marks-completion, at-risk lists, defaulter queues | school | scheduled jobs + events | priority feed, widgets, predictions |

**Key idea — "learned defaults per school":** the School Profile + accepted-recommendation history let Akshara *tune its own thresholds per school* (e.g., what counts as "late fee follow-up," "at-risk attendance," "marks-entry overdue") deterministically, without a model call. This is the heart of "school-adaptive."

**Build note:** a lightweight `ai_school_profile`, `ai_persona_memory`, `ai_interaction_memory`, and reuse of existing snapshot/rollup tables. All new tables inherit the RLS pattern (org+school scoped, `erp_tenant` grants) proven in the audit.

---

## 4. Context Engine

Assembles a **minimal, RBAC-scoped, tenant-safe context bundle** for any AI surface — extending the audited Copilot context engine to all personas.

- **Inputs:** persona + permissions (from JWT claims), current screen, School Profile, relevant Fact/Signal Memory, recent Interaction Memory.
- **Rules:** load only the sections the persona's RBAC allows (the audit confirmed this pattern); **delimit and label** all untrusted data (school/student names, free text) to neutralize prompt injection (closes AI-5); cap context size; never include another tenant's data (RLS).
- **Output:** a compact structured context + a **cache key** = `hash(surface, persona, school, inputs-signature, profile-version)`.

The cache key is the linchpin of API minimization (§7).

---

## 5. Per-persona AI (role-aware intelligence)

Each persona gets a **router** that selects the right deterministic analytics + the right (rare) model call. All are read-only, RBAC-scoped, and language-aware.

| Persona AI | Deterministic core (spine) | Where the model adds value | Primary output |
|---|---|---|---|
| **Teacher AI** | today's classes, marks-pending, attendance-not-marked, homework due, at-risk students in *my* classes | phrase the daily brief; suggest next action; explain a student's trend | "Morning brief" + action cards |
| **Parent AI** | child's attendance/marks/fees/homework/notices (own-child, RLS) | answer in the **parent's language**, empathetic tone, "what should I do" | Parent guidance + Q&A (already partly built) |
| **Principal AI** | approvals queue, exceptions (unmarked attendance, overdue marks), fee collection %, incidents | prioritize the day; draft a broadcast; summarize a workflow | Approvals inbox + daily pulse |
| **Director AI** | cross-school KPIs (RLS org-scope), league, collection, margin | executive summary, cross-school comparison narrative | Board pack + comparisons |
| **Office/Admin AI** | admissions funnel, enrollment tasks, document gaps, front-desk queue | draft letters, suggest next lead action, spot data gaps | Front-office worklist |
| **Finance AI** | dues, aging, defaulter queue, PTP-due, day-close, collection targets | prioritize the call queue, suggest recovery messaging, explain a ledger | Recovery CRM assistant |
| **Transport AI** | route rosters, capacity, doc-expiry, transport dues | flag over-capacity, expiring docs, suggest re-allocation | Fleet/roster alerts |
| **Library AI** | overdue list, catalog gaps, circulation trends | prioritize overdue follow-up, suggest catalog cleanup | Overdue + catalog worklist |
| **Inventory AI** | low-stock, reorder levels, consumption trends, write-off queue | reorder suggestions, anomaly flags | Reorder + anomaly worklist |

**Rule:** the router *always* renders the deterministic core; the model call is **optional enrichment** with a safe fallback (exactly the audited pattern, now generalized).

---

## 6. Priority · Recommendation · Predictive engines

- **Priority Engine (deterministic, no model).** Scores every actionable item for a persona (urgency × impact × age × school-learned weight) and produces the **ordered daily feed**. Uses Fact/Signal Memory + School Profile thresholds. This is the "what matters now" layer — cheap, explainable, always-on.
- **Recommendation Engine (deterministic-first, model-optional).** Turns priorities into concrete next actions ("call these 8 defaulters," "mark 2 classes' attendance," "approve 5 leaves"). Learns from accept/dismiss (Persona Memory). The model only *phrases* or *explains* a recommendation when asked.
- **Predictive Insights (deterministic models + optional narrative).** Fee-default likelihood, admission-conversion, student-risk (the audited Predictions module) — grounded in real data, with an optional model-generated explanation. Extend cautiously; keep every prediction traceable to its signals.

---

## 7. Caching strategy & API minimization (the cost moat)

The audit found **zero** AI caching today — this is the single highest-leverage build.

**Three-tier serving:**
1. **Deterministic tier (0 model calls).** Priority feed, widgets, analytics, rollups — pure SQL. **~80–90% of all AI-surface impressions should resolve here.**
2. **Cache tier (0 model calls).** Response cache keyed on the Context Engine's cache key; **semantic cache** (embedding-nearest) for copilot-style questions so paraphrases hit. TTL per surface (short for volatile data, long for stable explanations); invalidated by events (§8).
3. **Model tier (1 call).** Only on a cache miss *and* genuine novelty/uncertainty. Bounded `max_tokens` per surface; **request timeout** → deterministic fallback (closes AI-3).

**Cost controls (close AI-1):** per-user and per-org **rate limits** + a **monthly spend cap** (soft-degrade to deterministic when exceeded); per-tenant budget visible in Control Center. **Batch + reuse:** identical daily briefs across teachers of the same class reuse one generation; broadcast narratives generate once and localize deterministically.

**Target economics:** with tiers 1–2 absorbing ~90%+ of traffic, a 1,000-teacher school runs on tens of model calls/day, not thousands — the "school-specific AI" feels bespoke while costing almost nothing.

---

## 8. Event-driven updates

Reuse the existing `domain_events` stream (audited) as the nervous system:

- **On event** (fee paid, marks published, attendance submitted, approval decided, lead converted): update Fact/Signal Memory, **invalidate the affected cache keys**, and refresh the priority feed — no polling, no full recompute.
- **Scheduled jobs** (the reminder/scheduling foundation, XCT-2) precompute nightly rollups and warm the cache for the morning brief, so the first login of the day is instant *and* free.
- **Push/in-app** proactive nudges ride the existing reminder rail (owner-gated for external channels).

This makes dashboards **live and cheap**: they reflect reality within seconds of an event, without a model call.

---

## 9. Dynamic role-aware dashboards & widgets

Build on the audited **Dynamic Widget Platform** (`widget_registry`, `dashboard_layouts`, per-role/vertical layouts, tenant overrides):

- **Composition = School Profile × Persona × Priority Engine.** The dashboard is assembled per login from enabled modules, the persona's role, and the current priority feed — not a static layout.
- **Widgets are deterministic-first** (KPIs, lists, trends from SQL) with an **optional AI "explain/summarize" affordance** that hits the cache/model tier only on demand.
- **Adaptive layout:** frequently-used widgets rise; dismissed ones sink (Persona Memory) — per-school, per-user, all deterministic.

---

## 10. Automation opportunities (guarded)

Automation is **suggest-then-confirm** by default (never silent writes; preserves governance):

- Draft-and-hold: fee-reminder batches, overdue-book notices, doc-expiry alerts, marks-overdue nudges (ride XCT-2; external delivery owner-gated).
- Auto-prioritized queues: defaulter call queue, approvals inbox ordering, at-risk intervention lists.
- Auto-summaries: daily principal pulse, weekly director digest, parent weekly digest (deterministic catalog + optional model phrasing).
- **Never automate:** money movement, approvals, publishing marks, or anything the maker-checker governance owns.

---

## 11. Governance, safety & privacy

- **RBAC-scoped context** + **RLS-scoped memory/cache** (per-tenant, per-persona) — no cross-tenant learning.
- **Prompt-injection hardening:** delimit/label untrusted data; output-side guard; read-only, no tools.
- **Language governance:** parent-facing AI generates natively in the parent's language; the **comms catalog stays deterministic (no LLM translation)** — preserve the audited split.
- **Cost governance:** rate-limit + spend-cap + per-tenant budget + full call logging (surface, tokens, cost, cache-hit).
- **Explainability:** every AI output links to its deterministic evidence ("explain this number").
- **Key management:** provider key in the Control Center encrypted vault (audited) or env; **no-key → deterministic health signal** (closes AI-4), never silent.

---

## 12. Build sequence (maps to Master Roadmap Phase 3)

**P3-AI-1 — Foundation (build first; unlocks everything, controls cost):**
1. Response cache + cache-key from a generalized Context Engine.
2. Rate-limit + spend-cap + per-tenant budget.
3. Request timeout → deterministic fallback; no-key health signal.
4. Prompt-injection hardening (delimit/label + output guard).
5. Event-driven cache invalidation on `domain_events`.
6. Memory tables (School Profile, Persona, Interaction, Fact/Signal).

**P3-AI-2 — Adaptive wave (after foundation):**
7. Priority Engine (deterministic daily feed).
8. Per-persona routers (Teacher → Parent → Principal → Finance → Office → Director → Transport/Library/Inventory).
9. Recommendation Engine + accept/dismiss learning.
10. Dynamic role-aware dashboard composition on the Widget Platform.
11. Semantic cache (embeddings) for copilot paraphrase hits.
12. Guarded automation (draft-and-hold) on XCT-2.

**Prerequisites (from the audit):** AI cost foundation depends on nothing but Phase 0; the adaptive wave should follow Phase 1 (modules stable) and the reminder/scheduling + export foundations (XCT-1/2). Rename deterministic "Intelligence" surfaces to "Analytics" to avoid over-claiming AI (AI-6).

---

## 13. Success metrics

| Dimension | Target |
|---|---|
| **API minimization** | ≥90% of AI-surface impressions served with 0 model calls (deterministic + cache) |
| **Cost** | Per-school monthly AI spend bounded by the spend-cap; median <₹X/school (set at pilot) |
| **Latency** | Deterministic/cache tier <150ms p95; model tier <2s with timeout fallback |
| **Adaptivity** | Dashboards + thresholds differ measurably per school without any code change |
| **Adoption** | Daily-brief open rate + recommendation-accept rate rising over the pilot |
| **Safety** | 0 cross-tenant leakage; 0 AI-caused writes; 100% of model calls logged with cost |

---

## 14. Why this is the moat

Competitors bolt a chatbot onto a static ERP. Akshara's design makes **the entire product adapt per school and per person, proactively, at near-zero marginal cost** — because the intelligence is *deterministic-first with a thin, cached, governed model layer on top*. That is hard to copy (it requires the determinism-first discipline the audit found already in place), cheap to run (the caching moat), and compounding (every school's memory tunes its own experience). This is Akshara's strongest long-term differentiator — see [`LONG_TERM_COMPETITIVE_STRATEGY.md`](LONG_TERM_COMPETITIVE_STRATEGY.md).
