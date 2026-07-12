# Item Model Specification

**Date:** 2026-07-11 · **Status:** SPEC (proposal — not implemented)
**Layer:** L3 generative mould. Produces original, solver-verified, certified questions.
**Relationship:** distilled from many Question DNA objects (`QUESTION_DNA_SPECIFICATION.md`); is the
**A2 "certified family"** made concrete; extends the empty `question_templates` table; registers into the
engine through the sanctioned `templates_ext` hook where it stays within the current archetype, and
through a scoped engine change where it introduces new archetypes.

---

## 1. What an Item Model is (and is not)

An **Item Model is a reusable assessment mould** — a parametric family that generates unlimited original
instances of *one archetype testing one construct*. It is **not** a question and **not** a wording
variant. Two questions that differ only in phrasing belong to the **same** Item Model; two questions that
differ in cognitive structure (direct vs reverse vs graph) are **different** Item Models even for the same
concept.

This is the fix for the core diversity failure. Today the engine's 88 single-substitution templates are,
in effect, 88 instances of *one* Item Model archetype. The target is genuine structural diversity: for a
single concept like Ohm's Law, distinct Item Models —
```
IM-OHM-DIRECT        find V given I,R              (single_step_numerical)
IM-OHM-MISSING-R     find R given V,I              (reverse_numerical)
IM-OHM-GRAPH         read slope of a V-I graph     (graph_interpretation)
IM-OHM-CIRCUIT       series/parallel sub-network   (multi_step_numerical)
IM-OHM-MISCONCEPTION trap: V∝1/I confusion         (misconception_detection)
IM-OHM-MULTISTEP     V=IR then P=VI                 (multi_concept_integration)
IM-OHM-EXPERIMENT    infer from a readings table   (experiment_inference)
```
— each a separate mould with its own difficulty-driver profile, distractor generators, and solution
strategy. The engine gains diversity by having many *moulds*, not many *strings*.

---

## 2. Schema

```jsonc
ItemModel {
  item_model_id,
  concept_scope[],            // concept_code(s) this model tests
  assessment_construct,       // the LO/competency measured (from DNA §4)
  archetype,                  // one of the controlled vocabulary (DNA §5)
  cognitive_operation_chain,  // ordered operations (DNA §6)
  difficulty_driver_profile,  // target ranges per driver → predicted difficulty band (DNA §7)
  stem_structure,             // parametric stem skeleton with typed slots (NOT source wording)
  variable_schema,            // {symbol, type, unit, role}
  parameter_constraints,      // ranges (learned from DNA §8) + relational constraints
  dependency_rules,           // derivation order among variables
  answer_function,            // deterministic: params → answer (+ units)  [the solver]
  distractor_generators[],    // each: {misconception_type, transform, applicability}  (from DNA §9)
  visual_generator,           // nullable: semantic visual spec (VISUAL spec) for diagram archetypes
  solution_strategy,          // structured step template (DNA §10)
  allowed_profiles[],         // NEET | JEE_MAIN | JEE_ADVANCED | CBSE_X | FOUNDATION | ...
  forbidden_combinations,     // parameter combos that are trivial/degenerate/out-of-syllabus
  certification_status,       // draft | ai_validated | teacher_validated | certified  (A2 lifecycle)
  provenance                  // #DNA distilled from, licence classes, evidence strength
}
```

### 2.1 Mapping onto existing empty tables (reuse, don't recreate)

| ItemModel field | Storage |
|---|---|
| stem_structure, variable_schema, parameter_constraints, answer_function ref, difficulty band | `question_templates` (currently empty — this is its intended purpose) |
| distractor_generators | `distractors` (currently empty) — with `misconception_type` |
| concept_scope, construct, certification_status | `question_families` (repurpose the 2,015 draft rows) |
| answer_function relations | `formulas` (extended with real `expression`/`symbols`) |
| generated instances + verdicts | `generated_items` (schema exists, currently empty) |

The dormant Postgres `edu_question_families` / `edu_question_templates` / `edu_distractors` mirror already
matches this shape (from the docs audit) — the SQLite store stays the working copy per the local-storage
decision.

---

## 3. How Item Models are built (clustering, not copying)

```
many QuestionDNA (same concept + same archetype + compatible construction model)
  → cluster by structural signature (archetype + operation chain + relation used)
  → derive variable_schema from the shared givens/unknown
  → derive parameter_constraints from the UNION of observed real value ranges (DNA §8)
  → derive answer_function from the shared answer_generation_rule, expressed against the relation library
  → derive distractor_generators from the RECURRING misconception transforms across the cluster (DNA §9)
  → derive difficulty_driver_profile from the cluster's measured drivers (DNA §7)
  → author the stem_structure as an ORIGINAL parametric skeleton (typed slots; no source sentence)
  → certification lifecycle (A2): draft → ai_validated → teacher_validated → certified
```
Key properties:
- **Structure is learned; wording is authored fresh.** No source sentence is reused — satisfies D8 / Rule 7
  and the mission's anti-paraphrase rule.
- **Parameter ranges are grounded in real observed values**, so instances are realistic (not the current
  arbitrary `2..20`).
- **Distractors are grounded in real recurring misconceptions**, not arithmetic noise.
- **Every instance is independently solver-verified** at generation (GATE 4-5), so correctness does not
  depend on the authoring being perfect.

---

## 4. Generation from an Item Model (the contract)

An Item Model turns a fully-specified **generation contract** into an instance. The engine decides
everything structural; the model (if used) only realizes language.

