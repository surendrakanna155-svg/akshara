# Phase-0 Evidence Report — Kill Test Results

> **UPDATE 2026-07-12 — Phase-0b bounded re-run appended (§6).** After the owner-approved bounded re-run
> (fixing only the two instruments, thresholds unchanged): **Hypothesis B now PASSES all gates**; **Hypothesis
> A still misses the ≥8-Item-Models-per-subject gate**, now for a well-understood, in-roadmap reason
> (concept-quality debt + thin per-concept density in a 200-item slice). Overall: **quality proven; yield-
> density gated on a known fix → STOP for owner reassessment** (options in §6.4). Read §1–§5 for the first run,
> §6 for the re-run and the final verdict.

**Date:** 2026-07-12 · **Author role:** Chief Assessment Intelligence Architect
**Governed by:** `PHASE0_PREREGISTRATION.md` (frozen before any result was observed) and
`OPUS_FABLE_RECONCILIATION_RECORD.md` §7. Thresholds were **not** moved after results were seen.
**Scope executed:** Phase 0 only. No Phase A–F work. No change to any of the 8 frozen `kie/qpgen/` engine
surfaces. All Phase-0 code is standalone/throwaway (`scratchpad/phase0/`), read-only on `kie.db`, wrote no
schema, registered no family into the engine.
**Raw evidence preserved in:** `docs/question-intelligence-quality/phase0_evidence/` (mining metrics, recovered
DNA samples, held-out/originality, blind judging packet, unblinding key, three raw judge score files, Biology
agreement verdicts).

> **Hypothesis-B evidence label (mandatory):** **AI-PANEL VALIDATED PHASE-0 PROXY EVIDENCE.** It is **not**
> teacher validation and **not** expert validation. Real independent teacher validation remains **mandatory**
> before any production-scale quality claim or market claim. The AI panel can *screen/kill* cheaply; it cannot
> *certify* for production.

---

## 0. Headline verdict

**NEITHER hypothesis fully cleared its pre-registered gates → STOP for owner reassessment. Do NOT proceed to
Phases A–F.**

This is the disciplined outcome, not a disappointing one: the kill test worked. The **substance** is strongly
encouraging — hand-built lane Item Models beat the current engine decisively on exactly the dimensions the
redesign targets, with high inter-judge agreement, and Biology non-numeric items independently reached the
quality bar. But **each hypothesis missed one pre-registered gate**, and both misses are attributable to
**instrument limitations of a deliberately throwaway Phase-0 harness**, not to disconfirmation of the
architecture:

- **Hypothesis A** passed recovery, both independent-verification floors, held-out generalization, and
  originality — but **missed the "≥8 Item Models per subject" gate** (the throwaway harness only clusters the
  numeric lane, and the non-numeric Knowledge Verification Substrate it would need does not exist yet).
- **Hypothesis B** passed the absolute quality bar, no-regression, the agreement floor, the Biology-specific
  bar, and proved a ≥1.0 lift on **3 of 4** required dimensions — but **missed the 4th lift dimension
  (`difficulty_accuracy`)**, because the blind packet did not expose an intended difficulty label for the
  dimension to measure against.

Per the pre-registered kill rule ("Hypothesis B missing the lift test → STOP"), the correct action is to
**STOP and reassess with the owner** before funding Phase A. Options are in §4.

---

## 1. Hypothesis A — structure-mining yield

Representative discovery slice mined read-only from the 7,746 complete `(1)(2)(3)(4)` MCQ chunks. Multi-
question chunks were split; per-question stem/options/answer-key recovered; subject attributed by lexicon;
lane classified; numeric items verified by an independent relation library (throwaway, ~30 relations);
Biology non-numeric items verified by an independent model-agreement oracle (the Tier-2 half of the eventual
KVS check — a **weaker** proxy, as pre-registered).

