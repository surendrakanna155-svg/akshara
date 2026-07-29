# QIE — Repository Integration Master Plan

**Date:** 2026-07-29 · **Status:** ARCHITECTURE PHASE — no implementation code
**Mandate:** all new QIE feature development paused. No new question types, no new bindings, no new lanes.
**Objective:** make the knowledge the repository already holds usable by the engine.
**Predecessors:** `QIE_CAPABILITY_AUDIT_2026-07-29.md` · `QIE_REPOSITORY_INVENTORY_AUDIT_2026-07-29.md`

---

# PART 1 — VALIDATION OF EVERY PRIOR FINDING

Every claim re-tested against the live stores. **Two of my own findings were wrong and are corrected
here.**

## 1.1 Confirmed

| Claim | Re-tested value | Verdict |
|---|---|---|
| Certified concepts | `ki_concept status='certified'` = **2,009** (of 2,836) | ✅ |
| Legacy concept registry | `kie.db concepts` = **3,006** (1,692 active) | ✅ |
| Certified facts | `governed_fact status='verified'` = **2,041** | ✅ |
| Facts without concept binding | **617** | ✅ |
| Formulas carrying an equation | `SUM(expression LIKE '%=%')` = **0 of 317** | ✅ |
| Operators | `compose.OPERATORS` = **9** | ✅ |
| Active bindings | **36** | ✅ |
| PYQ indexed | **15,803** | ✅ |
| NCERT substrate | **57,390** chunks from **1,241** documents | ✅ |
| Prerequisite graph | **1,805** edges, **1,183** KC-resolved | ✅ |
| Unified inventory | **8,450** rows, **41** promotable, **1,189** KC-resolved | ✅ |
| KVS evidence bar | **77 of 3,759** carry ≥2 sources | ✅ |
| Figure elements / links | **0 / 0** | ✅ |
| **Write-back absent** | `grep INSERT\|UPDATE\|commit()` in `certgen/` → **zero hits** | ✅ |
| **Generator read surface** | `certgen/` opens exactly one DB directly (`qie.db`, read-only); `knowledge_index.db` arrives via a caller-supplied connection to `planner` | ✅ |

## 1.2 CORRECTION 1 — `governed_fact` is **not** stranded by the namespace fork

The inventory audit listed `governed_fact` among the legacy-namespace casualties. **That was wrong.**

```sql
SELECT COUNT(*) FROM governed_fact g JOIN ki_concept c ON c.concept_id = g.certified_concept_code;
-->  1,424
SELECT COUNT(DISTINCT certified_concept_code) FROM governed_fact WHERE certified_concept_code LIKE 'KC_%';
-->  1,362
-- and it is identical to the provenance field:
SELECT SUM(certified_concept_code = json_extract(provenance,'$.concept_id')) ... -->  1,424 / 1,424
```

**1,424 of the 2,041 certified facts (69.8%) are already KC-native, spanning 1,362 distinct certified
concepts.** They are not blocked by any namespace problem. They are simply **not read by the generator.**

This materially improves the integration outlook: the single largest certified asset needs *connection*,
not *migration*.

## 1.3 CORRECTION 2 — certified relations are **41**, not 49

`governed_relation` holds 49 rows: **41 certified, 8 rejected**. `gates.load_certified_relations` filters
on `status='certified'`, so the live registry the validator consults is **41**. Earlier statements of "49
certified relations" overstated by 8.

## 1.4 REFINEMENT — the DNA layer has **three** namespaces, not two

| Namespace | Distinct codes | Resolves to |
|---|---|---|
| Legacy `SUBJ_NAME` (e.g. `BIO_ACTIVATION_ENERGY`) | **94** | `kie.db concepts` |
| Pseudo-code `Subject:keyword` (e.g. `Biology:enzyme`, `Chemistry:ion`) | **93** | **nothing** |
| `KC_*` | **0** | — |

So the DNA layer is worse than "one fork away": **half of it does not resolve even within its own legacy
registry.** `Biology:enzyme` is a keyword bucket, not a concept identifier.

---