```
GenerationContract (engine-built) {
  item_model_id, concept, profile, target_difficulty_band, seed,
  chosen_parameters (constraint-solved),  computed_answer (answer_function),
  distractor_intents[] (which misconceptions to instantiate),  visual_spec (if any),
  solution_step_scaffold
}
   → language realization:
        Tier 0: deterministic stem_structure fill (no model)          ← default, current path
        Tier 1: small model rephrases for age/context variation       ← optional, benchmarked
   → INDEPENDENT SOLVE (GATE 4-5) → distractor/ambiguity/flaw/difficulty gates → originality gate
   → certified instance persisted to generated_items with its verdicts
```
Contrast with today's AI contract (`materialize.spec_of`), which hands the model only labels and asks it
to invent the assessment. Here the assessment logic is settled before the model sees anything; the model's
failure modes (wrong answer, bad distractor, mislabeled difficulty) are structurally prevented or caught.

---

## 5. Archetype coverage targets

The engine must eventually support the full archetype vocabulary. Priority order (by achievability with
the existing corpus + deterministic verifiability):

**Tier A — deterministic-verifiable now (build first):**
single_step_numerical (exists), reverse_numerical, missing_variable_inference, multi_step_numerical,
multi_concept_integration, property_application.

**Tier B — needs distractor/misconception DNA (build with structure-mining):**
misconception_detection, comparison, cause_effect, assertion_reason (with position randomization —
fixes the always-(a) flaw), error_analysis, definition_recognition (upgrade existing).

**Tier C — needs visual/table intelligence:**
graph_interpretation, table_interpretation, diagram_interpretation, experiment_inference.

**Tier D — needs richer language + expert review:**
case_interpretation (case-study), constraint_reasoning, HOTS/Olympiad where the profile permits.

Each archetype ships only when it passes the gold benchmark for that archetype — not because the code path
exists.

---

## 6. Difficulty and the driver profile

An Item Model declares a **target difficulty band** as a region in driver-space (not a single label). A
generated instance is accepted for that band only if its *measured* drivers fall in range (GATE 9). This
is what finally makes "hard" mean something: a HARD Item Model must actually require more reasoning steps /
concept integration / misconception pressure than an EASY one, and every instance is checked.

Same-concept Item Models across bands give the paper real difficulty control — e.g. IM-OHM-DIRECT (easy)
vs IM-OHM-CIRCUIT-MULTISTEP (hard) — instead of one template relabeled.

---

## 7. Certification (A2 alignment)

Item Models follow the A2 family-certification lifecycle exactly:
```
draft → ai_validated (passes all deterministic + independent-solve gates on K sampled instances)
      → teacher_validated (blind expert review sample passes, GOLD_BENCHMARK_PLAN)
      → certified (runtime may instantiate deterministically, AI-free, per I9)
```
A certified Item Model produces unlimited runtime instances with **zero runtime AI** (I9): parameters
constraint-solved, answer solver-verified, distractors from certified generators, boundary-clean. Runtime
never mints uncertified content and never calls a model — the intelligence was spent once, offline, at
certification.

---

## 8. Acceptance criteria for the Item Model layer

- A concept with sufficient DNA yields **multiple distinct-archetype** Item Models, not one.
- Every certified Item Model: (a) generates K instances all independently solver-correct; (b) every
  instance's measured difficulty drivers fall in the declared band; (c) distractors carry a
  `misconception_type` and pass plausibility (GATE 7); (d) AR/position-bias flaws are structurally
  impossible (randomized keys); (e) 0 runtime LLM tokens.
- Diagram-archetype Item Models carry a working `visual_generator` or are not certified.
- Blind expert review (benchmark) rates certified-model output at or above the target quality bar before
  the model is allowed to scale.

---

## Reconciliation Amendment (2026-07-12, post-Fable-5)

Governed by `OPUS_FABLE_RECONCILIATION_RECORD.md`. Item Models are **per-lane** (Record §2) — a numeric
`answer_function` is the NUMERIC_RELATIONAL/DATA lane only; conceptual lanes carry a KVS-backed
`verification_ref` (assertion_base / taxonomy_store / sequence_store / structure_function_map /
comparison_matrix) instead of an equation. **Anti-clone safeguards, now mandatory (this spec previously
risked a sophisticated clone generator):**

- **Minimum evidence bar to promote a cluster to an Item Model:** ≥ **K=5** distinct DNA drawn from ≥ **2**
  distinct resources. A 1-2-DNA "cluster" is memorization of a specific source item (an *originality*
  risk, not just a diversity one) and is rejected. Report the honest cluster-size distribution.
- **Algebraic/semantic equivalence normalization** is part of clustering: CAS-normalized relation identity
  for numeric lanes, KVS-canonical fact identity for conceptual lanes, so algebraic twins do not inflate
  "diversity" (the current 88-templates-one-archetype failure must not recur one level up).
- **Concept binding is `concept_scope[]` of canonical `concept_code`s** — never keyword substring. A
  generated item whose bound concept is not in `concept_scope` is rejected (concept-binding-integrity gate).
- **Difficulty bands declare per-driver widths** and must be shown to discriminate on K sampled instances,
  else the band is decorative.
- **Versioning + retirement:** each Item Model carries a `version`; a superseded model is retired but its
  version is retained on every `generated_items` row it produced (for exposure/statistics lineage);
  Phase-2 `flagged` psychometrics trigger re-certification or retirement.
- **Registry integration:** item-model families register with **explicit priority** and may **supersede or
  retire** native families by id/binding (fixes native-precedence, Record F3); registration runs a
  **structural-integrity check** (unique id, unique generator, no unintended binding overlap, no bare
  single-word binding — catches the shadowed-generator class, Record F6).
- **ASSERTION_RELATION mould** samples the target relation class and realizes it from KVS facts (replaces
  the four hard-coded `_ar_family` templates); **MISCONCEPTION_DIAGNOSTIC mould** is distractor-first and
  supplies typed misconception generators to the other lanes.
