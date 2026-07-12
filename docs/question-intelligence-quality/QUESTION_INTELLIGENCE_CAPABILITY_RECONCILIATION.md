# Question Intelligence — Capability Reconciliation (Architecture Correction Checkpoint)

**Date:** 2026-07-12 · **Status:** RECONCILIATION ONLY — no implementation, no new lane, no gate change, no
B-series fix, no generation, `qpgen` untouched. Independent audit of the whole QIE program (mission → Phase
0/0b → A0–A5 → B1–B10) against measured code + artifacts. **Where narrative and code/measurement disagree,
code and measurement win.**

---

## 1. Executive verdict — what actually failed

**The evaluation abstraction failed. The architecture, corpus, and verification did not.**

- **Architecture:** sound. The `question_dna` / `item_model` schemas already model the correct richer space —
  `question_dna(lane, archetype, …)` and `item_model(lane, archetype, assessment_construct, cognitive_chain,
  difficulty_band, allowed_profiles, …)` are **distinct columns** (`kie/qie/store_schema.sql`). The design was
  never "subject × number-of-models."
- **Corpus:** sufficient *for the profiles it actually contains*. Measured: Biology×NEET **1623 distinct
  recovered questions / 87 docs**; Physics×JEE **2937**; Physics×NEET **1093**; Chemistry×NEET **1175**
  (`scratchpad/subject_profile_matrix.py`, run 2026-07-12). It is thin/absent only for profiles the corpus was
  never acquired for (Board/SCERT/ICSE assessment items = **0** recovered — those sources are textbooks).
- **Verification:** works. Phase-0 numeric relation-match 54.3% ≥ 40% floor; Biology model-agreement 91.7% ≥
  30% floor ([PHASE0_EVIDENCE_REPORT.md:67-71](PHASE0_EVIDENCE_REPORT.md)); Tier-2 B6/B7 46/48 agreement.
- **The abstraction that failed:** the **"≥8 verified Item Models per subject"** gate. It is a Phase-0
  *scaling-viability* instrument that (a) counts a scale proxy, not quality; (b) is **profile-blind**; (c)
  **conflates lane with archetype** and so excludes legitimate archetypes; (d) demands a **symmetric**
  per-subject archetype yield the corpus and the assessment domains never had. B6–B10 progressively optimized
  this instrument. The correct response is not another blocker fix — it is to retire the instrument as a
  product gate and measure Subject × Profile × Archetype capability instead.

**Would passing 4/4 prove Akshara can generate excellent papers? No.** 4/4 would prove only that ≥8 mineable
structured clusters exist per subject in a NEET/JEE corpus. It says nothing about board profiles (0 evidence),
nothing about archetype coverage of a real blueprint, nothing about paper-level non-repetition, and it
*already excludes* the dominant, legitimate NEET-Biology archetype. Quality readiness is a different
instrument (the gold benchmark) — and that one already passed its substance in Phase 0.

## 2. Origin and purpose of the ≥8-per-subject gate

- Born as **Hypothesis A (structure-mining yield)** in the Phase-0 pre-registration:
  "≥ **8 distinct-lane/archetype Item Models per subject**, each distilled from ≥ **K=5** distinct DNA drawn
  from ≥ **2** distinct source resources" ([PHASE0_PREREGISTRATION.md:50-51](PHASE0_PREREGISTRATION.md);
  [OPUS_FABLE_RECONCILIATION_RECORD.md:279](OPUS_FABLE_RECONCILIATION_RECORD.md)).
- **Stated purpose = a funding go/no-go**, an "**anti-clone/anti-copy floor**" (Record:279). Kill rule: "STOP;
  reassess the architecture **before any Phase-A schema or engine work is funded**"
  ([PREREGISTRATION.md:83-86](PHASE0_PREREGISTRATION.md)). "Passing … **authorizes nothing further by
  itself**."
