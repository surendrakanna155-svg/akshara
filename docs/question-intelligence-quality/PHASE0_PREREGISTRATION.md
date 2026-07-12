# Phase-0 Pre-Registration — locked BEFORE any result is observed

**Date:** 2026-07-12 · **Status:** PRE-REGISTERED. Written and frozen **before** the mining harness was run
and **before** any judge score was generated. No threshold in this file may be weakened, reinterpreted, or
moved after results are seen (owner instruction, 2026-07-12).
**Governs:** the Phase-0 kill test defined in `OPUS_FABLE_RECONCILIATION_RECORD.md` §7.
**Scope guard:** Phase 0 only. No Phase A–F work. The 8 frozen `kie/qpgen/` engine surfaces are **not
touched** — all Phase-0 code is standalone/throwaway, reads the DB read-only, writes no schema, registers no
family into the engine.

---

## 1. Owner-approved benchmark amendment (verbatim intent)

Independent human teacher reviewers are **not currently available**. For **Hypothesis B only**, the teacher-
review requirement is replaced by an **AI-PANEL proxy**:

- **Three independent strong judge model passes.** Each judge runs in an isolated context (no shared state),
  is a strong model, and scores independently.
- **Blind + anonymized.** CURRENT-ENGINE (Engine A) and QUESTION-DNA+ITEM-MODEL (Engine B) outputs are
  shuffled, stripped of any architecture/source label, and given opaque IDs. Judges are **not told** which
  architecture produced any item, and are **not told the hypothesis under test**.
- **Same rubric, same bars.** Judges score the existing benchmark dimensions; the **same absolute quality
  bars and the same ≥1.0-point quality-lift** from Record §7 apply unchanged.
- **Raw scores + rationale preserved** for every judge × item × dimension.
- **Majority agreement required**; inter-judge agreement reported. **Disputed or unstable results are NOT
  counted as proven improvement.**
- **Labeling (mandatory):** this evidence is **"AI-PANEL VALIDATED PHASE-0 PROXY EVIDENCE."** It is **not**
  teacher validation and **not** expert validation and must never be described as such.
- **Real independent teacher validation remains MANDATORY** before any production-scale quality claim or
  market claim. The AI panel is a pre-teacher screening proxy that can *kill* the architecture cheaply; it
  cannot *certify* it for production.

**Honest denominator on judge independence:** the three passes are three independent runs of strong Claude
models (separate contexts), not three different vendors. This is a real limit of the proxy and is reported as
such; it does not substitute for cross-vendor or human diversity.

---

## 2. Locked acceptance thresholds (unchanged from Record §7)

### Hypothesis A — Structure-mining yield (measured, deterministic)
Representative discovery slice, **≥200 source items per subject** across {Physics numeric, Chemistry
numeric+conceptual, Mathematics, **Biology non-numeric**}. Report every quantity honestly with its
denominator. **Pass gates:**
- Complete-item recovery ≥ **60%** for numeric subjects; ≥ **45%** for Biology.
- **Independent-verification success ≥ 40%** of recovered numeric items (relation-match-by-solver reproduces
  the stated key) **AND ≥ 30%** of recovered Biology items (independent check agrees the key is correct).
  **If numeric verification < ~40% ⇒ FAIL (mining economics collapse).**
- ≥ **8 distinct-lane/archetype Item Models per subject**, each distilled from ≥ **K=5** distinct DNA drawn
  from ≥ **2** distinct source resources.
- Held-out generalization: ≥ **70%** of items generated for held-out concepts pass all deterministic gates.
- Originality: **0** generated items within the similarity threshold (structural parameter-tuple + lexical
  n-gram + semantic) of any source item.

**Phase-0 honesty note on Biology verification:** the deterministic Knowledge Verification Substrate (KVS) is
a Phase-A/B deliverable and does **not** exist yet. Biology "independent verification" in Phase-0 is therefore
measured by **independent-model agreement only** (the Tier-2 half of the eventual KVS+model check), which is a
**weaker** signal than the numeric relation-match. This is reported explicitly; a Biology pass on model-
agreement alone is provisional and must be re-confirmed against a real KVS in Phase B.

### Hypothesis B — Item-model quality spike (AI-panel proxy)
Hand-build **6–10 Item Models** on the final (lane-based) schema spanning ≥4 lanes, mandatorily including
**≥2 Biology non-numeric** (CONCEPTUAL_CAUSAL / CLASSIFICATION_TAXONOMIC / STRUCTURE_FUNCTION), **≥1
ASSERTION_RELATION** (truth-table varied), **≥1 numeric multi-step**, **≥1 MISCONCEPTION_DIAGNOSTIC**.
Generate Engine-B instances; generate matched Engine-A items for the same concepts by running the current
`templates`/definition-match path read-only; machine-gate correctness (below); anonymize + shuffle;
AI-panel scores. **Pass gates (all must hold):**
- **Absolute bar:** Engine-B **median ≥ 4/5** on correctness, syllabus_alignment, concept_precision,
  ambiguity (ambiguity reverse-scored so 5 = unambiguous).
- **Lift:** Engine-B median **exceeds Engine-A by ≥ 1.0 rubric point** on cognitive_depth,
  distractor_quality, difficulty_accuracy, and solution_quality.
- **No regression:** Engine-B ≥ Engine-A on correctness, syllabus_alignment, ambiguity.
- **Agreement:** inter-judge Krippendorff's α ≥ **0.6** on the gated dimensions (else re-anchor; low-agreement
  dimensions are **not** counted as proven).
