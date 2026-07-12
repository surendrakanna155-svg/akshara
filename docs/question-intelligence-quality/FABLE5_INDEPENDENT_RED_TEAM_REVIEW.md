# FABLE5 Independent Red-Team Review — Quality-First Question Intelligence

**Date:** 2026-07-11 · **Reviewer:** Independent Red-Team Assessment Architecture Reviewer (Fable 5)
**Type:** READ-ONLY independent audit. No code, DB, engine, roadmap, or existing deliverable modified.
**Scope:** The 11 documents in `docs/question-intelligence-quality/`, independently re-verified against
the live code (`kie/qpgen/`, `kie/curate/`, `kie/phase2/4/5/7`), the live DB
(`curriculum/knowledge/kie/kie.db`), the four frozen `qp_output_audit` JSON snapshots
(`curriculum/reports/qp_audit/`), checkpoint `775fd78e`, and the canonical decision documents
(AIP v3.0, AIMS Rule 7, GAP_ANALYSIS D-3/CI-C10/CI-C11, Amendment A2).
**Method:** every load-bearing quantitative claim was independently reproduced (live registry import,
live `find_template` sweep over all 1,736 active concepts, read-only SQL, recomputation of the clone
metric from raw JSON) — not accepted from the documents. Current code was treated as authoritative
over documentation throughout.

---

## 1. Executive verdict

**The previous architect's root-cause evidence is substantially correct — every load-bearing number
reproduced exactly under independent measurement** (94 registry families; 88 single-formula; AR answer
hard-coded to option (a); `solver_verified` an unconditional literal; 92/1,736 = 5.3% template
coverage; 57/1,736 = 3.3% definitions; 0/57 full papers in all four frozen snapshots;
272/357 = 76.2% clone rate recomputed from raw JSON; 7,746 complete MCQ chunks; `distractors` and
`question_templates` at 0 rows and wiped by `phase7_questions.py:120-121`; images/equations extracted
by Phase 2 and never read by Phase 4). The central thesis — *the engine measures constraint
compliance, not educational quality, and the pipeline discards the structure quality would need* — is
**CONFIRMED as architecture, not opinion.**

**The proposed architecture is directionally sound and is NOT fundamentally over-engineered.** The
core inversions (structure learned offline, wording never copied; engine decides assessment logic,
model only realizes language; acceptance by adversarial survival, not confidence; predicted vs
empirical difficulty separated) are the correct fixes for the measured defects, and they respect the
locked decisions (A2/I9/D1/D2/D6/D7/D8) with only citation-precision slips.

**However, this review found 8 material defects/gaps that must be corrected before the plan is
approved for build, plus 5 previously-unreported engine defects** (§2.3) that change the remediation
calculus. The most serious:

1. **The architecture has no credible lane for non-numeric subjects.** The linchpin
   (relation-match-by-solver-verification) and distractor-transform recovery are numeric-only. Biology
   is 919 of 3,006 concepts and half of NEET; it is precisely the slice at 0% objective fill today,
   and Phase B as specified cannot mine or verify it (§4.1).
2. **The Assertion-Reason remedy is insufficient.** Randomizing key *position* does not fix that the
   correct *semantic* answer is constant ("both true, R explains A") for every AR family (§2.3-N1).
3. **A missing gate class: realization fidelity.** If a Tier-1 model rephrases the stem, no specified
   gate confirms the rendered text still encodes the chosen parameters; GATE 4's input source is
   unspecified, which decides whether it can catch this at all (§6.2).
4. **An internal contradiction in the psychometric spec:** distractor-selection frequency cannot be
   computed from the D2 marks grid, which captures per-question marks, not chosen options (§8.4).
5. **Native-registry precedence structurally blocks content-only remediation** — a flawed built-in
   family can never be overridden via `templates_ext` because `find_template` returns the first match
   and native families load first (verified, 5 concrete overlaps exist today) (§16).
6. **Benchmark statistics are under-specified** (no N, no agreement statistic, no test, thresholds
   deferred) and blindness is compromised by engine style recognizability (§14).
7. **Multimodal sequencing is wrong given facts on the ground:** the board-acquisition lane is live
   (227 downloaded / 171 verified board PDFs as of 2026-07-09), so a minimal ingestion slice must move
   ahead of full Phase E or the new corpus is ingested lossy and re-processed later (§15.2).
8. **The plan carries no effort estimates and no per-phase kill criteria**, and lacks the cheap
   Phase-0 spike that could kill or prove the DNA→Item-Model hypothesis before schema investment
   (§15.4).

**Final verdict: CONDITIONAL GO** (§21). The direction is right and grounded in reproduced evidence;
the conditions are enumerated and bounded.

---

## 2. Independent reproduction of major findings

### 2.1 Reproduced by this review (methods and results)

| # | Finding | Independent method | Result |
|---|---|---|---|
| R1 | Template census | Imported live `kie.qpgen.templates.REGISTRY` via `curriculum/.venv` | **94 total = 52 native + 42 ext** (4 AR, 1 match, 89 numeric) |
| R2 | Single-formula dominance | Instantiated all 89 numeric families; counted dependent computation steps in solutions | **88 single-step; 1 borderline** (`math_compound_interest`: A = P(1+r/100)ᵗ then CI = A−P). Zero multi-concept, reverse, graph, case-study, error-analysis families |
| R3 | AR answer key | Read `templates.py` `_ar_family` | `"answer": _AR_OPTS[0]` — always "(a)"; options rendered *inside the stem string* in fixed order; no rotation applied (numeric `_mcq_options` DOES rotate by seed — the asymmetry is real) |
| R4 | `solver_verified` | Read both assignments | `templates.py:684` and `materialize.py:171` — unconditional literal `True`; no second solve path exists anywhere in `qpgen/` |
| R5 | Template coverage | Ran `find_template` across all 1,736 active concepts × 5 question types against the live DB | **92/1,736 = 5.3%** — exact reproduction |
| R6 | Definition coverage | SQL on live `concepts` | **57/1,736 = 3.28%** non-empty definitions on active concepts (only 43 are ≥50 chars — "usable" is generous) |
| R7 | Full-paper count | All four `curriculum/reports/qp_audit/*.json` snapshots | `teacher_ready_full_paper: 0` in **every** snapshot (48–54 served of 57) |
| R8 | Clone rate | Recomputed the flat stem-key Counter from raw `audit_content_density_levers.json` | **272/357 = 76.2%** — exact match. Decomposition (new): 86% of clone occurrences span *different configs*; 10 of 54 served papers contain the same question **twice within one paper** (see N5) |
| R9 | Phase-7 structure loss | Read `phase7_questions.py` | Lines 119-121: `DELETE FROM distractors, question_templates, question_families, question_patterns`; only patterns (4-field skeleton string, line 125) + draft families re-inserted. Stems, options, answers, solutions never stored |
| R10 | Empty tables | SQL + grep | `distractors=0`, `question_templates=0`; **zero non-test `INSERT INTO` either table in the entire codebase** — empty by construction, not by accident |
| R11 | Image/equation loss | Read `phase2_parse.py` + `phase4_chunk.py` | Phase 2 extracts images (105-119) and tags equations (185-194) into `parsed/<doc>.json`; `phase4_chunk.py` never reads the `images`/`equations` keys; `parsed_documents` INSERT (447-458) drops even the counts |
| R12 | Corpus composition | SQL on `source_documents`/`document_metadata` | NEET 152 + AIIMS 26 + AIPMT 6 + JEE 94 vs **3** TS_SCERT docs; `stream` taxonomy has no school-board category at all |
| R13 | MCQ recoverability | SQL | **7,746** chunks contain all of (1)(2)(3)(4) — exact match to the claimed figure |
| R14 | Cross-subject contamination | SQL heuristic sweep | 8 confirmed Biology-under-Physics active concepts (`PHY_TRANSPORT_IN_PLANTS`, `PHY_MICROORGANISMS`, …) beyond the audit's own examples |
| R15 | Difficulty honesty | Latest frozen snapshot | `d9_difficulty_met_pct_all = 40.6` — matches "~40%" |