# PART 2 — COMPLETE REPOSITORY ARCHITECTURE

12 SQLite stores. No cross-store foreign keys anywhere.

| # | Store | Purpose | Owner (writer) | Key tables & counts | Reads from | Read by | State |
|---|---|---|---|---|---|---|---|
| 1 | **`kie.db`** (197 MB) | Raw OCR substrate + legacy derivations | `kie/store.py`, `phase1_verify.py`, `phase7_questions.py` | `chunks` 57,390 · `document_sections` 62,048 · `source_documents` 1,241 · `concepts` 3,006 · `formulas` 317 · `question_patterns` 4,853 · `question_families` 2,015 · `concept_edges` 1,654 | PDFs | `gates` (chunk checks), `spine`, `stem_dna` | **LIVE substrate / LEGACY derivations** |
| 2 | **`knowledge_index.db`** | **The certified curriculum spine** | `qie/knowledge/build.py` (engineer→audit→certify) | `ki_concept` 2,836 (**2,009 certified**) · `ki_chapter` 284 · `ki_rejected` 6,234 · `ki_gap` 21 | `kie.db` chunks | **`planner` → all `certgen`** | **LIVE — authoritative** |
| 3 | **`qie.db`** | Derived quality knowledge | `qie/evidence/*`, `qie/mine.py`, `qie/kvs_*` | `governed_fact` 2,438 (**2,041 verified, 1,424 KC-native**) · `governed_relation` 49 (**41 certified**) · `question_dna` 2,996 · `distractor_dna` 1,842 · `item_model` 84 · `kvs_*` 3,934 · `pilot_verified_item` 1,496 | `kie.db`, PYQ | **`certgen` reads `governed_relation` ONLY** | **PARTLY LIVE** |
| 4 | **`pyq_corpus.db`** | 15 years of previous-year questions | `qie/pyq/store.py`, `mining.py`, `dna_v2.py` | `pyq_item` 15,803 · `pyq_item_difficulty` 15,803 · `exam_dna_v2` 15 · `marking_scheme` 4 | `kie.db` chunks | `stem_dna` (offline miner only) | **DISCONNECTED from generation** |
| 5 | **`graph_edges.db`** | Prerequisite / namespace graph | `qie/graph/prereq_edges.py`, `namespace.py`, `evidence_clean.py` | **`prereq_edge` 1,805 (1,183 KC-resolved)** · `concept_namespace` 3,021 · `cleaned_evidence` 2,034 | `knowledge_index.db` | **nothing outside `qie/graph/` + tests** | **DISCONNECTED — KC-native** |
| 6 | **`unified_inventory.db`** | Cross-store asset registry | `qie/inventory/store.py`, `manifest.py`, `promote.py` | `unified_inventory` 8,450 (**41 promotable**) · `crosswalk` 2,186 | `qie.db`, `qpl`, `factory_corpus` | `qp_bridge`, `scope_audit` | **LIVE but not in the generator path** |
| 7 | **`figure_catalog.db`** (191 MB) | Figure captions + assets | `qie/diagrams/catalog.py` | `figure` 113 · `figure_asset` 87 · **`figure_element` 0** · **`figure_link` 0** | PDFs, `kie.db` | nothing | **DISCONNECTED — skeleton only** |
| 8 | **`factory_corpus.db`** | Dormant AI-factory trial | `qie/factory/corpus.py` | `candidate` 1,000 · `gate_result` 7,649 · `judge_verdict` 91 | blueprints | `factory` lane (dormant) | **DORMANT ($0 policy)** |
| 9 | **`examdna.db`** | Exam weighting | `qie/pyq/dna_v2.py`, `taxonomy.py` | `exam_weight` 236 · `exam_distribution` 70 | PYQ | nothing in generation | **DISCONNECTED** |
| 10 | **`qdi.db`** | Question-difficulty intelligence | `qie/knowledge/run_qdi.py` | `qdi_pattern` 12 · `qdi_source` 6 | — | nothing | **DISCONNECTED — near-empty** |
| 11 | **`qpl_question_bank.db`** | Superseded QPL trial | `qie/knowledge/blueprint_store.py` | `candidate` 24 | — | nothing | **SUPERSEDED** |
| 12 | **`ocr_recovery.db`** | OCR re-processing manifest | `qie/ocr_recovery/store.py` | `recovery_result` 10 | `kie.db` | recovery lane | **LIVE, narrow scope** |