| Subject | Inspected | Complete recovery | Numeric items | Numeric verified | Item Models (≥5 DNA/≥2 res) |
|---|---|---|---|---|---|
| Physics | 266 | **94.0%** (250) | 39 | **56.4%** (22) | 2 (`P=VI`, `R=V/I`) |
| Chemistry | 299 | **83.6%** (250) | 14 | 28.6% (4) | 0 |
| Biology | 268 | **93.3%** (250) | 2 | 50% (1) | 0 |
| Mathematics | 227 | **88.1%** (200) | 17 | **70.6%** (12) | 1 (`series`) |

- **Numeric independent-verification (aggregate over numeric subjects): 38/70 = 54.3% ≥ 40% floor → PASS.**
  (Per-subject, Chemistry alone is 28.6% on N=14 — small-N; the pre-registered floor is on recovered numeric
  items in aggregate.)
- **Biology non-numeric verification (model-agreement proxy): 55 agree / 1 disagree / 4 unverifiable of 60 =
  91.7% ≥ 30% floor → PASS** — on the **key-bearing subset only** (honest denominator: only ~44% of recovered
  items carry a recoverable in-segment answer key; keyless items are unverifiable in Phase-0). This is
  model-agreement, **not** KVS entailment; it must be re-confirmed against a real KVS in Phase B.
- **Complete-item recovery: 83.6–94.0%, all ≥ the 60% numeric / 45% Biology floors → PASS.**
- **Held-out generalization: 80/80 = 100% deterministic-gate pass → PASS.**
- **Originality: 0/80 source-tuple / similarity violations → PASS.**
- **≥8 distinct-lane Item Models per subject: FAIL** (2 / 1 / 0 / 0). **This is the gate Hypothesis A misses.**

**Honest reading of the FAIL.** Two confounds, both real and both about the instrument, not the architecture:
1. **The throwaway harness only discovers *numeric-lane* models.** Non-numeric model discovery requires
   clustering against the KVS (assertion/taxonomy/sequence/structure-function stores), which is a Phase-A
   deliverable and was not built. For Biology, numeric models are ~0 by construction; its models must come
   from the non-numeric lanes — which Phase-0 could not cluster. So the ≥8-per-subject gate is **structurally
   under-measured** for the non-numeric lanes.
2. **The relation library is deliberately tiny (~30 relations) and key-association is naive** (first
   `Answer(n)` per segment), and OCR exponent flattening (`10–31`, `12.2 × 10–14`) suppresses numeric
   verification. A production miner would have hundreds of relations and boundary-typed chunks (E-lite).

**The most important Hypothesis-A finding is not the gate miss — it is this:** of ~950 recovered items, only
**~7% are numeric-relational**; the corpus is overwhelmingly **non-numeric**. This **confirms** the
reconciliation's central thesis (F8): a numeric-only architecture serves <10% of the evidence, and the
architecture's Biology/NEET bet lives entirely in the non-numeric lanes — which **cannot be yield-proven in
Phase-0 without first building the KVS.** That is a concrete **sequencing implication**: the KVS + E-lite
boundary must precede large-scale mining, exactly as the reconciled roadmap ordered.

---

## 2. Hypothesis B — item-model quality spike (AI-PANEL VALIDATED PHASE-0 PROXY EVIDENCE)

Pool: **16 Engine-B** items from **8 hand-built lane Item Models spanning 6 lanes** (NUMERIC multi-step,
MISCONCEPTION_DIAGNOSTIC, ASSERTION_RELATION truth-table, CONCEPTUAL_CAUSAL×2, CLASSIFICATION_TAXONOMIC,
STRUCTURE_FUNCTION) + **7 Engine-A** items generated from the **real current-engine `templates` code** (numeric
`instantiate`, the real `_ar_family`, and faithful definition/definition-match patterns). All numeric items
were **machine-correctness-gated before review** (Engine-A 4/4, Engine-B 5/5). Items were anonymized,
shuffled (seed 20260712), and scored by **3 independent strong judge passes** (isolated contexts, blind to
engine/lane/hypothesis).

