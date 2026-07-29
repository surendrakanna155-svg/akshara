# QIE — Repository Inventory Audit

**Date:** 2026-07-29 · **Purpose:** prove what knowledge the repository actually contains, before any
roadmap decision. **No capability estimates in this document.**
**Trigger:** the challenge that the capability audit measured only the active generation bindings rather
than the whole repository. **That challenge was correct, and this document corrects the record.**

---

## 0. What the previous audit got wrong

The capability audit (`QIE_CAPABILITY_AUDIT_2026-07-29.md`) counted **what the generator can reach**. It
did not inventory the repository. Stores it never opened:

| Store | Rows it never counted |
|---|---|
| `kie.db formulas` | 317 |
| `kie.db question_patterns` | 4,853 |
| `kie.db question_families` | 2,015 |
| `kie.db concepts` | 3,006 |
| `kie.db concept_edges` | 1,654 |
| `graph_edges.db prereq_edge` | 1,805 |
| `graph_edges.db concept_namespace` | 3,021 |
| `unified_inventory.db` | 8,450 |
| `qie.db kvs_assertion` | 3,759 |

**The repository is far larger than that audit implied.** What follows separates rows that carry
generative content from rows that do not — because the second correction is that much of this volume,
inspected, cannot drive a generator.

---

## 1–8. The counts

### 1. Certified concepts — **2,009**

There are **two separate concept registries**, and they are not compatible.

| Registry | Store | Total | Breakdown |
|---|---|---|---|
| **Certified index (authoritative)** | `knowledge_index.db ki_concept` | 2,836 | **certified 2,009** · quarantined 757 · rejected 70 |
| Legacy registry | `kie.db concepts` | 3,006 | active 1,692 · merged 31 · rejected 1,283 |

`knowledge/planner.py` states the rule: *"QIE planning now consumes ONLY the certified knowledge index
(`ki_concept.status='certified'`). It may not read `kie.db.concepts`."* The 1,692 "active" legacy concepts
are **not** additional certified knowledge; they are the superseded registry whose defects
(`Gahe tava jaya gatha` as a Class-10 Maths concept, `Contributors`, `Preamble`) motivated building the
certified index.

### 2. Certified facts — **2,041**

`qie.db governed_fact`: 2,438 total → **2,041 verified**, 397 rejected.
Of the 2,041: 1,424 carry an explicit `provenance.concept_id`; **617 carry no concept binding at all.**

### 3. Formulas — **317 named, 0 usable as expressions**

`kie.db formulas` holds 317 rows (law 161 · rule 71 · principle 51 · theorem 34).

```sql
SELECT SUM(expression LIKE '%=%'), COUNT(*) FROM formulas;   -->  0 | 317
```

**Not one contains an equation.** The `expression` column holds the *name*: `"Huckel rule"`,
`"Bernoulli's principle"`, `"Stoke's law"`. These are law **labels**, not relations. They cannot be
solved, substituted into, or verified.

Actual usable relations live elsewhere:

| Source | Count | Usable? |
|---|---|---|
| `qie.db governed_relation` (certified) | **49** | yes — real equations |
| `kie.qie.relations.LIBRARY` (code) | **86** | yes — executable |
| `kie.db formulas` | 317 | **no — names only** |

### 4. Operators — **9**

`kie.qie.compose.OPERATORS`: `differentiate, integrate_def, evaluate, real_roots, min_root, max_root,
unique_root, subtract_poly, absval`. Polynomial calculus only.

### 5. Bindings — **36 active, 84 legacy stranded**

| Kind | Count | Connected? |
|---|---|---|
| `certgen` bindings (numeric 20 · chains 5 · AR 4 · match 3 · conceptual 4) | **36** | **yes** |
| `qie.db item_model` | 84 | **no** — see §11 |

### 6. DNA-derived concepts — **187 distinct, none usable**

| Asset | Rows | Distinct concepts |
|---|---|---|
| `question_dna` | 2,996 | **187** |
| `distractor_dna` | 1,842 | — |
| `question_patterns` | 4,853 | — |
| `question_families` | 2,015 (all `draft`) | — |