**Total identified knowledge rows: ~180,000. Rows the generator can address: ~2,050** (2,009 certified
concepts + 41 certified relations).

---

# PART 3 — DISCONNECTED PIPELINES AND THEIR DISPOSITION

| Component | Rows | Why it disconnected | Disposition |
|---|---|---|---|
| **Prerequisite graph** (`prereq_edge`) | 1,805 / 1,183 KC | Built in the R5 wave *after* the planner was written; no one went back to wire it. **KC-native, correct, unused.** | **INTEGRATE** — highest value, lowest risk in the repository |
| **Certified facts** (`governed_fact`) | 2,041 / **1,424 KC-native** | Built for the qualitative lane, which `certify.py` cannot auto-certify; nobody revisited it for the *deterministic* lanes | **INTEGRATE** — as planner signal + distractor source, not as answer keys |
| **Unified inventory** | 8,450 | Built as a promotion registry for a bank the generator never writes to | **INTEGRATE** — becomes the write-back target (Part 7) |
| **PYQ corpus** | 15,803 | Provenance-grade: span pointers, no keys, 0.8% concept linkage | **BRIDGE** — as *frequency/structure signal only*; never as content |
| **`exam_dna_v2` / `examdna.db`** | 321 | `insufficient_evidence` on every behavioural dimension | **BRIDGE** — use the `published` subject weights only; keep the honest-null discipline |
| **DNA layer** (`question_dna`, `distractor_dna`) | 4,838 | **Triple namespace fork**; `solution_dna` + `difficulty_drivers` empty; 77% of distractors `other` | **ARCHIVE** — see rationale below |
| **`item_model`** | 84 | Legacy namespace; superseded by `certgen` bindings | **ARCHIVE** |
| **KVS** (`kvs_*`) | 3,934 | 98% below their own ≥2-source bar; content is TOC headings | **ARCHIVE** (retain the 77 that pass) |
| **`kie.db formulas`** | 317 | Extractor captured law *names*, never expressions | **MIGRATE** — re-extract expressions from `chunks`; the names are a useful worklist |
| **`question_patterns`** | 4,853 | `stem_skeleton` is a tag string, not a template | **ARCHIVE** — retain as PYQ frequency evidence only |
| **`question_families`** | 2,015 | All `draft`, boilerplate descriptions | **DELETE** (after snapshot) — carries no information |
| **`kie.db concepts`** | 3,006 | Superseded by the certified index; planner forbidden to read it | **ARCHIVE — never integrate.** It contains the defects the certified index was built to remove |
| **`concept_edges`** | 1,654 | Legacy namespace + heading artefacts (`PHY_SNAPSHOTS → PHY_KEEP_THE_CURIOSITY_ALIVE`) | **DELETE** (superseded by `prereq_edge`) |
| **Figures** | 113 / 87 | `figure_element` + `figure_link` declared "FUTURE", never filled | **ISOLATE** — needs a vision-authorized programme; not an integration task |
| **`qdi.db`** | 18 | Never populated; `misconception_pressure` hardcoded 0 | **ISOLATE** — revisit when there is response data |
| **`qpl_question_bank.db`** | 24 | Superseded trial | **DELETE** (after snapshot) |
| **`factory_corpus.db`** | 8,700 | Owner $0 policy | **ISOLATE — preserve.** Policy decision, not an architecture defect |
| **Generated questions** | 0 persisted | No write-back path exists | **BUILD** (Part 7) |

### Why ARCHIVE rather than migrate the DNA layer

Migrating `question_dna` would require inventing a `Subject:keyword → KC_*` mapping for 93 codes that are
not concepts at all (`Biology:enzyme`). The 94 legacy-resolvable codes point into `kie.db concepts`, whose
rejected half is exactly the junk the certified index excluded. The payload is thin regardless:
`solution_dna` empty, `difficulty_drivers` empty, 77% of distractors `other`.

