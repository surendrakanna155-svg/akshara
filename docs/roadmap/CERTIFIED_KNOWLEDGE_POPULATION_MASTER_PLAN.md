# CERTIFIED KNOWLEDGE POPULATION — Master Plan
## How Akshara builds and continuously expands a production-grade Certified Knowledge Bank

**Status:** 📐 **Engineering + operational planning — documentation only.** No code, schema change,
migration, or live API call is produced by this plan. · **Scope:** Classes 1–12 (all boards, NCERT-anchored),
JEE Main, JEE Advanced, NEET. · **Predecessors:** Program D (bank-consumer pipeline, engineering-complete on
fixtures), the QIE certification factory, the frozen KIE index, Program B (PYQ), the ERP Education Suite.

> **Prime directive.** The bank is the product. Every question a student ever sees must be **certified** —
> earned through an evidence chain, not asserted by a model. AI is an **offline factory worker**, never a
> runtime oracle. This plan describes the factory that fills the bank, and the loops that keep it growing and
> improving — **without weakening a single certification gate.**

---

## 0. Executive summary

**The situation.** Program D proved the *consumption* path end-to-end on fixtures: `Certified Bank → Retrieval
→ Deterministic Assembly → Student`. It is dark, waiting on one input — **certified content**. The certified
product bank (`qpl_question_bank.db`) holds **0 product-visible certified questions**. Engineering is no longer
the blocker; **populating the bank is.**

**The one hardest truth, stated up front.** The QIE certification architecture certifies a question by
**independently re-deriving its answer** (a computer-algebra system reproduces the key) and then requiring an
**independent cross-family judge** to accept it. This works for **STRUCTURED_NUMERIC** items (physics,
chemistry, quantitative math). It **cannot**, by construction, certify **QUALITATIVE** items —
"which hormone regulates blood sugar", "why is the reaction endothermic", a definition, a reasoning MCQ —
because there is no sympy re-derivation of a fact, and a language-model judge is "a language model of the same
kind" (`certify.py:14-16`), so it yields no *independent* truth. **This is the load-bearing constraint of the
entire program:** a large fraction of school and NEET content (especially Biology, and conceptual items in
every subject) has **no autonomous certification path today.** The plan therefore runs **two lanes** with
different economics and different human-intervention profiles — and is honest that the qualitative lane
**requires either a proven primary source or a human expert**, forever.

**The strategy.**
1. **Anchor on truth we already have.** The frozen KIE index carries ~2009 certified *concepts* (NCERT 6–12);
   Program B carries **15,803 provenance-linked past-exam items (PYQ)**. PYQ are **exam-authentic** — the
   single richest, cheapest, highest-trust seed. Certifying PYQ (whose answers are known/officially keyed) is
   the fastest path to a non-empty, high-value bank.
2. **Run the autonomous quantitative factory at scale.** For STRUCTURED_NUMERIC, the sympy-re-derivation +
   cross-family-judge factory is genuinely autonomous. Drive it hard, budget-governed, per concept × difficulty.
3. **Run a source-proven / human-in-the-loop qualitative lane.** For qualitative content, certification means
   `evidence_class='source_proven'` (answer traceable to a certified primary source) or a **maker–checker human
   expert review** — never a model's say-so. This lane is slower and costs expert time; plan for it explicitly.
4. **Certify FAMILIES, not just instances** (Amendment A2 / I9). A certified *item model* + verified solver +
   distractor library instantiates thousands of runtime variants deterministically — the true path to
   "millions" without generating and judging each one live.
5. **Close the loops.** Pilot response data calibrates *measured* difficulty, flags weak items, and feeds
   weakness intelligence — so the bank gets **better**, not just bigger.

**GO/NO-GO (detail §9): GO** to build the population program in waves, **starting with PYQ certification**
(highest value, lowest cost, unblocks Program D acceptance). **HOLD** any live generation spend until a wave's
budget + acceptance gate is owner-approved. **NO-GO** on shipping any question that did not earn certification,
and on relaxing the sympy/independence gates to raise qualitative yield.

---

## 1. Current reality — the honest baseline (what already exists)

This plan **wires and drives existing machinery**; it invents little. The assets:

### 1.1 The QIE certification factory (`curriculum/scripts/intelligence/kie/qie/factory/`)
The append-only, fail-closed certification engine. A candidate becomes `certified` **only** when (`certify.py
certify_run`): (a) a re-derived **gate battery** passes with no FATAL and no QUARANTINE; (b) an **independent
sympy re-derivation** reproduces the answer (`gates.independent_solve`, `answers_agree` rel_tol 0.02); (c) a
passing **`solution_verified`** gate (every step checks); (d) a passing **`distractor_verified`** gate (every
wrong option proven wrong); (e) a **cross-family judge** accepts it (`independent=1` AND `judge_family ≠
generator_family`); (f) mandatory **provenance + telemetry** (RI-8: model+version+prompt_sha256+actor for
generation AND judge). Stamped `evidence_class='sympy_rederived'`, earned depth, computed archetype. Governance
invariants: **RI-6** one product-visible bank (role-stamped), **RI-8** real provenance, **RI-9** bank-level
dedup (no two certified rows share content). Evidence classes: `sympy_rederived` (quantitative),
`model_agreed_on_owned_evidence`, `source_proven` (the qualitative/knowledge lanes).

### 1.2 The frozen Knowledge Index (KIE, `knowledge_index.db` 7.9M)
`ki_concept` (KC_<sha14> permanent concept ids; ~2009 **certified** concepts, NCERT 6–12), `ki_source`,
`ki_chapter`. The concept spine. **Frozen** (v1.4/v1.5) — the substrate every generation plan anchors to.
Coverage is strong for **NCERT 6–12**; **thin for Classes 1–5 and for JEE/NEET-specific depth**.

### 1.3 The concept graph + governed facts (`graph_edges.db` 5.0M, `qie.db` 2.9M)
`concept_namespace` (1108 rows, KC_↔legacy crosswalk), `concept_prerequisites` (prereq/parent-child/related/
confused-with edges), `governed_fact` (verified facts). This is the **hierarchy + prerequisite DAG** that makes
planning, sequencing, and weakness intelligence possible.

### 1.4 Program B — the PYQ corpus (`pyq_corpus.db` 9.5M)
**15,803 provenance-linked past-exam items.** Exam-authentic questions with known official answers. Exam DNA v2
is honestly `insufficient_evidence` for every exam (needs ≥30 sittings/exam; has ~10–14) — but the *items
themselves* are real and keyed. **The single best seed corpus.**

### 1.5 Program D — the consumption pipeline (engineering-complete on fixtures)
Offline exporter → `edu_platform_question_bank` importer (idempotent, recall=tombstone) → `edu_bank_items_union`
→ the **unchanged** deterministic solver → near-dup filter + prefer-unseen + explainable ranking → student.
Plus `edu_concept_vocabulary` (KC↔UUID), calibration (predicted vs measured), Bloom/marks, per-tenant flags.
**Dark until the bank is non-empty + owner cut-over.** This plan's output flows *into* this pipeline.

