# Question DNA Specification

**Date:** 2026-07-11 · **Status:** SPEC (proposal — not implemented)
**Layer:** L2 (analysis/reference intelligence). Copyright-safe: stores *structure*, never source wording.
**Relationship:** Question DNA is the input to Item Models (`ITEM_MODEL_SPECIFICATION.md`). It is
extracted from source questions and student-response evidence; it is **not** a production question.

---

## 1. Why a new object (not an extension of what exists)

The current `question_patterns` row is `mcq|bloom=understand|difficulty=hard|options=4` — a 4-field
metadata string (`phase7_questions.py:125`). It captures *that a shape occurred*, not *how the question
works*. The current `QuestionSlot` (`models.py:124-143`) is a rendered instance — stem/options/answer as
flat strings. Neither can hold the analysis a quality engine needs: the cognitive chain, the difficulty
drivers, the construction schema, the distractor strategies, the visual dependency.

Question DNA is therefore a **new, separate object**. Separation is deliberate and threefold:
- from **source wording** — DNA never stores the copyrighted sentence, only its abstracted structure
  (satisfies Rule 7 / D8; the mission's "do not solve copyright by synonym replacement");
- from the **production item** — DNA is analysis; a generated `QuestionSlot` is output;
- from the **generative mould** — one Item Model is distilled from many DNA objects.

---

## 2. Top-level shape

```jsonc
QuestionDNA {
  dna_id,                       // stable hash of the structural signature (NOT of source text)
  provenance,                   // resource_id, page, bbox, question_number, license_status, extraction_confidence
  identity,                     // §3
  assessment_construct,         // §4
  archetype,                    // §5 (controlled vocabulary)
  cognitive_operations,         // §6 (ordered chain)
  difficulty_drivers,           // §7 (measured vector)
  construction_model,           // §8 (givens/unknown/constraints/answer rule)
  distractor_dna,               // §9 (per wrong option)
  solution_dna,                 // §10
  visual_dna,                   // §11 (nullable)
  quality_flags,                // §12 (why this DNA may be unusable — OCR damage, diagram-locked, etc.)
  source_class                  // OFFICIAL_AUTHORITATIVE | OPEN_LICENSED | ... (licence ledger; §13)
}
```

Persisted in a new local (gitignored) store, mirroring the dormant Postgres shape where one exists.
Fields below marked **(derived)** are computed deterministically; **(model)** may use a Tier-2 model at
*extraction time only* (never runtime), with the result independently checkable.

---

## 3. IDENTITY

```
board_or_profile         // NEET | JEE_MAIN | JEE_ADVANCED | CBSE_X | ... (from resource metadata)
class_or_grade_band
subject                  // Physics | Chemistry | Biology | Mathematics
chapter, topic, subtopic
canonical_concept        // resolved to concept_code (reuse phase6 concept resolver)
prerequisite_concepts[]  // from concept_edges prerequisite DAG (phase6_graph)
```
Concept resolution reuses the existing `phase6_graph.mentions()` resolver; prerequisites reuse the
DAG-validated `concept_edges`. No new concept infrastructure.

---

## 4. ASSESSMENT CONSTRUCT

The thing the item actually measures — absent entirely today.
```
learning_outcome          // e.g. "apply V=IR to find an unknown quantity in a single resistor"
competency                // curriculum competency code where a mapping exists (concept_board_mappings)
evidence_required         // what a correct response demonstrates the student can do
skill_measured            // single skill, stated concretely
```
This is what lets us later ask "does this paper cover the constructs, not just the chapters?"

---

## 5. ARCHETYPE (controlled vocabulary)

Exactly one archetype per DNA, from a fixed enum (extensible only by governance):
```
direct_recall, definition_recognition, property_application,
single_step_numerical, multi_step_numerical, reverse_numerical, missing_variable_inference,
misconception_detection, comparison, cause_effect, assertion_reason,
case_interpretation, experiment_inference, graph_interpretation, table_interpretation,
diagram_interpretation, error_analysis, constraint_reasoning, multi_concept_integration
```
Today's engine can express ~2 of these (single_step_numerical, definition_recognition). The archetype is
the primary axis of the diversity the mission demands and the primary lever for cognitive depth.

---

## 6. COGNITIVE OPERATIONS (ordered chain)

Not a single Bloom label — the actual ordered operations a solver performs.
```
operations: [identify, recall, substitute, transform, compare, infer, eliminate,
             sequence, model, calculate, verify, generalize]   // ordered, repeatable
example (Ohm's-law reverse):
  identify(quantity sought) → select(relation V=IR) → transform(R=V/I)
  → substitute(values) → calculate → verify(units)
```
`bloom` is retained as a **derived roll-up** of this chain (for backward-compat with blueprints), but the
chain is the source of truth. The number and type of operations feed the difficulty drivers (§7) and are
independently checkable against a generated instance (GATE 10).

---

## 7. DIFFICULTY DRIVERS (measured vector — replaces the Easy/Medium/Hard heuristic)

Each driver is a small non-negative integer or scalar, **measured**, not asserted:
```
reasoning_steps            // count of cognitive operations that are not identify/recall
concept_count              // distinct concepts required
prerequisite_depth         // max depth in the prerequisite DAG
representation_shifts       // e.g. words→equation, graph→value, table→ratio
information_density
irrelevant_information      // presence/among of distracting givens
calculation_load            // arithmetic/algebraic operation count
algebraic_manipulation      // 0..n, rearrangement complexity
hidden_constraint           // boolean/score
misconception_pressure      // strength of the trap the distractors exploit
option_similarity           // numeric closeness / conceptual proximity of options
visual_interpretation_load
abstraction_level
context_novelty
```
**Predicted difficulty** = a deterministic function of this vector (weights fixed and versioned;
`PSYCHOMETRIC_CALIBRATION_SPECIFICATION.md` §3). This is the quantity a generated instance is checked
against in GATE 9 — the label can finally be *verified*, not just stamped.

---

## 8. CONSTRUCTION MODEL

The parametric skeleton — the bridge from DNA to an Item Model's generator.
```
givens[]              // {symbol, quantity, unit, role: input|constant|context}
unknown               // {symbol, quantity, unit}
constraints[]         // e.g. v < c; integer answer; a,b,c a Pythagorean triple
variable_roles        // which givens vary, which are fixed
parameter_ranges      // observed ranges from REAL source values (grounds realistic parameterization)
dependency_graph      // which quantity derives from which
invariant_relationships
transformation_rules
answer_generation_rule // the relation/algorithm that yields the answer (→ Item Model answer_function)
```
`parameter_ranges` is learned from the actual numbers in source problems (not guessed) — this is what
makes generated parameters realistic instead of the current hard-coded `_p(cc,s,"m",2,20)` bounds.

---

## 9. DISTRACTOR DNA (per wrong option)

The single most under-exploited asset in the corpus. Every real MCQ ships 3 human-authored distractors =
3 validated misconceptions. Today all ~15,000 are discarded.
```
per distractor:
  misconception_type  ∈ { sign_error, unit_conversion_error, formula_confusion,
                          partial_calculation, inverse_relation, wrong_concept,
                          boundary_case_error, arithmetic_slip, observation_confusion,
                          overgeneralization, off_by_constant (e.g. g=10 vs 9.8), dropped_factor }
  transform           // the operation on the correct answer that yields this distractor
                      //   (recovered by diffing wrong option vs correct value)
  plausibility_prior  // how often chosen (if response data available; else null)
```
The transform is recovered deterministically by comparing each wrong option to the correct value (e.g.
"×2", "dropped sin²", "used g=10"). This yields a **grounded distractor generator** for the Item Model —
never a random near-miss.

---

## 10. SOLUTION DNA

```
key_insight            // the one idea that unlocks it
strategy               // named approach
ordered_steps[]        // structured (identify → apply → compute → answer → verify)
relations_used[]       // formulas/rules (link to the relation library)
common_mistake         // the mistake the distractors punish
shortest_valid_solution
alternative_method     // where genuinely useful (nullable)
```
This becomes the teacher-friendly 4-5 step solution at generation time — but stored as structure so it
can be re-realized in different wording per instance and machine-checked step-by-step.

---

## 11. VISUAL DNA (nullable)

```
visual_type            // geometry | circuit | ray_diagram | force_diagram | graph | coordinate_plot
                       //   | biology_schema | chemistry_structure | table
visual_variables       // measurable quantities the figure encodes
labels
geometry               // structured description (→ semantic visual spec, VISUAL spec)
question_dependency    // answerable_without_visual: true|false   (critical — see below)
transformation_possibilities  // how the figure could be re-parameterized for an original item
```
`question_dependency=false` (answerable without the visual) means the visual is decorative and can be
regenerated freely. `true` (the answer *requires* reading the figure) means the item is
**diagram-locked**: it can only become a production item if we can generate an equivalent semantic visual
(VISUAL spec), else it is flagged and excluded — never silently converted to text-only.

---

## 12. QUALITY FLAGS (why a DNA may be unusable)

```
ocr_damaged            // source text/values corrupted → structure unreliable
diagram_locked         // requires a visual we cannot yet regenerate
regional_script        // Hindi/Bengali/etc. — excluded from English generation
multi_correct          // multiple correct options (JEE Advanced) — needs a distinct pipeline
ambiguous_source       // options mis-paired in source (observed in real chunks)
low_extraction_confidence
```
DNA carrying a blocking flag is retained for analysis but **not promoted** to an Item Model. Honest
denominator: we report how many source problems are cleanly abstractable vs flagged.

---

## 13. Source & Licence classification (mandatory on every DNA)

Reuses and extends the existing licence ledger (`RESOURCE_STORAGE_POLICY.md`, per-resource
`license_status`). The mission's taxonomy maps onto it:
```
source_class ∈ { OFFICIAL_AUTHORITATIVE, OPEN_LICENSED, LICENSED_INTERNAL,
                 PUBLIC_REFERENCE_ANALYSIS_ONLY, RESTRICTED, UNKNOWN }
```
Rule: DNA from any class may inform **structure learning** (L2). **No source's expressive wording may
enter the production Certified Question Bank (L3).** `RESTRICTED`/`UNKNOWN` DNA is quarantined pending
review; `PUBLIC_REFERENCE_ANALYSIS_ONLY` (previous papers / third-party banks) is analysis-only by
default. The L1 (curriculum) / L2 (pattern intelligence) / L3 (original certified) separation is
preserved exactly.

---

## 14. Extraction pipeline (offline, tiered)

```
source question (from multimodal ingestion, boundaries known)
  → GATE quality_flags (deterministic: OCR damage, script, diagram-lock)     Tier 0
  → identity + concept resolution                                             Tier 0 (reuse phase6)
  → archetype classification                                                  Tier 1 (small model, benchmarked)
  → construction model: parse givens/unknown/values                           Tier 0 where regex-parseable
  → RELATION MATCH by solver-verification: does a library relation, fed the
      source's own numbers, reproduce the stated answer? keep only matches    Tier 0 (deterministic)
  → distractor DNA: diff wrong options vs correct value → transforms           Tier 0
  → cognitive chain + difficulty drivers                                       Tier 0 derived + Tier 2 review
  → solution DNA                                                               Tier 1/2
  → persist DNA (no source wording)
```
The **relation-match-by-solver-verification** step (from the governing QI audit) is the copyright-and-
correctness linchpin: structure is confirmed only when a known relation reproduces the real answer from
the real numbers — zero fabrication, zero copying. Model tiers per `MODEL_ROUTING_AND_COST_PLAN.md`.

---

## 15. Acceptance criteria for the DNA layer

- Every DNA traces to `resource_id + page + bbox + question_number` with an extraction confidence.
- No DNA stores a verbatim source sentence (automated check: no ≥N-token span matches source text).
- Distractor transforms are recovered for ≥X% of clean computational MCQs (measured, reported honestly).
- Diagram-locked and OCR-damaged DNA are flagged, counted, and excluded from promotion — not forced.
- The honest denominator (clean-abstractable vs total detected) is reported, never hidden.

---

## Reconciliation Amendment (2026-07-12, post-Fable-5)

Governed by `OPUS_FABLE_RECONCILIATION_RECORD.md` §2. **The single most important revision:** §§8-9 and §14
above describe a **numeric-only** extraction path (givens/unknown/answer-rule; relation-match-by-solver;
distractor = numeric diff). That path is now **one lane of eleven**. Question DNA carries a mandatory `lane`
discriminator, and each lane has its own executable evidence shape, representation, and — critically —
**independent-verification** strategy. Non-numeric correctness is **not** forced through a math relation
model; it is verified against the **Knowledge Verification Substrate (KVS)** — typed, curated,
provenance-tracked, multiply-sourced stores (`relation_library`, `assertion_base`, `taxonomy_store`,
`sequence_store`, `structure_function_map`, `comparison_matrix`) plus independent Tier-2 agreement.

**The 11 lanes** (full per-lane spec — evidence shape · DNA · Item Model · transforms · difficulty drivers ·
distractor strategy · verification · originality — is in `OPUS_FABLE_RECONCILIATION_RECORD.md` §2):
`NUMERIC_RELATIONAL` (existing linchpin), `DATA_INTERPRETATION`, `MISCONCEPTION_DIAGNOSTIC`,
`CONCEPTUAL_CAUSAL`, `CLASSIFICATION_TAXONOMIC`, `PROCESS_SEQUENCE`, `STRUCTURE_FUNCTION`, `COMPARATIVE`,
`ASSERTION_RELATION`, `DIAGRAM_VISUAL` (Phase E-full), `EXPERIMENT_OBSERVATION`.

- **ASSERTION_RELATION** replaces the always-"(a)" AR templates: DNA is `{assertion_fact, reason_fact,
  truth(A), truth(R), explains(R,A)}`, each field independently established from the KVS; the key is
  *derived* from those three checks, never hard-coded, and all four relation classes are reachable.
- **Distractor DNA (§9) is generalized:** numeric diff is the NUMERIC_RELATIONAL/DATA lane only. Non-numeric
  distractors come from `concept_edges` (sibling/parent confusion), curated confusion lists, and the
  MISCONCEPTION_DIAGNOSTIC lane's misconception library — not numeric perturbation.
- **Difficulty drivers (§7) corrected:** `prerequisite_depth` is near-unusable now (the prerequisite DAG
  has only **10** edges); `information_density`, `abstraction_level`, `context_novelty` have no measurement
  procedure and are **deferred** (not shipped as pseudo-measurements); drivers are **per-profile** and map
  to **ordinal bands** before any scalar. See `PSYCHOMETRIC_CALIBRATION_SPECIFICATION.md`.
- **Concept identity:** DNA `identity.canonical_concept` binds to a **canonical concept_code**; keyword
  substring binding is removed for generation (Record F5).
- **`assumptions[]` added** to the construction/identity block (explicit "take g = 10", "neglect friction",
  per-profile conventions) — required by the ambiguity and blind-solve gates.
- **Corpus note:** real non-numeric evidence exists — 2,924 Biology-keyword complete MCQ chunks, 787 AR
  chunks, 1,904 match-column chunks, 1,654 typed `concept_edges`, 230 concepts with `reference_facts`.