### 2.2 The live-output examples are real

The root-cause audit's §4 verbatim examples were cross-checked against the raw audit JSON
`filled_stem_keys` and the two hand-read output audits. The glued-word answer keys ("thetime rate at
which work is done…") are consistent with the current answer path: `materialize.py:129` ships the
stored definition **verbatim** as the key, `usable_definition()` (materialize.py:66-84) checks only
length/truncation heuristics, and both `gate_stem_artifacts` (audit instrument) and
`stem_quality_ok`/`_real_key` (engine) inspect the **stem or generic-placeholder text only — never
OCR-glue in the answer key**. A paper can be "integrity-gates = 0" while its answer keys carry glued
OCR text. Confirmed as a live gap in both the engine and the measuring instrument.

One correction of framing: the superscript flattening (`10⁻²⁴` → `10-24`) was reproduced on a
**born-digital, non-OCR NCERT PDF** (`ocr_used=0`, `method=archive:pymupdf`). The damage mechanism is
plain-text extraction discarding baseline shift, not OCR per se. The MULTIMODAL spec's fix (structured
equation capture) is still the right fix, but "OCR damage" under-describes the problem: **every**
current document, however clean, loses exponent structure.

### 2.3 New defects found by this review (not in any of the 11 documents)

- **N1 — AR flaw is semantic, not just positional.** Every AR family authors an assertion and a reason
  that are both true restatements of the same law, so the correct *meaning* is always "both true and R
  explains A." The Item-Model spec's remedy ("assertion_reason with position randomization — fixes the
  always-(a) flaw", ITEM_MODEL §5 Tier B) randomizes where the constant answer sits, not what it is. A
  student who learns the pattern still scores 100%. AR families need a truth-table generator (A
  true/R false, non-explaining R, etc.) — a content requirement the specs never state.
- **N2 — Silent generator shadowing in `templates_ext.py`.** `g_triangle_area` is defined twice
  (lines ~185 and ~290); the second silently shadows the first, so `math_triangle_area` and
  `math_triangle_measure` are two template_ids executing the **identical** generator with different
  concept bindings. Nothing prevents both appearing near-identically in one paper.
- **N3 — `select._priority` contradicts its own docstring.** The tuple puts `_fill_rank` before
  `subject_usage` (select.py:98-113), so fill-ability dominates and subject balance is a tie-break —
  the opposite of the documented intent. Directly relevant to Phase D, which builds on this function.
- **N4 — Coverage was bought with topical precision, unchecked.** Several extension families bind by
  single bare-word "conjunctive" groups (`("volume",)`, `("circle",)`, `("triangle",)`,
  `("equilibrium",)`, `("efficiency",)`, `("perimeter",)`, `("median",)`), so e.g. a concept titled
  "Volume of a Sphere" binds to a **cuboid** generator, "Thermal Equilibrium" to a Kc computation.
  And `validate.py:49-50` **exempts template-sourced items from the `UNGROUNDED_STEM` check** — the
  mismatch prints with no gate able to see it. The proposed GATE 10 would catch cognitive mismatch but
  no proposed gate checks *concept-topical* match of a template-filled item; the DNA/Item-Model
  concept binding must not inherit this substring-matching mechanism.
- **N5 — Within-paper duplicate regression.** Recomputed from raw JSON: 10 of 54 served papers in the
  latest frozen run print the same stem twice in one paper (0 in the three earlier runs), caused by
  duplicate concepts (`PHY_OHM_S_LAW` vs `CHE_OHMS_LAW`) binding the same universal AR text while
  dedup keys on `(concept_code, question_type)`. This **contradicts** the remediation report's
  "within-paper 0" claim, which was measured on an earlier snapshot and never re-checked.
- **N6 — Native-registry precedence blocks content-only remediation.** `find_template` returns the
  first REGISTRY match; native families precede `templates_ext` families. Verified 5 existing
  native/ext keyword-group overlaps. Consequence: the flawed AR families (and any weak native family)
  **cannot be retired or overridden through the sanctioned content lane** — a fact that materially
  strengthens the case that some engine surface must change (§16).
- **N7 — Two committed same-day documents disagree on definition counts** (25/1,415 vs 57/1,736); the
  live DB matches the later figure. The root-cause audit's "46 engine-native + 42" split is
  arithmetically wrong (actual 52 + 42 = 94; the total and conclusion stand). `formulas` is 317 rows
  live vs 281 in the QI audit (post-audit growth). None of these change any conclusion; all should be
  corrected for record hygiene.

---

## 3. Claim-by-claim verdict table

| Claim (previous architect) | Verdict | Independent evidence |
|---|---|---|
| 88 of 94 families are one direct-substitution archetype | **CONFIRMED** | R1/R2: live registry import + instantiation of all families |
| Assertion-reason answer-key predictability | **CONFIRMED — and understated** | R3 + N1: key is hard-coded `_AR_OPTS[0]` AND semantically constant; proposed fix is insufficient |
| Bloom/difficulty labels causally disconnected from content | **CONFIRMED** | `phase7:66-81` heuristics at ingest → `pool.py` copies (LONG_ANSWER unconditionally HARD/ANALYZE, pool.py:112-122) → `select.py:164-177` stamps → `validate.py` never reads `bloom`; d9 = 40.6% |
| `solver_verified` is not an independent solve | **CONFIRMED** | R4: unconditional literal at both sites; same expression computes stem numbers and answer |
| No cognitive-depth validation | **CONFIRMED** | Full validate.py enumeration (§7.1): all 14 checks structural/deterministic-format |
| No distractor plausibility validation | **CONFIRMED** | Only exact-string distinctness; padding is numeric perturbation (±1,±2,×2…); some hand-authored distractors dimensionally incoherent (Ω+A labeled "V", templates.py:110) |
| 5.3% concept template coverage (92/1,736) | **CONFIRMED — reproduced exactly** | R5 |
| 3.3% usable definition coverage (57/1,736) | **CONFIRMED** (generously: 43 ≥50 chars) | R6; the older "25/1,415" figure is stale |
| 0 of 57 papers reach full coverage | **CONFIRMED** | R7: all four snapshots, `teacher_ready_full_paper = 0` |
| 76% cross-paper clone/repetition | **CONFIRMED — reproduced exactly (272/357)** | R8; nuance: the metric folds within-paper and cross-config repetition together; cross-config dominates (86%) |
| OCR-damaged answer material reaching output | **CONFIRMED** | §2.2: answer keys ship stored definitions verbatim; no answer-side artifact gate in engine or instrument; nuance: mechanism includes born-digital extraction flattening, not only OCR |
| Cross-subject contamination | **CONFIRMED** | R14: 8 new live examples + the audit's own (Totipotency-on-Chemistry) + N5's Ohm duplicate pair |
| Real question structure discarded during ingestion | **CONFIRMED** | R9: Phase-7 aggregation keeps only (concept,type,bloom,diff)→frequency |
| Distractor and question-template tables empty | **CONFIRMED** | R10: 0 rows; wiped every run; zero producing INSERTs exist |
| Images/equations lost at the DB boundary | **CONFIRMED** | R11: extracted by Phase 2, never read by Phase 4, counts dropped at the `parsed_documents` INSERT |
| Corpus = JEE/NEET foundation, not school boards | **CONFIRMED** | R12; but see §15.2 — a *separate* board lane is live with 171 verified PDFs |
| ~5,224 clean computational MCQs / ~14,000 detected problems | **PARTIALLY_CONFIRMED** | The 7,746 superset reproduced exactly (R13); the 5,224 clean-English-computational subset uses the QI audit's regex filters and was not independently re-derived — plausible, treat as an estimate until CP-A measures it |
| 2,015 draft `question_families` unused by the engine | **PARTIALLY_CONFIRMED** | Structurally confirmed (no qpgen read of the table); the row count was not re-queried this session |
| `formulas` = law names only, zero equations | **CONFIRMED** | 317 rows live, no `=`/symbols; `phase5_concept.py` writes the name into `expression` |
| "46 engine-native + 42 ext" split | **INCORRECT (immaterial)** | Actual 52 + 42; total 94 and the conclusion stand |
| Claimed alignment with D1/D2/D6/D7/D8/Rule 7/A2/I9 | **PARTIALLY_CONFIRMED** | Substance aligns; citation imprecision: "Rule 7" lives in AIMS §RULE-7, L1/L2/L3 in GAP_ANALYSIS D-3, not in AIP v3.0; A2/I9 are owner-approved in direction but **not ratified**; D6's N=100 is explicitly "initial, tunable" and an open owner decision (O-D) |