**Cost of migration is high, payload is near-zero, and the risk is re-importing rejected concepts into a
certified pipeline.** Archive it, keep it queryable for forensics, and do not spend on it.

---

# PART 4 — INTEGRATION ARCHITECTURE

## Principle: bridges, not merges

**No database is merged. No store is rewritten. No frozen store is touched.**

Every integration is a **read-only adapter** that resolves foreign knowledge into the KC namespace, in
memory, at read time — exactly the pattern `certgen` already uses for `governed_relation` (loaded via
`ctx`, never written into a store).

```
        ┌──────────────── KC NAMESPACE (authoritative) ────────────────┐
        │   knowledge_index.db : ki_concept 2,009 certified            │
        └──────────────────────────┬───────────────────────────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              │                    │                    │
     ┌────────▼───────┐  ┌─────────▼────────┐  ┌────────▼─────────┐
     │ NATIVE bridges │  │ CROSSWALK bridges│  │  SIGNAL bridges  │
     │ (already KC)   │  │ (need mapping)   │  │ (aggregate only) │
     ├────────────────┤  ├──────────────────┤  ├──────────────────┤
     │ prereq_edge    │  │ pyq_item         │  │ exam_dna_v2      │
     │   1,183 KC     │  │   via stem_dna   │  │   subject weights│
     │ governed_fact  │  │   concept links  │  │ pyq frequency    │
     │   1,424 KC     │  │ formulas         │  │ difficulty proxy │
     │ governed_relat.│  │   (re-extract)   │  │                  │
     │   41 certified │  │                  │  │                  │
     └────────────────┘  └──────────────────┘  └──────────────────┘
```

**Three bridge classes, three risk profiles:**

| Class | Mechanism | Risk | Members |
|---|---|---|---|
| **Native** | Direct `KC_` join. No mapping. | **Near zero** | `prereq_edge` (1,183), `governed_fact` (1,424), `governed_relation` (41) |
| **Crosswalk** | Requires a mapping table with explicit confidence + honest-null | Medium | PYQ concept links, re-extracted formulas |
| **Signal** | Aggregate statistics only; never per-item content | Low | exam weights, PYQ frequency, difficulty proxy |

## The three mandatory properties

| Property | How it is guaranteed |
|---|---|
| **Deterministic** | Bridges are pure functions of frozen inputs. No model calls. Same stores in → same resolution out. Enforced by test, as `certgen` already is. |
| **Traceable** | Every bridged value carries `{source_store, source_table, source_id, bridge_method, confidence}` into item provenance. A generated question can name where every input came from. |
| **Reversible** | Bridges are read-time adapters. Deleting the adapter module restores exact prior behaviour. **No store is mutated, so there is nothing to roll back.** |

## Challenge to an assumption

**`unified_inventory` should NOT become the integration hub.** It was built as a *promotion* registry over
three question stores, it resolves concepts at 14.1%, and 3,682 of its rows are `held_low_quality`.
Repurposing it as the general knowledge bus would inherit that debt. It should remain what it is — the
**write-back target** (Part 7) — and the read-side bridges should address the source stores directly.

---

# PART 5 — LEGACY NAMESPACE STRATEGY

**Design only. No migration is proposed, and I recommend none be performed.**

## 5.1 The honest finding first

| Legacy population | Codes | Recommendation |
|---|---|---|
| `SUBJ_NAME` resolving to `kie.db concepts` | 94 | Bridge **only if** a consumer needs it — currently none does |
| `Subject:keyword` pseudo-codes | 93 | **Not concepts.** No bridge is meaningful |
| `kie.db concepts` (registry) | 3,006 (1,283 rejected) | **Never bridge into a certified path** |

**The bridge should be built as infrastructure and left mostly unused.** Its value is future
compatibility and forensics, not unlocking content — because the content behind the legacy namespace is
thin and partly rejected. Building it to "unlock the DNA layer" would be building it on a false premise.

## 5.2 Layer design