Three findings on quality:

* **`question_dna.solution_dna` and `difficulty_drivers` are empty in all 2,996 rows.**
* **`question_patterns.stem_skeleton` is not a skeleton.** It is a tag string:
  `"assertion_reason|bloom=remember|difficulty=hard|options=1"`. No wording, no structure, no parametric
  slots.
* **`question_families` are all `status='draft'`** with boilerplate descriptions
  (*"PYQ-derived draft family (analysis-only, original)"*).

### 7. Previous-year questions indexed — **15,803**

`pyq_corpus.db`: `pyq_item` 15,803 · `pyq_item_difficulty` 15,803 · `pyq_chunk_subject` 14,575 ·
`exam_dna_v2` 15 · `marking_scheme` 4. Span 2011–2025, 26 distinct sittings.
Established previously: `concept_kc` linked on 132 (0.8%); difficulty is `structural_proxy` on 100%;
`exam_dna_v2` reports `insufficient_evidence` for both behavioural dimensions; no answer keys.

### 8. NCERT indexed — **1,241 documents → 57,390 chunks → 2,009 certified concepts**

`kie.db`: `source_documents` 1,241 · `parsed_documents` 1,229 · `chunks` 57,390 ·
`document_sections` 62,048 · `chunks_fts` full-text index present.
`knowledge_index.db`: `ki_chapter` 284 accepted · `ki_rejected` 6,234 (the audit trail of what was refused).

### Other stores

| Store | Contents |
|---|---|
| `graph_edges.db` | **`prereq_edge` 1,805** · `concept_namespace` 3,021 · `cleaned_evidence` 2,034 · `revisits_edge` 18 |
| `unified_inventory.db` | `unified_inventory` **8,450** · `crosswalk` 2,186 |
| `figure_catalog.db` (191 MB) | `figure` 113 · `figure_asset` 87 · **`figure_element` 0 · `figure_link` 0** |
| `factory_corpus.db` | `candidate` 1,000 · `gate_result` 7,649 · `judge_verdict` 91 (the dormant AI-factory trial) |
| `qpl_question_bank.db` | `candidate` 24 |
| `examdna.db` | `exam_weight` 236 · `exam_distribution` 70 |
| `qdi.db` | `qdi_pattern` 12 · `qdi_source` 6 |
| `qie.db` KVS | `kvs_assertion` 3,759 · `kvs_taxonomy` 131 · `kvs_sequence` 21 · `kvs_structure_function` 15 · `kvs_comparison` 8 |
| `qie.db` | `pilot_verified_item` 1,496 · `tier2_verdict` 454 |

**`kvs_assertion` quality check.** 3,759 rows, but **only 77 carry the ≥2 independent evidence sources its
own schema requires** — 98% fail their own bar. Inspected content is heading fragments, not knowledge:
`Snapshots —parent_child→ Keep the curiosity alive`, `Safety First —parent_child→ Think like a scientist`.
`kie.db concept_edges` (1,654) contains the same artefacts: `PHY_SNAPSHOTS —parent_child→
PHY_KEEP_THE_CURIOSITY_ALIVE`.

**`unified_inventory` — the system's own verdict on its assets:**

| promotion_status | rows |
|---|---|
| held_low_quality | **3,682** |
| held_qualitative | **2,103** |
| practice_tier_eligible | 1,434 |
| rejected_source | 458 |
| honest_null | 456 |
| quarantined | 184 |
| eligible | 77 |
| **promotable** | **41** |
| held_trial | 15 |

Concept resolution: **1,189 of 8,450 (14.1%) resolve to a `KC_` id.**

---

## 9. Are these repositories unified, or separate?

**Separate. Twelve SQLite files, no foreign keys between them, and two mutually incompatible concept
namespaces.**

`unified_inventory.db` is a genuine attempt at unification — it crosswalks `qie.db`,
`qpl_question_bank.db` and `factory_corpus.db` into one registry with a `concept_kc` column. But:

* it covers **only question/relation/fact assets** — not concepts, formulas, patterns, prereq edges, PYQ,
  or figures;
