# Current vs. Required Architecture

**Date:** 2026-07-11 · **Companion to:** `QUESTION_QUALITY_ROOT_CAUSE_AUDIT.md`
**Purpose:** Map every component of a quality-first Question Intelligence System against what exists
today, so the roadmap extends what works and only rebuilds what is genuinely missing.

Legend: **EXISTS_AND_SUFFICIENT** · **EXISTS_BUT_WEAK** · **PARTIAL** · **MISSING** · **REDUNDANT** ·
**CONFLICTS** (with a locked decision).

---

## 1. The architectural gap in one picture

**Today (constraint-first):**
```
corpus → parse (loses images/equations) → chunk (loses question boundaries)
       → concepts (noisy) + frequency metadata (Phase 7 discards structure)
       → select concept + STAMP difficulty/bloom label
       → render from 94 hand-authored 1-formula templates OR raw definition OR spec
       → constraint gates (syllabus/format) → print
```
Intelligence lives in **boundary enforcement**. Quality is **unmodeled**.

**Required (quality-first):**
```
corpus → routed multimodal parse (preserve visuals/equations/tables + provenance)
       → question-boundary extraction (stem/options/answer/solution/visual)
       → Question DNA extraction (construct, archetype, cognitive chain, difficulty drivers,
                                   distractor DNA, solution DNA, visual DNA)   [L2, separate from wording]
       → cluster DNA → ITEM MODELS (variable schema, constraints, answer fn, distractor generators)
       → generation CONTRACT (engine decides everything; model only realizes language)
       → deterministic parameterize → INDEPENDENT solve → distractor/ambiguity/difficulty/flaw gates
       → originality gate → certify (family-level, A2)
       → PAPER intelligence (archetype + cognitive + difficulty + exposure diversity)
       → [Phase 2] empirical calibration from marks-grid responses
```
Intelligence lives in **the item model and the gates**. Boundary enforcement is retained as a subset.

---

## 2. Component-by-component

### 2.1 Knowledge & ingestion

| Component | Status | Evidence | Action |
|---|---|---|---|
| PDF parse (PyMuPDF + Tesseract + pdfplumber) | EXISTS_BUT_WEAK | `phase2_parse.py` — one route for all docs; no multi-column reading-order; equations = font heuristic | Add **parser routing** by doc class (MULTIMODAL spec) |
| Image / figure extraction | PARTIAL → effectively MISSING | extracted to JSON side-file `phase2_parse.py:105-119`, **dropped at DB boundary**; no `images` table | New `visual_assets` store + chunk links |
| Equation extraction | EXISTS_BUT_WEAK | `_is_math_span` tags spans, truncates to 200 chars, never persisted | Real formula/relation extraction into `formulas.expression` + `symbols` |
| Table extraction | EXISTS_AND_SUFFICIENT | `block_type="table"` chunks survive `phase4_chunk.py:101-111` | Extend into `table_spec` for data-interpretation items |
| Chunking | EXISTS_BUT_WEAK | token/heading only; block_type ∈ {paragraph, table}; no question boundaries | Add question-boundary detection (stem/option/solution block types) |
| Provenance (resource, page) | PARTIAL | `doc_id`, `page_start/end` populated; `char_start/end` always NULL; no bbox in DB | Populate offsets + bbox; link visuals |
| Concept extraction | EXISTS_BUT_WEAK | 3 regex sources + 3 noise passes; ~27% sampled active concepts noise/mistagged | Tighten active-eligibility gate before generation |
| `formulas` (law names) | EXISTS_BUT_WEAK | 317 rows, 0 equations | Relation library with real expressions |
| `concept_edges` (prereq DAG) | EXISTS_AND_SUFFICIENT | `phase6_graph.py`; DAG-validated | Reuse for prerequisite depth (a difficulty driver) |
| Intake (incremental) | EXISTS_AND_SUFFICIENT (volume); propagates losses | `intake/pipeline.py` reuses frozen phases | Benefits automatically once phases improve |
| Licence ledger | EXISTS_AND_SUFFICIENT | per-resource `license_status`; 6+ states; `LICENSE_REPORT.md` | Extend states to the mission's L1/L2/L3 taxonomy (below) |

### 2.2 Question representation