```
  ┌─────────────────────────────────────────────────────────────┐
  │ L1  MAPPING LAYER   concept_bridge (new store, additive)     │
  │     legacy_code · legacy_store · kc_id · method · confidence │
  │     · evidence · status · created_at · superseded_by         │
  │     method ∈ {exact_name, alias, canonical_norm, curated,    │
  │               unresolved, ambiguous, refused}                │
  └─────────────────────────┬───────────────────────────────────┘
                            │
  ┌─────────────────────────▼───────────────────────────────────┐
  │ L2  TRANSLATION LAYER   pure functions, no I/O               │
  │     to_kc(legacy) -> KC | None      (honest-null, never guess)│
  │     to_legacy(kc) -> [legacy...]    (one-to-many is legal)   │
  └─────────────────────────┬───────────────────────────────────┘
                            │
  ┌─────────────────────────▼───────────────────────────────────┐
  │ L3  VALIDATION LAYER                                         │
  │     · every kc_id must exist AND be status='certified'       │
  │     · class/discipline of the mapping must agree             │
  │     · a mapping to a REJECTED legacy concept is refused      │
  │     · round-trip: to_legacy(to_kc(x)) must contain x         │
  └─────────────────────────┬───────────────────────────────────┘
                            │
  ┌─────────────────────────▼───────────────────────────────────┐
  │ L4  CONFLICT / UNKNOWN HANDLING                              │
  │     0 candidates  -> unresolved  (honest-null, NOT an error) │
  │     1 candidate   -> resolved                                │
  │     >1 candidates -> ambiguous — REFUSED, never auto-picked  │
  │     rejected src  -> refused, with reason recorded           │
  └──────────────────────────────────────────────────────────────┘
```

## 5.3 Conflict policy

Modelled on `prereq_edges.py`, which already does this correctly: it records
`resolution_method ∈ {subject_name, cross_subject_unique, ambiguous, unresolved}` with a
`candidate_count`, and **never guesses** — 552 of its 1,805 edges are honestly unresolved and 70 are
honestly ambiguous. That is the pattern to copy, not to improve on.

## 5.4 Future compatibility

The bridge is **append-only and versioned**. A mapping is never edited in place; a correction inserts a
new row and sets `superseded_by` on the old one. This keeps every past generation reproducible.

## 5.5 Rollback

Nothing to roll back — no source store is written. Rollback = stop consulting the bridge. The bridge store
is additive and can be deleted without affecting any existing behaviour.

---

# PART 6 — PLANNER EXPANSION

## 6.1 What the planner reads today

| Input | Source | Used for |
|---|---|---|
| `ki_concept` (certified) + `ki_chapter` (accepted) | `knowledge_index.db` | the entire legal universe |
| `boundary.out_of_scope` | same | the curriculum-boundary gate |
| `taught_at_class`, `academic_discipline` | same | class/discipline binding |

That is all. `check_plan` performs seven deterministic refusals and issues nothing it cannot defend.
**It has no notion of prerequisite order, exam weighting, question frequency, or difficulty evidence.**

## 6.2 Recommended additional inputs, in priority order

| # | Input | Source | Rows | Determinism | Value |
|---|---|---|---|---|---|
| **1** | **Prerequisite depth + ordering** | `prereq_edge` | **1,183 KC** | ✅ frozen table, pure join | **Highest.** Enables genuine multi-concept composition (which concepts legitimately combine), prerequisite-respecting sequencing, and a *principled* difficulty driver |
| **2** | **Certified facts as planner signal** | `governed_fact` | **1,424 KC** | ✅ frozen | Which certified concepts have supporting facts → richer scenario context and distractor grounding. **Never as an answer key** |
| **3** | Certified relations (widen usage) | `governed_relation` | 41 | ✅ already used by gates | Extend from validation-only to *planning* input: which concepts are relation-reachable |
| **4** | Re-extracted formulas | `kie.db formulas` + `chunks` | 317 names | ⚠️ requires extraction | Would materially widen relation coverage (currently 41+86) |
| **5** | PYQ frequency (aggregate) | `pyq_item` via `stem_dna` | 5,786 stems | ✅ deterministic miner | Concept-selection weighting: which concepts real examiners actually choose |
| **6** | Exam subject weights | `exam_dna_v2` `published` rows | 9 | ✅ | Paper blueprint proportions |
| **7** | Question-type mix | `pyq_item.question_type` | 15,803 | ✅ measured | Authentic archetype proportions |

