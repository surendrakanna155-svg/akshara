# Quality-First Implementation Roadmap

**Date:** 2026-07-11 · **Status:** PROPOSAL — awaiting owner approval. **No implementation begun.**
**Governs the sequence for:** `QUESTION_DNA_SPECIFICATION.md`, `ITEM_MODEL_SPECIFICATION.md`,
`MULTIMODAL_INGESTION_ARCHITECTURE.md`, `VISUAL_INTELLIGENCE_SPECIFICATION.md`,
`QUALITY_GATE_SPECIFICATION.md`, `PSYCHOMETRIC_CALIBRATION_SPECIFICATION.md`, `GOLD_BENCHMARK_PLAN.md`,
`MODEL_ROUTING_AND_COST_PLAN.md`.

**Success metric (repeat):** independent teachers, reviewing blind samples, consistently judge Akshara
questions as educationally strong, correct, diverse, useful, and competitive. **Not** "the endpoint works."

---

## 0. Guardrails that hold for the whole program

- **Quality first.** 100 excellent questions beat 100,000 weak ones. No archetype/subject scales until it
  passes its gold-benchmark round.
- **Benchmark-gated, not endpoint-gated.** Every phase that adds generative capability ends with a blind
  benchmark round for the affected cells; a failed round sends work back, it does not ship.
- **Preserve L1/L2/L3.** Curriculum knowledge (L1) vs pattern intelligence (L2) vs original certified bank
  (L3). No source wording enters L3. Licence class on every artifact.
- **Respect locked decisions.** A2 family certification + I9 (runtime AI-free); D1/D6 response spine +
  item-statistics schema; D2 (no per-student OMR — marks grid only); D7 (independent blind solve; eval
  harness); D8 (original-content-first).
- **Isolate engine changes.** Content grows via the `templates_ext` hook with zero engine edits wherever
  possible. The few genuine engine changes (new gates, `item_model_id` on the slot, archetype-diversity
  term in selection, structured solutions) are bundled into one reviewed "engine v2" change set with its
  own regression gate — never smuggled through the content lane.
- **Local-only derived knowledge.** DNA / Item Models / visual assets stay gitignored per the storage
  decision; only code/tests/schema/docs are committed. Verify branch before each commit (shared worktree).
- **Honest denominators.** Always report can-fill vs total, clean-abstractable vs detected, benchmark
  cells passed vs attempted.

---

## 1. Phase map (each phase is independently reviewable; stop-and-review between phases)

```
A  Foundations        — schema, DNA store, benchmark harness, gate scaffold, engine-v2 seam
B  Structure mining   — Question DNA + Item Models learned from the EXISTING corpus (Tier A archetypes)
C  Quality gates      — blind solve, distractor plausibility, difficulty-driver, item-writing rubric
D  Paper intelligence — archetype/cognitive/difficulty/exposure diversity; composition optimization
E  Multimodal + visual— parser routing, question boundaries, visual assets, semantic visuals (Tier C archetypes)
F  Psychometrics      — response spine seeded (now), CTT then IRT (Phase-2, response-fed)
```
Phases A→D are the quality core and are achievable on the existing corpus with the existing (improved)
ingestion. E unlocks visual archetypes. F is gated on real response data and is the platform's Phase 2.

---

## 2. Phase A — Foundations (no new questions yet)

**Goal:** the substrate on which quality can be built and measured. Build the instrument before the engine.

1. **Baseline snapshot.** Capture the pre-change `qp_output_audit` JSON so every later delta is
   attributable (the Batch-0 checkpoint flagged this as not-yet-done).
2. **Gold benchmark harness** (`GOLD_BENCHMARK_PLAN`): rubric, reference set for a first slice of concepts,
   reviewer protocol, A/B/gold blind-interleave tooling. This must exist before any generative change so we
   can measure lift, not assert it.
