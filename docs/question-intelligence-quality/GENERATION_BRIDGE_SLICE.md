# Certified-Model → Generation Bridge — narrowest vertical slice (NEET Biology factual)

**Date:** 2026-07-13 · **Status:** DONE (internal validation only — **NOT** the 100–300 pilot). Closes the
primary verified blocker from the readiness check: certified QIE Item Models are now connected to actual
new-question generation, for **NEET Biology factual_single_best_answer only**. Golden-tests-first. No corpus,
no Certified-Bank change, no architecture redesign, no board/difficulty/visual work. **486 tests green.**
Evidence: `phase0_evidence/gen_bio_neet/`.

## Bridge implemented — `qie/generate.py`

Pipeline: **select certified models → build verified evidence → author new stems → gate → independent
verification → PASS/REJECT/QUARANTINE with full provenance.** It never fabricates: answers and distractors are
only ever *verified fact tokens*, and the stem is an *authored frame*, never source-question wording.

| Requirement | How it is met |
|---|---|
| 1. Select only genuinely certified Biology×NEET models | `select_certified_concepts` filters `certifiable ∧ Biology ∧ NEET ∧ factual_single_best_answer ∧ BIO_` — **19 concepts reachable**. |
| 2. Preserve subject/concept/Class-6–12/foundation/NEET/archetype boundaries | Generation is scoped to a certified concept + NEET profile + factual archetype; answer/distractor tokens are bound to their concept; the concept carries its kie.db grade/boundary metadata. |
| 3. New stems, no source-wording copying | Authored `FRAMES` ("Which one of the following is most closely associated with {topic}?"); the near-copy gate rejects any item whose option-set equals a source MCQ. **15/15 distinct authored stems, 0 near-copies.** |
| 4. Answer from verified evidence | Correct = an *exclusive* verified entity token of the concept; `correct_fact_key = fact_key(concept, answer)`. |
| 5. Distractors from governed evidence | Distractors = verified entity tokens of **other** certified concepts (never of this concept); each carries its own `distractor_fact_key`. *(Plausibility is minimal — see blockers.)* |
| 6. Automatic independent correctness verification | Pluggable `verify_fn`; this slice used the **governed 2-judge Tier-2 lane** (verifier + adversarial refuter, isolated) on every item. |
| 7. Reject / quarantine bad items | Gates: `UNSUPPORTED_ANSWER`, `TAUTOLOGY`, `DISTRACTOR_IN_CONCEPT`, `DUPLICATE_OPTION`, `NEAR_COPY_OF_SOURCE`, `DUPLICATE_GENERATED`; verification → `ANSWER_DISAGREEMENT` (REJECT) / `UNVERIFIABLE` (QUARANTINE). |
| 8. Full provenance | Each item: `gen_id → item_model_id → concept → correct_fact_key + distractor_fact_keys → verification{verdict}`. |

## Internal validation sample (measured — not the pilot)

- **Certified models reachable:** 19 Biology×NEET factual concepts.
- **Distractor mechanism:** governed cross-concept verified entity tokens (bounded to the 180-token verified
  inventory); *plausibility not yet tuned*.
- **Questions attempted:** **15** (1 per concept, gated).
- **PASS / REJECT / QUARANTINE:** **11 / 4 / 0**.
- **Answer correctness (independently verified, both judges agree):** **11/15 = 73%.** The 4 REJECTs were
  caught by **both** independent judges — the safety net working exactly as intended:
  Proteins→"Phosphodiester bonds" (nucleic-acid bond, not protein), Molecular-Basis→"Repressor protein"
  (not uniquely best vs histones), Mitochondria→"Mitochondria" (tautology — now also caught deterministically),
  Plasma→"Plasma membrane" (blood-plasma ≠ cell membrane).
- **Originality:** 15 distinct authored-frame stems; **0 near-copies** of any source MCQ; answers/distractors
  are short verified fact tokens (entities), not copied source stems.

**The slice is proven:** genuinely new, boundary-scoped, verified-answer questions are generated from certified
models, and semantically-wrong candidates are automatically rejected rather than shipped.

## Exact blocker before the 100–300 pilot

1. **Automated in-loop verification (safety-critical).** `run()` accepts a `verify_fn`; in this slice the
   Tier-2 judges were dispatched manually. The pilot needs `verify_fn` wired to an **automatic** governed
   Tier-2 call so every generated item is verified in-loop and only PASS ships. This is a wiring task, not a
   redesign — it is the one non-negotiable blocker.
2. **Bounded validated distractor-plausibility mechanism (quality).** Distractors are currently random
   cross-concept tokens (e.g. "cobalt", "bioinformatics"), which makes the key too easy and depresses
   difficulty realism. A plausibility rule (same organ-system family / same entity type / near difficulty) is
   needed before scaling for quality — correctness is already gated, but difficulty is not.

*(Secondary refinements, not blockers: a broader authored-frame bank for stem diversity; concept-title
disambiguation for a handful of ambiguous titles like "Plasma".)*

**STOP for owner review.** Do not start the 100–300 pilot. Once blocker 1 (automatic in-loop verification) is
wired and blocker 2 (distractor plausibility) is in place, the same path expands to NEET Physics/Chemistry and
JEE Physics/Chemistry/Mathematics, closing only measured blockers, before controlled 100–300 batches.