- **Biology-specific:** Biology non-numeric items independently reach the absolute bar (correctness ≥ 4 AND
  distractor_quality ≥ 4). A pass elsewhere with Biology failing is a **FAIL**.
- **Correctness machine-gated before the panel** (independent solver / KVS-proxy for numeric; independent-
  model check for non-numeric). Panels score perceived correctness too, but the machine gate is authoritative
  and reported alongside.

### Kill rule
If Hypothesis A misses the independent-verification floor **or** Hypothesis B misses the absolute bar, the
lift test, the agreement floor, or the Biology-specific bar → **STOP; reassess the architecture before any
Phase-A schema or engine work is funded.** Both must pass to proceed. Passing produces an evidence report and
a STOP for owner approval — it authorizes nothing further by itself.

---

## 3. AI-panel protocol (Hypothesis B)

1. Pool all Engine-A + Engine-B items; strip labels; assign opaque IDs; deterministic shuffle (seed fixed
   here = 20260712).
2. Three judge passes, each isolated, each scores **every** item on: correctness, syllabus_alignment,
   concept_precision, cognitive_depth, difficulty_accuracy, distractor_quality, ambiguity (reverse-scored),
   originality, solution_quality — each 1–5 with a one-line rationale and, for MCQ, the option the judge
   believes correct (for an independent correctness cross-check).
3. Judges are given only: item text, options, stated answer/solution, subject, intended class/profile. They
   are not told the engine, the hypothesis, or that a comparison exists.
4. Preserve raw JSON (judge × item × dimension + rationale + chosen option) under
   `docs/question-intelligence-quality/phase0_evidence/`.
5. Aggregate: per-engine median per dimension (across items × judges); lift = Engine-B median − Engine-A
   median per dimension; inter-judge agreement per dimension (Krippendorff α, ordinal); majority-direction
   check per dimension (≥2/3 judges agree on the sign of the A→B difference). Small-N significance reported
   via a paired sign/Wilcoxon check where N permits; where N is too small for significance, that is stated
   and the result is treated as **indicative, not proven**.
6. A dimension counts as "proven improvement" only if the lift bar is met **and** α ≥ 0.6 **and** the
   majority-direction check holds. Otherwise it is "unstable/disputed" and does not count.

---

## 4. Analysis + reporting rules
- Report exact measured numbers with denominators; no rounding away of failures.
- Rejected structures are counted with reasons (rejection is data).
- If a gate fails, say so plainly and STOP; do not re-scope the slice or re-run to hunt a pass.
- The evidence report is labeled **AI-PANEL VALIDATED PHASE-0 PROXY EVIDENCE** for Hypothesis B.
- Nothing here authorizes Phases A–F or any engine change.

*Frozen 2026-07-12 prior to execution. Any deviation is a protocol violation and must be disclosed in the
evidence report.*

---

## 5. Phase-0b addendum — bounded re-run (owner-approved 2026-07-12, recorded BEFORE re-run results)

Owner approved a **bounded** re-run after the first run cleared most gates but missed one gate per hypothesis,
both attributable to the throwaway instrument. Phase-0b changes **only the two instruments**; **every threshold
in §2 is unchanged.** No Phase A–F work; no engine-surface change; same random seed (20260712) for sampling so
the instrument change is isolated.

**Fix A (Hypothesis A — the ≥8-Item-Models-per-subject gate was under-measured):**
1. **Broaden the relation library** from ~30 to a comprehensive physics/chemistry/mathematics set (~70+
   relations with arity/units) so numeric verification and numeric-model discovery reflect real capability, not
   a stub. The library is authored from standard curriculum relations, **not** reverse-engineered from the
   sampled items.
2. **Add non-numeric lane clustering** so the model count is measured across **all** lanes, not only numeric:
   each recovered non-numeric item is classified into a lane (ASSERTION_RELATION, CLASSIFICATION_TAXONOMIC,
   CONCEPTUAL_CAUSAL, COMPARATIVE, STRUCTURE_FUNCTION, PROCESS_SEQUENCE, DATA/MATCH) by structural signature and
   mapped to a concept; a cluster qualifies as an Item Model at the **same** bar (≥5 DNA from ≥2 resources). A
   bounded independent model-agreement pass over Physics/Chemistry/Mathematics non-numeric samples confirms the
   non-numeric evidence is real (Biology already at 55/60).

**Fix B (Hypothesis B — `difficulty_accuracy` was unmeasurable):**
3. **Expose an intended difficulty band per item** in the blind packet for **both** engines. Engine-A uses the
   **real current-engine label** (the `estimate_difficulty` heuristic for numeric/AR; the hard-coded
   `LONG_ANSWER → HARD` for the descriptive item — i.e. the engine's actual, sometimes-dishonest label).
   Engine-B uses each Item Model's **honestly declared** band. Judges then score `difficulty_accuracy` = does
   felt difficulty match the **stated** band. The full 3-judge panel is re-run on the difficulty-labeled packet
   (all dimensions re-scored); results are reported transparently even if a previously-passing dimension moves.

**Discipline:** Phase-0b is a corrected measurement, not a pass hunt. If a gate still fails, it is reported as a
fail and the STOP stands. Thresholds are not touched. Judge independence remains 3 strong-Claude passes (proxy,
not teachers); the AI-PANEL label and mandatory-teacher-validation rule are unchanged.