## 6.3 What the planner must NOT consume

| Rejected input | Why |
|---|---|
| `kie.db concepts` | Explicitly forbidden by `spine.py`/`planner.py`; contains rejected junk |
| `question_dna` / `distractor_dna` / `item_model` | Triple namespace fork; empty payload fields |
| `kvs_*` | 98% below their own evidence bar |
| `pyq_item_difficulty` labels | `structural_proxy` (length), never measured — would launder a length heuristic into a difficulty claim |
| `exam_dna_v2` behavioural dimensions | `insufficient_evidence` on every one |

**Determinism is preserved throughout**: every recommended input is a frozen table consumed by pure join
or aggregation. No input introduces a model, a heuristic score, or an unbounded value.

---

# PART 7 — WRITE-BACK ARCHITECTURE

**Confirmed absent:** `grep -rn "INSERT|UPDATE|commit()" certgen/` returns nothing. Generated items live
only in memory. Consequences today: no cross-session dedup, no reuse, no accumulation, no audit trail of
what was ever produced, and `duplicate_exact` can only see items from the current run.

## 7.1 Proposed lifecycle

```
   GENERATED QUESTION  (certgen, in memory)
            │
            ▼
   ┌─────────────────┐  22 gates + lane FATAL proofs        [EXISTS]
   │   VALIDATION    │  fail -> quarantine row, never dropped silently
   └────────┬────────┘
            ▼
   ┌─────────────────┐  item_hash (exact) + stem_norm_hash (numeral-masked)
   │  DEDUPLICATION  │  scoped by (class, discipline); cross-RUN and cross-SESSION
   └────────┬────────┘  reuses factory/corpus.py hashing — do not reinvent
            ▼
   ┌─────────────────┐  content-addressed; binding + engine + index fingerprint
   │   VERSIONING    │  a re-run with an unchanged pipeline is a NO-OP
   └────────┬────────┘  a changed binding supersedes, never overwrites
            ▼
   ┌─────────────────┐  NEW STORE: certgen_bank.db  (append-only)
   │  QUESTION BANK  │  item · gate_result · provenance · solution · lineage
   └────────┬────────┘
            ▼
   ┌─────────────────┐  one row per banked item, asset_class='question_item'
   │ UNIFIED INVENTRY│  evidence_class='deterministic_computed', is_deterministic=1
   └────────┬────────┘  concept_kc populated (Lane C is KC-native — 100% resolution)
            ▼
   ┌─────────────────┐  dedup corpus for future runs · paper assembly ·
   │  FUTURE REUSE   │  coverage reporting · regression corpus
   └─────────────────┘
```

## 7.2 Design decisions

| Decision | Rationale |
|---|---|
| **New store `certgen_bank.db`**, not a table in `qie.db` | `qie.db` is a derived-knowledge store with its own lifecycle. A separate bank keeps rollback trivial (delete the file) and avoids touching a store other lanes read. |
| **Append-only** | Matches `gate_result` and `governed_fact` conventions. Never overwrite a certified row. |
| **Content-addressed ids** | `sha256(binding_id ∥ concept_id ∥ params ∥ stem)` — a re-run is a no-op, so the bank is idempotent. |
| **Pipeline fingerprint on every row** | `{engine_version, binding_version, index_fingerprint}`. When the certified index re-versions, every affected item is identifiable for re-validation. |
| **Quarantine is persisted, not discarded** | The 6 currency-dimensional failures were only visible because I was watching. Persisted quarantine turns gate failures into a queryable defect log. |
| **`unified_inventory` is the index, `certgen_bank` is the content** | Preserves the inventory's existing role instead of overloading it. |

**Lane C is KC-native**, so every banked item resolves to a certified concept at 100% — against the
inventory's current 14.1%. The bank would immediately be the best-resolved asset class in the repository.