* its own crosswalk resolves **14.1%**;
* **nothing in `certgen` reads it.**

### The namespace fork — the central structural finding

```sql
-- do the DNA layer's concept codes exist in the certified index?
SELECT COUNT(DISTINCT concept_code) FROM question_dna;              -->  187
SELECT ... LEFT JOIN ki_concept ON concept_id = concept_code;       -->    0 matches
```

**Zero of 187.** The DNA / item-model / KVS / concept-edge layer is keyed on legacy codes
(`BIO_ACTIVATION_ENERGY`, `PHY_SNAPSHOTS`, `BRD_PHY_ce26529e8f59`) drawn from `kie.db concepts` — the
registry the planner is explicitly forbidden to read. The certified index is keyed on `KC_*`.

**These two halves of the repository cannot address each other.** That single fact explains most of the
disconnection below.

---

## 10. Repositories currently used by the question generator

**Two.**

| Store | What is read | By |
|---|---|---|
| `knowledge_index.db` | `ki_concept` (certified) + `ki_chapter` (accepted) | `planner.certified_universe_by_discipline` → every `certgen` resolver |
| `qie.db` | **`governed_relation` only** (49 rows) | `engine.certified_relation_context()` |

The validator additionally opens `kie.db` (`DB_PATH`) for chunk-level checks.

That is the entire read surface of the generator.

---

## 11. Repositories NOT connected to the generator

| Store / table | Rows | Why it is disconnected |
|---|---|---|
| `graph_edges.db prereq_edge` | **1,805 (1,183 KC-resolved)** | **No consumer outside `qie/graph/` and its tests. Correctly namespaced on `KC_*`. This is the most valuable disconnected asset in the repository.** |
| `graph_edges.db concept_namespace` | 3,021 | same |
| `qie.db item_model` | 84 | legacy namespace |
| `qie.db question_dna` | 2,996 | legacy namespace; `solution_dna` + `difficulty_drivers` empty |
| `qie.db distractor_dna` | 1,842 | legacy namespace; 77% classified only as `other` |
| `qie.db kvs_*` | 3,934 | legacy namespace; 98% below their own evidence bar; heading fragments |
| `qie.db governed_fact` | 2,041 verified | 617 unbound; qualitative lane not auto-certifiable |
| `qie.db pilot_verified_item` | 1,496 | model-verified, `held_qualitative` in the unified inventory |
| `kie.db formulas` | 317 | **no expressions — names only** |
| `kie.db question_patterns` | 4,853 | `stem_skeleton` is a tag string, not a template |
| `kie.db question_families` | 2,015 | all `draft`, boilerplate |
| `kie.db concepts` | 3,006 | superseded registry; planner forbidden to read it |
| `kie.db concept_edges` | 1,654 | legacy namespace; heading artefacts |
| `pyq_corpus.db` | 15,803 | read only by the offline `stem_dna` miner; **no generator path** |
| `unified_inventory.db` | 8,450 | read by `qp_bridge`/`inventory`, **not by `certgen`** |
| `figure_catalog.db` | 113 / 87 | `figure_element` + `figure_link` empty |
| `examdna.db` | 306 | no consumer in the generation path |
| `qdi.db` | 18 | misconception pressure hardcoded 0 |
| `factory_corpus.db` | 1,000 candidates | dormant AI-factory lane ($0 policy) |
| `qpl_question_bank.db` | 24 | superseded |

---

## 12. Dependency diagram — with every break marked

