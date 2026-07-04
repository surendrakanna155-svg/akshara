# Adaptive AI Design 01 — The AI Decision Framework

**Status:** 🟢 Design-final (no code) · **Author:** Fable · **Date:** 2026-07-03
**Suite:** `docs/design/adaptive-ai/` (index: [`00_ADAPTIVE_AI_DESIGN_INDEX.md`](00_ADAPTIVE_AI_DESIGN_INDEX.md))
**Anchors:** [`../../strategy/ADAPTIVE_AI_MASTER_BLUEPRINT.md`](../../strategy/ADAPTIVE_AI_MASTER_BLUEPRINT.md) (architecture) · [`../../audits/06_AI_ARCHITECTURE_AUDIT.md`](../../audits/06_AI_ARCHITECTURE_AUDIT.md) (ground truth) · Roadmap **P3-AI-1/P3-AI-2**.

> **Purpose.** This is the single decision instrument every other document in this suite uses.
> Before any surface is called "AI," it must be placed on the **Serving Ladder** below and pass the
> **placement test**. The default answer is *never* "call the model" — it is "which cheaper tier
> already solves this?" This framework is what makes Akshara's intelligence feel bespoke while
> costing near zero.

---

## 1. The Serving Ladder (Tier 0 → Tier 3)

Every intelligent behaviour in Akshara is served from exactly one of four tiers. **Lower tier always
wins when it can express the behaviour.** Model calls are the exception, not the mechanism.

| Tier | Name | What serves it | Marginal cost | Latency | Target share of all "AI-surface" impressions |
|---|---|---|---|---|---|
| **T0** | **Templates & Rules** | Static templates + slot substitution · config · rule tables · the deterministic comms catalog | ₹0 | <10ms | ~40% |
| **T1** | **Deterministic Intelligence** | SQL rollups, threshold engines, scoring formulas, learned per-school defaults, priority ranking, statistical trends | ₹0 | <150ms | ~45% |
| **T2** | **Cached AI** | Response cache (exact key) · semantic cache (paraphrase) · shared generations (one call, N users) · pre-warmed nightly generations | ₹0 (amortized) | <150ms | ~10% |
| **T3** | **Live Model Call** | One governed call to the Model Gateway (`_shared/ai/anthropic_client.ts`), bounded tokens, timeout → T1 fallback | per-call | <2s p95 | **≤5%** |

**Global invariant (from the Blueprint §1):** ≥90% of impressions resolve at T0–T2. Every design in
docs 05–07 declares a tier per surface; the EOS AI gate (P3) measures the real ratio.

### Tier definitions in practice

- **T0 — Templates & Rules.** Anything whose output space is enumerable in advance: notification
  texts, reminder copy, certificate wording, standard letters, status explanations, localized parent
  comms (the frozen deterministic catalog — **no LLM translation, ever**). Personalization = slot
  filling (`{child_name}`, `{amount}`, `{due_date}`) + per-school branding + language variant lookup.
- **T1 — Deterministic Intelligence.** Anything computable from tenant data: every number, list,
  rank, trend, exception, deadline, comparison, and **priority ordering**. Includes *learned
  personalization*: per-school thresholds and per-user preferences tuned from history are still
  deterministic (a stored number, not a model output). The existing `_shared/intelligence/*` suite
  lives here (rename "Intelligence"→"Analytics" per AI-6).
- **T2 — Cached AI.** A model output reused beyond its first generation: exact-key response cache,
  semantic (embedding-nearest) cache for copilot paraphrases, **shared generations** (one narrative
  for all teachers of the same class/section; one director digest per org per day), and **pre-warmed
  generations** (nightly jobs generate tomorrow-morning briefs while rates are idle).
- **T3 — Live Model Call.** Genuinely novel language work: open-ended Q&A the caches miss,
  first-generation narratives, empathetic in-language parent guidance, draft text a human will edit.
  Always: deterministic facts injected (model never computes), output validated, bounded
  `max_tokens`, request timeout with T1 fallback, logged with cost, rate-limited, under spend-cap.