---

# PART 8 — REPOSITORY HEALTH SCORECARD

Scored 1–5. **Engineering** = schema/code quality · **Content** = usefulness of what is stored ·
**Certification** = evidentiary strength · **Integration** = wired into the engine · **Production** =
usable in a production generator today.

| Store | Eng | Content | Cert | Integ | Prod | Notes |
|---|---|---|---|---|---|---|
| `knowledge_index.db` | **5** | **5** | **5** | **5** | **5** | The crown jewel. Audited, class-bound, boundary-carrying, honest-null throughout |
| `graph_edges.db` | **5** | **4** | **4** | **1** | **1** | Excellent engineering, KC-native, records ambiguity honestly — **and nobody reads it** |
| `qie.db governed_fact` | 4 | **4** | 4 | **1** | 2 | 1,424 KC-native facts, unused by the generator |
| `qie.db governed_relation` | 4 | 3 | **5** | **4** | 4 | Only 41 certified — correct but far too few |
| `unified_inventory.db` | 4 | 2 | 3 | 2 | 2 | Good design; 14.1% resolution, 41 promotable of 8,450 |
| `pyq_corpus.db` | 4 | 3 | 2 | 1 | 1 | Provenance-grade only: no keys, 0.8% concept linkage, proxy difficulty |
| `kie.db` (substrate) | 4 | **5** | 3 | 3 | 3 | 57,390 chunks — the raw asset everything derives from |
| `kie.db` (derivations) | 2 | **1** | 1 | 1 | 1 | Formulas without expressions, patterns without templates, draft families |
| `qie.db question_dna` | 3 | **1** | 2 | **1** | 1 | Triple namespace; empty solution/difficulty payload |
| `qie.db kvs_*` | 3 | **1** | **1** | **1** | 1 | 77 of 3,759 meet their own bar; TOC fragments |
| `qie.db item_model` | 3 | 2 | 2 | **1** | 1 | Superseded by `certgen` bindings |
| `figure_catalog.db` | 4 | **1** | 2 | **1** | **1** | 191 MB for 113 captions; element/link tables empty |
| `factory_corpus.db` | **5** | 3 | 4 | **1** | **1** | Well built, dormant by owner policy |
| `examdna.db` | 3 | 2 | 2 | **1** | 1 | `insufficient_evidence` on every behavioural dimension |
| `qdi.db` | 3 | **1** | 1 | **1** | 1 | Effectively empty |
| `qpl_question_bank.db` | 3 | **1** | 2 | **1** | **1** | Superseded |
| **`certgen` (code)** | **5** | 3 | **5** | **5** | 3 | Best-engineered component; content-starved and cannot persist |

**Pattern: engineering quality is consistently high; integration is consistently 1.** This is not a
codebase with a quality problem. It is a codebase with a **wiring** problem.

---

# PART 9 — IMPLEMENTATION ROADMAP

## P0 — mandatory

| # | Item | Effort | Risk | Value |
|---|---|---|---|---|
| **P0-1** | **Wire `prereq_edge` into the planner** — prerequisite depth, legal concept-combination sets, ordering | **S** (2–3 d) | **Very low** — frozen table, KC-native, pure join | **Highest in the plan.** Unlocks principled composition and a real difficulty driver |
| **P0-2** | **Write-back: `certgen_bank.db` + unified-inventory rows** | **M** (1–2 w) | Low — new additive store | Ends the "generate and forget" cycle; enables cross-session dedup |
| **P0-3** | **Wire `governed_fact` (1,424 KC) as planner + distractor signal** | **M** (1 w) | Low — read-only bridge | Activates the largest certified asset in the repository |
| **P0-4** | **Provenance threading** — every bridged input recorded on the item | **S** (2–3 d) | Very low | Precondition for trusting P0-1/3 |
| **P0-5** | **Archive/delete decisions executed** (snapshot then mark) | **S** (2 d) | Low | Stops future audits re-discovering dead stores |

**P0 total ≈ 3–4 weeks.** No migrations. No frozen store touched.

