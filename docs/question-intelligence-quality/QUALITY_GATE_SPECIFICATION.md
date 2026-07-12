# Quality Gate Specification

**Date:** 2026-07-11 · **Status:** SPEC (proposal — not implemented)
**Principle:** Generation and approval are independent. A question is accepted because it **survives
adversarial verification**, never because a model reported high confidence.
**Extends:** the existing `validate.py` scaffold (fail-closed, reject-with-reasons) — additively. Existing
constraint gates become GATE 1-3/6; the educational gates below are new.

---

## 1. What exists vs. what is missing

Today `validate.py` enforces 14 constraint checks (syllabus, subject, type, marks, 4-distinct-options,
answer-in-options, exact-key dedup, OCR-artifact-in-stem). **Zero** of them measure an educational
property. "solver_verified" means self-consistent-by-construction, not independently solved. The
assertion-reason always-answer-(a) flaw passes cleanly. Glued-word garbage in the *answer* passes because
the artifact check only looks at the *stem*.

The gate ladder below adds the missing educational verification. Each gate declares: **type**
(deterministic / independent-model / hybrid), **fail action**, and **reuse** of existing code.

---

## 2. The 15-gate ladder

| # | Gate | Type | Fails when | Reuse |
|---|---|---|---|---|
| 1 | Schema integrity | deterministic | missing/blank required field; malformed option set | `validate._objective_violations` |
| 2 | Curriculum/syllabus boundary | deterministic | concept out of resolved scope | `validate.py:34-35` |
| 3 | Concept boundary | deterministic | wrong subject / unclean concept | `validate.py:36-39` |
| 4 | **Independent blind solve** | independent | a second, independent solver's answer ≠ the key | NEW |
| 5 | **Answer correctness** | deterministic/CAS | numeric/dimensional answer wrong; units inconsistent | NEW (+ relation library) |
| 6 | Option uniqueness | deterministic | options not all distinct (incl. numeric-equivalence 10 vs 10.0) | extend `validate.py:87-88` |
| 7 | **Distractor plausibility** | hybrid | a distractor is trivially eliminable, off-magnitude, or not a real misconception | NEW |
| 8 | **Ambiguity** | independent | ≥2 options defensibly correct; stem under-specified | NEW |
| 9 | **Difficulty-driver verification** | deterministic | measured drivers fall outside the item model's declared band | NEW |
| 10 | **Cognitive/Bloom verification** | hybrid | operations actually required ≠ claimed chain/Bloom | NEW |
| 11 | **Visual consistency** | deterministic | visual required but missing/inconsistent with stem/answer | NEW (VISUAL §4) |
| 12 | **Formula/unit/dimensional** | deterministic/CAS | dimensional mismatch; unit error; impossible magnitude | NEW |
| 13 | **Originality / similarity** | deterministic | too similar to a protected source item or an already-issued item | NEW (embeddings + n-gram) |
| 14 | **Item-writing-flaw rubric** | deterministic | position bias, longest-correct, grammatical cue, all/none-of-above, "always/never" | NEW |
| 15 | **Paper-level diversity** | deterministic | archetype/cognitive/difficulty/context over-concentration across the paper | NEW (PAPER intelligence) |

### 2.1 GATE 4 — Independent blind solve (the keystone)
A **separate solver from the one that generated the item** answers the stem **without seeing the key**:
- numeric/structural items → the deterministic relation library / CAS, implemented independently of the
  Item Model's `answer_function` (a genuinely second path, not the same expression re-run);
- verbal/conceptual items → an independent model pass (Tier-2), prompted only with the stem+options.

Disagreement between the generated key and the blind solve ⇒ **REJECT**. This is D7 Layer 4 made real. It
is the gate that turns "solver_verified" from a self-consistency label into an actual verification.

### 2.2 GATE 7 — Distractor plausibility
Each distractor must (a) carry a `misconception_type` (from the Item Model's certified generators), (b)
be within a defensible magnitude/type of the correct answer (not wildly off), and (c) not be eliminable by
a surface cue. A distractor that is pure arithmetic noise fails. For MCQs with response data, low
distractor-selection-frequency (a "dead" option) is flagged (Phase 2).

### 2.3 GATE 8 — Ambiguity
An independent solver enumerates defensible answers. If more than one option is defensibly correct, or the
stem lacks information to determine a unique answer, ⇒ REJECT. Catches the "two options defensibly
correct" failure the mission calls out.

### 2.4 GATE 9 — Difficulty-driver verification
Recompute the difficulty drivers (`QUESTION_DNA_SPEC` §7) on the **generated instance** and confirm they
fall in the Item Model's declared band. A "hard" item whose measured drivers are easy ⇒ REJECT (or
re-band). This is what finally makes the difficulty label trustworthy.

### 2.5 GATE 10 — Cognitive/Bloom verification
Confirm the operations actually required by the generated instance match the claimed cognitive chain; the
Bloom roll-up is derived from that chain, not stamped. Resolves the current `pool.py:117` contradiction
(long-answer stamped `analyze` while the verb is `understand`).

### 2.6 GATE 13 — Originality / similarity
Two checks: (a) **source distance** — the generated item must not be a shallow paraphrase of any protected
L2 source item (n-gram + embedding similarity below a threshold); (b) **self distance** — not a
near-duplicate of an already-issued item (exposure). Replaces the current exact `(concept,type)` key dedup.