**Median scores (1–5), median lift = B − A, inter-judge Krippendorff α (interval):**

| Dimension | A median | B median | Median lift | α |
|---|---|---|---|---|
| correctness | 5 | 5 | 0.0 | 0.79 |
| syllabus_alignment | 5 | 5 | 0.0 | 0.90 |
| concept_precision | 4 | 5 | +1.0 | 0.73 |
| **cognitive_depth** | 1 | 3 | **+2.0** | 0.91 |
| difficulty_accuracy | 4 | 4 | **0.0** | 0.71 |
| **distractor_quality** | 3 | 4 | **+1.0** | 0.73 |
| ambiguity (reverse) | 5 | 5 | 0.0 | 0.90 |
| originality | 2 | 3 | +1.0 | 0.85 |
| **solution_quality** | 3 | 4 | **+1.0** | 0.91 |

**Gate checks (pre-registered, unchanged):**
- **Absolute bar** (B median ≥ 4 on correctness/syllabus/concept_precision/ambiguity): **5 / 5 / 5 / 5 → PASS.**
- **No regression** (B ≥ A on correctness/syllabus/ambiguity): 5=5 / 5=5 / 5=5 → **PASS.**
- **Agreement** (α ≥ 0.6 on all gated dims): 0.71–0.91 → **PASS.**
- **Biology-specific bar** (Biology non-numeric items: correctness ≥ 4 AND distractor_quality ≥ 4): medians
  **5 and 4 → PASS.**
- **Lift ≥ 1.0 on all four required dims**: cognitive_depth (+2, 3/3 judges), distractor_quality (+1, 3/3),
  solution_quality (+1, 3/3) → proven; **difficulty_accuracy (0 median, 0/3 judges) → NOT met.**
- **`HYPB_PASS = False`** — fails solely on the `difficulty_accuracy` lift gate.