---

## 2. The Placement Test (apply to every candidate surface)

Walk down; stop at the first "yes."

```
Q1. Is the output enumerable in advance (finite messages/labels/documents)?
      YES → T0 (template + slots + language variant). STOP.
Q2. Is the output computable from tenant data (number/list/rank/flag/trend/order)?
      YES → T1 (SQL/rules/scoring; add learned thresholds for adaptivity). STOP.
Q3. Is it language work whose input signature repeats across users or across time?
      YES → T2 (shared generation / response cache / semantic cache / pre-warm). STOP.
Q4. Is it genuinely novel language work for THIS user, NOW, with real user value?
      YES → T3 — but the prompt embeds T1 facts, and the answer is cached for Q3 next time.
      NO  → the surface is not AI. Build it as a normal feature or drop it.
```

**Corollaries:**
1. Every T3 answer becomes a T2 asset (write-through caching). The system gets cheaper with use.
2. A surface may **straddle tiers**: the widget body is T1; its "Explain" affordance is T2/T3
   on-demand. Render the deterministic core always; enrich lazily.
3. If a T3 surface cannot state its T1 fallback, it is not shippable (audit pattern, preserved).

---

## 3. Where LLMs genuinely earn their cost (and where they never do)

### The model IS worth a call for
| Use | Why a template/rule can't do it |
|---|---|
| Open-ended copilot Q&A after cache miss | unbounded question space |
| First generation of a narrative brief (then shared/cached) | fluent synthesis across many signals |
| Empathetic, in-language parent guidance ("what should I do?") | tone + native-language generation (generation ≠ translation — allowed split) |
| Draft-for-human-edit (broadcast draft, recovery message, letter) | human edits; value is a good starting point |
| "Explain this number/trend to me" on demand | ad-hoc phrasing of deterministic evidence |
| Question-paper gap-fill (moderation-gated, never auto-published) | content creation, already governed |

### The model is NEVER used for
| Anti-use | Correct tier |
|---|---|
| Computing any number, total, rank, or list | T1 |
| Deciding priority/ordering of work items | T1 Priority Engine (explainable score) |
| Translating parent comms | T0 frozen deterministic catalog (governance) |
| Routine reminders/notifications | T0 templates on the reminder rail |
| Threshold alerts (low stock, overdue, absent) | T1 rules + learned thresholds |
| Any write, approval, or money action | never AI (governance; maker-checker owns these) |
| Predictions' scores (fee-default, at-risk) | T1 statistical signals; T3 only for optional narrative |
| Re-answering a question already answered for the same context | T2 |

---

## 4. Standard patterns (the reusable vocabulary of docs 05–07)

Each pattern below is referenced by name in the module/persona designs.

| # | Pattern | Tier | Description |
|---|---|---|---|
| P1 | **Template+Slots** | T0 | Enumerable message + deterministic slot fill + language variant + school branding |
| P2 | **Rule/Threshold Alert** | T1 | Condition over live data → alert/nudge; thresholds are per-school **learned defaults** |
| P3 | **Priority Feed** | T1 | urgency × impact × age × learned weight → ordered actionable list (see doc 04) |
| P4 | **Exception Surface** | T1 | show only what deviates (unmarked, overdue, missing, anomalous) — the ERP's default lens |
| P5 | **Shared Generation** | T2 | one model call serves N users with the same input signature; personalization re-applied deterministically per user |
| P6 | **Pre-warmed Brief** | T2 | nightly job generates the morning artifact; first login is instant and free |
| P7 | **Semantic Cache Hit** | T2 | embedding-nearest match answers paraphrases of already-answered questions |
| P8 | **Explain-on-Demand** | T2/T3 | deterministic surface carries an optional "explain/why" affordance; only a tap costs anything |
| P9 | **Draft-and-Hold** | T3 | model drafts, human reviews/edits/sends; never auto-sent externally (owner-gated) |
| P10 | **Narrative-over-Facts** | T3 | T1 computes every fact; model only phrases them; output validated; T1 fallback |
| P11 | **One-Click Action** | T0/T1 | a recommendation carries its action pre-filled (deep-link + pre-populated form); confirmation stays human |
| P12 | **Accept/Dismiss Learning** | T1 | recommendation feedback updates Persona Memory weights — adaptivity with zero model calls |