- The charter retained it explicitly as a **scaling** gate, not a quality gate:
  "**QUALITY ARCHITECTURE PROVEN. YIELD NOT YET PROVEN**" and the yield gate "**blocks Phase-B scaling** … No
  scaling until it clears" ([PHASE_A_CHARTER.md:8-14](PHASE_A_CHARTER.md)).
- It is **absent from `QUALITY_GATE_SPECIFICATION.md`** — the product quality gate is the 15-gate educational
  ladder + the gold benchmark, not a per-subject model count.

**Conclusion:** the ≥8 gate was always a *viability/scaling* instrument. Pre-registration correctly froze it
to prevent goalpost-moving *during the experiment*. The experiment is over. Pre-registration does not make a
scaling proxy the right *product* metric forever.

## 3. What the gate taught us (Phase 0 → B10)

| Phase | ≥8 result | What it actually established |
|---|---|---|
| Phase-0/0b | Bio/Math **FAIL** (2/1/0/0) | The report itself said the FAIL was "**about the instrument, not the architecture**" — non-numeric lanes were structurally un-clusterable in the throwaway harness ([PHASE0_EVIDENCE_REPORT.md:77-83](PHASE0_EVIDENCE_REPORT.md)). **Hypothesis B (quality) PASSED** the absolute bar, no-regression, agreement, and the Biology-specific bar; it missed only `difficulty_accuracy` **lift** due to a blind-packet instrument flaw ([:123-132](PHASE0_EVIDENCE_REPORT.md)). |
| B1–B5 | 2/4 | Full-corpus mining + KVS multi-source; confirmed Physics/Chemistry pass via NUMERIC_RELATIONAL (genuine solver-verified). |
| B6–B7 | 2/4 | Built the Tier-2 model-agreement lane + strict concept resolver — **genuine capability**. Blocker reframed to "Biology per-concept depth." |
| B8 | 2/4 | Exposed that Math's "6 verified" are **false relation-matches** on misattributed physics/calculus — **a real correctness finding** (`kie/qie/math_structure.py`). |
| B9 | 2/4 | Full corpus discovery/reconciliation: two disjoint corpora, all PDFs reconciled, stranded evidence bridged — **genuinely valuable**; proved the blocker is not unfound corpus. |
| B10 | 2/4 | `bio_resolve.py` fixed the resolution-recall artifact (524 items → 17 diverse canonical concepts); then measured that the diverse Biology evidence is **factual-recall** the lane taxonomy excludes (436 distinct stems), and Math genuine school evidence ≈ 0. **This is the finding that breaks the frame.** |

**Net lesson:** every B-round produced a genuine artifact, but each was framed as "move the ≥8 number." By B10
the number could only move by (a) counting replication (inflation), (b) admitting an archetype the taxonomy
omitted, or (c) counting out-of-profile JEE calculus — i.e. by **gaming an experimental gate**. That is the
signal to correct the metric.

## 4. Disposition of the ≥8-per-subject gate

**RETIRE as a product/go-live gate → DEMOTE_TO_DIAGNOSTIC and SPLIT_BY_PROFILE.**

- **Retire** the uniform, subject-only, structured-only "≥8 per subject" as a pass/fail product gate. It is
  the wrong altitude and the wrong shape.
- **Keep** the underlying **per-model promotion bar** — ≥5 distinct DNA from ≥2 resources — it is a real
  anti-clone/originality floor and lives in the schema (`item_model.n_dna ≥ 5`, `n_resources ≥ 2`,
  [store_schema.sql](../../curriculum/scripts/intelligence/kie/qie/store_schema.sql)) and specs
  ([ITEM_MODEL_SPECIFICATION.md:198-201]).
- **Split by profile + archetype**: yield is measured per **(subject × profile × archetype)** cell against
  that cell's *required* archetypes, not a flat 8 per subject.
- **Demote to diagnostic**: "mineable structured Item Models per subject" remains a useful *evidence-density*
  diagnostic — reported, never a gate.
- **Do not weaken** any verification threshold (relation-match tolerance, KVS ≥2-doc, Tier-2 agreement,
  benchmark absolute bar). Retiring a mis-shaped *count* is orthogonal to verification rigor.