| Component | Status | Evidence | Action |
|---|---|---|---|
| `QuestionSlot` object | EXISTS_BUT_WEAK | `models.py:124-143` — flat stem/opts/answer/solution + bare labels | Keep as the **rendered instance**; add `item_model_id`, driver + verdict provenance |
| Item Model | MISSING | no field; `question_templates` table empty | New object; extend `question_templates` (ITEM_MODEL spec) |
| Question DNA | MISSING | `question_patterns` is a 4-field string | New L2 store (QUESTION_DNA spec) |
| Difficulty drivers | MISSING | bare enum | New driver vector on Item Model + instance |
| Cognitive-operation chain | MISSING | — | New ordered list on Item Model + DNA |
| Assessment construct / LO | MISSING | only free-text `chapter` | New construct field; map to `concept_board_mappings` |
| Distractor DNA | MISSING | `distractors` empty | Populate `distractors` with misconception type |
| Structured solution steps | MISSING | one string | Step array (identify→apply→compute→answer→verify) |
| Visual spec | MISSING | declared out-of-scope `templates.py:177` | New semantic visual spec (VISUAL spec) |

### 2.3 Generation

| Component | Status | Evidence | Action |
|---|---|---|---|
| Template registry (94, 88 single-substitution) | EXISTS_BUT_WEAK | measured registry | Grow via learned item models across archetypes |
| Definition-match MCQ | EXISTS_BUT_WEAK | `materialize.py:241-272`; sibling-concept distractors | Keep; upgrade distractors to misconception-driven |
| Descriptive render (verb+title) | EXISTS_BUT_WEAK | `materialize.py:116-137`; ships raw OCR text as key | Gate answer-key quality; structured model answers |
| AI-fill contract | EXISTS_BUT_WEAK | `spec_of` sends only labels | Replace with full **generation contract** (engine supplies structure) |
| Selection (concept spread) | EXISTS_AND_SUFFICIENT (concept); MISSING (archetype) | `select._priority` | Add archetype/cognitive/exposure diversity terms |
| `question_families` (2,015 draft) | REDUNDANT as-is | unused by engine | Repurpose: family → item model link, A2 certification |

### 2.4 Validation & quality

| Component | Status | Evidence | Action |
|---|---|---|---|
| Constraint gates (syllabus/subject/format) | EXISTS_AND_SUFFICIENT | `validate.py:32-98` | Keep as GATE 1-3, 6 |
| Independent blind solve | MISSING | "solver_verified" = self-consistent | New GATE 4-5 |
| Distractor plausibility | MISSING | string-distinct only | New GATE 7 |
| Ambiguity (semantic) | MISSING | exact-string only | New GATE 8 |
| Difficulty-driver verification | MISSING | — | New GATE 9 |
| Bloom/cognitive verification | MISSING | never read in validate | New GATE 10 |
| Visual consistency | MISSING | — | New GATE 11 |
| Formula/unit/dimensional | MISSING | — | New GATE 12 |
| Originality / similarity | MISSING (only exact key dedup) | `validate.py:117-121` | New GATE 13 |
| Item-writing-flaw rubric | MISSING | AR always-(a) uncaught | New GATE 14 |
| Paper-level diversity | PARTIAL (coverage only) | matrix measures repetition post-hoc | New GATE 15 |

### 2.5 Psychometrics & calibration