---

## 5. The recommendation rubric (used by every design in this suite)

Every recommendation in docs 04–08 carries these five fields. Conventions:

- **Why better** — one sentence: what the cheaper/smarter placement wins vs the naive "call an LLM" or "static ERP" alternative.
- **User impact** — 🌟🌟🌟 daily-felt / 🌟🌟 weekly-felt / 🌟 occasional.
- **API savings** — vs the naive all-LLM implementation of the same surface:
  **100%** (T0/T1: zero calls forever) · **95–99%** (T2-dominant: first-call-only or shared) ·
  **70–90%** (T3 with cache+dedupe) · **n/a** (surface is new; cost is *bounded*, state the bound).
- **Complexity** — S (≤2d) · M (~1wk) · L (>1wk), matching roadmap conventions.
- **Priority** — **W1** = P3-AI-1 foundation · **W2** = P3-AI-2 adaptive wave · **W3** = post-GA/Future (owner-timed). A surface may ship its T1 core in W2 and its T3 enrichment in W3.

---

## 6. Hard governance rails (inherited, non-negotiable)

1. **No AI on any write path** — money, marks, approvals, publishing, identity. AI proposes; humans (and maker-checker) dispose.
2. **Comms translation stays deterministic** — the frozen English-first decision; the catalog is law. AI may *generate natively* in the parent's language for parent-AI surfaces only.
3. **RLS/tenant isolation extends to intelligence** — memory, caches, embeddings are school-scoped; no cross-tenant reuse of a cached generation, even on identical keys.
4. **RBAC scopes context** — a context bundle never contains data the requesting persona couldn't read directly (doc 02).
5. **Every T3 call is logged** (surface, inputs-hash, tokens, cost, cache-written) and governed (rate limit, monthly spend cap, timeout → fallback, no-key → visible health state, never silent).
6. **Every AI output is explainable** — it can show the T1 evidence behind it.
7. **Truth in naming** — deterministic surfaces are "Analytics"/"Smart," not "AI" (closes AI-6). We only call it AI when a model was (or may be) involved.

---

## 7. Worked examples (calibration)

| Candidate surface | Naive build | Placement-test result |
|---|---|---|
| "Remind parents about fees due Friday" | LLM writes each message | **T0** P1: catalog template + slots + language variant. 100% savings. |
| "Which students are at risk this term?" | ask model to analyze | **T1** P2/P4: signal formula (attendance, marks delta, fee stress) with learned thresholds. 100%. |
| "Teacher's morning brief" | per-teacher LLM call each open | **T1 core + T2** P6/P5: deterministic brief always; phrased narrative pre-warmed nightly, shared per class-section. ~98%. |
| "Parent asks: why did Aarav's rank drop?" | LLM every time | **T3 → T2** P10/P7: facts from T1; first answer generated, cached; siblings/paraphrases hit semantic cache. ~80–90% over time. |
| "Principal broadcast for tomorrow's holiday" | LLM writes + sends | **T3 draft** P9: draft-and-hold; localization via **T0 catalog**; human sends. Bounded: ≤1 call/broadcast. |
| "Reorder chalk when stock is low" | AI predicts demand | **T1** P2: reorder point = consumption rate × lead time, learned per school. 100%. |

---

*Next: [`02_CONTEXT_ENGINE_DESIGN.md`](02_CONTEXT_ENGINE_DESIGN.md) — the engine that assembles the
tenant-safe, RBAC-scoped context bundle and mints the cache keys this framework depends on.*