```
                          KNOWLEDGE SOURCES
   1,241 source_documents -> 57,390 chunks -> 62,048 document_sections
                                  |
                                  v
                            CERTIFICATION
   ki_concept 2,009 certified (KC_*)          kie.db concepts 3,006 (LEGACY codes)
   ki_chapter 284 accepted                    kie.db formulas 317  [NO EXPRESSIONS]
   governed_fact 2,041 verified                            |
                    |                                      |
        ============|======== NAMESPACE FORK ==============|============
        |  KC_* side (certified)             legacy SUBJ_* side        |
        ============|======================================|============
                    |                                      |
                    v                                      v
              CONCEPT GRAPH                              DNA
   graph_edges.prereq_edge 1,805  ##BREAK 1##    question_dna     2,996  ##BREAK 4##
   (1,183 KC-resolved, 0 consumers)             distractor_dna   1,842  ##BREAK 4##
   concept_namespace       3,021  ##BREAK 1##   question_patterns 4,853  ##BREAK 5##
   kie.db concept_edges    1,654  ##BREAK 2##   question_families 2,015  ##BREAK 5##
                    |                            item_model          84  ##BREAK 4##
                    |                            kvs_*            3,934  ##BREAK 6##
                    |                                      |
                    v                                      X  (cannot reach bindings:
                 BINDINGS                                      legacy namespace)
   certgen: 36 hand-authored
   reads: ki_concept + governed_relation(49)
                    |
                    v
             QUESTION PLANNER
   planner.certified_universe_by_discipline
   check_plan (7 deterministic refusals)
   ##BREAK 3## no prerequisite ordering, no exam blueprint, no PYQ-frequency weighting
                    |
                    v
            QUESTION GENERATOR
   5 lanes -> 115 items
                    |
                    v
               VALIDATION
   22-gate battery + lane FATAL proofs   [CONNECTED AND WORKING]
                    |
                    v
   ##BREAK 7## no write-back: generated items enter no bank, no unified_inventory row
```

### The seven breaks, precisely located

| # | Break | Where exactly |
|---|---|---|
| **1** | **Prerequisite graph is orphaned** | `graph_edges.db` has 1,183 KC-resolved prerequisite edges. `certgen` and `planner` never open it. **Correct namespace, real content, zero consumers.** The cheapest high-value reconnection in the repository. |
| **2** | Legacy concept edges unusable | `kie.db concept_edges` (1,654) — legacy namespace *and* heading artefacts. Not worth reconnecting. |
| **3** | Planner has no ordering or blueprint input | `check_plan` validates a spec but nothing supplies prerequisite depth, exam weighting, or a paper blueprint. `examdna.db` (306 rows) sits unread. |
| **4** | **DNA layer stranded by the namespace fork** | `question_dna` / `distractor_dna` / `item_model` are keyed on legacy codes. **0 of 187 DNA concept codes match any `KC_` id.** No join is possible without a crosswalk that does not exist. |
| **5** | Pattern/family layer carries no structure | `question_patterns.stem_skeleton` is `"mcq\|bloom=apply\|difficulty=hard\|options=4"`. `question_families` are draft stubs. Reconnecting them would import metadata, not questions. |
| **6** | KVS below its own evidence bar | 77 of 3,759 assertions meet the ≥2-source requirement; content is TOC headings. |
| **7** | No write-back path | Generated items are returned in memory. They are not persisted to a bank, do not receive `unified_inventory` rows, and are not deduplicated against prior runs across sessions. |

---

## Summary of findings

**The repository contains more knowledge than the capability audit credited — and less usable knowledge
than the raw row counts suggest.**

Corrected totals:

* certified concepts **2,009** (plus a superseded 3,006-row registry that must not be used)
* certified facts **2,041** (617 unbound)
* formulas **317 named / 0 with expressions**; usable relations **49 certified + 86 in code**
* operators **9**
* bindings **36 active / 84 legacy stranded**
* DNA-derived concepts **187 distinct — none resolvable to the certified index**
* PYQ indexed **15,803**
* NCERT indexed **1,241 docs → 57,390 chunks → 2,009 certified concepts**

**Where the pipeline actually breaks:** the repository is split by a **concept-namespace fork**. Everything
derived before the certified index was built (DNA, item models, KVS, concept edges, patterns, families —
roughly 17,000 rows) is keyed on legacy codes that share **zero** identifiers with the 2,009 certified
concepts the generator is required to use. Those assets are not merely unwired; **no join exists that
would wire them.**

The one substantial asset that is correctly namespaced, non-trivial, and simply unused is the
**prerequisite graph: 1,183 KC-resolved edges over 1,183 concepts, with no consumer anywhere outside its
own module and tests.**