## 5. Audit of the 11-lane taxonomy

The 11 lanes ([OPUS_FABLE_RECONCILIATION_RECORD.md:137-168]) were founded on finding **F8 (non-numeric
Biology gap)** as **verification-strategy** groupings ("A lane — not a subject — is the unit of capability …
each with its own independent-verification strategy", [:118-121]). That is a sound axis **for verification**.
Two defects:

1. **Lane ≠ archetype, but the implementation collapsed them.** The mission's assessment axis is a **19-value
   `archetype`** vocabulary ([QUESTION_DNA_SPECIFICATION.md:80-89]); the 11 lanes are a **coarser
   verification axis** the schema keeps separate (`question_dna.lane` **and** `question_dna.archetype`). The
   B-series miner writes them equal — `INSERT … item_model(…lane, archetype…) VALUES (…, lane, lane, …)`
   ([kie/qie/mine.py](../../curriculum/scripts/intelligence/kie/qie/mine.py) `run()`), and clusters/counts by
   `(lane, concept)`. So "how we verify" was silently promoted to "what archetype we can assess."
2. **The taxonomy is incomplete for assessment form.** "Nothing was REJECTED outright"
   ([RECONCILIATION_RECORD:109]) — factual-recall/definition was **omitted, never dispositioned**. The 11
   lanes are also **structured-only**; they have no home for the single-best-answer conceptual item, which is
   the dominant NEET-Biology form.

**Verdict:** the 11 lanes are **valid as a verification-strategy taxonomy** and should be retained *for that
purpose*. They are **invalid as the archetype/coverage taxonomy** and must not be the axis the yield/coverage
gate counts.

## 6. Exact treatment of factual-recall / single-best-answer

Factual-recall is **a legitimate ARCHETYPE, not a missing structure-intelligence lane.** It is already in the
mission vocabulary as `direct_recall` and `definition_recognition`
([QUESTION_DNA_SPECIFICATION.md:80-90]; the engine "can express ~2 of these (single_step_numerical,
**definition_recognition**)"). It was omitted from the 11 verification lanes because it has no *structured*
evidence shape — but it has a valid **verification** path: KVS multi-source corroboration (deterministic) +
Tier-2 independent-model agreement (governed), exactly the CONCEPTUAL/ASSERTION verification the lanes already
use.

**Therefore:** do **not** add a `FACTUAL_RECALL` *lane*. Instead (a) treat `direct_recall` /
`definition_recognition` as first-class **archetypes** (already in the enum), (b) let them be **verified**
through the existing KVS-assertion + Tier-2 lane machinery, and (c) make them **profile-gated** — legitimate
and discriminating as a dominant NEET-Biology form, deliberately *capped* as a dominant Board form (Board
prizes understanding/application). B10 measured **~28 genuine Biology concepts** with ≥5 distinct
semantic-answer factual stems from ≥2 docs — real, verifiable capability the current gate cannot see.

## 7. Separating lane, archetype, Item Model, assessment profile

Confirmed against code + specs; these are four distinct responsibilities that were partly conflated in the
miner (not in the schema):

| Concept | Responsibility | Where it lives (authoritative) |
|---|---|---|
| **Structure-intelligence lane** | *How* source reasoning/evidence is structurally understood and **independently verified** | `question_dna.lane`, `kie/qie/lanes.py` (11), `Verify` enum |
| **Question archetype** | *What* assessment form/cognitive pattern the student sees | `question_dna.archetype`, `item_model.archetype` (19-value mission vocab) |
| **Item Model** | Reusable generation mould for one archetype × construct within a concept/profile | `item_model` row (parametric schema, distractors, verification_ref) |
| **Assessment profile** | Rules for which archetypes/difficulty/constructs are *valid & expected* for a target exam | `item_model.allowed_profiles`, `question_dna.provenance.board_or_profile`, per-profile difficulty drivers |

**Minimum correction (design-level, not implemented here):** the miner must populate `archetype`
independently of `lane`, and must populate `allowed_profiles` from source provenance. Yield/coverage must be
counted over `(subject, profile, archetype)`, verification over `lane`.

## 8. Subject × Profile corpus capability matrix (measured)

Measured from recovered evidence (`scratchpad/subject_profile_matrix.py`, 2026-07-12; distinct = normalized
distinct stems):

| Subject | NEET | JEE | Board/SCERT/ICSE | Foundation-practice | Rating |
|---|---|---|---|---|---|
| **Physics** | 1093 / 111 docs | **2937 / 302** | 0 | 30 | STRONG (NEET+JEE) · Board ABSENT |
| **Chemistry** | **1175 / 109** | 19 / 5 | 0 | 75 | STRONG NEET · THIN JEE · Board ABSENT |
| **Biology** | **1623 / 87** | — | 0 | 33 | STRONG NEET (factual-recall archetype) · Board ABSENT |
| **Mathematics** | 46\* (physics-noise) | **95 / 8** (50 calculus) | 0 | 13 | MODERATE JEE (calculus) · school-clean ABSENT · Board ABSENT |

\*Math×NEET is `guess_subject` misattribution of physics "ratio/circle" items — not real math.

Ratings: **STRONG** = Physics/Chemistry/Biology × NEET, Physics × JEE. **MODERATE** = Math × JEE.
**THIN** = Chemistry × JEE. **ABSENT** = every subject × Board (sources are textbooks, 0 recovered MCQs),
Math × school-clean. **PROFILE_MISMATCHED** = Math × (school gate) — JEE-calculus evidence judged by a school
verifier. **UNRESOLVED** = the ~14–30 per-subject `UNKNOWN`-profile items.

**Headline:** the corpus is a **NEET + JEE** corpus. Board/school **assessment** evidence is ~0 across all
subjects (board *content* exists as textbooks → concepts, but not as question evidence). The ≥8 uniform gate
judged a NEET/JEE corpus against a school-structured, profile-blind standard.

## 9. Correct treatment of JEE Mathematics evidence

JEE Math evidence is **real and valuable — for the JEE Math profile**, not "unusable Mathematics." Measured:
95 distinct JEE Math questions, 82 numeric-answer, **50 distinct are calculus** (integrals/derivatives/
maxima-minima). B8 showed the school relation library "verifies" these only by coincidence and the
`math_structure` model correctly rejects them.

**Classification, not deletion:** tag this evidence `profile = JEE_MAIN/JEE_ADVANCED`, `archetype ∈
{multi_step_symbolic, calculus, coordinate_geometry, algebraic_transformation}`, and build a **JEE-profile
symbolic verifier** (e.g. sympy-based) when the JEE Math profile is actually funded. Do **not** count it
toward a school/Board Math gate; do **not** call it invalid math. Genuine *school-profile* Math in this corpus
is ~1 item — so a **Board/school Math profile is EVIDENCE-ABSENT** and must be acquired, not mined from here.

## 10. Correct treatment of Biology factual evidence

Biology's strength is **NEET single-best-answer factual/conceptual recall** — legitimate and highly
discriminating **in the NEET profile**. B10: `bio_resolve.py` resolves 524 items → 17 canonical concepts with
diverse ≥5-distinct/≥2-doc support; ~28 concepts carry verifiable factual evidence. The current gate discards
this because (a) it lands in `CONCEPTUAL_GENERIC` (no *structured* lane), and (b) the gate counts structured
lanes only. **Correct treatment:** admit `direct_recall`/`definition_recognition` as archetypes (§6), verify
via KVS multi-source + Tier-2, gate *by NEET profile*, and require diversity (distinct-stem support) to avoid
replication inflation. Under a profile-and-archetype-correct metric, **Biology×NEET is READY on evidence**;
under the current gate it reads as FAIL — a metric artifact.

## 11. Proposed Question Intelligence Capability Matrix

Evaluate capability over the full space the schema already anticipates — **not** `subject × #models`:

```
CELL = subject × assessment_profile × class/level × curriculum_boundary(concept)
       × assessment_construct × archetype × cognitive_chain
       × difficulty_driver_support × verification_method
per cell record:  evidence_depth · generation_diversity · solution_verifiability · visual_support
```

- **Rows** are driven by each profile's **required archetype set** (§13), not a uniform 8.
- A cell is *covered* only with **verified** Item Models meeting the per-model ≥5-DNA/≥2-resource bar and the
  cell's verification method.
- The matrix is **sparse and asymmetric by design** — Biology×NEET fills recall/classification/
  structure-function/assertion; JEE-Math fills symbolic/calculus; Board fills understanding/application/
  competency; a subject/profile with no evidence is honestly ABSENT, not FAIL.

## 12. New metrics (five separate, none a vanity number)

These already exist *conceptually* in the docs (coverage vs quality vs scale are distinct —
[ROADMAP:102], [GOLD_BENCHMARK_PLAN.md:14-24], [CHARTER:8-9]); the B-series collapsed them into one number.
Re-separate them:

1. **CAPABILITY COVERAGE** = fraction of a **profile's required (archetype × construct)** cells supported by
   ≥1 verified Item Model. *(Per profile. This replaces "≥8 per subject.")*
2. **EVIDENCE READINESS** = concepts with sufficient **multi-source DNA** (≥5 distinct / ≥2 resources) per
   (subject, profile). *(Diagnostic density; the old ≥8 becomes one view of this.)*
3. **QUALITY READINESS** = gold-benchmark performance vs Engine-A + absolute bar, blind
   ([GOLD_BENCHMARK_PLAN.md:79-85]). *(Already substantially PASSED in Phase 0.)*
4. **SCALE READINESS** = post-originality/verification parameter-and-context diversity per Item Model (can it
   emit many non-clone instances). *(This is what "yield" should have meant.)*
5. **PAPER READINESS** = ability to satisfy a **real profile blueprint** end-to-end with strong,
   non-repetitive, verified items (uses the existing `qpgen` blueprint/feasibility path,
   [kie/qpgen/blueprint.py](../../curriculum/scripts/intelligence/kie/qpgen/blueprint.py)).

Improvement over the prompt's draft: (1) is **per profile** (not global), and each metric names its
**denominator** so none can silently become a vanity count.

## 13. Profile-specific archetype expectations (evidence-grounded proposal, owner to ratify)

Not symmetric across subjects/profiles. Draft required-archetype sets (to be ratified, and only where a
profile is funded + evidenced):

- **NEET Biology:** direct_recall/definition · classification_taxonomic · structure_function · process_sequence
  · conceptual_causal · assertion_relation · misconception_detection · diagram_interpretation. *(Evidence:
  STRONG.)*
- **NEET/JEE Physics:** single_step_numerical · multi_step_numerical · reverse/missing-variable ·
  constraint_reasoning · graph/data_interpretation · experiment_inference · multi_concept_integration.
  *(Evidence: STRONG.)*
- **JEE Mathematics:** algebraic_transformation · equation/inequality · multi_step_symbolic ·
  coordinate_geometry · calculus · sequence/progression · probability/combinatorics · geometry/trig.
  *(Evidence: MODERATE, needs a JEE symbolic verifier.)*
- **Board 6–10 (all subjects):** recall *where curriculum-valid (capped)* · understanding · application ·
  competency/case-interpretation · experiment_observation · data/table/graph · visual · short/long
  constructed-response. *(Evidence: ABSENT — acquire before claiming.)*

**Rule:** the engine must not demand identical archetype distributions from every subject/profile. A dominant
factual-recall share is valid for NEET Biology and undesirable for Board; multi-step calculus is excellent JEE
and invalid for Class-10 Board.

## 14. Minimum schema / architecture corrections (design only — NOT implemented)

The schema is already correct; the corrections are in **population and counting**, not new tables:

1. **Miner**: populate `question_dna.archetype` from the 19-value vocabulary **independently of `lane`**
   (stop `archetype = lane`); populate `item_model.allowed_profiles` from source provenance
   (`source_documents.exam` → profile).
2. **Profile map**: one deterministic `source/group → assessment_profile` table (already prototyped in
   `scratchpad/subject_profile_matrix.py`; promote to a committed reference, not code that mutates kie.db).
3. **Yield/coverage**: count over `(subject, profile, archetype)`; keep verification over `lane`.
4. **Archetype classifier**: a proper archetype tagger (recall / classification / structure-function / causal
   / sequence / assertion / numeric-*), separate from the lane classifier — the single biggest missing piece.
5. No `qpgen` change; no kie.db mutation; the ≥5-DNA/≥2-resource per-model bar unchanged.

## 15. Phase-A/B work that remains valid and reusable

- **Reusable as-is:** relation library + solver verification (`relations.py`); KVS multi-source substrate
  (`kvs_build.py`); Tier-2 governed model-agreement lane + cache (`tier2_verify.py`); `bio_resolve.py`
  (specific-entity resolution); `math_structure.py` (false-match rejection + JEE-vs-school separation);
  `qcorpus_adapter` / `doc_recover` / `stranded_recover` (evidence recovery); the corpus reconciliation
  (`corpus_reconciliation.json`); the benchmark harness (`benchmark.py`); the whole `item_model`/`question_dna`
  schema; `qpgen` blueprint/feasibility/assembly.
- **Reusable with reframing:** all B-yield artifacts become **evidence-density diagnostics** per (subject,
  profile), not pass/fail.

## 16. Assumptions / metrics to supersede

- ✗ "≥8 verified Item Models per subject = product/scale readiness." → superseded by §12 five metrics.
- ✗ "lane = archetype." → superseded by §7 separation.
- ✗ "factual-recall is junk / not an archetype." → superseded by §6 (it is `direct_recall`/`definition_recognition`).
- ✗ "one uniform archetype bar for all subjects." → superseded by §13 profile-specific expectations.
- ✗ "corpus is subject-shaped." → superseded by §8 subject × profile.
- ✗ "Math evidence is unusable." → superseded by §9 (it is JEE-profile evidence).

## 17. Next implementation sequence (proposed; do NOT start until owner approves)

1. Ratify §12 metrics + §13 profile archetype expectations (owner decision).
2. Commit the `source → profile` reference map + a read-only `(subject, profile, archetype)` capability report
   (diagnostic; no gate).
3. Build the **archetype classifier** (separate from lane); backfill `archetype` + `allowed_profiles` in the
   miner. Re-measure capability coverage per profile.
4. Stand up the **gold benchmark** as the *quality* gate for the first funded profile (NEET Biology is the
   highest-evidence, highest-value candidate).
5. Only then, per funded profile: verify (KVS+Tier-2 / solver / symbolic), measure the five readiness metrics,
   and gate scaling on **quality + paper readiness**, never on a raw model count.
6. Board/school profiles: acquire assessment evidence first (currently ABSENT) — do not claim readiness.

## 18. Are B6–B10 improving the product, or gaming an experimental gate?

**Both — and that is the problem.** Each round produced a *genuine* artifact (Tier-2 lane, resolver,
false-match exposure, corpus reconciliation, entity resolver). But from B6 onward the **framing** was
"move the ≥8 number," and by B8–B10 the number could only move by inflation, an omitted archetype, or
out-of-profile calculus. B10 is where honest measurement made the gate's wrongness undeniable: the evidence
is there, but the *metric* cannot represent it. Continuing B11 as another targeted ≥8 fix would be **pure
gating of an experimental instrument.** The correct move is this reconciliation: keep the genuine artifacts,
retire the mis-shaped gate, and measure Subject × Profile × Archetype capability with separated
coverage/evidence/quality/scale/paper metrics.

---

**STOP for owner review.** No code changed, no lane added, no gate altered, no generation run, `qpgen`
untouched. Success criterion for this checkpoint is not 4/4 — it is that Akshara now measures the *right*
question intelligence per real assessment profile and no longer mistakes an experimental yield metric for
product readiness.
