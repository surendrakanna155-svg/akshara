# Opus × Fable-5 Reconciliation Record — Quality-First Question Intelligence

**Date:** 2026-07-12 · **Author role:** Chief Assessment Intelligence Architect (reconciliation pass)
**Type:** READ-ONLY reconciliation. No code, DB, engine, or roadmap changed. Canonical specs revised in place.
**Reconciles:** the original 11 deliverables (`docs/question-intelligence-quality/`, 2026-07-11) +
`FABLE5_INDEPENDENT_RED_TEAM_REVIEW.md` (2026-07-11) + **independently re-measured repository reality
(2026-07-12).**
**Rule honored:** previous conclusions were not preserved for consistency. Every Fable finding was
re-verified against current code/DB/output before being accepted, bounded, or rejected. Current code is
authoritative over all documentation.

---

## 0. How to read this record

This is the single source of truth for the final architecture decisions. The 11 canonical specs were
revised to match it; each carries a `## Reconciliation Amendment (2026-07-12)` block pointing here.
Section 1 is the finding-by-finding disposition; sections 2-7 are the six mandated final decisions.

Evidence convention: every quantitative claim below was reproduced this session by importing the live
registry through `curriculum/.venv`, running `find_template` over the live `concepts` table, read-only
SQL against `curriculum/knowledge/kie/kie.db`, and recomputation from the frozen
`curriculum/reports/qp_audit/*.json`. Where a number corrects a prior document, both are shown.

---

## 1. Finding-by-finding disposition

Legend: **ACCEPTED** · **PARTIALLY_ACCEPTED** (with the exact boundary) · **REJECTED** (with counter-evidence) ·
**SUPERSEDED** (both prior positions replaced by a better one).

### F1 — Template family count (46+42 vs 52+42) → **ACCEPTED**
- **Fable finding:** live registry = 52 native + 42 extension = 94; the original audit's "46 engine-native + 42" split is wrong.
- **Independent verification:** imported `kie.qpgen.templates.REGISTRY` → 94 families. Native block A (`REGISTRY = [...]`) = 5; native block B (`REGISTRY += [...]`) = 47; native total = **52**. `kie.curate.templates_ext.build_families(...)` = **42**. 52+42 = 94. Of the 94: 89 numeric (88 single-formula direct-substitution + 1 borderline two-step `math_compound_interest`), 4 assertion-reason, 1 match.
- **Repository evidence:** live import; `templates.py` blocks at lines ~155-166 and ~571-656; `templates_ext.py` `build_families` return list.
- **Architecture impact:** cosmetic to conclusions (94 total and "88/94 one archetype" stand) but the denominator must be correct for record integrity.
- **Documents revised:** `QUESTION_QUALITY_ROOT_CAUSE_AUDIT.md` (C3 split corrected to 52+42).

### F2 — Assertion-Reason failure is semantic, not positional → **ACCEPTED**
- **Fable finding:** the deeper flaw is that the correct *relation* is always "Both A and R are true and R correctly explains A"; position randomization is not a sufficient fix.
- **Independent verification:** all 4 AR families (`ar_newton_first`, `ar_ohm`, `ar_momentum_conservation`, `ar_archimedes`) call `_ar_family(...)`, whose `build()` hard-codes `"answer": _AR_OPTS[0]` (templates.py). Each family is hand-authored so that the assertion **and** the reason are both true restatements of the same law — so the correct answer is semantically constant ("(a)") for every instance and every seed. There is also no option-order rotation (numeric `_mcq_options` rotates by seed; AR does not). Both defects confirmed; the semantic one is the binding constraint.
- **Repository evidence:** `templates.py` `_AR_OPTS`, `_ar_family`, and the four `ar_*` registrations; live corpus holds **787** assertion/reason chunks (real evidence for a genuine AR lane exists).
- **Architecture impact:** AR needs genuine construction intelligence that can produce **all four relation classes** (A∧R∧explains; A∧R∧¬explains; A∧¬R; ¬A∧R), each independently verified against a fact base — see the **ASSERTION_RELATION lane** (§2, lane 10) and the AR fix in §4. Position randomization is demoted to a necessary-but-insufficient sub-step.
- **Documents revised:** `QUESTION_DNA_SPECIFICATION.md` (ASSERTION_RELATION lane), `ITEM_MODEL_SPECIFICATION.md` (AR truth-table generator), `QUALITY_GATE_SPECIFICATION.md` (GATE 14 semantic key-constancy), `QUESTION_QUALITY_ROOT_CAUSE_AUDIT.md` (C4 deepened).