### 2.7 GATE 14 — Item-writing-flaw rubric
Deterministic rubric of classic flaws: correct-answer position bias (fixes the AR always-(a) flaw —
GATE 14 would reject the current AR family until keys are randomized), longest-option-usually-correct,
grammatical agreement cues between stem and only the correct option, "all/none of the above", absolute
qualifiers ("always/never") in distractors, overlapping options, negatively-worded stems without emphasis.

---

## 3. Adversarial verification (how gates 4/7/8/10 are run for confidence)

For items where a single check is not conclusive, run **independent verifiers prompted to refute**, and
reject on a majority-refute. Diversity of lens beats redundancy: for a numeric item, verify by
(re-solve), (unit/dimensional), (does-a-distractor-also-solve); for a conceptual item, verify by
(correctness), (ambiguity), (syllabus-fit). This mirrors the platform's D7 "independent blind solve"
discipline and is run **offline at certification**, not at runtime.

---

## 4. Rejection is an asset

Every rejected item is preserved with its gate and reason (the current `validation` list already does
this per slot). Rejections drive Item Model improvement: a family whose instances repeatedly fail GATE 7
has weak distractor generators; one failing GATE 9 has a wrong difficulty band. Rejection statistics are a
first-class engine-health signal, not waste.

---

## 5. Where gates run

- **Certification time (offline):** all 15 gates on sampled instances of a candidate Item Model. A model
  is certified only if its sampled instances pass. Expensive gates (independent-model 4/8/10) run here.
- **Runtime (deterministic, AI-free, I9):** the cheap deterministic gates (1-3, 5-6, 9, 11-14) re-run on
  every instance; the independent-model gates are **not** re-run at runtime (the family already earned
  trust). This keeps runtime zero-LLM while preserving per-instance safety.

---

## 6. Hard-reject rules (from the mission, non-negotiable)

- generated answer ≠ independent solve ⇒ REJECT.
- two options defensibly correct ⇒ REJECT.
- visual required but missing/inconsistent ⇒ REJECT.
- shallow paraphrase of a protected/reference item ⇒ REJECT.
- No item is accepted on an LLM's self-reported confidence score.

---

## 7. Acceptance criteria

- The blind-solve gate (4) demonstrably catches injected wrong-key items (test with deliberately corrupted
  keys → 100% caught).
- The item-writing-flaw gate (14) rejects the current fixed-position AR family until keys are randomized.
- Distractor plausibility (7) rejects arithmetic-noise distractors present in today's output.
- Every gate is independent of generation; disabling generation-side "confidence" changes nothing.
- Rejections are preserved with reasons and feed a per-Item-Model health report.

---

## Reconciliation Amendment (2026-07-12, post-Fable-5)

Governed by `OPUS_FABLE_RECONCILIATION_RECORD.md`. The 15-gate ladder is kept **as taxonomy**; in
**implementation** the numeric-correctness passes (4/5/12) share one relation-library pass and the
structure-recompute passes (9/10) share one pass — net protection, not gate count, is the measure. **Gates
added or hardened:**

- **GATE 4 input is the RENDERED stem** (numbers/units re-parsed from the emitted text), not the stored
  parameter set — otherwise blind-solve verifies the contract, not the question students see. The blind
  solver may not import the Item Model's `answer_function`.
- **Independent verification is per-lane** (Record §2): numeric → relation-match-by-solver; conceptual →
  KVS entailment (`assertion_base`/`taxonomy_store`/`sequence_store`/`structure_function_map`/
  `comparison_matrix`) **plus** independent Tier-2 agreement given only stem+options; disagreement ⇒ reject
  or quarantine. Correctness is **never** taken from the generator.
- **NEW — Concept-binding integrity:** a template/item-model instance whose bound concept is not in the
  model's declared `concept_scope[]` is rejected; the template grounding exemption (`validate.py`) is
  removed once scope binding lands (Record F5).
- **NEW — Family-equivalence deduplication:** duplicate/near-duplicate concepts and equivalent Item Models
  collapse to one **exposure identity**; combined with **within-paper rendered-stem structural dedup**
  (GATE 15), this fixes the `PHY_OHM_S_LAW`/`CHE_OHMS_LAW` twice-in-one-paper defect (Record F4). Paper
  dedup keys on rendered-stem structure, not `(concept_code, question_type)`.
- **NEW — Realization fidelity:** every contract parameter appears once, with its unit, in the rendered
  stem; no extra numeric tokens; the answer string is absent from the stem. Closes the Tier-1-rephrase
  drift channel.
- **GATE 14 extended — AR semantic key-constancy:** reject an Assertion-Reason family whose correct
  relation class is constant across instances (fixes the always-"(a)" flaw at the semantic level, not just
  position). Add paper-level key-position balance.
- **NEW — Answer/solution artifact gate:** OCR/extraction artifacts in the answer key or solution (not only
  the stem) are rejected — closes the stem-only asymmetry that let glued-word keys ship.
- **NEW — Registration-integrity gate:** family registration verifies unique template_id, unique generator
  object, no unintended binding overlap, and no bare single-word binding for new families (Record F6).
- **GATE 13 gains a structural level:** a generated numeric item must not reproduce an observed source
  parameter-tuple for its relation (catches structure-plus-numbers copies that lexical/semantic checks miss).