### 1.6 The ERP Education Suite + dormant CI schema
Live: `education_blueprint_solver.ts` (deterministic, golden-tested), `edu_question_bank_items` (school bank).
Dormant/seam: `edu_student_item_responses` (response/marks spine + `trust_status`), `edu_item_exposures`,
`edu_item_rotation_policies`, `canonical_concepts` (graph + Bloom + misconceptions), `edu_question_templates/
families/distractors` (the family/item-model home for A2), `edu_blueprint_templates`, `edu_exam_profiles`.

### 1.7 The database inventory (all under `KIE_HOME`, gitignored, LOCAL-ONLY derived knowledge)
`kie.db` 197M (knowledge base) · `knowledge_index.db` 7.9M (frozen concept index) · `pyq_corpus.db` 9.5M (PYQ) ·
`graph_edges.db` 5.0M (graph) · `factory_corpus.db` 7.4M (trial — **discredited**) · `qie.db` 2.9M (governed
facts) · `unified_inventory.db` 2.6M · **`qpl_question_bank.db` 324K — THE production bank, 0 certified** ·
`qdi.db`, `examdna.db`, `ocr_recovery.db`. Storage law: raw PDFs local+gitignored; **derived knowledge LOCAL
ONLY**; Git = schemas/engine/tests; VPS = app-server only; **no prod promotion of knowledge without owner OK.**

### 1.8 The honest gaps (what the population program must produce)
- **0 certified product questions** (the blocker).
- **No autonomous qualitative certification** (biology, definitions, reasoning) — needs source-proven or human.
- **Thin coverage** for Classes 1–5 and JEE/NEET-specific depth in the concept index.
- **No measured difficulty** (needs pilot response signal).
- **No human review workflow** wired (maker–checker exists as a *pattern* in the ERP, not for content cert).
- **PYQ not yet certified** into the product bank (the fastest available win).

---

## 2. The population model — the end-to-end factory

```
 [OFFLINE · AI-allowed · budget-governed]                          [ONLINE · deterministic · AI-free]
 ┌───────────────────────────────────────────────────────────┐
 │ ACQUIRE ─► MAP ─► PLAN ─► GENERATE ─► CERTIFY ─► (HUMAN?) ─┼─► PROMOTE ─► SERVE ─► LEARN ─┐
 │  sources    KC     specs   AI draft   evidence   review    │  (Program D)  (solver)  (spine)│
 │  (PYQ,      curric  per     (offline)  chain +    exceptions│                                │
 │   NCERT,    map     concept            judge      only)     │                                │
 │   experts)                                                  │                                │
 └───────────────────────────────────────────────────────────┘                                │
        ▲                                                                                        │
        └──────────────────── EXPAND (weakness gaps, coverage gaps, new sittings) ◄─────────────┘
                                        continuous quality improvement loop
```

**Two certifiability lanes (the central fork).**

| | **Lane Q — Quantitative (STRUCTURED_NUMERIC)** | **Lane K — Qualitative / Knowledge** |
|---|---|---|
| Subjects | Physics, Chemistry (numeric), Math | Biology, conceptual items in all subjects, definitions, reasoning |
| Certification | **Autonomous**: sympy re-derivation + cross-family judge | **Source-proven** (`source_proven`) OR **human maker–checker** |
| Evidence class | `sympy_rederived` | `source_proven` / `model_agreed_on_owned_evidence` |
| Economics | AI generation cost only (offline, budgeted) | AI *draft* + expert *time* (the real cost) |
| Human in loop | Exceptions only (quarantine review) | **Required** for anything not source-traceable |
| Scale path | Certify **families** → instantiate millions deterministically | Certify curated items + families; slower |

**PYQ is a third, privileged inflow**: exam-authentic items with **official answer keys**. For Lane-Q PYQ,
sympy re-derivation certifies them cheaply; for Lane-K PYQ, the **official key is the primary source**
(`source_proven`) — the fastest qualitative certification available.

The remaining sections detail every stage with its Architecture, Data flow, Required services, Required
databases, Quality gates, Human-intervention points, Automation opportunities, Risks, and Acceptance criteria.

---

## 3. The 20 stages (each with the 9 required facets)

Organised in six clusters: **A** Foundation & Acquisition · **B** Production & Certification · **C** Metadata
& Lifecycle · **D** Product Consumption · **E** Intelligence Loops · **F** Measurement & Scale.

### CLUSTER A — Foundation & Acquisition

#### Area 1 — Knowledge acquisition pipeline
- **Architecture.** Deterministic universe **Board → Class → Subject → DocType** (`run_acquisition.py`,
  configs `boards.json`/`classes.json`). Sources: (a) **PYQ** (`pyq_corpus.db`, 15,803 — the priority inflow);
  (b) **NCERT/board textbooks + official syllabi** (already mined into KIE 6–12); (c) **official exam keys**
  (JEE/NEET answer keys — primary-source truth); (d) later, licensed publisher content. Raw PDFs land
  local+gitignored; OCR/extraction feeds the knowledge base (`kie.db`) and the frozen index build.
- **Data flow.** source PDF → OCR/extract (`ocr_recovery`) → governed facts (`qie.db`) + concepts
  (`ki_concept`) → generation substrate. PYQ → parsed item + official key → certification queue.
- **Required services.** Acquisition runner; OCR pipeline (`kie/qie/ocr_recovery/`); extraction/normalisation;
  a **coverage ledger** service (what cells are acquired vs pending).
- **Required databases.** `kie.db` (knowledge base), `knowledge_index.db` (concepts), `pyq_corpus.db` (PYQ),
  `qie.db` (governed facts); raw-PDF object store (local/gitignored).
- **Quality gates.** Transparent denominator (the **736 Priority-A cells** discipline — never a hidden
  fraction); provenance on every extracted fact; OCR confidence threshold; official-key parity check.
- **Human intervention.** Curator confirms a source is canonical/current edition; disputes on ambiguous
  syllabus scope; sign-off to add a new board/exam to the universe.
- **Automation.** Crawl/parse/OCR/extract; coverage-gap detection; auto-queue new sittings when they appear.
- **Risks.** Stale/edition-drift sources; OCR errors poisoning facts; scope creep (acquiring beyond syllabus);
  copyright on publisher content. **Mitigation:** edition-stamped provenance, OCR-recovery lane (never
  auto-apply), syllabus-boundary gates, licensed-only ingestion.
- **Acceptance.** Every in-scope cell has a provenance-stamped source or an explicit honest-null; PYQ parsed
  with official keys; coverage denominator published, not fudged.

#### Area 6 — Curriculum mapping
- **Architecture.** The canonical **Board×Class×Subject×Chapter×Topic → KC_** map. Anchored by
  `CANONICAL_CURRICULUM_MATRIX.json` + `ki_chapter`/`ki_source`, bridged to the ERP by Program D's
  `edu_concept_vocabulary` (KC↔UUID) and `canonical_concepts.concept_code`. Every certified item is tagged to
  exactly one KC_ (or explicit honest-null) so retrieval, blueprints, and coverage are curriculum-addressable.
- **Data flow.** syllabus doc → chapter/topic extraction → KC_ assignment (crosswalk `concept_namespace`) →
  vocabulary row (KC↔UUID) → item tag at certification.