## P1 — high value

| # | Item | Effort | Risk |
|---|---|---|---|
| P1-1 | **Formula re-extraction** — 317 names → expressions mined from `chunks` | **L** (3–4 w) | **Medium** — extraction accuracy; must be gate-verified before entering the relation registry |
| P1-2 | Legacy↔KC bridge store (built, mostly unused; forensics + future compatibility) | M (1 w) | Low |
| P1-3 | PYQ frequency as planner weighting (aggregate signal only) | M (1 w) | Low |
| P1-4 | Exam blueprint from `published` subject weights + measured type mix | M (1 w) | Low |
| P1-5 | Persisted quarantine + defect log | S (3 d) | Very low |

## P2 — future

| # | Item | Effort | Risk |
|---|---|---|---|
| P2-1 | Figure element/link population (vision-authorized) | **XL** | High — needs an authorized pipeline |
| P2-2 | `qdi.db` misconception pressure from real response data | L | Blocked on data that does not exist |
| P2-3 | Factory-lane reactivation | M | **Owner policy decision, not engineering** |
| P2-4 | Cross-store referential integrity checks in CI | M | Low |

## Quick wins (≤ 3 days each, do first)

1. **`prereq_edge` → planner** (P0-1). One frozen table, one join, immediate composition capability.
2. **Provenance threading** (P0-4). Small, and everything downstream depends on it.
3. **Archive marking** (P0-5). Costs nothing, prevents repeated re-litigation of dead stores.
4. **Relation-registry correction** — the count is 41, not 49; fix the reporting.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| **Re-importing rejected legacy concepts into a certified path** | **High** | Bridge validation refuses any mapping to a non-certified target; `kie.db concepts` never consulted by the planner |
| **Formula re-extraction produces wrong expressions** | **High** | Every extracted relation must pass `gates.independent_solve` + dimensional check before registry entry; refuse rather than admit |
| Bank accumulating stale items after an index re-version | Medium | Pipeline fingerprint on every row enables targeted re-validation |
| Bridges silently degrading determinism | Medium | Bridges are pure functions; add determinism tests mirroring existing `certgen` tests |
| **Integration mistaken for capability** | **High** | Wiring everything in P0 still leaves 36 bindings. **Integration does not generate questions — it makes authoring worth more.** Report the two separately |

---

# PART 10 — BRUTALLY HONEST ASSESSMENT

**The premise of this phase is correct.** The problem is integration, not missing knowledge — but that
statement needs one important qualification.

**What integration will genuinely unlock:**
* 1,183 prerequisite edges → real composition logic and a principled difficulty driver
* 1,424 KC-native certified facts → scenario and distractor grounding
* a persistent bank → cumulative value instead of per-run output

**What integration will NOT unlock, and I want to be plain about it:**
* `question_dna`, `item_model`, `kvs_*`, `question_patterns`, `question_families`, `concept_edges` —
  **roughly 17,000 rows that inspection shows carry no generative payload.** Connecting them would import
  metadata, headings and empty fields. The inventory's own verdict is 41 promotable of 8,450.
* `formulas` — 317 rows that must be **re-derived**, not connected. That is extraction work, not wiring.
* PYQ — no answer keys, and per the standing owner decision, none will be recovered.

**The uncomfortable conclusion.** The audit reframed the problem as integration, and that reframing is
right — but the repository does not contain a large reserve of *usable* knowledge waiting behind a wiring
defect. It contains **one excellent certified spine (2,009 concepts), one excellent unused graph (1,183
edges), 1,424 usable facts, 41 certified relations — and a long tail of derived artefacts that did not
survive their own certification bar.**

Integration is the right next phase because it is cheap, low-risk and compounding. **It will not by itself
move JEE or NEET capability much**, because after every bridge is built the engine will still have 36
bindings over 2,009 concepts. Integration makes each future binding worth more; it does not substitute for
authoring them.

**Recommended sequence:** execute P0 (3–4 weeks, no migrations, nothing frozen touched), then resume
authoring with a planner that finally knows prerequisite structure and a bank that keeps what it makes.