No claim examined was found INCORRECT in substance; two were found MISLEADING only in attribution
detail (native/ext split; single-document citation of multi-document rules).

---

## 4. Question DNA — red-team findings

The DNA object is a genuine improvement over `question_patterns` (a 4-field string) and is *mostly*
assessment intelligence, not metadata. But:

**4.1 (CRITICAL) The DNA pipeline is numeric-shaped; the corpus and the product are not.**
`construction_model` (givens/unknown/units/answer rule), the extraction linchpin
("relation-match-by-solver-verification"), and distractor-transform recovery ("diff wrong option vs
correct value") are all defined **only for quantitative items**. Biology is 919/3,006 concepts, the
single largest corpus subject, half of NEET's marks, and today's worst cell (NEET Biology objective =
0% fill). For a conceptual MCQ ("Which hormone…?") there is no relation to match, no numeric diff to
recover a transform, and no CAS to blind-solve. The specs never say how conceptual DNA is *verified* —
which means Phase B's honest yield will be concentrated in Physics/Chemistry-numerical/Maths, and the
NEET promise stays unmet. **Required correction:** an explicit conceptual-item lane — verification via
the concept graph + definition evidence (the existing `_sibling_distractors` mechanism is the seed),
distractor typing via concept-confusion pairs (graph siblings/edges), Tier-2 model verification at
extraction time, all benchmark-gated — or an explicit, owner-visible statement that Biology/conceptual
items are out of scope for Phase B and remain definition-match only.

**4.2 No representation for item sets (testlets).** CBSE case-study (one context + 4-5 sub-questions),
JEE-Advanced paragraph comprehension, and matching data-sets are *sets* of linked items sharing
context. DNA models a single question; `case_interpretation` as an archetype cannot express "these 5
items share one stimulus and must ship together." Paper intelligence (§13) inherits the gap. The
corpus contains 714 matching-column and 123 integer-answer chunks (QI audit) — `matrix_match` and
`integer_answer` are also missing from the archetype vocabulary while `multi_correct` (JEE-Adv) is
demoted to a quality flag with no pipeline. Acceptable for Phase B if declared; fatal for the "JEE
Advanced later" ambition if never designed.

**4.3 The cognitive chain is a flat list.** Ordered operations cannot express branching (two parallel
sub-derivations that merge), iteration/case-split, or proof/derivation structure. There is no
`derivation/proof` archetype at all — ironic, since "derive/prove" is the current difficulty
heuristic's only content signal. For board descriptive papers (5-mark derivations) this is a real
expressive hole. A tree/DAG (or at least nested chains) should be permitted where needed.

**4.4 Hidden assumptions are under-modeled.** `hidden_constraint` is a driver score;
`constraints[]` is a parameter-solver input. Neither field records *stated assumptions* ("take g =
10 m/s²", "neglect friction", "ideal gas") — which are exactly what the ambiguity gate (GATE 8) and
the blind solver need to agree on, and what differs by profile (boards use g = 9.8; foundation uses
g = 10). Add `assumptions[]` (explicit, per-item, profile-aware).

**4.5 No answer-equivalence classes.** Nothing represents acceptable answer forms (0.5 m/s ≡ 50 cm/s;
fraction vs decimal; surd vs rounded; tolerance under g = 9.8 vs 10). GATE 4 will generate false
rejects (or worse, be loosened ad-hoc) without a declared equivalence/tolerance policy per item model.

**4.6 Subjective/unmeasurable fields are presented as "measured".** `abstraction_level`,
`context_novelty`, `information_density` have no measurement procedure anywhere in the spec —
dangerous, because GATE 9 rejects on drivers. `option_similarity` and `misconception_pressure` are
properties of a *rendered instance/distractor set*, not of source DNA — layer confusion. §7 should be
split into "countable now" vs "deferred until a procedure exists" (see §8).

**4.7 Multiple solution strategies:** `alternative_method` (single, nullable) cannot represent N
strategies, and nothing marks which strategies are *in-syllabus for the profile* (a calculus shortcut
may be out-of-scope for CBSE X). Minor now; matters for JEE.

**4.8 `dna_id` stability.** "Stable hash of the structural signature" — if the signature includes
measured drivers or model-extracted fields, every extractor improvement re-keys the corpus and breaks
dedup/lineage. The hash input must be pinned to a versioned, minimal structural core.

**4.9 `assessment_construct` per-DNA is over-weighted.** Free-text learning outcomes extracted per
source question (Tier-1/2) at mining scale are expensive and unverifiable, and Item Models re-derive a
construct anyway. Recommend: construct authored once per **Item Model** (human/Tier-2, reviewable),
with DNA carrying only concept + archetype. This deletes cost without losing capability.

**Strengths to preserve:** the quality-flags/honest-denominator design (§12), provenance discipline,
the licence-class mandate, and parameter ranges learned from observed values are all correct and
directly responsive to measured failures.

---

## 5. Item Models — red-team findings

**5.1 The clone-generator risk is real and is the plan's central bet.** The design's own defenses
(archetype as the primary diversity axis; parameter ranges; exposure control; GATE 15) are the right
shape. What is missing is the **evidence bar for a model**: nothing specifies the minimum cluster size
or source spread for promoting DNA clusters into an Item Model. A "cluster" of 1-2 DNA is memorization
of a specific question — the failure mode is then an *originality* problem (a structure-plus-numbers
copy of one identifiable source item), not just a diversity one. **Require:** minimum K distinct DNA
from ≥2 distinct resources per Item Model (K per archetype declared up front), and report the honest
distribution of cluster sizes.

**5.2 "Same family" is under-defined at the algebra level.** Clustering key = archetype + operation
chain + relation. But V=IR, R=V/I, I=V/R are one relation in three roles (correctly split — different
archetypes), while P=VI vs P=I²R are *different relations* testing one construct (should they merge?),
and s=ut+½at² vs v²=u²+2as overlap. Without CAS-normalized relation identity plus an explicit
merge/split rule, mining will both over-split (inflating "diversity" with algebraic twins — exactly
the current 88-templates-one-archetype failure at a new level) and under-split. The Batch-0 CP-C note
("normalize algebraically equivalent relations") must be promoted into the Item-Model spec itself.

**5.3 Difficulty preservation under parameterization is only half-solved.** GATE 9 recomputes drivers
per instance — good — but the drivers that actually vary within a model are `calculation_load` and
`option_similarity`; if the declared band is wide, every instance passes and "band" is decorative.
Bands need declared widths per driver and a demonstration (on K sampled instances) that the band
discriminates.

**5.4 Degenerate-value prevention** (`forbidden_combinations` + constraints) is adequately specified
*mechanically* but the constraint language is undefined (ranges? relational predicates? code?). This
is the piece the empty `question_templates.constraints` column will hold — define its grammar in
Phase A, not during mining.

**5.5 Versioning/retirement is missing.** `certification_status` is a lifecycle, not a version. There
is no `version` field, no retirement/supersession rule, no answer to "an instance was served from
model v1; v2 fixes a flaw; what happens to exposure/统计 lineage?" The psychometric `flagged` status
implies demotion — wire the loop explicitly: Phase-2 flags → model re-certification or retirement,
with `generated_items` keeping the model version that produced each instance.

**5.6 Bad-family detection before response data** relies on gate rejection statistics + benchmark
sampling — sound, provided rejection stats are per-model from day one (the spec says this; keep it).

**5.7 Registry integration must not inherit `find_template` binding.** Item Models declare
`concept_scope[]` by `concept_code` — good. But if CP-D registration routes through `templates_ext`,
binding collapses back to title-substring keyword groups (N4) and native-precedence shadowing (N6).
**Concept-code-exact binding is a hard requirement for the new path.**

---

## 6. Generation contract — findings

**6.1 The contract inversion is the strongest idea in the plan and is correctly aimed.** Verified
against the current contract: `materialize.spec_of` (materialize.py:308-316) hands the model only
labels + "be original" — the previous architect's characterization is exact. Moving parameter choice,
answer computation, distractor intent, and solution scaffold into the engine is the only demonstrated
way to make small models sufficient, and the plan's insistence on a benchmarked routing criterion
(cheapest tier that passes the task benchmark; re-benchmark on model swap) is the right governance.

**6.2 (GAP) Realization fidelity is unguarded.** Tier-1 "rephrases for age/context variation" can drop
a given, alter a number, introduce an unintended cue, or embed the answer. No gate in the 15-gate
ladder checks *rendered text ↔ contract agreement*. Two required fixes:
- **GATE 4's input must be the rendered stem**, parsed independently (numbers/units re-extracted from
  text), not the stored parameter set — otherwise blind solve verifies the contract, not the question
  students see. The spec's "a genuinely second path" phrasing permits either reading; pin it.
- Add a deterministic **realization-fidelity check**: every contract parameter appears in the rendered
  stem exactly once with its unit; no extra numeric tokens; answer string absent from stem. Cheap,
  Tier-0, closes the drift channel.

**6.3 Tier boundaries are otherwise sound.** Deterministic: parameters, answers, drivers, SVG, dedup,
rubric — correct. Tier-1: archetype classification, language realization — correct *with* 6.2.
Tier-2: conceptual blind solve, ambiguity adjudication, hard DNA extraction — correct, offline only.
Never-LLM: statistics, similarity thresholds, certification decisions — correctly stated.
Hallucination entry points not fully enumerated by the spec: archetype misclassification at DNA time
(benchmark it — the spec says so), solution-step prose (machine-check numeric steps; sample-audit
verbal), and realization (6.2).

**6.4 Zero-runtime-AI (I9) is honored** by the certify-offline/instantiate-deterministically split,
including the runtime gate subset. No conflict found.

---

## 7. Quality gates — findings

**7.1 Baseline verified.** The current `validate.py` implements exactly 14 structural checks
(enumerated: OUT_OF_SYLLABUS, WRONG_SUBJECT, UNCLEAN_CONCEPT, BAD_TYPE, BAD_MARKS, EXAM_MISMATCH,
UNGROUNDED_STEM [with the template exemption, N4], LOW_QUALITY_STEM, BAD_OPTION_COUNT,
MALFORMED_OPTION, DUPLICATE_OPTIONS, NO_ANSWER, ANSWER_NOT_IN_OPTIONS, AMBIGUOUS_ANSWER,
paper-level exact DUPLICATE) — all deterministic string/set operations; zero educational checks. The
"15 new-gate ladder extends a sound scaffold" premise is accurate.

**7.2 Gate-by-gate assessment (merge to ~11; add 2):**

| Gate | Verdict | Notes (input → decision; FP/FN risk; action) |
|---|---|---|
| 1-3, 6 (existing constraints) | KEEP | Already fail-closed. GATE 6's numeric-equivalence extension (10 vs 10.0) is right; also normalize units before comparing (2 m vs 200 cm) |
| 4 Independent blind solve | KEEP — **keystone** | Input must be rendered stem (§6.2). Numeric: independent relation library. Verbal: Tier-2, certification-time only. FP risk: answer-equivalence/tolerance policy missing (§4.5) — define before enabling, else it will be quietly loosened |
| 5 Answer correctness | **MERGE into 4** | For numeric items 4 and 5 are one computation; keep dimensional/unit checks as part of the same pass |
| 12 Dimensional/unit | **MERGE into 4/5 pass** | Same relation-library machinery; separate listing adds process, not protection |
| 7 Distractor plausibility | KEEP | Deterministic part now (magnitude window, unit coherence, not-eliminable-by-units); misconception-type presence enforced by construction (generators carry types). "Real misconception" judgment is NOT reliably automatable pre-response-data — scope the hybrid part to certification sampling, not per-instance |
| 8 Ambiguity | KEEP, split | Numeric: deterministic — "does any distractor satisfy an alternative applicable relation/assumption set?" Verbal: Tier-2 certification-time. FN risk high for under-specified stems; assumptions[] (§4.4) is prerequisite |
| 9 Difficulty drivers | KEEP | Deterministic recompute vs band. Depends on §8 trimming the driver set to measurable ones; else it rejects on pseudo-measurements |
| 10 Cognitive/Bloom | **MERGE into 9** | Same recomputation pass over the same structure; as a separate "hybrid" gate it will degenerate into a rubber stamp. Bloom = derived roll-up, asserted at model certification, spot-audited by benchmark |
| 11 Visual consistency | KEEP (Phase E) | Deterministic spec↔stem↔answer agreement is well-designed |
| 13 Originality/similarity | KEEP, redesign thresholds | n-gram+embedding on short formulaic stems has BOTH high FP (all Ohm's-law items resemble each other) and FN (structure copied, wording new). Add the **structural** check that actually matters: generated parameter tuple must not reproduce an observed source tuple for that relation (§12). Calibrate lexical/semantic thresholds per archetype on the gold set before enforcement |
| 14 Item-writing flaws | KEEP, extend | Add: **semantic key-constancy within family** (N1 — the AR trap), and paper-level key-position balance (belongs in 15). Deterministic, cheap |
| 15 Paper diversity | KEEP (Phase D) | Must include within-paper rendered-stem dedup (N5 recurrence guard), not just family caps |
| **NEW: Realization fidelity** | ADD | §6.2. Deterministic. Closes the only ungated LLM channel in the certified path |
| **NEW: Answer/solution artifact** | ADD | The stem-only artifact asymmetry (§2.2) must be closed at generation time, not only in the audit instrument |

15 gates as documentation is fine; as *implementation*, 11 checks + 2 additions with merged passes is
the same protection with less machinery. The certification-time vs runtime split (expensive
model-gates offline; deterministic subset re-run per instance) is correct and I9-compliant.

**7.3 Adversarial verification (majority-refute panels)** is appropriate for certification sampling
only; applied per-instance it would be cost-prohibitive and is unnecessary given deterministic
re-verification at runtime. The spec already scopes it this way — hold that line.

---

## 8. Difficulty model — findings

**8.1 The predicted/empirical separation is educationally correct** and the explicit "never present
one as the other" rule is the most important sentence in the psychometric spec. Replacing
`len(text)>600 ⇒ hard` with structural drivers is defensible and is standard practice (difficulty
modeling from item features), *provided* the drivers are actually measurable.

**8.2 Split the 14 drivers into three classes:**
- **Countable now (keep, 7):** reasoning_steps, concept_count, prerequisite_depth (DAG exists),
  representation_shifts (countable if encoded in the item model), calculation_load,
  algebraic_manipulation, irrelevant_information (countable as planted-given count).
- **Derived from other layers (keep but relocate, 2):** misconception_pressure (from distractor
  generator strength), option_similarity (from the rendered option set — an instance property).
- **No measurement procedure exists (defer, 3+):** information_density, abstraction_level,
  context_novelty. As spec'd these are asserted numbers wearing a "measured" costume; GATE 9 rejecting
  on them would be false precision. Drop from v1; reintroduce only with a written procedure.
- Redundancy: reasoning_steps↔calculation_load and information_density↔irrelevant_information are
  strongly correlated pairs; hidden_constraint is fine as boolean.

**8.3 Missing drivers:** formula-recall burden (is the relation given in the stem or must it be
recalled? — a large, cheap, real difficulty axis), numeric "niceness" (integer vs decimal vs surd
answers), reading/language load (dominant for Class 6-8 board papers), and estimated solution time
(needed anyway by the paper-level time budget). Profile matters: **weights must be per-profile**
(CBSE-X vs NEET vs JEE-Main vs JEE-Advanced are different difficulty geometries; a single versioned
weight vector, as spec'd, will be wrong for at least three of them). The g=9.8-vs-10 convention split
also belongs to profile.

**8.4 (CONTRADICTION) Distractor statistics vs D2.** §4.1 of the psychometric spec promises
`distractor_selection_frequency` and `distractor_efficiency` from CTT — but the D2-compliant capture
is a **per-question marks grid**, which records marks, not which option a student chose. Option-level
frequencies are uncomputable from that spine. AIP explicitly notes option-level evidence from formal
exams was "not pursued." The only sanctioned sources of option-level data are digital administrations
(in-app practice per Amendment A2 / adaptive practice), which the spec never mentions. **Fix:** state
that distractor-level statistics come only from digital-response channels when they exist; remove
them from the marks-grid CTT list; keep p-value/discrimination/blank-rate, which the grid does
support.

**8.5 Fake-hard risk** (calculation-load stuffing = tedious, not hard) is real; cap the
calculation-load contribution in the predicted-difficulty function and let the benchmark's
difficulty-accuracy dimension arbitrate. The eventual regression of observed difficulty on drivers
(§5 of the spec) is the correct closed loop and is correctly restricted to deterministic regression.

**8.6 Prefer ordinal bands over a scalar.** A weighted scalar with invented weights implies precision
that will not survive first contact with response data. v1 should map driver vectors to bands via
explicit rules (e.g. "hard requires ≥2 non-recall operations AND ≥2 concepts OR misconception
pressure"), which are inspectable and arguable by teachers; regress toward scalars once empirical
data exists.

---

## 9. Distractor intelligence — findings

**9.1 For numeric items the design is genuinely strong.** Transform recovery by diffing real wrong
options against the correct value, misconception-typed generators, magnitude/cue checks — this is the
best-evidenced part of the plan (the corpus demonstrably contains ~3 human-authored wrong options per
recovered MCQ; the current engine demonstrably ships arithmetic noise, sometimes dimensionally
incoherent). The enum covers sign/unit/formula-confusion/partial/inverse/boundary/off-by-constant
adequately; add `wrong_relation_selection` explicitly (using P=I²R where V is given) and
`graph_misread` for Phase E.

**9.2 (CRITICAL, same root as §4.1) There is no recovery path for conceptual distractors.** "Diff
wrong option vs correct value" is undefined for "(b) mitochondria". For Biology/descriptive Chemistry
the misconception source must be different: concept-graph siblings and confusion pairs (the
`_sibling_distractors` mechanism already in `materialize.py:205-238` is a working, domain-grounded
seed), curated confusion lists per chapter, and Tier-2 extraction of recurring wrong-answer *concepts*
(not values) from source MCQs. Without this, distractor DNA — "the single most under-exploited asset"
— is exploited for at most half the corpus.

**9.3 Independent distractor checks — required set is mostly present across gates 6/7/8/14:**
plausibility (7), uniqueness incl. numeric equivalence (6), incorrectness (8 must verify each
distractor is *not* defensibly correct — state this as the gate's definition), closeness window (7),
cueing/grammar/length/position (14). **Missing:** cross-option unit consistency (all options same
dimension/unit format unless the trap is unit choice); distractor≠correct under unit conversion; and
paper-level key-position balance (14/15).

**9.4 `plausibility_prior` stays null until digital response data exists (§8.4)** — do not let a model
fabricate it in the interim; the spec's hard rule covers this, keep it.

---

## 10. Solution intelligence — findings

**10.1 The structured step array is right; the mandatory/optional split is missing.** Recommended
contract, aligned to the stated product goal (teacher opens question → understands → can explain):
- **Mandatory:** final answer (with unit); key insight (one line); ordered steps (each numeric step
  machine-checkable: relation, substitution, result); relations_used (linked to the relation library);
  **per-distractor rationale for MCQ** ("(b) is what you get if you add resistances in parallel
  directly") — this is DNA §9 data surfacing to the teacher and is the single highest-value teacher
  feature in the plan; it must be mandatory, not implicit.
- **Optional:** short hint; alternative method (profile-gated per §4.7); common_mistake (merge with
  distractor rationale — they are the same fact in two shapes; keeping both invites drift).
- 4-5 steps is right for board/foundation; allow archetype-dependent length (JEE-Adv multi-concept
  chains legitimately need 6-8).

**10.2 The independent solver can genuinely avoid repeating the generator** for numeric items *iff*
GATE 4 consumes the rendered stem (§6.2) and the relation library is a separate implementation from
`answer_function` (the spec says "genuinely second path" — make it a structural rule: the blind solver
may not import the item model). For verbal items, "independent" means a model that sees stem+options
only; acceptable offline. Solutions re-realized from structure per instance (not stored prose) is
correct and enables step-level checking.

---

## 11. Multimodal / Visual — findings

**11.1 The diagnosis is verified** (R11): the parse layer already detects images and equation spans
and then loses them; question boundaries are never detected; `char_start/end` NULL; no bbox in the
store. The "route, don't force" design and question-boundary detection as the highest-value upgrade
are correct.

**11.2 The 4-parser × 12-class benchmark is over-scoped for a first pass.** Building hand-labelled
ground truth across 12 document classes before any adoption is a project in itself. Recommend:
benchmark **2 candidates** (keep PyMuPDF baseline; evaluate MinerU *or* Docling first, adding Marker
only if equation capture fails the bar) across **4 classes that dominate the real corpus** (native
text, scanned, equation-heavy, two-column question bank) on ~20-30 hand-labelled documents. Expand
classes only when a real document class arrives that the routing table cannot place. The principle
(adopt by measured score, quarantine on low confidence, no silent caps) is right — keep it.

**11.3 Semantic-SVG generation is appropriate — with two honesty flags.** For geometry, circuits,
ray/force diagrams, graphs, coordinate plots and tables, deterministic spec→SVG is the correct,
copyright-clean, GATE-11-verifiable choice. But (a) **biology schematics**: a "stylized original house
style" renderer for biological structures is a significant design/engineering effort the roadmap
prices at zero — treat biology_schema as Tier-D, not Tier-C; (b) **chemistry structures** from
SMILES-like input require a real cheminformatics layout dependency (licence-check it) or a large
bespoke effort. Photographic/apparatus images are correctly excluded via diagram-lock. The
`answerable_without_visual` flag + never-silently-convert rule is exactly right.

**11.4 (SEQUENCING — see §15.2)** A minimal ingestion slice (persist visual assets + question-boundary
block types + provenance for **newly ingested** documents) must be pulled forward. Full visual
*generation* (SVG, Tier-C archetypes) correctly stays later.

---

## 12. Originality / provenance — findings

**12.1 The structural approach is technically sound**: DNA stores no source wording (with an automated
≥N-token span check), production items are fresh parameterizations, similarity gate on output. This
genuinely prevents *shallow paraphrase* — the failure mode the mission forbids.

**12.2 Leak paths the specs miss:**
- **Parameter-tuple coincidence.** If the constraint solver samples the exact observed source values
  for a relation learned from few DNA (§5.1), the generated item is the source item re-worded —
  structure + numbers identical. Add: exclude (or flag) exact observed source tuples per relation.
- **Distinctive context echo.** stem_structures authored from a cluster can absorb a memorable
  scenario ("a juggler throws…"). Rule: contexts authored from a controlled context library, never
  from source scenarios.
- **Rare distractor values.** A distinctive wrong option recovered from one source and reproduced
  verbatim is a fingerprint; distractor generators must emit *transforms applied to new parameters*,
  never stored source values (the spec implies this; state it).
- **Small-cluster models are the copyright risk concentrator** — same fix as §5.1 (minimum cluster
  size + multi-source requirement).

**12.3 Similarity must be measured at four levels** — lexical (n-gram), semantic (embedding),
**structural (relation + parameter distance — the level that actually catches structure-plus-numbers
copies)**, and visual (spec distance, Phase E). The spec has the first two; add the third now, the
fourth with E.

**12.4 Evidence retention:** keep per-generated-item nearest-source id + distances + gate verdicts in
`generated_items` (already planned), plus the licence class of every DNA that fed the item's model.
This is what an external originality review will ask for. The licence ledger reuse is verified real
(`license_status` populated by discovery scripts; `LICENSE_REPORT.md` exists) with one caveat: it is a
free-text field with organically grown values, not a governed enum — the DNA `source_class` mapping
should normalize it once, centrally.

---

## 13. Paper intelligence — findings

**13.1 Strong items are necessary but demonstrably not sufficient** — the audit instrument itself
proves papers fail at the composition level (76% clone rate, `max_single_concept_reuse=21`,
within-paper duplicates). The Phase-D dimension list (concept coverage, archetype/cognitive/difficulty
distribution, type mix, visual diversity, time budget, semantic/structural repetition, family
exposure, misconception-pattern repetition) is the right list.

**13.2 Missing paper-level dimensions:** testlet/case-study composition (§4.2 — CBSE Science X
blueprints *require* case-study sections); answer-key position balance across the paper;
easy→hard ordering conventions (boards expect section-internal progression); cross-section
double-testing (same concept as MCQ and long-answer — needs semantic dedup, not just concept-code
dedup, per N5); and cohort-level exposure (which papers a *school* has already received) — the
`exposure_count` field exists in the psychometric store but no keying by school/cohort is designed.

**13.3 Deterministic constraint optimization is appropriate** — and should stay modest: seeded greedy
selection with local swap repair against hard constraints (blueprint, boundary) and a weighted
diversity score. A full ILP/CP-SAT solver is unnecessary and would be the plan's first genuinely
over-engineered runtime component; determinism/reproducibility (seed → same paper) is the
non-negotiable property.

**13.4 Fix the substrate first:** Phase D builds on `select._priority`, which today contradicts its
own documented ordering (N3) and has no archetype term. The engine-v2 seam must land the corrected,
tested priority function before diversity terms are tuned on top of it.

---

## 14. Gold benchmark — findings

**14.1 The design has the right skeleton** (blind interleave, independent practicing teachers,
rubric with anchors, paper-level review, milestone cadence, honesty rules) and the two-instrument
model (cheap broad frozen matrix + expensive deep human benchmark) is correct.

**14.2 It is not yet a measurement instrument.** Missing, and required before Phase A exit:
- **Sample size:** none stated. Minimum ~30 items per engine per cell-group under review, or the
  medians are noise.
- **Reviewers:** ≥3 independent raters per item; recruitment, calibration session against the gold
  reference set, and payment/independence declared.
- **Agreement statistic:** name it (Krippendorff's α or quadratic-weighted κ; α ≥ 0.6 to trust a
  dimension) and pre-commit what happens when agreement fails (re-anchor rubric, don't average junk).
- **Statistical test:** paired per-cell comparison (Wilcoxon/Mann-Whitney) with declared α; "median
  exceeds" without a test is eyeballing.
- **Pre-registration:** thresholds "set with reviewers during calibration and recorded before
  scoring" is good intent — make it a committed file (rubric, thresholds, analysis plan) *before*
  generation of test items, so goalposts physically cannot move.
- **Correctness is not a teacher dimension.** Answer correctness must be machine-gated (GATE 4)
  before items reach reviewers; teachers adjudicate only genuinely contested items. Teachers rating
  correctness 1-5 invites false confidence.
- **Blindness is structurally compromised** and the plan should say so: Engine A's items ("Define X.",
  single-substitution stems) are stylistically recognizable against Engine B's. Mitigate (uniform
  formatting, interleaved gold anchors) and — more importantly — rest the scale decision on the
  **absolute bar vs gold anchors**, with beat-Engine-A as a secondary check. Beating a 0/57 engine is
  a floor, not a target.
- **Difficulty evaluation:** teacher-felt difficulty is a weak estimator; treat the
  difficulty-accuracy dimension as advisory until Phase-2 empirical data exists, and gate instead on
  correctness/depth/distractor-quality/ambiguity.

**14.3 One canon note:** AIP §11's "eval harness" is a golden-set regression harness for model swaps;
this benchmark is a much larger instrument. Compatible, but they should be named apart so the D7
obligation (evals on every model change) is not assumed satisfied by milestone benchmarks.

---

## 15. Roadmap sequencing — findings

**15.1 A→B→C→D order is correct** (instrument before engine; models before gates have subjects;
diversity after there is something to diversify). F's seed-now/fill-later split is correct and
D11-compliant. B's internal CP-A→CP-E order is sound and correctly demotes Batch-0 to a hypothesis.

**15.2 (CORRECTION REQUIRED) E must be split; a slice moves early.** The stated premise "E can
parallelize… kept as its own phase" undersells a hard fact verified this review: the board-acquisition
lane is **live** — 227 downloaded / 171 verified board PDFs (COVERAGE_MATRIX.md, LICENSE_REPORT.md,
on-disk trees) as of 2026-07-09, architecturally separate from KIE ingestion. When these are ingested
through the current phases, their equations, figures, and question boundaries are destroyed at the
known loss points (R11), and everything must be re-parsed later. Raw PDFs are retained locally, so the
loss is recoverable — but re-ingestion collides with the intake dedup/versioning design and the
"360-doc baseline immutable" rule, making "ingest twice" a governance problem, not just a compute
cost. **Split E into E-lite (persist `visual_assets` + question-boundary block types + bbox/offset
provenance on *newly ingested* documents; no SVG, no routing benchmark) scheduled alongside A/B, and
E-full (parser routing, visual generation, Tier-C archetypes) where it currently sits.** E-lite is
also what CP-A wants anyway: mining MCQs from `(1)(2)(3)(4)` regex over token-window chunks will lose
option association at chunk borders; boundary-typed blocks make Phase B's own yield higher.

**15.3 The relation library is on the critical path and under-scoped.** Phase A prices "relation
library v0 covering the first benchmark slice" — fine — but Phase B's yield over 5,224 MCQs is
*bounded* by relation coverage, and hand-authoring a dimensioned relation library across
physics/chem/math is weeks of expert work that appears nowhere as a cost. Measure it early (15.4) and
report relation-coverage as a first-class Phase-B denominator.

**15.4 (ADD) Phase 0 — a two-week kill test before Phase A's schema investment.** The roadmap's
smallest slice is currently "all of Phase A." Cheaper decisive test:
1. **Mining feasibility spike:** run CP-A extraction + relation-match on a ~200-MCQ random sample
   (physics + physical chemistry). Metric: % of items where quantities parse AND a library relation
   reproduces the stated key. If <~40%, Phase B's economics collapse → rethink before building DNA
   schema. Also measures OCR/extraction damage honestly.
2. **Quality-lift spike:** hand-author (not mine) 4-5 Item Models for ONE concept cluster (e.g.
   current electricity) across archetypes — expressible **today** via `templates_ext` with zero engine
   edits (multi-step, reverse, misconception MCQ are all just `build()` functions) — plus a prototype
   blind-solve script, and run a 2-3 teacher informal blind review against Engine-A items. If
   hand-built models with real distractor intent don't visibly lift teacher judgment, the whole
   DNA→Item-Model bet needs re-examination before any mining infrastructure exists.
Both spikes are read-only/content-lane and produce the two numbers the owner most needs: **yield** and
**lift**.

**15.5 Missing from the roadmap entirely:** effort/cost estimates per phase (the owner cannot
sequence-approve blind); explicit per-phase kill criteria (benchmark gates exist but no "abandon/
re-scope if X" thresholds); the teacher-review operational pipeline (A2's `TEACHER_VALIDATED` stage at
scale needs a workflow — who reviews, in what tool, tracked where — the benchmark plan covers episodic
review, not the standing certification stage); and the within-paper dedup fix (N5), which should not
wait for Phase D since it is a live correctness regression.

---

## 16. Frozen-engine decision

**Decision: `MINIMAL_ENGINE_EXTENSION`** — decided from code, not from the previous architect's
documents.

`KEEP_ENGINE_FROZEN` is untenable on three code facts: (1) educational gates must attach to
`validate.py`/the slot object — no content-lane mechanism can add a gate; (2) native-registry
precedence (N6, verified with 5 live overlaps) means the flawed AR families and weak native families
**cannot be retired or overridden via `templates_ext` at all**; (3) archetype/exposure terms must
live in `select.py`. `ENGINE_V2_REQUIRED`/`FULL_REDESIGN_REQUIRED` are equally unjustified: the
boundary engine, blueprint system, template mechanism, assemble/print path, and validation scaffold
are sound and load-bearing (verified; the previous architect's keep-list is correct). What is needed
is bounded, additive, and enumerable — the previous architect's "engine v2 change set" conclusion is
**CONFIRMED in substance**; "v2" overstates it. One reviewed change set, its own regression gate
(frozen matrix green + golden tests), owner-approved as a single decision.

**Exact minimum engine surfaces that must change:**

| # | Surface | Change | Why (evidence) |
|---|---|---|---|
| 1 | `qpgen/models.py` (QuestionSlot) | ADD fields: `item_model_id`, `difficulty_drivers`, `gate_verdicts`, structured `solution_steps` | C1 — quality unrepresentable on the slot (models.py:124-143) |
| 2 | `qpgen/validate.py` | ADD the merged educational gate ladder (§7.2) + answer/solution artifact check; REMOVE the template exemption from grounding once concept-code binding lands (N4) | zero educational checks today; stem-only artifact asymmetry (§2.2) |
| 3 | `qpgen/select.py` | ADD archetype/template-exposure term + within-paper family cap; FIX `_priority` order vs docstring (N3) | 76% clones; no archetype term exists |
| 4 | `qpgen/pool.py` | REMOVE hard-coded LONG_ANSWER→HARD/ANALYZE (pool.py:112-122); labels flow from item-model bands | C2 internal contradiction |
| 5 | `qpgen/templates.py` | ADD registry precedence/override + retirement (ext can supersede native by template_id/binding); RETIRE or truth-table-fix the 4 native AR families (N1/N6); concept-code-exact binding for item-model families (N4) | first-match precedence blocks content-lane remediation |
| 6 | `qpgen/materialize.py` | REPLACE `spec_of` with the generation contract; ADD realization-fidelity check; structured solutions; answer-key artifact gating | contract hands labels only (materialize.py:308-316) |
| 7 | `qpgen/assemble.py` | ADD within-paper rendered-stem dedup (N5) + key-position balance | live regression: 10/54 papers |
| 8 | Ingestion phases `phase2/4(/7)` — **outside the qpgen freeze, separately scoped** | E-lite persistence (visual assets, boundary block types, offsets/bbox); stop the Phase-7 wipe once DNA store replaces it | R9/R11 |

Everything else (scope.py, blueprint(s).py, chapters.py, sanitize.py, engine.py orchestration, the
frozen matrix runner) stays untouched. Two engine bugs (N2 shadowed generator, N5 dedup) deserve
fixing regardless of program approval — they are defects, not architecture.

---

## 17. Missing architecture components (consolidated)

1. **Conceptual/non-numeric DNA + distractor lane** (Biology, descriptive Chemistry) — §4.1/§9.2. The
   single largest gap; decides whether NEET is served.
2. **Item sets/testlets** (case-study, paragraph, matrix-match, integer-answer, multi-correct
   pipelines) — §4.2/§13.2.
3. **Realization-fidelity gate + rendered-stem input rule for GATE 4** — §6.2.
4. **Answer-equivalence/tolerance policy** per item model — §4.5.
5. **Registry precedence/retirement mechanism** — §16.5 (N6).
6. **Minimum-evidence bar for Item-Model promotion** (cluster size, multi-source) — §5.1/§12.2.
7. **Algebraic-equivalence normalization rule in the Item-Model spec** — §5.2.
8. **Assumptions[] field + per-profile conventions** (g=9.8/10 etc.) — §4.4/§8.3.
9. **Structural similarity level in GATE 13** (source parameter-tuple distance) — §12.3.
10. **Distractor-statistics data source correction** (digital-practice channel, not marks grid) — §8.4.
11. **Teacher-certification workflow/tooling** for the standing TEACHER_VALIDATED stage — §15.5.
12. **Phase 0 kill-test + per-phase effort estimates and kill criteria** — §15.4/§15.5.
13. **Item-Model versioning/retirement lifecycle** wired to Phase-2 flags — §5.5.
14. **Benchmark statistics** (N, raters, agreement, test, pre-registration) — §14.2.

## 18. Over-engineered components (consolidated)

1. **15 separate gates** → same protection as ~11 merged checks + 2 additions (§7.2). Keep the ladder
   as documentation; don't build 15 processes.
2. **14 difficulty drivers** → 7 countable + 2 relocated; 3 have no measurement procedure and should
   be deferred, not shipped as pseudo-measurements (§8.2). Scalar weighted difficulty → ordinal band
   rules first (§8.6).
3. **4-parser × 12-class ingestion benchmark** → 2 parsers × 4 dominant classes × ~25 labelled docs
   first (§11.2).
4. **Per-DNA free-text assessment_construct extraction** → author construct per Item Model instead
   (§4.9).
5. **Per-instance adversarial multi-verifier panels** → certification-time sampling only (already the
   spec's position; flagged so it doesn't creep) (§7.3).
6. **ILP-style paper composition** → seeded greedy + swap repair is sufficient and reproducible
   (§13.3).
7. **19-archetype vocabulary at launch** — fine as vocabulary; do not build extraction/classifiers for
   archetypes with no corpus evidence until a document class supplies them (`experiment_inference`,
   `constraint_reasoning` have thin evidence in the current corpus).

## 19. Top 10 risks (ranked)

1. **Biology/conceptual lane absent** → NEET (the flagship profile) remains definition-match-only
   after the entire Phase B investment. (§4.1)
2. **Structure-mining yield unknown** — relation-match may recover far fewer than 5,224 items
   (OCR/extraction damage, relation-library coverage); no spike is scheduled to measure it before
   schema build. (§15.3/15.4)
3. **Sophisticated clone generator** — small DNA clusters + few models per concept + wide difficulty
   bands reproduce today's 76% clone failure one level up, now with originality exposure. (§5.1/§12.2)
4. **Benchmark cannot prove the claim it gates on** — no N/agreement/test/pre-registration; style
   recognizability; teachers rating correctness. Scale decisions would rest on soft evidence. (§14)
5. **LLM realization drift ungated** — the one channel where a model can silently corrupt a certified
   item. (§6.2)
6. **Board PDFs ingested lossy** while E waits — rework + intake-immutability governance conflict.
   (§15.2)
7. **Registry precedence** silently routes concepts to old flawed families even after new models
   ship. (N6)
8. **Difficulty pseudo-measurement** — unmeasurable drivers + invented weights make GATE 9 reject/pass
   on noise and discredit the label with teachers. (§8)
9. **Psychometric promise unkeepable** (distractor stats from marks grid) — erodes trust in the
   whole calibration story when discovered later. (§8.4)
10. **Program cost opacity** — no effort estimates/kill criteria; a benchmark-gated program without
    exit prices invites sunk-cost continuation. (§15.5)

## 20. Exact recommended corrections

**Before approval (doc-level, cheap):**
1. Add the conceptual-item lane to QUESTION_DNA/ITEM_MODEL specs (§4.1, §9.2) — or explicitly scope
   Biology out of Phase B in the roadmap and in anything shown to the owner.
2. Rewrite the AR remedy: truth-table-varied AR generation (all four keys reachable), semantic
   key-constancy check in GATE 14. (N1)
3. Pin GATE 4 input = rendered stem; add the realization-fidelity gate; add the answer/solution
   artifact gate. (§6.2, §2.2)
4. Merge gates per §7.2 (4+5+12; 9+10; fold 6 into 7's pass) — keep the 15-gate doc as taxonomy.
5. Correct PSYCHOMETRIC §4.1: distractor-level stats require digital response capture; marks-grid
   yields p-value/discrimination/blank-rate only. (§8.4)
6. Split difficulty drivers into measurable-now vs deferred; per-profile weight vectors; ordinal bands
   v1. (§8)
7. Add to ITEM_MODEL: minimum cluster evidence (K, multi-source), algebraic-equivalence normalization,
   version/retirement lifecycle, answer-equivalence policy, `assumptions[]`. (§5, §4.4-4.5)
8. Add structural (parameter-tuple) similarity to GATE 13 + source-tuple exclusion. (§12.2-12.3)
9. Benchmark plan: pre-registered thresholds file, ≥3 raters, ≥30 items/cell, Krippendorff α ≥ 0.6,
   paired nonparametric test, machine-gated correctness, absolute-bar-primary framing. (§14.2)
10. Roadmap: insert Phase 0 (two spikes, §15.4); split E into E-lite (alongside A/B) + E-full; add
    per-phase effort estimates and kill criteria; schedule the N5 within-paper dedup fix immediately.
11. Fix record hygiene: native/ext split (52+42), stale definition counts, formulas row drift; cite
    Rule 7 → AIMS, L1/L2/L3 → GAP_ANALYSIS D-3; note A2/I9 as approved-direction/unratified. (N7,
    §3 last row)

**At Phase-A implementation:**
12. Land the §16 engine change-list as ONE reviewed change set with the frozen matrix + golden tests
    green, including the two outright bug fixes (N2, N5) and the `_priority` correction (N3).
13. Concept-code-exact binding for all item-model families; no new family may bind by title substring.
    (N4)

## 21. Final verdict

**CONDITIONAL GO.**

- The root-cause investigation is **sound**: every materially load-bearing claim reproduced exactly
  from code, DB, and raw artifacts. The diagnosis (constraint compliance ≠ quality; structure
  discarded at ingestion; content starvation) is correct and complete enough to build on.
- The proposed architecture is **the right shape** — structure-learning, engine-owned intelligence,
  adversarial gates, predicted/empirical separation, benchmark-gated scaling — and is implementable on
  the existing Akshara architecture through a bounded `MINIMAL_ENGINE_EXTENSION` (§16) plus the
  sanctioned content lane.
- It is **not approved as-written**. The conditions in §20 items 1-11 are required before build
  approval; items 1 (conceptual lane), 3 (realization fidelity), 5 (psychometric contradiction), 9
  (benchmark statistics), and 10 (Phase 0 + E-lite sequencing) are the ones that change outcomes, not
  just documents. Phase 0's two spikes (mining yield; hand-built-model quality lift) should run before
  any schema or engine work is funded — they are the cheapest way to kill or confirm the program's
  central bet.
- Scaling to lakhs of items remains correctly forbidden until the (corrected) benchmark shows a
  blind-reviewed lift **and** an absolute quality bar vs gold anchors — "better than a 0/57 engine" is
  a floor, not a target.

*Reconciliation with the previous architect is explicitly out of scope for this review, per the
mission. This document modifies none of the 11 existing deliverables.*