- **Required services.** Curriculum-matrix builder; KC-resolver (`crosswalk.py`/`namespace.resolve_to_kc`);
  the Program-D vocabulary seed job.
- **Required databases.** `knowledge_index.db`, `graph_edges.db` (namespace), ERP `edu_concept_vocabulary` +
  `canonical_concepts`, `curriculum/reports/CANONICAL_CURRICULUM_MATRIX.json`.
- **Quality gates.** One KC per topic or honest-null (never a guessed mapping — Program D discipline);
  board-variant mapping (same concept, different chapter numbering) reconciled, not duplicated.
- **Human intervention.** Reconcile board-specific chapter/topic naming; approve a new syllabus mapping;
  resolve `concept_namespace` `ambiguous`/`unresolved` rows (789 currently honest-null).
- **Automation.** Name/alias matching → KC; board-mapping suggestions; drift detection vs frozen index.
- **Risks.** Mis-mapping → wrong retrieval/coverage; board drift; the 789 unresolved crosswalk rows.
  **Mitigation:** honest-null over guessing; freeze-pinned crosswalk; human reconciliation queue.
- **Acceptance.** Every certified item is curriculum-addressable to a KC or explicitly unmapped; coverage can
  be reported per Board×Class×Subject×Chapter.

#### Area 7 — Concept hierarchy
- **Architecture.** The **prerequisite DAG + concept identity** already in `graph_edges.db`
  (`concept_prerequisites`: prerequisite / parent_child / related / confused_with; self-loop-guarded) over
  permanent `KC_<sha14>` ids (`spine.concept_id`). Feeds ERP `canonical_concepts` + `concept_prerequisites`
  (dormant) with Bloom levels + common misconceptions. This DAG powers sequencing, adaptive next-concept,
  weakness propagation, and blueprint constraints.
- **Data flow.** concept extraction → identity (KC_) → prereq edges → graph → (Program D) canonical_concepts
  UUID mint → ERP-consumable hierarchy.
- **Required services.** Graph builder (`qie/graph/`), prereq inference, Bloom/misconception enrichment,
  the concept-graph seed into `canonical_concepts`.
- **Required databases.** `graph_edges.db`, ERP `canonical_concepts` + `concept_prerequisites` (dormant, to be
  seeded — owner-gated migration band ≥ `20260881`).
- **Quality gates.** Acyclic prereqs (no cycles), identity-collision refusal (R3-5: concept_id collision
  logged + refused, never a silent merge/demotion), confused-with pairs curated for distractor generation.
- **Human intervention.** Approve prerequisite edges (pedagogical judgement); resolve identity collisions;
  curate misconceptions (these seed *plausible* distractors).
- **Automation.** Edge inference from co-occurrence + textbook ordering; Bloom tagging; misconception mining
  from PYQ wrong-answer patterns.
- **Risks.** Wrong prereq → bad sequencing/adaptivity; cycles; over-merging distinct concepts.
  **Mitigation:** acyclicity gate, collision-refusal, human edge review.
- **Acceptance.** A queryable, acyclic prereq DAG with Bloom + misconceptions per concept, seeded into the ERP
  and driving sequencing/adaptivity.

### CLUSTER B — Production & Certification

#### Area 2 — Certification pipeline
- **Architecture.** The QIE factory (`certify.py`/`gates.py`/`judge.py`), unchanged and un-weakened. **Lane Q**
  (STRUCTURED_NUMERIC): generate → gate battery (grounding, dedup, dimensional, depth) → **independent sympy
  solve** → solution-verified → distractor-verified → **cross-family judge** → `certify_run` →
  `evidence_class='sympy_rederived'`. **Lane K** (qualitative): generate/curate → form gates → **source-proof
  binding** (answer traceable to a certified primary source / official key → `source_proven`) → optional judge
  → **human maker–checker** for anything not source-bound. **PYQ**: the official key IS the source proof.
- **Data flow.** spec (from plan) → candidate corpus (`factory_corpus`/a fresh production run) → gates +
  evidence rows (append-only, item-hash-bound) → judge verdict → `certify_run` → **the ONE production bank**
  `qpl_question_bank.db` → Program D export.
- **Required services.** Planner (`blueprint.py`); generator (offline model, budget-governed via
  `qie/execution/` provider routing — OpenAI direct, Anthropic via OpenRouter, family derived); gate runner
  (sympy); cross-family judge; `certify_run`; the recert/append-only runner pattern (`recert.py`).
- **Required databases.** `factory_corpus.db` (candidates/evidence), `qpl_question_bank.db` (certified product
  bank, RI-6), `knowledge_index.db` (substrate, read-only), `graph_edges.db` (concepts/boundaries).
- **Quality gates (the battery — never relaxed).** `duplicate_exact` (FATAL), `near_duplicate` (QUARANTINE),
  relation-grounded, dimensional consistency, `independent_solve` + `answers_agree` (rel_tol 0.02),
  `solution_verified`, `distractor_verified`, cross-family `judge accept`, mandatory provenance+telemetry
  (RI-8). Qualitative adds `source_proven` binding.
- **Human intervention.** **Lane K maker–checker** (required); quarantine adjudication (a QUARANTINE is a
  certification *event*, never a silent promote); relation waivers (owner-only, audited).
- **Automation.** Lane Q is **fully autonomous** end-to-end. Lane K automates the *draft* + source-candidate
  retrieval; a human confirms. PYQ certification (Lane Q via sympy, Lane K via official key) is highly
  automatable.
- **Risks.** **Qualitative uncertifiability** (the central risk — no shortcut; do not let a model "certify" a
  fact); low Lane-Q yield (Program C: 0/22 recalled survived — good questions are *hard* to generate);
  generator=judge collapse; replay/self-refuted-metadata bypass. **Mitigation:** two-lane honesty, cross-family
  enforcement, append-only content-bound evidence, budget-gated runs, source-proof for qualitative.
- **Acceptance.** Every promoted row carries a complete, content-bound evidence chain + independent
  disposition; 0 rows promoted without it; Lane split measured and reported (what % is sympy vs source vs
  human).

#### Area 10 — Evidence and provenance tracking
- **Architecture.** Already the QIE factory's spine: **append-only, content-bound** evidence
  (`gate_result`/`independent_answer`/`judge_verdict`, each stamped with the candidate's `item_hash` at check
  time), mandatory model+version+prompt_sha256+actor (RI-8), payload sha256 computed (never caller-supplied),
  `run_telemetry`. Program D carries the provenance object through the export artifact to `edu_platform_
  question_bank.provenance`.
- **Data flow.** every stage appends an evidence row bound to the current item_hash → certification consumes
  ONLY rows matching the current hash → provenance rides the export → ERP stores it → student-visible
  "certified" trust marker.
- **Required services.** The corpus writer (`corpus.py`), telemetry recorder, the export provenance stamper.
- **Required databases.** `factory_corpus.db` (evidence), `qpl_question_bank.db`, ERP
  `edu_platform_question_bank.provenance` (JSONB).
- **Quality gates.** Evidence bound to current content (the replay case can never certify); placeholder/banned
  actor ids refused; telemetry mandatory before certify.
- **Human intervention.** Audit/recall (excise a bad certified row → append tombstone, never delete); waiver
  authorship.