### F3 — Native template precedence blocks content-only remediation → **ACCEPTED**
- **Fable finding:** `find_template` returns the first `REGISTRY` match and native families load before `templates_ext`; ~5 live overlaps mean flawed native families cannot be overridden via the content lane.
- **Independent verification:** `find_template` iterates `REGISTRY` in insertion order, returning the first `subject`+`qtype`+keyword-group match; `templates.py` appends `templates_ext` families **after** the native list. Reproduced **5** native/ext keyword-group overlaps: `phy_equations_motion`/`phy_displacement_motion`, `phy_pressure`/`phy_pressure_liquid`, `math_circle_area`/`math_circle_measure`, `phy_charge_current`/`phy_electric_current`, `math_cube_volume`/`math_cuboid_volume_generic`. Critically, `ar_ohm` (the family behind the within-paper duplicate, F4) is **native** — it cannot be retired or overridden through `templates_ext` at all.
- **Repository evidence:** live overlap computation; `templates.py:695-699` appends ext after native.
- **Architecture impact:** family **retirement + explicit registry priority + versioning** is required; this is an engine change (surface #5, §6) — it cannot be done in the content lane, which strengthens the MINIMAL_ENGINE_EXTENSION decision.
- **Documents revised:** `CURRENT_VS_REQUIRED_ARCHITECTURE.md` (surface list), `QUALITY_GATE_SPECIFICATION.md` (registry-integrity gate).

### F4 — Within-paper duplication (10/54); prior "within-paper 0" wrong → **ACCEPTED**
- **Fable finding:** 10 of 54 served papers in the latest frozen run print the same stem twice; cause is the duplicate concept pair `PHY_OHM_S_LAW` / `CHE_OHMS_LAW` both binding the same universal AR template while dedup keys on `(concept_code, question_type)`.
- **Independent verification:** confirmed both are **active** concepts, both `subject_domain='Physics'`, titles "Ohm's law" / "Ohms law" (a third, `CHE_OHM_S_LAW`, is `merged`). Both resolve to template `ar_ohm` via `find_template`. The paper-level dedup (`validate.validate_paper` DUPLICATE) keys on `(concept_code, question_type)`, so two different concept codes rendering identical text both pass. Recomputed from `audit_content_density_levers.json`: 10/54 papers carry a within-paper duplicate stem (0 in the three earlier snapshots) — so the remediation report's "within-paper 0" was true for its snapshot and became stale after the fill-aware-selection change.
- **Repository evidence:** live concept query; `validate.py` DUPLICATE key; recomputed JSON.
- **Architecture impact:** two defenses required — **family-equivalence deduplication** (normalize duplicate/near-duplicate concepts and equivalent Item Models to one exposure identity) and **generated-item duplicate prevention** (rendered-stem structural dedup within a paper, not concept-code dedup). Both land in the paper/assemble surfaces (§6, surfaces #3/#7) and GATE 15.
- **Documents revised:** `QUALITY_GATE_SPECIFICATION.md` (GATE 15 + family-equivalence dedup), `CURRENT_VS_REQUIRED_ARCHITECTURE.md`, `QUESTION_QUALITY_ROOT_CAUSE_AUDIT.md` (C6 within-paper note).

### F5 — Broad keyword binding + grounding bypass → **ACCEPTED**
- **Fable finding:** single-word keyword groups bind unrelated concepts to templates (e.g. "Volume of a Sphere" → cuboid generator), and template items bypass the grounding check.
- **Independent verification:** `templates_ext.py` families bind by single bare-word "conjunctive" groups: `("volume",)`, `("circle",)`, `("triangle",)`, `("equilibrium",)`, `("efficiency",)`, `("perimeter",)`, `("parallelogram",)`, `("median",)`, `("integer",)`. `find_template` uses plain substring `in` matching (no tokenization). And `validate.py` grounding is gated `if needs_grounding and src != "template"`, where `needs_grounding` is only true for SHORT/LONG_ANSWER or `src == "ai"` — so **template-sourced MCQ/numerical items are never grounding-checked**, and a topically-mismatched template item prints clean.
- **Repository evidence:** `templates_ext.py` keyword groups; `validate.py` grounding block (quoted this session).
- **Architecture impact:** concept binding must move to **canonical-concept-code-exact scope declarations** (`concept_scope[]` of `concept_code`s per Item Model); keyword substring binding is **removed** for all new item-model families and restricted/audited for the legacy registry. A **concept-binding-integrity gate** (a template's bound concept must be in the model's declared `concept_scope`, and template items regain topical grounding via that scope) is added.
- **Documents revised:** `ITEM_MODEL_SPECIFICATION.md` (concept-code binding), `QUALITY_GATE_SPECIFICATION.md` (concept-binding-integrity gate), `CURRENT_VS_REQUIRED_ARCHITECTURE.md`.

### F6 — Shadowed generator function → **ACCEPTED (as a symptom, not an isolated bug)**
- **Fable finding:** `g_triangle_area` is defined twice in `templates_ext.py`; the second silently shadows the first, so `math_triangle_area` and `math_triangle_measure` execute the identical generator.
- **Independent verification:** confirmed two `def g_triangle_area` inside `build_families()` (~line 185 and ~line 290); Python binds the later definition, so the first is dead code and two template_ids share one generator.
- **Repository evidence:** `templates_ext.py` (both defs read this session).
- **Architecture impact:** this is a **registration-integrity** gap — family registration has no structural check for duplicate template_ids, duplicate generator identity, overlapping bindings, or degenerate keyword groups. A **registration-time integrity check** (unique template_id, unique generator object per family, no unintended binding overlap, no single-word group for new families) is added to the registry surface. It is both a bug fix and an architecture-level prevention.
- **Documents revised:** `QUALITY_GATE_SPECIFICATION.md` (registry-integrity gate), `CURRENT_VS_REQUIRED_ARCHITECTURE.md` (surface #5).

### F7 — Psychometric data contradiction (distractor telemetry vs D2) → **PARTIALLY_ACCEPTED**
- **Fable finding:** the psychometric spec promises `distractor_selection_frequency`/`distractor_efficiency` from CTT, but the D2 marks-grid captures marks-per-question, not the chosen option; those metrics are uncomputable from that spine.
- **Independent verification:** confirmed — but the boundary is sharper than Fable stated. The **canonical AIP v3.0 schema already resolves this**: `edu_student_item_responses.chosen_option SMALLINT` is annotated *"ONLY from digital attempts (§6.4)"*, and AIP §6.4 line 178 states *"The grid yields marks per question, not which option the student chose. Distractor-level analytics (§10) therefore come only from digital attempts (in-app DPP/practice, Phase 2)."* So the failure was that **`PSYCHOMETRIC_CALIBRATION_SPECIFICATION.md` drifted from canon** by listing distractor-level metrics under the marks-grid CTT block — not that the platform lacks the capability. No schema extension is needed; the `chosen_option` field already exists and is populated only by the digital-practice channel.
- **Repository evidence:** `docs/Vision/design/Assessment-Intelligence-Platform.md:107-121, 178`.
- **Architecture impact:** metrics are re-classified (§5 below). The psychometric spec is corrected to source distractor telemetry from the digital-practice channel only, matching AIP §6.4/§10 — the fix is re-alignment to canon, not new invention.
- **Documents revised:** `PSYCHOMETRIC_CALIBRATION_SPECIFICATION.md` (metric classification + source correction).

### F8 — Biology / non-numeric intelligence gap → **ACCEPTED (the most important finding)**
- **Fable finding:** the structure-mining linchpin (relation match, formula normalization, parameter constraints, numeric distractor diffing) is numeric-only; Biology (~919 concepts, critical to NEET, ~0% fill) has no executable lane; the DNA/Item-Model spec describes conceptual archetypes but no executable extraction/verification path for them.
- **Independent verification:** confirmed and sharpened. `QUESTION_DNA_SPECIFICATION.md §8` (construction_model), §14 (extraction linchpin = "relation-match-by-solver-verification"), and §9 (distractor = numeric diff of wrong option vs correct value) are **all numeric-shaped**; the archetype enum (§5) names `cause_effect`, `comparison`, `assertion_reason`, etc., but no section says how a conceptual item's answer is *independently verified*. **Corrected corpus numbers:** active Biology = **525** (Fable's/​memory's "919" is the all-status count including 1,239 rejected + merged; active-only is 525); only **20/525** active Biology concepts carry a definition; **0** active concepts have `common_misconceptions` populated; **230** carry `reference_facts`. But real raw material exists: **2,924** Biology-keyword complete `(1)(2)(3)(4)` MCQ chunks, **1,654** typed `concept_edges` (`related` 1,482 / `parent_child` 162 / `prerequisite` 10). Also note the prerequisite DAG has only **10** edges — so `prerequisite_depth` as a difficulty driver is near-unusable today (a correction to §7 drivers).
- **Repository evidence:** live SQL (this session); DNA/Item-Model specs.
- **Architecture impact:** the architecture is re-founded on **11 explicit structure-intelligence lanes** (§2), each with its own evidence shape, DNA representation, Item Model structure, transformations, difficulty drivers, distractor strategy, **independent-verification strategy**, and originality controls. The key generalization: the numeric "relation library" becomes a broader **Knowledge Verification Substrate** (relation library + assertion base + taxonomy store + sequence store + structure-function map + comparison matrix), so non-numeric correctness is verified deterministically against curated, multiply-sourced, provenance-tracked knowledge plus independent-model corroboration — **not** forced through a math relation model.
- **Documents revised:** `QUESTION_DNA_SPECIFICATION.md` (lanes), `ITEM_MODEL_SPECIFICATION.md` (per-lane moulds), `QUALITY_GATE_SPECIFICATION.md` (per-lane verification), `QUALITY_FIRST_IMPLEMENTATION_ROADMAP.md` (per-lane build order), `CURRENT_VS_REQUIRED_ARCHITECTURE.md`.

### F9 — Multimodal ingestion sequencing (E-lite early) → **ACCEPTED**
- **Fable finding:** the board-acquisition lane is live (171 verified / 227 downloaded PDFs) and the owner is preparing 200-300 more; a minimal ingestion slice must move ahead of full Phase E, or the new corpus is ingested lossy and re-processed later.
- **Independent verification:** confirmed from `curriculum/reports/COVERAGE_MATRIX.md` (227 downloaded / 171 verified, 2026-07-09), on-disk `curriculum/resources/curriculum/{cbse,ap,telangana,icse}/`, and `LICENSE_REPORT.md`; and from the parse/chunk loss points (`phase2_parse.py` extracts images/equations into `parsed/<doc>.json`; `phase4_chunk.py` never reads them; `parsed_documents` INSERT drops even the counts). Raw PDFs are retained locally, so loss is recoverable — but re-ingestion collides with the intake dedup/versioning design and the "360-doc baseline immutable" rule, making "ingest twice" a governance problem, not only compute.
- **Repository evidence:** coverage/licence reports; `phase2_parse.py`/`phase4_chunk.py`.
- **Architecture impact:** define an **E-lite ingestion boundary** (§6/§2) that persists — for newly ingested documents — visual assets, question/option/answer/solution boundaries, equations/tables, and page+bbox provenance, **without** building the parser-routing benchmark or the visual-generation platform. E-lite lands in Phase A alongside foundations; E-full (routing benchmark, SVG generation, DIAGRAM_VISUAL archetypes) stays late.
- **Documents revised:** `MULTIMODAL_INGESTION_ARCHITECTURE.md` (E-lite boundary), `QUALITY_FIRST_IMPLEMENTATION_ROADMAP.md` (phase split).

### F10 — Frozen-engine decision (Engine v2 vs MINIMAL_ENGINE_EXTENSION) → **SUPERSEDED → MINIMAL_ENGINE_EXTENSION**
- **Positions:** original audit said "the content lane is insufficient; a reviewed Engine v2 change set is required"; Fable said `MINIMAL_ENGINE_EXTENSION` with 8 controlled surfaces.
- **Independent verification:** both agree the content lane alone is insufficient (F3 proves it — flawed native families can't be overridden in the content lane) and both agree the boundary/blueprint/template-mechanism/assemble/validation-scaffold are sound and must stay. The disagreement is naming, not substance. "v2" over-signals a rewrite; the required changes are additive, enumerable, and fit one reviewed change set. **Final: MINIMAL_ENGINE_EXTENSION** (§6).
- **Documents revised:** `CURRENT_VS_REQUIRED_ARCHITECTURE.md` (final decision + surface list), `QUALITY_FIRST_IMPLEMENTATION_ROADMAP.md`.

### Additional Fable items carried into the final architecture (condensed)
- **`select._priority` contradicts its docstring** (fill-rank dominates; subject balance is a tie-break) → **ACCEPTED**; fixed as part of surface #3 before Phase D tunes diversity on top of it.
- **Answer/solution artifact asymmetry** (stem-only artifact gates; OCR-glue ships in answer keys) → **ACCEPTED**; new answer/solution artifact gate (surface #2, GATE set).
- **Realization-fidelity gap** (Tier-1 rephrase can drop/alter a parameter, ungated) → **ACCEPTED**; GATE 4 input pinned to the rendered stem + a deterministic realization-fidelity check.
- **Gate over-count (15 → ~11 merged + 2 new)** → **PARTIALLY_ACCEPTED**; the 15-gate *ladder is kept as taxonomy* for clarity, but implementation merges the numeric correctness passes (4/5/12) and the structure-recompute passes (9/10) into shared passes, and adds realization-fidelity + concept-binding-integrity + registration-integrity. Net protection is what matters, not the count.
- **Difficulty drivers over-count / unmeasurable drivers / no per-profile weights** → **ACCEPTED**; drivers split into measurable-now / relocated / deferred, `prerequisite_depth` flagged near-unusable (10 edges), per-profile weight vectors, ordinal bands before scalar.
- **Benchmark under-specified** → **ACCEPTED**; pre-registered thresholds, ≥3 raters, agreement statistic, paired test, machine-gated correctness (§7 / Gold Benchmark revisions).
- **19-archetype vocabulary / testlets / item-sets** → **PARTIALLY_ACCEPTED**; the lane model (§2) subsumes the archetype vocabulary; item-sets (case-study/comprehension/matrix-match) are added as a first-class composite in the DATA_INTERPRETATION and DIAGRAM_VISUAL lanes and paper composition, but their full build is scheduled Tier-C/D, not Phase B.

### Nothing was REJECTED outright
No Fable finding survived re-verification as false. Two were bounded (F7 sharper boundary: canon already
had the field; gate-count is taxonomy-vs-implementation). One (F10) was superseded by a naming decision
both sides' substance already agreed on.

---

## 2. FINAL ARCHITECTURE — the 11 structure-intelligence lanes

The core reconciliation outcome. Assessment intelligence is organized into **lanes**, each an executable
extraction→representation→generation→**independent-verification** pipeline. A lane — not a subject — is the
unit of capability; a subject uses several lanes. The numeric linchpin is **one lane of eleven**, not the
model for all.

**Shared substrate — the Knowledge Verification Substrate (KVS):** the non-numeric analogue of the relation
library. Typed, curated, provenance-tracked, multiply-sourced stores against which answers are checked
deterministically: `relation_library` (equations+dimensions), `assertion_base` (subject–predicate–object
facts with ≥2 independent evidence sources), `taxonomy_store` (class membership), `sequence_store` (canonical
ordered processes), `structure_function_map`, `comparison_matrix` (entity × property). Built by mining
definitions, `reference_facts` (230 populated), `concept_edges` (1,654), and — crucially — the **answer keys
of the 2,924+ Biology / 7,746 total source MCQs**, cross-corroborated. **Correctness for a non-numeric item
is never asserted by a generator; it is entailed by the KVS and independently agreed by a Tier-2 model given
only stem+options.** Disagreement ⇒ reject or quarantine.

For each lane: **Src** = source evidence shape · **DNA** = representation · **IM** = reusable Item Model ·
**Xform** = valid transformations · **Diff** = difficulty drivers (lane-specific) · **Distractor** = wrong-option
strategy · **Verify** = independent verification · **Orig** = originality control.

1. **NUMERIC_RELATIONAL** (Physics, numeric Chemistry, Mathematics)
   - Src: MCQ/problem with quantities+units+answer. DNA: givens/unknown/relation/answer-rule. IM: variable schema + parameter constraints (learned ranges) + `answer_function`. Xform: reparameterize; direct↔reverse↔missing-variable; multi-step compose. Diff: reasoning_steps, calculation_load, algebraic_manipulation, formula-recall burden, representation_shifts. Distractor: recovered transforms (sign/unit/formula-confusion/off-by-constant) applied to fresh parameters. Verify: **relation-match-by-solver** on the rendered stem (independent relation library, not the generator). Orig: no source parameter-tuple reproduced; structural + lexical distance gate.

2. **CONCEPTUAL_CAUSAL** (Biology, Chemistry, Physics theory) — *cause→mechanism→effect*
   - Src: "why/what causes/what results" MCQ + explanatory prose. DNA: `{cause, mechanism, effect, conditions}` triple with evidence. IM: cause↔effect slot template over an `assertion_base` cluster. Xform: forward (given cause, find effect) / reverse (given effect, find cause) / mechanism-identification. Diff: chain length (cause→…→effect hops), prerequisite concepts, misconception_pressure. Distractor: adjacent-cause / correct-effect-wrong-mechanism / reversed-causality (from `concept_edges` + curated confusions). Verify: KVS `assertion_base` entails the key **and** Tier-2 blind-solve agrees; ≥2 independent evidence sources for the asserted cause–effect. Orig: fresh scenario framing from a controlled context library; no source sentence.

3. **CLASSIFICATION_TAXONOMIC** (Biology, Chemistry) — *is-a / belongs-to*
   - Src: "which of these is a/an X", "classify" MCQ. DNA: `{entity, class, discriminating_attributes}`. IM: membership-quiz mould over a `taxonomy_store` node. Xform: positive (pick the member) / negative (pick the non-member) / odd-one-out / attribute-to-class. Diff: taxonomic distance of distractors, attribute subtlety, number of near-siblings. Distractor: sibling classes / superficially-similar non-members (taxonomy neighbors). Verify: deterministic set-membership in `taxonomy_store` (curated, sourced) + Tier-2 agreement. Orig: entity/option sets drawn from the curated taxonomy, never a copied source option list.

4. **PROCESS_SEQUENCE** (Biology, Chemistry) — *ordering of steps/stages*
   - Src: "arrange in order", "what comes after X" (mitosis phases, digestion, reaction steps). DNA: canonical ordered list + step attributes. IM: ordering mould over a `sequence_store` entry. Xform: full-order / next-step / previous-step / insert-missing-step. Diff: sequence length, adjacency subtlety, presence of near-cycles. Distractor: adjacent-swaps / plausible-but-wrong order / off-by-one. Verify: deterministic order check against the canonical `sequence_store` sequence + Tier-2 agreement. Orig: canonical sequence is factual (not copyrightable); framing/labels fresh.

5. **STRUCTURE_FUNCTION** (Biology, Chemistry, anatomy/organelles) — *part↔role mapping*
   - Src: "function of X", "which part does Y". DNA: `{structure, function, location, system}`. IM: structure↔function match/MCQ over `structure_function_map`. Xform: structure→function / function→structure / part-in-system. Diff: map fan-out (one structure many functions), sibling structures. Distractor: functions of sibling structures / plausible-but-wrong role. Verify: deterministic lookup in `structure_function_map` + Tier-2 agreement. Orig: curated map; original stems; diagram (if any) via DIAGRAM_VISUAL lane.

6. **EXPERIMENT_OBSERVATION** (Physics, Chemistry, Biology practical) — *observe→infer*
   - Src: apparatus/observation → conclusion items. DNA: `{setup, variables, observation, valid_inference, controls}`. IM: observation→inference mould; often carries a small readings table (→ overlaps DATA_INTERPRETATION) or a diagram (→ DIAGRAM_VISUAL). Xform: vary observation → change inference; identify controlled variable; predict result. Diff: number of variables, confound presence, inference depth. Distractor: correlation-as-causation / ignored-control / wrong-variable. Verify: numeric inference by recomputation; qualitative inference by KVS rule + Tier-2. Orig: synthetic apparatus parameters; original observation values.

7. **DIAGRAM_VISUAL** (Physics, Biology, Geometry, Chemistry) — *read/label a figure* (Phase E-full)
   - Src: figure-dependent item. DNA: visual_type + measurable_values + `answerable_without_visual`. IM: semantic-visual-spec generator + reader. Xform: re-parameterize the figure; label / read-value / interpret. Diff: reading load, clutter, number of labels. Distractor: adjacent-label / misread-value. Verify: **GATE 11** — `answer_function` reads the spec, not pixels; spec↔stem↔answer agreement. Orig: deterministic SVG from a fresh spec; never a traced source image. **Diagram-locked source items with no regenerable spec are excluded, not converted to text.**

8. **COMPARATIVE** (all subjects) — *compare entities across attributes*
   - Src: "difference between", "which has higher X" items. DNA: `{entities[], attribute, ordering/relation}`. IM: comparison mould over a `comparison_matrix` (entity × property). Xform: pick-higher/lower / true-difference / shared-property. Diff: attribute subtlety, entity similarity, number of compared attributes. Distractor: true-of-one-entity-not-the-asked / reversed-comparison. Verify: deterministic cell lookup in `comparison_matrix` (curated, sourced) + Tier-2. Orig: matrix is factual; option framing fresh.

9. **MISCONCEPTION_DIAGNOSTIC** (all subjects) — *the distractor is the assessment*
   - Src: MCQs whose wrong options encode named misconceptions. DNA: `{correct_concept, misconception_set, trigger}`. IM: distractor-first mould — the misconception options are primary, the key is the non-misconception. Xform: swap the tested misconception; vary surface. Diff: misconception_pressure, closeness of the trap. Distractor: **the curated misconceptions themselves** (this lane is where distractor DNA is richest; it feeds all other lanes' distractor generators). Verify: key is the KVS-entailed truth; each distractor is a *known* misconception (typed, sourced); Tier-2 confirms the key is uniquely correct and each distractor is genuinely wrong. Orig: misconception library is analytical (L2); options phrased fresh. **This lane is the primary remedy for "arithmetic-noise distractors" and the seed for non-numeric distractors.**

10. **ASSERTION_RELATION** (all subjects) — *the corrected AR lane*
    - Src: 787 real AR chunks + any two KVS facts with a known explanatory relation. DNA: `{assertion_fact, reason_fact, truth(A), truth(R), explains(R,A)}` — each field **independently established from the KVS**. IM: AR mould that **samples the target relation class** — (A✓R✓ explains), (A✓R✓ ¬explains), (A✓ R✗), (A✗ R✓) — and selects facts to realize it. Xform: swap relation class; vary the fact pair. Diff: subtlety of the explanation relation, plausibility of the false statement. Distractor: the four fixed AR options (unavoidable format) with **seed-rotated order AND semantically varied correct class** — so the key is not constant. Verify: three independent checks — truth(A), truth(R), explains(R,A) — each against the KVS + Tier-2; the AR key is *derived* from these, never hard-coded. Orig: A/R sentences authored fresh from KVS facts. **This replaces the four hard-coded `_ar_family` templates and structurally fixes F2.**

11. **DATA_INTERPRETATION** (all subjects) — *read a table/graph, compute/infer* (table now; graph in E-full)
    - Src: table/graph + question. DNA: `{data_spec, quantity_asked, extraction+operation}`. IM: data-table generator + reader mould (tables preserved today as `block_type='table'`). Xform: re-populate data; change the asked quantity; single vs multi-cell. Diff: cells to read, operation complexity, distractor closeness. Distractor: read-wrong-cell / right-cell-wrong-operation / trend-misread. Verify: recompute the answer from the generated data spec (deterministic). Orig: synthetic data; original table; graph via DIAGRAM_VISUAL.

**Lane readiness / build order:** Tier-A now (deterministic-verifiable, corpus-rich): NUMERIC_RELATIONAL,
DATA_INTERPRETATION(table), MISCONCEPTION_DIAGNOSTIC. Tier-B next (KVS-backed conceptual): CONCEPTUAL_CAUSAL,
CLASSIFICATION_TAXONOMIC, PROCESS_SEQUENCE, STRUCTURE_FUNCTION, COMPARATIVE, ASSERTION_RELATION. Tier-C
(visual, Phase E-full): DIAGRAM_VISUAL, graph-based DATA_INTERPRETATION, EXPERIMENT_OBSERVATION. **A lane
ships only after it passes the gold benchmark for that lane** — capability is per-lane, benchmark-gated, not
declared by the code path existing.

---

## 3. FINAL ROOT CAUSE

Unchanged in spirit, sharpened in scope: **the engine measures constraint compliance, not educational
quality, and the pipeline discards at ingestion the very structure quality requires — and the one generative
lane it does have is numeric-only.** Three compounding causes, all code-verified:
1. **No item model / no quality representation** (`QuestionSlot` carries flat strings + bare labels; quality
   is unrepresentable, so ungeneratable and unmeasurable).
2. **Structure destroyed at Phase 7** (14k detected problems → `(concept,type,bloom,difficulty)` frequency
   tuples; `distractors`/`question_templates` wiped; images/equations dropped at the parse→chunk boundary;
   answer keys ship raw OCR-glued definition text).
3. **The only generative capability is a single numeric archetype** (88/94 single-formula substitution;
   AR semantically constant; distractors arithmetic noise; concept binding by keyword substring), which
   **structurally cannot serve Biology / non-numeric science** — the largest corpus slice and half of NEET.
The fix is the lane architecture (§2) + item models + independent verification gates + benchmark-gated
scaling — **not** more definitions and not a prompt patch.

---

## 4. FINAL ENGINE FREEZE DECISION — `MINIMAL_ENGINE_EXTENSION`

One reviewed, additive change set with its own regression gate (frozen matrix green + golden tests). Not a
rewrite; not content-lane-only (F3 proves the content lane cannot retire flawed native families or add
gates). Exact surfaces allowed to change — **everything else in `kie/qpgen/` stays frozen**:

| # | Surface (file) | Change |
|---|---|---|
| 1 | `qpgen/models.py` | ADD to `QuestionSlot`: `item_model_id`, `lane`, `difficulty_drivers`, `gate_verdicts`, structured `solution_steps` |
| 2 | `qpgen/validate.py` | ADD educational gate ladder (blind-solve/answer-correctness, distractor plausibility, ambiguity, difficulty-driver, cognitive, originality-incl-structural, item-writing incl. AR semantic key-constancy, **concept-binding integrity**, **realization fidelity**, **answer/solution artifact**); REMOVE the template grounding exemption once concept-scope binding lands (F5) |
| 3 | `qpgen/select.py` | ADD lane/archetype + exposure diversity terms and within-paper family cap; FIX `_priority` order to match documented intent |
| 4 | `qpgen/pool.py` | REMOVE hard-coded `LONG_ANSWER → HARD/ANALYZE`; labels flow from item-model difficulty bands |
| 5 | `qpgen/templates.py` | ADD explicit registry priority + **family retirement/versioning** (ext may supersede/retire native by id/binding); RETIRE the 4 hard-coded `_ar_family` templates in favor of the ASSERTION_RELATION lane; **concept-code-exact binding** for item-model families; **registration-time structural-integrity check** (unique id, unique generator, no unintended overlap, no bare-single-word binding for new families) |
| 6 | `qpgen/materialize.py` | REPLACE `spec_of` with the full generation contract; ADD realization-fidelity check + structured solutions + answer-key artifact gating |
| 7 | `qpgen/assemble.py` | ADD within-paper rendered-stem structural dedup (F4) + key-position balance |
| 8 | Ingestion phases `phase2/phase4(/phase7)` — **separately scoped, outside the qpgen freeze** | E-lite persistence (visual assets, question/option/answer/solution boundary block types, offsets/bbox, equations/tables); retire the Phase-7 structure wipe once the DNA store supersedes it |

Frozen and untouched: `scope.py`, `blueprint.py`/`blueprints.py`, `chapters.py`, `sanitize.py`,
`engine.py` orchestration, the frozen `qp_output_audit.py` matrix. The two outright bugs (F4 dedup, F6
shadowed generator) are fixed regardless of program approval.

---

## 5. PSYCHOMETRIC METRIC CLASSIFICATION (respecting D1/D2/D6)

| Metric | Class | Source / condition |
|---|---|---|
| p-value (item facility) | **SUPPORTED_NOW** (once the marks-grid spine is seeded, Phase F) | marks-grid: correct/incorrect per question |
| blank_rate | **SUPPORTED_NOW** | marks-grid: attempted vs blank per question |
| discrimination (upper-lower) | **SUPPORTED_NOW** | marks-grid: per-item score + total score |
| point-biserial | **SUPPORTED_NOW** | marks-grid: per-item score correlated with total |
| IRT (Rasch→2PL→3PL) | **SUPPORTED_NOW, volume/fit-gated** | marks-grid dichotomous data; only when N + fit justify |
| distractor_selection_frequency | **FUTURE_ONLY (digital-practice channel)** | needs `chosen_option` — captured *only* by in-app DPP/practice (AIP §6.4); never from the marks grid |
| distractor_efficiency | **FUTURE_ONLY (digital-practice channel)** | derived from option-level selection; same source constraint |
| response time / speededness | **FUTURE_ONLY (digital-practice channel)** | `time_spent_ms` from digital attempts only |

**REQUIRES_RESPONSE_SCHEMA_EXTENSION: none** — the canonical `edu_student_item_responses.chosen_option`
field already exists (AIP §10.1); the gap is the *data channel* (digital practice, Phase 2+), not the schema.
**Predicted difficulty** (from measured drivers) is available at generation and is always labeled
`predicted`, never presented as an empirical statistic. **No LLM ever writes an empirical field.**

---

## 6. FINAL PHASE ORDER

```
Phase 0  Kill test           — Hypothesis A (mining yield) + Hypothesis B (item-model quality spike).
                               Content-lane + throwaway; NO schema, NO engine change. §7 gates. STOP if either fails.
Phase A  Foundations + E-lite — DNA store (lane-typed) + item-model/distractor/generated_items stores +
                               KVS v0 (relation library + assertion-base seed); pre-registered benchmark harness;
                               inert engine-v2 seam; E-LITE ingestion boundary for the incoming 200-300 PDFs
                               (persist visuals/boundaries/provenance; no routing benchmark, no SVG). Matrix green.
Phase B  Structure mining     — DNA + Item Models per lane. Tier-A lanes first (numeric, table-data,
                               misconception), then Tier-B KVS lanes (causal, taxonomic, sequence,
                               structure-function, comparative, assertion-relation). Per-lane benchmark gate.
Phase C  Quality gates         — independent blind solve, concept-binding integrity, family-equivalence dedup,
                               distractor plausibility, difficulty-driver, AR semantic, realization fidelity,
                               originality (structural). Injected-defect tests.
Phase D  Paper intelligence    — lane/archetype/difficulty/exposure diversity; within-paper + family-equivalence
                               dedup; key-position balance. Clone-rate collapse + paper-level benchmark.
Phase E-full Multimodal+visual — parser-routing benchmark; visual generation (semantic SVG); DIAGRAM_VISUAL,
                               graph DATA_INTERPRETATION, EXPERIMENT_OBSERVATION lanes. Zero silent diagram loss.
Phase F  Psychometrics         — marks-grid spine (seeded from A); CTT (§5 SUPPORTED_NOW); IRT volume-gated;
                               distractor telemetry only if/when the digital-practice channel exists.
```
E-lite moved into A (was inside the old Phase E). E-full stays late. F seeds in A, fills post-data. Every
phase that adds generative capability ends on a blind gold-benchmark round for the affected lanes/cells.

---

## 7. PHASE-0 ACCEPTANCE GATES (pre-registered; both hypotheses must pass)

Pre-register the sample, rubric, thresholds, and analysis plan in a committed file **before** running.
Use test counts as evidence of nothing; "looks better" as evidence of nothing.

**HYPOTHESIS A — Structure-mining yield.** Random discovery-split slice, ≥200 source items per subject
across {Physics numeric, Chemistry numeric+conceptual, Mathematics, **Biology non-numeric**} (≥800 total).
Measure & report honestly: items inspected; complete-item recovery; concept-mapping confidence; DNA
extraction success; independent-verification success; reusable Item Models discovered; equivalent families
collapsed; rejected structures + reasons; held-out generalization; originality/source distance. **Pass gates:**
- Complete-item recovery ≥ **60%** numeric subjects, ≥ **45%** Biology (lower bar acknowledged; below ⇒ ingestion is the blocker → E-lite must precede mining).
- **Independent-verification success ≥ 40%** of recovered numeric items (relation-match-by-solver) AND ≥ **30%** of recovered Biology items (KVS entailment + Tier-2 agreement). *If numeric < ~40%, mining economics collapse → STOP and reassess.*
- ≥ **8 distinct-lane/archetype Item Models per subject**, each distilled from ≥ **K=5** distinct DNA drawn from ≥ **2** distinct resources (anti-clone/anti-copy floor).
- Held-out: ≥ **70%** of items generated for held-out concepts pass all deterministic gates.
- Originality: **0** generated items within the similarity threshold (structural parameter-tuple + lexical n-gram + semantic embedding) of any source item.

**HYPOTHESIS B — Item-model quality spike.** Hand-build **6-10 Item Models** on the final schema spanning
≥4 lanes, mandatorily including ≥2 **Biology non-numeric** (CONCEPTUAL_CAUSAL / CLASSIFICATION_TAXONOMIC /
STRUCTURE_FUNCTION), ≥1 **ASSERTION_RELATION** (truth-table varied), ≥1 numeric multi-step, ≥1
MISCONCEPTION_DIAGNOSTIC. Generate blind samples; interleave with current-engine items and gold anchors;
≥3 independent practicing teachers; pre-registered rubric. **Pass gates:**
- **Absolute bar:** Engine-B median ≥ **4/5** on correctness, syllabus_alignment, concept_precision, ambiguity (ambiguity reverse-scored).
- **Lift:** Engine-B median **exceeds Engine-A by ≥ 1.0 rubric point** on cognitive_depth, distractor_quality, difficulty_accuracy, and solution_quality, **paired Wilcoxon p < 0.05**.
- **No regression:** Engine-B ≥ Engine-A on correctness, syllabus_alignment, ambiguity.
- **Agreement:** Krippendorff's α ≥ **0.6** on the gated dimensions (else re-anchor the rubric; do not average low-agreement scores).
- **Biology-specific:** the Biology non-numeric items independently reach the absolute bar (correctness ≥4, distractor_quality ≥4) — Biology is the make-or-break; a pass elsewhere with Biology failing is a **fail**.
- Correctness is **machine-gated (GATE 4) before review**; teachers adjudicate only genuinely contested items — they do not certify correctness by opinion.

**Kill rule:** if Hypothesis A misses the independent-verification floor **or** Hypothesis B misses the
absolute bar, the lift test, the agreement floor, or the Biology-specific bar → **STOP; reassess the
architecture before any Phase-A schema or engine work is funded.** Both must pass to proceed.

---

## 8. UNRESOLVED RISKS (carried forward for owner visibility)

1. **KVS construction cost/quality (Biology make-or-break).** The assertion/taxonomy/sequence/structure-
   function stores must be built from a corpus where only 20/525 Biology concepts have definitions, 0 have
   misconceptions populated, and several "active" concepts are OCR junk ("Aelangelang", "Amazing fact").
   Phase-0 Hypothesis A directly measures whether the KVS can be mined at the ≥30% Biology floor; if not,
   Biology needs a curated-knowledge acquisition effort (owner-scoped), not just mining.
2. **Concept-quality debt underneath everything.** ~4/15 sampled active concepts are noise or mis-tagged;
   the Ohm duplicate pair (F4) is one instance. Family-equivalence dedup treats the symptom; a concept-
   canonicalization pass (merge/reject) is a prerequisite the roadmap must schedule, not assume.
3. **Relation-library / KVS coverage bounds Phase-B yield** and is weeks of expert curation priced at zero
   in effort terms; Phase-0 measures it, but the estimate gap remains until it does.
4. **Teacher-review operational pipeline** (A2 `TEACHER_VALIDATED` at scale) — the benchmark plan covers
   episodic review; a standing certification workflow (who, in what tool, tracked where) is undesigned.
5. **Blindness limits of the benchmark** — Engine-A's style is recognizable; the scale decision leans on the
   absolute bar vs gold anchors, with beat-Engine-A secondary. Residual reviewer bias remains a known limit.
6. **Digital-practice channel dependency** for all distractor telemetry — until in-app DPP exists (Phase 2+),
   distractor efficiency is unverifiable from real data; predicted plausibility (GATE 7) is the only signal.
7. **Program cost opacity** — no per-phase effort estimates yet; benchmark gates exist but the owner cannot
   fully sequence-cost the program until Phase-0 returns the yield/lift numbers.
8. **E-lite vs intake-immutability governance** — pulling ingestion forward for the incoming PDFs must
   reconcile with the "360-doc baseline immutable" rule; treated as additive/versioned, but the governance
   edit is a real, owner-visible decision.

---

## 9. Record hygiene corrections (for the audit trail)

- Template split **52 native + 42 ext = 94** (not 46+42).
- Active Biology = **525** (all-status 919 includes 1,239 rejected + 31 merged).
- `formulas` = **317** rows live (audit-era doc said 281 — post-audit growth); still 0 equations.
- `question_patterns` = **4,853** rows; `distractors`/`question_templates` = **0** (wiped every Phase-7 run).
- Prerequisite `concept_edges` = **10** (so `prerequisite_depth` is near-unusable as a difficulty driver now).
- Definition coverage 57/1,736 = 3.3% (only 43 are ≥50 chars).
- Citation precision: **Rule 7** lives in AIMS (`ASSESSMENT_INTELLIGENCE_MASTER_SPECIFICATION.md`), **L1/L2/L3**
  in `GAP_ANALYSIS.md` D-3, **not** in AIP v3.0; **A2 / I9 / D-7** are owner-**direction**-approved (2026-07-08)
  but **not ratified**; D6's N=100 promotion threshold is explicitly "initial, tunable" (AIP §17 O-D, open).
- "76% clone" (272/357) and "Phase-7 structure loss" are **two different audits** measuring two different
  failure modes (paper-assembly diversity vs corpus structure loss) — both real, cited separately.

---

*This record modifies none of the pre-existing analysis in the original 11 deliverables' bodies except the
in-place corrections and amendment blocks enumerated per finding above. It supersedes the standalone Fable-5
review only where §1 marks a finding SUPERSEDED/PARTIALLY_ACCEPTED. No implementation is authorized. Owner
approval is required before Phase 0 begins (see the presentation summary).*