3. **Schema extensions** (reuse the empty/dormant tables): populate-ready `question_templates`
   (Item Model), `distractors` (distractor DNA), `generated_items` (instances + verdicts), a new
   `question_dna` store, and the driver/verdict provenance fields. Migrations mirror the dormant `edu_*`
   shape.
4. **Engine-v2 seam:** add `item_model_id` + driver/verdict provenance to `QuestionSlot`; a place in
   `validate.py` for the new gate ladder; an archetype-diversity hook in `select._priority`. Land these as
   inert scaffolding (behavior unchanged, matrix green) so later phases plug in without re-touching the
   engine.
5. **Relation library v0:** real formula/relation store (physics/chem/math) with dimensional metadata — the
   independent solver's backbone (GATE 4-5) and the fix for `formulas.expression` = names.

**Exit:** benchmark harness runs; schema migrated; engine-v2 seam merged with matrix unchanged; relation
library covers the concepts in the first benchmark slice. **No question quality claim yet.**

---

## 3. Phase B — Structure mining → Item Models (the core quality lift)

**Goal:** learn solver-verified, distractor-bearing Item Models from the ~5,224 clean computational MCQs +
776 AR problems the pipeline currently discards. This is where the corpus finally becomes questions.

1. **CP-A structure recovery** (from the Batch-0 hypothesis, now one step among many): parse clean English
   computational MCQ chunks into `{quantities+units, values, 4 options, correct option}`; measure OCR
   damage; fix a deterministic discovery/holdout split. Report the honest clean-abstractable count.
2. **CP-B relation match + independent verify:** match parsed quantities against the relation library; keep
   only matches where the relation, fed the source's own numbers, reproduces the correct option
   (zero fabrication, zero copying). Dimensional gate; unit normalization.
3. **DNA extraction:** emit Question DNA (identity, construct, archetype, cognitive chain, difficulty
   drivers, construction model, **distractor DNA from diffing the real wrong options**, solution DNA). No
   source wording stored.
4. **CP-C Item Models:** cluster DNA → Item Models; learn parameter ranges + constraints from real values;
   mine recurring distractor transforms into certified generators; author original stem structures; dedupe;
   rank. Cover Tier A archetypes first (single/multi-step/reverse numerical, missing-variable,
   multi-concept), then Tier B (misconception, comparison, AR **with randomized keys**).
5. **CP-D register + generate:** register high-confidence families via `templates_ext` (content-only) and,
   for new archetypes, through the engine-v2 seam; generate; run the Phase-C gates (below); originality /
   source-distance gate.
6. **CP-E benchmark round:** blind A/B/gold on the covered cells. Only cells that pass are cleared to scale.

**Exit:** a first batch of certified Item Models across Tier A/B archetypes for a benchmark slice, each
producing solver-verified original instances that **beat the current engine on blind review** for
cognitive depth, distractor quality, difficulty accuracy — with no regression on correctness/syllabus.
Frozen matrix shows the coverage lift; benchmark shows the quality lift.

---

## 4. Phase C — Quality gates (independent verification)

**Goal:** every item earns acceptance by surviving verification, not by a confidence score. Implements
`QUALITY_GATE_SPECIFICATION.md`.

- GATE 4-5 Independent blind solve + answer/dimensional correctness (deterministic for numeric; independent
  model for verbal).
