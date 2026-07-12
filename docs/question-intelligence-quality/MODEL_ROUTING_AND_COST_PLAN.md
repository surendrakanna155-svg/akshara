# Model Routing and Cost Plan

**Date:** 2026-07-11 · **Status:** SPEC (proposal — not implemented)
**Principle:** The **engine** supplies the intelligence (item model, constraints, answer, distractor
intents); the model only realizes language. This lets a small model produce high-quality output and drives
frontier-model dependency down over time. Every route is **benchmark-driven** — not chosen because a model
is cheap, and not because it is powerful.
**Aligns with:** I9 (runtime deterministic, AI-free) — all model use is **offline** (DNA extraction, Item
Model authoring, certification); runtime instantiation is zero-LLM.

---

## 1. The four tiers

```
TIER 0 — deterministic algorithms (NO model)
  parameter generation, constraint solving, answer computation (relation library / CAS),
  dimensional/unit checks, SVG visual rendering, difficulty-driver measurement, similarity/dedup,
  item-writing-flaw rubric, blind-solve for numeric items.
  → the DEFAULT. Correctness that can be deterministic MUST be deterministic.

TIER 1 — small/cheap model  (benchmark-certified per task)
  classification (archetype, block-type disambiguation), structured extraction from clean text,
  LANGUAGE REALIZATION of a fully-specified generation contract, simple critique.
  → the workhorse for language, once it passes the task's benchmark.

TIER 2 — stronger model
  hard Question-DNA extraction, novel Item-Model discovery, complex/ambiguous validation
  (independent conceptual solve, ambiguity adjudication), failed-item repair.
  → used where structure is genuinely hard to recover.

TIER 3 — frontier model / manual expert
  disputed, high-risk, or benchmark-development cases; adjudicating reviewer disagreements;
  bootstrapping a new subject/archetype before Tier-1/2 are certified for it.
  → rare, deliberate, logged.
```

---

## 2. Why this makes small models sufficient

Today's AI contract (`materialize.spec_of`) hands the model only `{concept, subject, type, bloom/difficulty
label, marks, "be original"}` and asks it to invent the entire assessment — the hardest possible task, one
only a frontier model does acceptably, and even then unverified. The redesign inverts this: by the time a
model is invoked for language realization, the engine has already chosen the archetype, solved the
parameters, computed the answer, and specified the distractor intents. The model's job shrinks from "design
an assessment item" to "phrase this stem naturally for a 14-year-old." That is a Tier-1-sized task. **The
engine, not the model, is where the intelligence lives** — which is exactly what lets cost fall without
quality falling.

---

## 3. Route selection is measured

For each task (archetype classification, stem realization, conceptual blind-solve, DNA extraction), the
route is chosen by running candidate tiers against the **gold benchmark** for that task and picking the
**cheapest tier that meets the quality bar**. Rules:
- Do **not** downgrade to a cheaper tier that fails the benchmark, even to save cost.
- Do **not** use a frontier model where a certified Tier-1 route passes.
- Re-benchmark when a model is swapped/upgraded (D7 eval-harness discipline: every model change passes
  evals before production).

Reuse the existing live provider abstraction (`callClaude()` / OpenRouter, admin-panel key/model
resolution) rather than building a new client.

---

## 4. Cost trajectory

```
Bootstrap (Phase A/B):  Tier 2/3 heavy — extracting DNA and discovering Item Models is hard, done once.
Steady state:           Tier 0 dominant — certified Item Models instantiate deterministically at runtime
                        with ZERO model calls (I9); Tier 1 only for optional language variation.
Frontier use:           asymptotically rare — reserved for new-domain bootstrap and dispute adjudication.
```
The architecture front-loads model cost into a one-time, offline, cached certification and makes the
per-question runtime cost effectively zero. This is the opposite of the current gated path, which (if ever
switched on) would pay a frontier model per question forever.

---

## 5. Caching and determinism

- Offline model outputs (DNA, authored stem structures) are cached by content hash (the existing
  `PersistentSpecCache` pattern) so nothing is paid for twice.
- Runtime is deterministic (seed → instance); no model, no cache miss, fully reproducible (I9 regression
  guard: generation of any mode emits 0 LLM tokens, asserted against the gateway).

---

## 6. Governance

- All model use inherits the existing AI governance gate (`KIE_AI_AUTHORIZED`, governed provider,
  re-validation). Model routing does not create a new ungoverned path.
- Every route logs tier, model id, task, and benchmark version — so cost and quality are auditable.

---

## 7. Acceptance criteria

- Every model route is backed by a benchmark result showing the chosen tier meets the bar.
- Runtime certified generation makes **zero** model calls (asserted).
- Frontier-tier usage is logged and trends down as Tier-1/2 routes are certified.
- A model swap triggers re-benchmark before it reaches production.

---

## Reconciliation Amendment (2026-07-12, post-Fable-5)

Governed by `OPUS_FABLE_RECONCILIATION_RECORD.md`. The tiering is retained, with one sharpening: **routes are
chosen by benchmark-certified capability on the specific task, not by model-size assumption.** "Tier 1 =
small model" is a cost expectation, not a routing rule — a task routes to the **cheapest tier that passes its
task benchmark**, and if only a stronger tier passes, that is the route until a cheaper one earns it. Two
additions:

- **Per-lane routing.** Language realization and archetype classification benchmark **per lane** (Record §2):
  a Tier-1 route certified for NUMERIC_RELATIONAL realization is **not** automatically trusted for
  CONCEPTUAL_CAUSAL or ASSERTION_RELATION realization — each lane earns its route.
- **Realization is gated regardless of tier.** Whatever tier realizes language, the deterministic
  realization-fidelity gate (QUALITY_GATE amendment) runs — so a cheaper route cannot silently drop or alter
  a contract parameter. Independent verification (blind solve / KVS entailment) is never the same model or
  path that generated the item.