- **Automation.** Fully automatic capture; the RI-8 placeholder scan; recall propagation (Program D
  tombstone).
- **Risks.** Provenance forgery, evidence/content drift, silent overwrite. **Mitigation:** computed hashes,
  append-only, guarded transitions (money-integrity pattern), content-hash binding.
- **Acceptance.** Any certified question can show its full chain: source → generation provenance → gates →
  independent solve → judge → certify event, all content-bound and reproducible.

#### Area 11 — Duplicate detection strategy
- **Architecture.** Three layers. (1) **Exact**: `item_hash` (stem|options|answer) — `duplicate_exact` FATAL +
  RI-9 bank UNIQUE. (2) **Lexical near-dup**: `norm_hash` (numbers→#) + Jaccard ≥ 0.85 ∧ difflib ≥ 0.85 →
  `near_duplicate` QUARANTINE (template-flooding defence). (3) **Semantic near-dup (Program D)**: offline
  `hashvec-128` vectors + request-time cosine ≥ 0.82 — catches paraphrase clones the lexical layer misses, and
  prevents two clones landing in one paper.
- **Data flow.** at certify: exact + lexical vs the whole bank (`prior_certified_dedup`); at export: compute
  the near-dup vector; at request: cosine filter within a paper.
- **Required services.** `gates` dedup, Program-D `embeddings.py` (offline) + `education_near_dup.ts`
  (request-time, deterministic, no model call).
- **Required databases.** `qpl_question_bank.db` (bank dedup), `edu_platform_question_bank.near_dup_embedding`.
- **Quality gates.** No two certified rows share `item_hash` or `stem_norm_hash` (RI-9); paraphrase pairs
  flagged for review; a paper contains no near-dups.
- **Human intervention.** Adjudicate a `near_duplicate` quarantine (genuine variant vs flooding).
- **Automation.** All three layers automatic; semantic clustering to surface families.
- **Risks.** Template-flooding inflating counts; over-aggressive dedup killing legitimate variants; embedding
  drift. **Mitigation:** versioned threshold, family-aware dedup (variants of a certified *family* are expected,
  not dups), reproducibility test.
- **Acceptance.** Measured, low duplicate rate; paraphrase clones caught; certified *families* not mistaken for
  dups; every dedup verdict explainable.

#### Area 3 — Human review workflow (where required)
- **Architecture.** A **maker–checker** review console reusing the ERP two-person pattern (as with fee
  concessions/exam-publish). Scope: (a) **Lane K** items not source-bound (**mandatory** expert accept/reject/
  edit); (b) **quarantine adjudication** for both lanes; (c) **relation waivers** (owner-only). Reviewers are
  subject experts; every decision is provenance-stamped (who/when/why) and append-only.
- **Data flow.** quarantine/pending item → review queue (by subject/board/concept) → expert verdict
  (accept→certify-with-`source_proven`/human-attested / reject / edit→fresh candidate) → audit ledger →
  (accept) promote.
- **Required services.** Review-queue service; a **content-review UI** (new — the one genuinely new product
  surface); reviewer RBAC; audit ledger.
- **Required databases.** A review-queue + verdict store (new, owner-gated migration band ≥ `20260881`);
  reuses `status_audit` pattern.
- **Quality gates.** Two-person (maker≠checker) for human-attested certification; reviewer competence tagging;
  no self-approval; SLA on queue age.
- **Human intervention.** **This stage IS the human intervention** — the qualitative certification authority.
- **Automation.** Draft + source-candidate retrieval + pre-filtering (form gates) reduce reviewer load to a
  yes/no/edit; batch similar items; auto-route by expertise.
- **Risks.** Reviewer bottleneck (the qualitative lane's real constraint), reviewer error, cost of expert time,
  rubber-stamping. **Mitigation:** maker–checker, sampled QA of reviewers, calibration items, throughput SLAs,
  automate everything up to the human judgement.
- **Acceptance.** Every human-certified item has a two-person audited verdict; queue SLA met; reviewer accuracy
  sampled and reported; no unattested qualitative item reaches the bank.

### CLUSTER C — Metadata & Lifecycle

#### Area 9 — Metadata standards
- **Architecture.** A frozen **item metadata contract** (Program D Contract-1 is the seed): identity
  (`content_hash`), curriculum (`kc_id`, `concept_uuid`, subject/chapter), pedagogy (`cognitive_level`/Bloom,
  `difficulty` + **`difficulty_calibration`** predicted|measured, `marks`), type (`question_type` incl.
  `numerical`), provenance, near-dup vector, `frozen_version`, lifecycle (`status`, `certification_class`).
  **Bloom is honest-null unless derivable; predicted difficulty is never sold as measured (R2-5).**
- **Data flow.** derived at certification/export (marks table, depth→Bloom, calibration=predicted) → carried
  through the artifact → stored on `edu_platform_question_bank` → surfaced to product.
- **Required services.** The exporter's metadata mapper (`erp_promote.py`), the calibration column, the Bloom
  derivation.
- **Required databases.** `edu_platform_question_bank` (all metadata columns), `edu_concept_vocabulary`.
- **Quality gates.** Every promoted item carries Bloom+marks+concept-UUID or explicit null; difficulty labelled
  predicted **or** measured, never blended; enum-map fail-closed.
- **Human intervention.** Approve the metadata schema version; adjudicate a mis-tagged item.
- **Automation.** Full derivation at export; schema-version pinning.
- **Risks.** Metadata drift across versions; predicted-as-measured; fabricated Bloom. **Mitigation:** versioned
  contract, honest-null discipline, calibration separation.
- **Acceptance.** 100% of certified items conform to the frozen metadata contract; no blended difficulty; schema
  version pinned per item.

#### Area 8 — Difficulty calibration
- **Architecture.** **Two explicit tiers, never blended.** (1) **Predicted** (`predicted_uncalibrated`) — a
  structural proxy from depth/archetype/step-count at certification (honest: labelled uncalibrated). (2)
  **Measured** (`measured_pilot`) — a **p-value / discrimination index** computed from real
  `edu_student_item_responses` once pilot signal exists (**not backfillable**; honest-null until then). An
  offline item-analysis job recomputes measured difficulty deterministically from responses.
- **Data flow.** cert → predicted label; pilot responses → item-analysis job → measured label + p-value →
  `difficulty_calibration='measured_pilot'` (append, never overwrite predicted).
- **Required services.** Item-analysis job (offline/edge), the response-spine reader.
- **Required databases.** `edu_student_item_responses` (spine), `edu_platform_question_bank.difficulty_
  calibration` + a p-value column (owner-gated additive).
- **Quality gates.** Measured only from ≥N real responses; predicted≠measured never conflated; deterministic
  recompute.
- **Human intervention.** Approve the N threshold; review items whose measured difficulty diverges wildly from
  predicted (possible bad item).
- **Automation.** Fully automatic once responses flow.
- **Risks.** Selling predicted as measured (**forbidden**); thin pilot signal; non-representative cohorts.
  **Mitigation:** honest-null, explicit labels, cohort tagging, minimum-N gate.
- **Acceptance.** Predicted on day one; measured appears only where real responses exist; the two are always
  distinguishable end-to-end.

#### Area 4 — Question lifecycle management
- **Architecture.** Append-only lifecycle: `candidate → {quarantined|rejected|expired_unjudged} → certified`
  (QIE), then in the product bank `active → tombstoned` (recall). No hard delete anywhere. Re-certification is
  a **fresh run** (never a mutation of a certified row). Program D adoption is **by reference**, so recall
  propagates to every school automatically.
- **Data flow.** state transitions are guarded (rowcount==1, expected-state) + audit-logged (`status_audit`);
  recall → tombstone → drops from `edu_bank_items_union`.
- **Required services.** `set_status`/`mark_certified` (guarded), `remediation.excise_run` (recall), Program-D
  importer tombstone.
- **Required databases.** `factory_corpus.db`, `qpl_question_bank.db`, `edu_platform_question_bank.status`.
- **Quality gates.** Guarded transitions (no double-apply — the money-integrity pattern), immutable certified
  content, recall auditable + propagating.
- **Human intervention.** Trigger a recall (item found wrong post-cert); approve re-certification.
- **Automation.** State machine + audit; auto-tombstone on re-export absence.
- **Risks.** Orphaned adoptions, un-propagated recall, silent re-stamp. **Mitigation:** adopt-by-reference,
  guarded writes, append-only audit.
- **Acceptance.** Any item's full lifecycle is queryable + audited; a recall removes it from every student
  surface within one export cycle; no certified content is ever mutated in place.

#### Area 5 — Versioning strategy
- **Architecture.** Version at **four levels**: (a) **concept spine** — frozen index versions (v1.4/v1.5,
  fingerprinted); (b) **item** — `content_hash` identity + `frozen_version` stamp; (c) **export artifact** —
  `artifact_version` + `content_fp`/`substrate_fp` freeze fingerprints; (d) **contracts/schemas** — semantic
  versions (Program-D Contract-1/2, enum-map version). A question is immutable; a "new version" is a **new
  certified item** (new content_hash) that may supersede the old (tombstone the old, adopt the new).
- **Data flow.** frozen-index version → item stamp → export fingerprint → import verify (mismatch refuses).
- **Required services.** Manifest builder, freeze-fingerprint checks, schema-version registry.
- **Required databases.** all stores carry a version/fingerprint; `factory_meta`, manifest.
- **Quality gates.** Freeze-fingerprint pin (export read-only on frozen substrate; byte-identity check); import
  refuses on fingerprint mismatch; no silent substrate drift.
- **Human intervention.** Approve a frozen-index re-freeze (new spine version); approve a contract bump.
- **Automation.** Fingerprinting + verification automatic.
- **Risks.** Substrate drift, version skew between QIE and ERP, un-versioned metadata. **Mitigation:**
  content-derived fingerprints, pinned versions per item, refuse-on-mismatch.
- **Acceptance.** Every item traces to a spine version; every export is fingerprint-verifiable; a superseding
  version cleanly tombstones its predecessor; no unversioned artifact enters the bank.

### CLUSTER D — Product Consumption (all read the certified bank; all deterministic, AI-free at request time)

#### Area 17 — Question paper generation
- **Architecture.** **Already built (Program D).** `education_blueprint_solver.ts` (deterministic, golden) fills
  a blueprint bank-first from the certified/adopted union; near-dup filter + prefer-unseen + explainable
  ranking shape the pool; `ai_candidate` gap-fill trends to ≈0 as coverage grows (owner-flippable to
  `hard_off`). This is the reference consumer — **nothing to rebuild; only feed it certified content.**
- **Data flow.** teacher request → union pool → solver → paper (deterministic, explainable) → exposure logged.
- **Required services.** `generateQuestionPaper` (extended), the union view, the flags.
- **Required databases.** `edu_bank_items_union`, `edu_program_d_settings`, `edu_item_exposures`.
- **Quality gates.** Deterministic (same request→same paper); blueprint honoured; `ai_candidate` rate measured;
  no near-dups; graceful honest shortfall (never a live-AI expansion under `hard_off`).
- **Human intervention.** Teacher edits/approves; manual authoring stays optional.
- **Automation.** Fully automatic generation; coverage-driven cut-over.
- **Risks.** Thin bank → high gap-fill/shortfall. **Mitigation:** the population program (this plan) fills the
  bank; measure `ai_candidate` rate as the coverage signal.
- **Acceptance.** Teacher papers served from certified content with a measured, declining AI rate; solver golden
  tests stay green.

#### Area 15 — Daily Practice generation (DPP)
- **Architecture.** A **deterministic DPP assembler** = a specialised blueprint over the certified bank:
  per class/subject/chapter, a fixed daily quota by difficulty mix + prerequisite readiness, exposure-aware
  (prefer-unseen), near-dup-free. Reuses the Program-D pool builder + solver; adds a **DPP blueprint template**
  (`edu_blueprint_templates`) + a scheduling seam (which concepts are "due" today per the spaced sequence).
- **Data flow.** student/class + date + concept-schedule → DPP blueprint → certified pool → deterministic DPP →
  exposure logged → response captured next day.
- **Required services.** DPP assembler (new, thin wrapper over the solver), a **spaced-schedule** service
  (concept-due model over the prereq DAG).
- **Required databases.** `edu_blueprint_templates`, `edu_bank_items_union`, `edu_item_exposures`,
  `edu_item_rotation_policies` (cooldown so DPPs don't repeat).
- **Quality gates.** Deterministic; no repeats across a class's recent DPPs (rotation cooldown); on-syllabus;
  honest shortfall when the bank is thin for a concept.
- **Human intervention.** Teacher can override the day's set; approve the DPP policy per class.
- **Automation.** Fully automatic daily generation + scheduling.
- **Risks.** Thin bank → repetitive/short DPPs; schedule not pedagogically sound. **Mitigation:** coverage-gap
  reporting drives generation priority; prereq-DAG-based scheduling; rotation policy.
- **Acceptance.** Every class gets a deterministic, non-repeating, on-syllabus DPP daily from certified content,
  with an honest shortfall signal that feeds the expansion queue.

#### Area 16 — Adaptive practice generation
- **Architecture.** Deterministic-first per the **Adaptive-AI design** (5-gate firewall: Domain → RBAC →
  Deterministic → Cache → W1; AI proposes, deterministic certifies). Adaptive = **select certified items** by
  the student's **mastery/weakness** over the concept DAG (next-concept = weakest ready prerequisite), difficulty
  matched to measured p-value, exposure-aware. **No live generation** — adaptivity is *selection/instantiation*
  of certified content, not new content at request time (I9).
- **Data flow.** student mastery vector (from response spine) → weakest ready concept(s) → certified pool for
  those concepts at calibrated difficulty → deterministic adaptive set → response → mastery update.
- **Required services.** A **mastery/weakness model** (Area 14), the adaptive selector (deterministic), the
  concept-DAG traversal.
- **Required databases.** `edu_student_item_responses` (mastery source), `edu_bank_items_union`,
  `canonical_concepts`+`concept_prerequisites` (the DAG), difficulty calibration.
- **Quality gates.** Deterministic given the mastery vector; AI-free at request time; difficulty within the
  student's zone; on-prerequisite.
- **Human intervention.** Teacher visibility/override; approve the adaptivity policy.
- **Automation.** Fully automatic selection; the offline mastery model.
- **Risks.** Bad mastery signal → wrong difficulty; thin certified coverage per concept collapses adaptivity to
  "whatever exists"; over-personalisation. **Mitigation:** honest-null mastery until enough responses,
  coverage-gap-driven generation, deterministic + explainable selection.
- **Acceptance.** A student receives certified items matched to their weakest ready concept at calibrated
  difficulty, deterministically and explainably, with **0 live-AI at request time**.

#### Area 18 — Revision-note generation
- **Architecture.** Revision notes are **derived, certified knowledge artifacts**, not questions: per KC_/
  chapter, a structured note assembled from **governed facts** (`qie.db` verified facts) + concept definition +
  common misconceptions + worked exemplars drawn from certified items. Generated **offline** (AI drafts,
  human/source certifies for the qualitative parts), stored as a **certified note** keyed to the concept.
  Request-time = deterministic fetch (no generation).
- **Data flow.** KC_ → governed facts + misconceptions + certified exemplar items → offline note draft →
  source/human certification → certified-note store → student fetch.
- **Required services.** A note assembler (offline), a certified-note store, request-time fetch.
- **Required databases.** `qie.db` (governed facts), `graph_edges.db` (misconceptions), a **certified-notes**
  table (new, owner-gated), certified items (exemplars).
- **Quality gates.** Every fact in a note is a **governed/certified** fact (no un-sourced claims — same bar as
  questions); notes versioned to the spine; misconceptions accurate.
- **Human intervention.** Expert review of a note (qualitative — required, like Lane K); approve templates.
- **Automation.** Draft assembly automatic; fact-sourcing automatic; the qualitative attestation is human.
- **Risks.** Un-sourced/incorrect facts in notes (a note is as dangerous as a wrong question); staleness.
  **Mitigation:** governed-facts-only, human attestation, spine-versioning, recall path.
- **Acceptance.** Notes contain only certified/governed facts, are concept-keyed + versioned, and are served
  deterministically; a recalled fact updates or tombstones its notes.

### CLUSTER E — Intelligence Loops (the bank gets *better*, not just bigger)

#### Area 13 — Student feedback learning loop
- **Architecture.** The **response spine is the sensor.** Every attempt (`edu_student_item_responses`: correct/
  marks/time/chosen-option, `capture_source` marks-grid-OCR|manual|digital) feeds two offline loops: (a)
  **item-quality** (item-analysis → measured difficulty + discrimination; a certified item with anomalous
  stats — everyone wrong, or a distractor never chosen — is **flagged for re-review**, possibly recalled); (b)
  **explicit feedback** (teacher/student "report this question" → review queue). Feedback **never** silently
  edits a certified item — it triggers a **fresh review/recert or a recall** (append-only discipline).
- **Data flow.** attempt → spine → offline item-analysis + feedback intake → flag/recall/recert queue → human
  or automated disposition → bank update (new version / tombstone).
- **Required services.** Item-analysis job, feedback-intake service, the review queue (Area 3).
- **Required databases.** `edu_student_item_responses`, `edu_item_exposures`, a feedback/flag store (new),
  `edu_platform_question_bank` (trust/recall).
- **Quality gates.** Statistical flags are advisory → human/recert disposes (never auto-edit a certified item);
  `trust_status` transitions guarded + audited; cohort-size minimum before acting.
- **Human intervention.** Disposition of flagged items; triage of explicit reports.
- **Automation.** Anomaly detection, auto-flag, auto-route; the loop that turns responses into difficulty.
- **Risks.** Acting on thin/biased signal; feedback abuse; silently mutating certified content. **Mitigation:**
  minimum-N, guarded transitions, append-only, human disposition.
- **Acceptance.** A demonstrably-bad certified item is flagged from response data and recalled/re-certified via
  an audited path; measured difficulty flows back; no certified item is ever silently edited.

#### Area 14 — Weakness intelligence integration
- **Architecture.** A **per-student (and per-class) mastery model** over the concept DAG: from the response
  spine, estimate mastery per KC_ (correct-rate × recency × difficulty-weighted, propagated along prereq
  edges — a weak prerequisite explains downstream failure). Honest-null until enough evidence. This mastery
  vector drives **adaptive practice (Area 16)**, **DPP prioritisation (Area 15)**, teacher dashboards, and
  **coverage-gap → generation priority** (weak concepts with thin certified coverage jump the expansion queue).
- **Data flow.** responses → per-KC mastery estimate → prereq propagation → weakness vector → {adaptive
  selection, DPP focus, teacher analytics, expansion priority}.
- **Required services.** Mastery estimator (offline/deterministic), prereq-propagation over `graph_edges`,
  weakness API for the ERP.
- **Required databases.** `edu_student_item_responses`, `graph_edges.db`/`concept_prerequisites`,
  `canonical_concepts`, a mastery store (new).
- **Quality gates.** Deterministic + explainable mastery ("weak in X because prerequisite Y failing"); honest-
  null under thin data; no single-attempt over-reaction.
- **Human intervention.** Teacher validates/overrides a weakness call; approve the mastery model.
- **Automation.** Fully automatic estimation + propagation.
- **Risks.** Wrong weakness → wrong practice; sparse data; conflating "not attempted" with "weak". **Mitigation:**
  honest-null, evidence thresholds, prereq-aware attribution, explainability.
- **Acceptance.** For a student with enough responses, an explainable weakness map exists and drives adaptive
  selection + expansion priority; sparse students get honest-null, not a fabricated map.

#### Area 12 — Continuous quality improvement
- **Architecture.** The **meta-loop** that ties the others together: a standing pipeline that (a) measures
  coverage + quality per Board×Class×Subject×Concept×Difficulty; (b) prioritises the **next generation batch**
  by *value* (weakness-weighted coverage gaps, thin certified concepts, exam-blueprint demand); (c) re-reviews
  statistically-flagged items; (d) ingests new PYQ sittings as exams happen; (e) re-freezes the spine when the
  knowledge base grows. Runs **offline, budget-governed, in waves**, each with an owner-approved budget + gate.
- **Data flow.** coverage + weakness + flags + new sources → prioritised generation/review batch → certify →
  promote → measure → repeat.
- **Required services.** The **prioritiser** (value-ranked work queue), the batch runner (certification factory),
  the coverage/quality measurer (Area 19).
- **Required databases.** all of the above + a **work-queue/priority** store.
- **Quality gates.** Every batch is budget-capped + acceptance-gated (yield, cost/certified-item, cert-rate);
  no gate weakened to hit a number; honest yield reporting (Program C's 0/22 is the cautionary baseline).
- **Human intervention.** Approve each wave's budget + scope; review yield; decide qualitative-lane staffing.
- **Automation.** Prioritisation, batch execution, measurement; humans set scope/budget + do Lane-K review.
- **Risks.** Chasing volume over value; budget overrun; yield collapse (hard questions are hard to generate);
  spine drift. **Mitigation:** value-ranked queue, hard budget caps, per-wave gates, honest yield metrics.
- **Acceptance.** The bank grows in the highest-value areas first; cost/certified-item is tracked and trending
  down; quality (flag rate, measured difficulty spread) is measured and improving; every wave is owner-gated.

### CLUSTER F — Measurement & Scale

#### Area 19 — Analytics and coverage measurement
- **Architecture.** A **coverage & quality ledger**: the transparent denominator (curriculum cells:
  Board×Class×Subject×Chapter×Concept×Difficulty×Type) vs the numerator (certified items per cell), plus
  quality metrics (measured-difficulty spread, discrimination, flag rate, duplicate rate, `ai_candidate` rate
  per paper, lane split sympy/source/human). Feeds the prioritiser (Area 12) and owner dashboards. Extends the
  existing `CANONICAL_CURRICULUM_MATRIX` discipline.
- **Data flow.** bank + response spine + factory telemetry → coverage/quality aggregates → dashboard + work-queue.
- **Required services.** Coverage aggregator, quality metrics, a reporting surface (owner + Mission-Control).
- **Required databases.** `qpl_question_bank.db`, `edu_platform_question_bank`, `edu_student_item_responses`,
  `run_telemetry`, `CANONICAL_CURRICULUM_MATRIX.json`.
- **Quality gates.** Transparent denominator (never a hidden fraction — the founding discipline); honest-null
  where uncovered; measured vs predicted clearly split.
- **Human intervention.** Read the dashboard; set coverage targets per exam/class.
- **Automation.** Fully automatic aggregation + gap detection.
- **Risks.** Vanity metrics (counting quarantined/trial rows as product — the audit's original sin); hidden
  denominators. **Mitigation:** RI-6 product-visible-only counting, published denominators, lane split.
- **Acceptance.** At any moment, exact certified coverage per curriculum cell + quality metrics are queryable,
  with an honest denominator; gaps drive the generation queue.

#### Area 20 — Scale strategy to millions of certified questions
- **Architecture.** Four multipliers, in priority order. (1) **PYQ certification** — 15,803 exam-authentic items
  certified cheaply (sympy for Lane-Q, official key for Lane-K) = the immediate base. (2) **Certified FAMILIES
  + runtime instantiation (A2/I9)** — the true "millions" lever: certify an *item model* (template + verified
  solver + distractor library) ONCE, then deterministically instantiate thousands of parameterised variants at
  request time (each variant is verifiable by the same solver; no per-instance generation/judging). (3)
  **Autonomous Lane-Q generation at scale** — budget-governed waves per concept×difficulty, cross-family judged.
  (4) **Human-scaled Lane-K** — expert throughput (the honest ceiling for pure qualitative). Scale of the
  *stores*: SQLite is fine for the offline factory today; at millions, the **product bank moves to Postgres**
  (Program D already targets Postgres `edu_platform_question_bank`) with partitioning by subject/board and the
  near-dup vectors indexed (pgvector-style) — a later, owner-gated infra step.
- **Data flow.** families (few) → instantiation (many) → certified variants served; PYQ (thousands) → certified;
  waves (continuous) → certified; all → Postgres product bank at scale.
- **Required services.** The family-instantiation engine (runtime, deterministic — the A2 build), the batch
  factory, the Postgres migration of the product bank + vector index (future).
- **Required databases.** `edu_question_templates`/`families`/`distractors` (the A2 home, dormant), Postgres
  `edu_platform_question_bank` (Program D), a vector index at scale.
- **Quality gates.** Every instantiated variant is solver-verifiable (family certification transfers only under
  the verified generator); no instance escapes the dedup/near-dup discipline; per-wave cost/yield gates.
- **Human intervention.** Approve family certifications (higher stakes — one family → thousands of items);
  approve the Postgres/vector infra step; staff Lane-K.
- **Automation.** Instantiation is fully automatic + deterministic; batch generation automatic; Lane-K is the
  human-bound tail.
- **Risks.** A wrong certified **family** propagates to thousands of items (blast radius); SQLite → Postgres
  migration risk; near-dup at 10⁶ scale (perf); cost of pure-qualitative volume. **Mitigation:** stricter
  family certification (extra judges, wider parameter sweep verified), staged Postgres cut-over (Program D
  pattern), indexed vectors, families-first economics, honest ceiling on pure-qualitative.
- **Acceptance.** Millions of *served* certified variants from a much smaller set of certified families + items,
  every one solver- or source-verifiable; the product bank scales on Postgres without weakening a gate; cost/
  certified-served-item is order-of-magnitude below per-instance generation.

---

## 4. Dependency map — on the existing ERP, QIE, and Program D

**On QIE (the factory + substrate) — hard dependencies:**
- Certification (Area 2) IS the QIE factory (`certify.py`/`gates.py`/`judge.py`) — unchanged, un-weakened.
- Substrate: frozen `knowledge_index.db` (concepts), `graph_edges.db` (hierarchy), `qie.db` (governed facts),
  `pyq_corpus.db` (PYQ seed). The population program **reads** these; it must not mutate the frozen index.
- The `qie/execution/` provider/budget layer (Program C) is the live-generation cost governor for every wave.
- The one product bank `qpl_question_bank.db` (RI-6) is the certification output and Program D's input.

**On Program D (the consumption pipeline) — this program FILLS what D SERVES:**
- Output flows through D's exporter → `edu_platform_question_bank` → union → solver. **Nothing new to build on
  the consumption side for papers (Area 17).** DPP/adaptive/notes (Areas 15/16/18) extend D's pool builder.
- D's `edu_concept_vocabulary` (KC↔UUID), calibration column, Bloom/marks, near-dup vectors, exposure seam,
  and per-tenant flags are **already the metadata + dedup + exposure infrastructure** this program produces
  content for.
- D's dormant migrations (`20260877`–`20260880`) + cut-over recipe are the promotion path; **applying them is
  the same owner gate** as before. New tables here (review queue, mastery, notes, work-queue) use the next
  band **≥ `20260881`**.

**On the ERP Education Suite — wiring, not rebuilding:**
- `education_blueprint_solver.ts` (unchanged authoritative solver) — the deterministic engine every product
  output reuses.
- Dormant CI schema is the home for A2 families/distractors, the concept graph, exposure, rotation, the
  response spine (the sensor for Areas 8/13/14), and blueprint/exam-profile templates (DPP/adaptive).
- The ERP two-person **maker–checker** pattern + `status_audit` are reused for human review (Area 3).
- RBAC/RLS/tenant isolation + the response-spine capture (`marks_grid_ocr`/manual/digital) already exist.

**Net:** the population program is **~70% driving existing machinery** (QIE factory, Program D pipeline, ERP
solver + dormant schema) and **~30% net-new** — chiefly: the **human review console** (Area 3), the **family
instantiation engine** (A2, Area 20), the **mastery/weakness model** (Area 14), the **certified-notes store**
(Area 18), and the **coverage/prioritiser** meta-loop (Areas 12/19).

---

## 5. Optimal execution order

```
W0 PYQ-FIRST      → W1 QUANT FACTORY   → W2 METADATA/CALIB → W3 FAMILIES (A2)  → W4 QUALITATIVE LANE
   certify PYQ        autonomous Lane-Q    difficulty+Bloom     instantiation       source-proven + human
   (fast, high-value) waves per concept    at cert/export       (scale lever)       review console
        │                    │                                        │                    │
        └──── unblocks Program D acceptance (non-empty bank) ─────────┴──── W5 INTELLIGENCE LOOPS ──┐
                                                                              feedback·weakness·CQI  │
                                                                                                     ▼
                                                                       W6 PRODUCT OUTPUTS + W7 SCALE/INFRA
                                                                       DPP·adaptive·notes · Postgres/vector
```

- **W0 — PYQ certification (do first).** Highest value, lowest cost, uses content that already exists with
  official keys. Lane-Q PYQ via sympy; Lane-K PYQ via official-key `source_proven`. **This is what makes the
  bank non-empty and unblocks Program D operational acceptance (M5.2).** Owner-gated budget for any live judge
  calls; much is deterministic.
- **W1 — Autonomous quantitative factory.** Budget-governed generation waves per concept×difficulty for
  STRUCTURED_NUMERIC, cross-family judged. Fills quant coverage. Honest yield tracking (expect low yield —
  Program C).
- **W2 — Metadata + calibration.** Bloom/marks/predicted-difficulty at export (built in Program D); measured
  difficulty begins as pilot responses flow.
- **W3 — Certified families + instantiation (A2/I9).** Build the family/item-model + runtime instantiation
  engine — the multiplier to scale. Higher-stakes certification (family blast radius).
- **W4 — Qualitative lane + human review console.** The genuinely new product surface + expert workflow;
  source-proven where possible, human maker–checker otherwise. Staffing-bound.
- **W5 — Intelligence loops.** Feedback → measured difficulty + item flagging; weakness/mastery model; the CQI
  prioritiser. Needs pilot response signal.
- **W6 — Product outputs.** DPP, adaptive practice, revision notes — thin deterministic wrappers over the
  now-populated bank + mastery model.
- **W7 — Scale/infra.** Postgres product bank + vector index as volume demands (owner-gated infra).

**Sequencing rationale:** value-first (PYQ), then the autonomous engine, then the scale multiplier (families),
then the human-bound lane, then the loops that need data, then products, then infra. Each wave is
independently valuable and **owner-gated on budget + acceptance**.

---

## 6. Cost / throughput model

- **Deterministic work is free** (compute-only): sympy re-derivation, dedup, instantiation, assembly, coverage.
  Maximise the deterministic share.
- **Live-AI cost is per generation + per judge call.** Program C's governor is the template: **hard/soft $
  budget caps, concurrency 1, rpm limit, priced per model** (e.g. sonnet-4.5), cross-family routing (OpenAI
  direct, Anthropic via OpenRouter). Every wave declares a budget; the runner **fails closed at the cap**.
- **Yield is the dominant cost driver, not per-call price.** Program C's finding — **0/22 recalled items
  survived current gates** — means naive generation has low certification yield; cost/certified-item ≫
  cost/generated-item. Plan budgets on **cost-per-CERTIFIED-item**, measured per wave, and stop a wave whose
  yield doesn't justify spend.
- **Families change the economics.** One certified family (a few AI calls to build+verify) → thousands of
  deterministic instances (free). This is why W3 is the scale lever, not brute-force W1.
- **Qualitative cost is expert time**, not tokens — model it as reviewer-hours/certified-item, and automate
  everything up to the human yes/no.

---

## 7. Cross-cutting risks & red-team

1. **The qualitative certification gap** (structural). *Threat:* pressure to let a model "certify" facts to hit
   Biology/NEET coverage. *Mitigation:* two-lane honesty; `source_proven` or human, never model-alone; report
   the lane split so the gap is visible, not hidden.
2. **Yield collapse / cost overrun.** *Threat:* burning budget generating un-certifiable questions.
   *Mitigation:* per-wave budget caps + cost/certified gate; PYQ-first + families-first economics.
3. **Gate erosion under coverage pressure.** *Threat:* relaxing sympy tolerance / independence / dedup to raise
   numbers. *Mitigation:* gates are frozen law; coverage is reported honestly with the denominator; NO-GO on
   any weakening.
4. **Family blast radius.** *Threat:* a wrong certified family → thousands of wrong served items. *Mitigation:*
   stricter family certification (wider verified parameter sweep, extra judges), fast recall of a family.
5. **Vanity metrics.** *Threat:* counting quarantined/trial/provisional rows as "certified" (the audit's
   original sin). *Mitigation:* RI-6 product-visible-only counting; published denominators.
6. **Substrate/version drift.** *Threat:* generating against a drifted spine. *Mitigation:* freeze-pinned
   substrate, fingerprint verification, honest re-freeze events.
7. **Human-review bottleneck.** *Threat:* Lane-K queue stalls the whole program. *Mitigation:* automate to the
   yes/no, staff to SLA, PYQ-official-key path to reduce human load, families to amortise review.
8. **Data poisoning via feedback.** *Threat:* abusing "report question" to recall good items. *Mitigation:*
   thresholds, human disposition, append-only + audited, never auto-edit certified content.
9. **Storage/privacy.** *Threat:* leaking derived knowledge or student response data. *Mitigation:* the
   local-only derived-knowledge law, tenant RLS on the spine, owner-gated prod promotion.

---

## 8. GO / NO-GO + owner decisions to ratify

- 🟢 **GO** to author + execute the population program **in owner-gated waves, W0 (PYQ) first** — it fills the
  bank with the highest-value, lowest-cost content and unblocks Program D acceptance, reusing the existing
  factory + pipeline with little net-new build.
- 🟡 **HOLD (owner-gated):** (a) **every live-generation budget** — no wave spends without an approved cap +
  acceptance gate; (b) **the qualitative-lane staffing model** (expert reviewers — the real cost/constraint);
  (c) **new migrations** (review queue, mastery, notes, work-queue — band ≥ `20260881`) + the eventual
  **Postgres/vector scale step**; (d) **prod promotion of any derived knowledge** (the local-only law).
- 🔴 **NO-GO** on: weakening any certification gate (sympy tolerance, independence, dedup, source-proof) to
  raise yield/coverage; a model "certifying" qualitative facts on its own say-so; counting non-product-visible
  rows as certified; any request-path live-AI generation (I9).

**Owner decisions to ratify before/within the program:**
1. **W0 PYQ scope + budget** — which exams/classes to certify first, and the live-judge budget cap.
2. **Qualitative-lane staffing** — who reviews (subject experts), throughput target, and cost model.
3. **Family certification bar (A2)** — the stricter gate for item-models (blast-radius policy).
4. **The metadata/versioning contract** as the standard (Program-D Contract-1 extended).
5. **Coverage targets** per exam/class (the denominator the prioritiser optimises).
6. **Scale-infra trigger** — the volume at which the product bank moves to Postgres + a vector index.

**Recommendation.** Approve the plan; authorize **W0 (PYQ certification)** as the first, highest-value,
budget-gated wave — it makes the bank non-empty, unblocks Program D, and proves the population factory
end-to-end before larger spend. Keep every subsequent wave, all migrations, all live spend, and the
qualitative-lane staffing **owner-gated**.

---

*No code, schema change, migration, live API call, or frozen-program modification was produced by this plan.
It designs how Akshara populates and continuously grows a certified knowledge bank using the existing QIE
factory, Program D pipeline, and ERP engines — without weakening a single certification gate.*