- GATE 7 Distractor plausibility (misconception-typed, magnitude-sane, not surface-eliminable).
- GATE 8 Ambiguity (independent solver; ≥2 defensible answers ⇒ reject).
- GATE 9 Difficulty-driver verification (measured drivers in the model's band).
- GATE 10 Cognitive/Bloom verification (chain matches the item; Bloom derived not stamped).
- GATE 13 Originality/similarity (source distance + self distance; replaces exact-key dedup).
- GATE 14 Item-writing-flaw rubric (position bias, longest-correct, cues, all/none — rejects the current
  AR always-(a) flaw).
- Rejections preserved with reasons; per-Item-Model health report.

**Exit:** injected-defect tests pass (corrupted keys 100% caught; arithmetic-noise distractors rejected;
AR position bias rejected). Gates run at certification (all) and runtime (deterministic subset, zero-LLM).

---

## 5. Phase D — Paper intelligence

**Goal:** paper quality, not average item quality. Add composition intelligence to selection.

- Diversity terms in selection: archetype, cognitive-operation, difficulty-distribution, context, and
  exposure — so a paper is not N variants of one archetype (today's failure mode; 76% clones measured).
- Composition optimization: satisfy the blueprint AND coverage AND difficulty distribution AND
  discrimination-quality (once calibrated) AND solution-time budget AND recent-exposure — deterministic
  scoring/constraint optimization, never random selection.
- GATE 15 paper-level diversity as a hard check.

**Exit:** benchmark paper-level review shows real diversity + difficulty distribution; clone rate collapses
on the frozen matrix; exposure control prevents cross-paper repetition.

---

## 6. Phase E — Multimodal ingestion + visual intelligence

**Goal:** stop losing structure at ingestion; unlock visual archetypes. Implements
`MULTIMODAL_INGESTION_ARCHITECTURE.md` + `VISUAL_INTELLIGENCE_SPECIFICATION.md`.

- Benchmark parser routes per document class; adopt by measured score.
- Question-boundary + option + answer/solution association; populate new block types; full provenance
  (bbox, offsets); persist images/equations/tables with chunk links (eliminate the DB-boundary drop).
- Visual Asset Intelligence (answerable-without-visual flag; diagram-locked exclusion).
- Semantic visual specs → deterministic SVG; Item Models with `visual_generator`; GATE 11 consistency.
- Tier C archetypes (graph/table/diagram/experiment) ship per-archetype after their benchmark round.

**Exit:** zero silent diagram loss (measured); Tier-C archetypes pass blind review; ingestion improvements
flow through intake automatically.

---

## 7. Phase F — Psychometric calibration (platform Phase 2)

**Goal:** turn predicted difficulty into empirically calibrated difficulty from real responses. Implements
`PSYCHOMETRIC_CALIBRATION_SPECIFICATION.md`.

- Seed the response spine **now** (D11: data can't be backfilled) via the per-question marks grid (D2: no
  per-student OMR).
- CTT (p-value, discrimination, point-biserial, distractor stats) into the locked D6 `edu_item_statistics`
  schema once volume permits; IRT (Rasch→2PL→3PL) gated on volume/fit.
- Close the loop: regress observed difficulty on driver vector to refine the predicted model; drift/broken-
  item flags.

**Exit:** items carry both predicted and empirical difficulty with correct provenance; no LLM ever writes a
statistic; promotion thresholds (D6) enforced.

---

## 8. Sequencing rationale (why this order)

- **A before everything:** you cannot claim quality without the instrument to measure it; you cannot plug
  in gates/models without the schema + seam.
- **B before C's full weight:** you need real Item Models before the gates have meaningful items to verify;
  but B's own CP-D already runs the core gates, so correctness is never ungated.
- **D after B/C:** diversity intelligence needs a diverse pool of archetypes to select from.
- **E can parallelize with B/C/D** for text archetypes but its visual archetypes gate on the visual
  pipeline; kept as its own phase to avoid coupling the core text lift to ingestion work.
- **F last / continuous:** needs real usage data; but its **seeding** starts in A so data accrues.

---

## 9. What we explicitly will not do

- Not scale volume before the benchmark proves quality.
- Not rewrite the boundary engine, template mechanism, or validation scaffold.
- Not call an LLM at runtime for certified generation (I9).
- Not introduce per-student answer-sheet OCR/OMR (D2).
- Not treat Batch-0 as approved architecture — its structure-mining idea is folded into Phase B as a
  hypothesis to prove, with its own benchmark gate.
- Not report any quality claim without blind-review evidence.

---

## 10. First concrete steps on approval (Phase A only)

1. Capture the baseline `qp_output_audit` snapshot.
2. Stand up the gold-benchmark harness + reviewer rubric for a first concept slice (e.g. Ohm's Law,
   kinematics, mole concept, AP-series, a genetics concept — spanning subjects/archetypes).
3. Land the schema migrations (Item Model / distractor DNA / DNA store / generated_items) + relation
   library v0, mirroring the dormant `edu_*` shape.
4. Merge the inert engine-v2 seam (slot fields, gate slot, selection hook) with the frozen matrix green.
5. Stop and review Phase A before starting Phase B structure mining.

**No code will be written until this roadmap is approved.**

---

## Reconciliation Amendment (2026-07-12, post-Fable-5) — Phase-0 first, corrected ordering

Governed by `OPUS_FABLE_RECONCILIATION_RECORD.md` §6/§7. The A→F sequence is retained but is **preceded by a
Phase-0 kill test** and **E is split** (E-lite → Phase A; E-full → late). Final order:

```
Phase 0  Kill test           — Hypothesis A (structure-mining yield) + Hypothesis B (item-model quality
                               spike). Content-lane + throwaway; NO schema, NO engine change. STOP if either
                               fails its pre-registered gate (below).
Phase A  Foundations + E-lite — DNA store (lane-typed) + item-model/distractor/generated_items stores + KVS v0
                               (relation library + assertion-base seed); pre-registered benchmark harness;
                               inert engine-v2 seam; E-LITE ingestion for the incoming 200-300 PDFs. Matrix green.
Phase B  Structure mining     — DNA + Item Models per lane; Tier-A lanes (numeric, table-data, misconception)
                               first, then Tier-B KVS lanes. Per-lane benchmark gate.
Phase C  Quality gates         — blind solve, concept-binding integrity, family-equivalence dedup, distractor
                               plausibility, difficulty-driver, AR semantic, realization fidelity, originality.
Phase D  Paper intelligence    — lane/archetype/difficulty/exposure diversity; within-paper + family dedup.
Phase E-full Multimodal+visual — parser-routing benchmark; SVG generation; DIAGRAM_VISUAL / graph-data /
                               experiment lanes.
Phase F  Psychometrics         — marks-grid spine seeded from A; CTT (SUPPORTED_NOW); IRT volume-gated;
                               distractor telemetry only via the digital-practice channel when it exists.
```

**Phase-0 acceptance gates (both must pass; full detail in Record §7):**
- **Hypothesis A:** ≥200 items/subject across Physics-numeric, Chemistry, Mathematics, **Biology non-numeric**;
  pass = independent-verification success ≥ **40%** numeric AND ≥ **30%** Biology, ≥ **8** distinct-lane Item
  Models/subject each from ≥ **K=5** DNA / ≥2 resources, held-out ≥ **70%** gate-pass, **0** originality
  violations. *Numeric verification < ~40% ⇒ STOP.*
- **Hypothesis B:** 6-10 hand-built Item Models (≥2 Biology non-numeric, ≥1 AR truth-table, ≥1 numeric
  multi-step, ≥1 misconception); blind ≥3-teacher review; pass = absolute bar (median ≥4/5 correctness/
  syllabus/concept-precision/ambiguity) AND lift ≥ **1.0** point over Engine-A on depth/distractor/difficulty/
  solution (Wilcoxon p<0.05) AND no regression AND Krippendorff α ≥ **0.6** AND Biology items hit the absolute
  bar. *Any miss ⇒ STOP and reassess before Phase-A funding.*

**Sequencing corrections:** E-lite is a Phase-A dependency (incoming PDFs must not ingest lossy); the within-
paper dedup fix (Record F4) and `select._priority` fix (Record F10-adjacent) land with the engine-v2 seam,
not deferred to Phase D; a **concept-canonicalization pass** (merge/reject duplicate & junk concepts) is a
Phase-A/B prerequisite the original roadmap assumed away (Record §8, risk 2). Add per-phase **effort
estimates and explicit kill criteria** before owner sign-off.