| Component | Status | Evidence | Action |
|---|---|---|---|
| Predicted difficulty (from drivers) | MISSING | label heuristic only | Deterministic driver model |
| `edu_item_statistics` schema | PARTIAL (locked, dormant) | Vision D6 §10.1 | Seed now (data can't be backfilled), fill in Phase 2 |
| Response spine (marks-grid) | PARTIAL (locked, dormant) | Vision D1 `edu_student_item_responses` | Phase 2; **D2 forbids per-student OMR** |
| CTT (p/discrimination/point-biserial) | MISSING | no response data | Phase 2 |
| IRT (Rasch/2PL/3PL) | MISSING | — | Phase 2, volume-gated |

### 2.6 Program-level

| Component | Status | Evidence | Action |
|---|---|---|---|
| Frozen 57-paper coverage matrix | EXISTS_AND_SUFFICIENT (coverage) | `qp_output_audit.py` | Keep; add answer/solution artifact check |
| Gold benchmark + blind expert review | MISSING | D7 §11 spec only | Build before scaling (BENCHMARK plan) |
| Model routing / cost tiers | PARTIAL | live ERP client; no KIE tiering | Tier-0..3 routing (MODEL_ROUTING plan) |
| A2 family certification | PARTIAL (designed, unratified) | `AMENDMENT_A2...md` | Adopt as the certification model |

---

## 3. Alignment with locked decisions (must not conflict)

The redesign is constrained by decisions already locked. Explicit alignment:

- **D1 (response-centric), D6 (item statistics), D7 (AI never auto-trusted; independent blind solve;
  eval harness):** the quality gates and calibration spec **implement** these, not replace them. New
  psychometric fields align to the existing `edu_item_statistics` schema.
- **D2 (no per-student answer-sheet OCR/OMR):** calibration uses the **per-question marks grid** only. Any
  proposal here that implied answer-sheet scanning would CONFLICT and is excluded.
- **D8 (original-content-first) + Rule 7 (PYQ = L2 analysis-only):** Question DNA stores structure, never
  wording; production items are original parameterizations. The L1/L2/L3 separation is preserved.
- **A2 (certify the family, not the instance) + I9 (runtime deterministic, AI-free):** Item Models are
  exactly A2 "certified families." Runtime instantiation is deterministic + solver-verified; AI is used
  **offline** at authoring/DNA-extraction time, never at runtime.
- **Engine-frozen + `templates_ext` content lane:** all new families register through the sanctioned hook;
  new gates are added to `validate.py` as additive checks. Where a change *must* touch engine code (e.g.
  the `QuestionSlot` gaining an `item_model_id`, or `select` gaining an archetype term), it is called out
  explicitly in the roadmap as a **scoped, reviewed engine change** — not smuggled in.

**One honest tension to surface for owner decision:** the current program treats `kie/qpgen/` as *frozen*
and grows only via content. A genuine quality-first system requires a small number of **engine-level**
changes (new gates, an archetype-diversity term in selection, an `item_model_id` on the slot, structured
solutions). These cannot be delivered purely through the content hook. The roadmap isolates them into a
single reviewed "engine v2" change set with its own regression gate, rather than pretending the content
lane alone suffices. See roadmap Phase A/C.

---

## 4. What we are explicitly NOT doing

- Not rewriting the boundary/scope engine, the template mechanism, or the validation scaffold.
- Not replacing the frozen coverage matrix — complementing it.
- Not introducing per-student OMR (D2).
- Not calling an LLM at runtime for certified generation (I9).
- Not solving copyright by paraphrase — only abstract structure is reused (D8).
- Not scaling volume before the benchmark proves quality.

---

## Reconciliation Amendment (2026-07-12, post-Fable-5) — final engine decision + minimal surfaces

Governed by `OPUS_FABLE_RECONCILIATION_RECORD.md` §4. The "honest tension" this document raised (§3) is
**resolved**: the content lane alone is insufficient (a flawed **native** family — e.g. the four `_ar_family`
templates — cannot be overridden through `templates_ext`, because `find_template` returns the first REGISTRY
match and native families load first; 5 live overlaps confirm it), and a rewrite is unwarranted (boundary,
blueprint, template mechanism, assemble, and the validation scaffold are sound and load-bearing).

**FINAL DECISION: `MINIMAL_ENGINE_EXTENSION`** — one reviewed, additive change set with its own regression
gate (frozen matrix green + golden tests). Exact surfaces allowed to change; **everything else in `kie/qpgen/`
stays frozen:**

| # | Surface | Change |
|---|---|---|
| 1 | `qpgen/models.py` | `QuestionSlot` gains `item_model_id`, `lane`, `difficulty_drivers`, `gate_verdicts`, structured `solution_steps` |
| 2 | `qpgen/validate.py` | new educational gate ladder (blind-solve, distractor plausibility, ambiguity, difficulty-driver, cognitive, originality-incl-structural, item-writing incl. AR semantic, **concept-binding integrity**, **realization fidelity**, **answer/solution artifact**); remove the template grounding exemption once scope binding lands |
| 3 | `qpgen/select.py` | lane/archetype + exposure diversity terms + within-paper family cap; fix `_priority` order to match its documented intent |
| 4 | `qpgen/pool.py` | remove hard-coded `LONG_ANSWER → HARD/ANALYZE`; labels flow from item-model bands |
| 5 | `qpgen/templates.py` | explicit registry priority + **family retirement/versioning**; retire the 4 `_ar_family` templates for the ASSERTION_RELATION lane; **concept-code-exact binding**; **registration-time integrity check** |
| 6 | `qpgen/materialize.py` | replace `spec_of` with the full generation contract; realization-fidelity check; structured solutions; answer-key artifact gating |
| 7 | `qpgen/assemble.py` | within-paper rendered-stem structural dedup + key-position balance |
| 8 | `phase2/phase4(/phase7)` — separately scoped, outside the qpgen freeze | E-lite persistence (visual assets, boundary block types, offsets/bbox, equations/tables); retire the Phase-7 structure wipe once the DNA store supersedes it |

Frozen and untouched: `scope.py`, `blueprint(s).py`, `chapters.py`, `sanitize.py`, `engine.py` orchestration,
`qp_output_audit.py`. The two outright bugs (within-paper dedup, shadowed generator) are fixed regardless of
program approval. Component-status corrections: template registry is **52 native + 42 ext = 94**;
`prerequisite` concept_edges = 10 (so prerequisite-depth is near-unusable as a driver now); Question DNA /
Item Model are **per-lane** (Record §2), not a single numeric model.