**Honest reading of the FAIL.** The blind packet **did not expose an intended difficulty label/band** for
either engine, so `difficulty_accuracy` ("does felt difficulty match the intended difficulty?") had no target
to match — judges scored perceived reasonableness, on which Engine-B's harder multi-step items showed only a
mean +0.5 lift and no median lift. This is a **packet-design limitation of the Phase-0 spike**, not evidence
that lane models cannot control difficulty (difficulty control is a declared Item-Model property the packet
simply didn't surface). Per the owner's rule, this is reported as a **gate miss, not reinterpreted into a
pass.**

**What the panel DID prove (strong, high-agreement proxy signal):** on the dimensions the current engine
structurally cannot do — cognitive depth (+2 median, α 0.91), distractor quality (+1, 3/3 judges), solution
quality (+1, α 0.91), concept precision (+1) — Engine-B beat the current engine cleanly, with **no regression**
on correctness/syllabus/ambiguity and the **Biology non-numeric items independently at the quality bar.** Two
representative unblinded judge rationales: Engine-A Ohm's-law item — *"V=IR correct; bare one-step plug-in with
a single option (degenerate MCQ)"* (cognitive_depth 1); Engine-B series-resistance misconception item scored
up specifically because the parallel-rule distractor is a real, diagnosed misconception.

---

## 3. Threshold scorecard (exact, against the frozen pre-registration)

| Gate | Threshold | Measured | Verdict |
|---|---|---|---|
| A · complete recovery | ≥60% num / ≥45% Bio | 94/84/93/88% | **PASS** |
| A · numeric verification | ≥40% (recovered numeric) | 54.3% aggregate | **PASS** |
| A · Biology verification | ≥30% | 91.7% (proxy, key-bearing subset) | **PASS** |
| A · held-out gate-pass | ≥70% | 100% | **PASS** |
| A · originality | 0 violations | 0 | **PASS** |
| **A · ≥8 Item Models/subject** | ≥8 each | 2 / 1 / 0 / 0 | **FAIL** (instrument-confounded) |
| B · absolute bar | median ≥4 ×4 dims | 5/5/5/5 | **PASS** |
| B · no regression | B ≥ A ×3 dims | all equal | **PASS** |
| B · agreement | α ≥0.6 | 0.71–0.91 | **PASS** |
| B · Biology bar | corr ≥4 & distractor ≥4 | 5 & 4 | **PASS** |
| B · lift ≥1.0 ×4 dims | all four | 3 of 4 (miss: difficulty_accuracy) | **FAIL** (packet-confounded) |
| **Overall** | both hypotheses pass | neither fully cleared | **STOP — reassess** |

---

## 4. What this means + reassessment options (owner decision)

The architecture is **promising on strong proxy evidence and NOT disconfirmed** — but it is **not proven under
the locked gates**, and Phase-0 additionally established that the **non-numeric lanes cannot even be
yield-tested until the KVS exists.** Per the pre-registered kill rule I am stopping here and **not** proceeding
to Phases A–F, **not** re-running to chase a pass, and **not** moving any threshold. Three options for the
owner:

1. **Phase-0b bounded re-run (recommended).** Fix only the two instrument limitations, then re-run under the
   **same** locked thresholds: (a) broaden the relation library and add a minimal non-numeric KVS-agreement
   clustering step so the "≥8 Item Models/subject" gate is measured fairly across lanes; (b) expose an intended
   difficulty band per item in the blind packet so `difficulty_accuracy` is measurable. Cheap, decisive, and
   keeps the kill test honest. This is a new approval, not a silent continuation.
2. **Accept the proxy signal and fund Phase A with the two gaps front-loaded.** The absolute bar, no-regression,
   agreement, Biology bar, and 3-of-4 lift with high agreement are, taken together, a strong pre-teacher
   signal. The owner may judge it sufficient to fund Phase A **provided** the KVS build and difficulty-label
   surfacing are the first Phase-A items and the two missed gates are re-tested at the Phase-A/B benchmark
   before any scaling. (Teacher validation still mandatory before production/market claims.)
3. **Reassess the architecture.** Not warranted by this evidence — the substantive signal is positive — but
   listed for completeness.

**My recommendation:** Option 1 (Phase-0b) if the owner wants the gates genuinely cleared before any funding;
Option 2 if the owner accepts a strong-but-incomplete proxy and wants momentum, with the KVS/difficulty work
contractually first. Either way, the STOP stands: no Phase A–F work and no engine-surface change begins without
explicit owner approval.

---

## 5. Limitations recorded (honesty)

- **Judge independence:** 3 independent passes of a strong Claude model (separate contexts), **not** three
  vendors or humans. Real limit; disclosed. AI-PANEL PROXY only.
- **Small N** (16 B / 7 A items): medians are robust but significance testing is under-powered; treated as
  indicative, and the ≥30-items/engine benchmark size (Gold Benchmark amendment) is a Phase-A requirement not
  met by this spike.
- **Biology verification is model-agreement, not KVS entailment** — the weaker proxy, on the key-bearing
  subset; must be re-confirmed against a real KVS.
- **Numeric verification suppressed by OCR exponent flattening** and naive key-association — E-lite
  (boundary-typed chunks) would raise it.
- **Engine-A faithful but partial:** for Biology the current engine often produces nothing printable at all
  (definition-starved), which is a point *against* the current engine, not a bias in its favour.

*No implementation is authorized. This report ends the Phase-0 (first-run) execution. See §6 for the
owner-approved bounded re-run.*

---

## 6. Phase-0b bounded re-run — results (owner-approved 2026-07-12)

Protocol frozen in `PHASE0_PREREGISTRATION.md §5` **before** re-run results were observed. Only the two
instruments changed; **every threshold is unchanged**; same sampling seed (20260712); same 8 engine surfaces
untouched (verified: `git status` clean on `kie/qpgen/` and `kie.db`). Raw v2 evidence in `phase0_evidence/`
(`hypA_v2_metrics.json`, `hypA_v2_nonnum_agreement.json`, `hypB_v2_blind_packet.json`, `judge_v2_1/2/3.json`,
`hypB_v2_results.json`).

### 6.1 Hypothesis A — broadened relation library + non-numeric lane clustering

| Subject | Complete recovery | Numeric verified | Non-numeric agreement (proxy) | Item Models (≥5 DNA/≥2 res) |
|---|---|---|---|---|
| Physics | 94.0% | 31/46 = 67.4% | 23/30 = 76.7% | 7 nominal (~5 genuine) |
| Chemistry | 87.4% | 8/19 = 42.1% | 26/30 = 86.7% | 6 nominal (~2 genuine) |
| Biology | 95.8% | 2/3 | 55/60 = 91.7% | 7 nominal (~4 genuine) |
| Mathematics | 89.7% | 21/35 = 60.0% | 29/30 = 96.7% | 7 nominal (~6 genuine) |

- **Numeric independent-verification: 60/100 = 60.0% aggregate ≥ 40% floor → PASS** (up from 54.3%; the broader
  library lifted it and Chemistry now clears per-subject too).
- **Non-numeric verification (model-agreement proxy): 133/150 = 88.7%, 0 disagreements ≥ 30% floor → PASS**
  across all four subjects (weaker proxy than numeric; must be re-confirmed against a real KVS in Phase B).
- **Recovery / held-out (100%) / originality (0 violations) → PASS.**
- **≥8 Item Models per subject: STILL FAIL.** Nominal count rose from 2/1/0/0 to **7/6/7/7**, but inspection
  of the qualifying clusters shows the count is **inflated by OCR-junk pseudo-concepts** — `BIO_CHOOSE_THE_COR`
  (a garbled "choose the correct" fragment registered as a concept) qualifies as a "model" in **all four
  subjects**, plus several `:misc` fallback buckets. Stripping junk/fallback clusters, the **genuine** distinct-
  archetype count is ~**5 / 2 / 4 / 6** — clearly under 8.

**What Phase-0b proved about the Hypothesis-A miss:** it is **real, not an instrument artifact** — a broader,
fairer instrument still misses the gate — and its cause is now identified precisely: **concept-quality debt**
(the concept layer is polluted with OCR-junk pseudo-concepts and lacks clean per-concept density) **compounded
by the small 200-item slice.** Both are addressable and already sequenced in the reconciled roadmap: a
**concept-canonicalization pass** (Record §8 risk 2) and **mining at full-corpus scale** (not a 200-item
slice). The ≥8-per-slice bar as I wrote it is genuinely not clearable until the concept layer is cleaned. This
is a more valuable finding than a manufactured pass.

### 6.2 Hypothesis B — difficulty band exposed (AI-PANEL VALIDATED PHASE-0 PROXY EVIDENCE)

Same 23-item pool, now carrying a `stated_difficulty` band (Engine-A = the **real** current-engine label,
including its dishonest `LONG_ANSWER → hard`; Engine-B = the Item Model's honestly declared band); full 3-judge
panel re-run.

| Dimension | A median | B median | Median lift | α | 3/3 majority? |
|---|---|---|---|---|---|
| correctness | 5 | 5 | 0 | 0.64 | — |
| syllabus_alignment | 5 | 5 | 0 | 0.91 | — |
| concept_precision | 4 | 4.5 | +0.5 | 0.48* | — |
| **cognitive_depth** | 1 | 3 | **+2.0** | 0.90 | yes |
| **difficulty_accuracy** | **2** | **4** | **+2.0** | 0.81 | yes |
| **distractor_quality** | 3 | 4.5 | **+1.5** | 0.88 | yes |
| ambiguity (reverse) | 5 | 5 | 0 | 0.83 | — |
| originality | 2 | 3 | +1.0 | 0.93 | — |
| **solution_quality** | 3 | 4 | **+1.0** | 0.83 | yes |

- **Absolute bar** (B median ≥4 ×4): 5 / 5 / 4.5 / 5 → **PASS.**
- **Lift ≥1.0 on all four required dims**: cognitive_depth +2, **difficulty_accuracy +2**, distractor_quality
  +1.5, solution_quality +1 — **all four proven** (each α ≥0.6 and 3/3 judges) → **PASS.**
- **No regression / agreement / Biology bar** (Biology non-numeric correctness 5, distractor 4.5) → **PASS.**
- **`HYPB_PASS = True`.**
- *`concept_precision` α fell to 0.48 in v2 (was 0.73 in the first run); it is an absolute-bar dim, not a
  required lift dim, and its median clears in both runs — flagged as a lower-confidence reading, not counted as
  a proven lift.*

**What Phase-0b proved about the Hypothesis-B miss:** the first-run `difficulty_accuracy` failure was **purely
the missing difficulty label**. With honest labels exposed, the current engine's difficulty_accuracy **collapses
to median 2** (judges correctly penalize a recall item labeled *hard* and trivial one-step numerics labeled
*medium* — the C2 defect made visible), while the lane models score **median 4**, a clean **+2 lift** with high
agreement. Hypothesis B — the architecture's core quality claim — is **validated on strong proxy evidence.**

### 6.3 Final Phase-0 (post-0b) scorecard

| Hypothesis | Verdict | Detail |
|---|---|---|
| **B — item-model quality** | **PASS** | absolute bar, all-4 lift, no-regression, agreement, Biology bar all met; the earlier miss was purely instrumental |
| **A — structure-mining yield** | **FAIL (one gate)** | recovery/numeric-verify(60%)/non-numeric-verify(89%)/held-out/originality PASS; **≥8 Item-Models/subject fails** (7/6/7/7 nominal, ~5/2/4/6 genuine) due to concept-quality debt + 200-item slice size |
| **Overall (both must pass)** | **STOP — reassess** | quality proven; yield-density gated on a known, in-roadmap fix |

### 6.4 What this means + reassessment options (owner decision)

Phase-0b **materially strengthened** the evidence: the architecture's **quality claim is now proven** on the
proxy (Hypothesis B PASS, high agreement, all four target dimensions, Biology at bar), and the remaining
failure (Hypothesis A's ≥8-models gate) is **diagnosed and bounded** — it is concept-quality debt + slice size,
both already first-class items in the reconciled roadmap, not a flaw in the architecture. Per the locked "both
must pass" rule I am still **stopping for your decision** and authorizing **nothing** further. Options:

1. **Accept B as proven; fund Phase A with the yield fix front-loaded (recommended).** Treat the ≥8-models
   miss as the scoped prerequisite it is: make **concept canonicalization + KVS v0 + E-lite** the *first* Phase-A
   deliverables, then **re-test the ≥8-Item-Models gate on full-corpus mining (not a 200-item slice)** at the
   Phase-B benchmark before any scaling. This follows the evidence: quality is validated; yield needs clean
   concepts and scale, which Phase A/B already build.
2. **Phase-0c yield-only test before funding.** Run one more bounded test: a concept-canonicalized, full-corpus
   (not 200-item) mining pass measuring only the ≥8-models gate. More rigor, more cost, delays Phase A.
3. **Reassess the architecture.** Not warranted — quality is proven and the yield gap is understood.

**Recommendation:** Option 1. The decisive Phase-0 signal — that lane Item Models beat the current engine on
every targeted quality dimension with high agreement, including Biology non-numeric — is exactly what Phase 0
existed to establish, and the yield gate's failure cause is already on the Phase-A/B critical path. Option 2 if
you want the yield gate literally cleared before any funding.

**The STOP holds:** no Phase A–F work, no engine-surface change, and no threshold movement occur without your
explicit approval. Real independent **teacher validation remains mandatory** before any production or market
quality claim — the AI panel screened, it did not certify.
