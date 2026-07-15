# Governed conversion batch 2 + quantitative notation-recovery safety finding

**Date:** 2026-07-15 · Continues `c2dc071d` (batch 1 + owner decision A). Autonomous continuation of the queued
scaled-conversion batches and the quantitative notation-recovery workstream. `qpgen` internals frozen; `kie.db`
untouched; bank not promoted; Classes 1–5 / state boards / broad acquisition remain HELD.

## A. Quantitative notation recovery — DETERMINISTIC ARITHMETIC INDUCTION IS UNSAFE (measured, not registered)

The queued lane was the **3,606 numeric answer-keyed candidates**. The available deterministic method is
answer-key relation induction: parse the stem's numeric givens, and ask whether any relation in the library
(`kie.qie.relations`, ~80 relations) reproduces the stated answer. **Measured on real evidence:**

| step | Physics | Chemistry |
|---|---|---|
| numeric candidates (subject-gated) | 3,080 | 414 |
| a library relation reproduces the answer | **1,044** | 97 |
| …AND the relation's domain matches the item's chapter (semantic gate) | **101** | 2 |
| …AND corroborated by ≥2 independent docs | **0** | **0** |

**The raw matches are ~90% false positives.** `V=IR` is just *a×b*, so it "verifies" any item where two givens
multiply to the answer — it matched items in **Waves, Calorimetry, Motion in a Straight Line, Fluid Mechanics**.
`n=m/M` is just *a÷b* and matched unrelated chapters. Registering these would assert **wrong physics**
("V=IR governs Waves") into the knowledge base.

**Root cause (the honest one):** a relation name is meaningless without the **symbol/unit binding** of the
givens — knowing that *5* is a resistance in Ω and *2* a current in A. That binding is precisely what the OCR
destroyed. Arithmetic coincidence cannot be distinguished from physical law without it.

**Decision (gate not weakened): nothing from this lane was registered.** Wrong knowledge is worse than missing
knowledge. After the semantic + corroboration safety gates, **zero** numeric relations were admissible — so
there is no safe yield to take, not merely a small one.

**This is a genuine capability blocker, not a knowledge-possession gap.** Safe quantitative conversion requires
recovering symbols/units/exponents from the **source page-images** with a math-capable extractor (LaTeX/math
OCR), then dimensional + answer-key verification. No such extractor is available in this environment; rendering
and math-OCR'ing the source PDFs is a new capability that must be provisioned. **Owner decision required** (see
below). The `4_recovered_notation` lifecycle state in `EVIDENCE_REGISTRY` remains correctly **unreached**.

## B. Governed conversion — batch 2 (qualitative, the safe lane)

Continued the proven pipeline on the queued structured/causal candidates (Biology + Physics priority).

- **58 examined → 51 verified (87.9% survival) · 7 rejected.** Higher yield than batch 1 (75.9%) because these
  Biology/Physics items carry less OCR damage. Rejects: an odd-one-out meta-question, ambiguous keys (jaundice
  system; companion-cell functions a *and* d both true), an imprecise key (catalytic efficiency is kcat/Km, not
  Km), OCR-garbled sponge options, a debatable "most accurate fossil dating" key, and one bad concept binding
  (chapter hint `Test` = filename artifact).
- **Cumulative admitted knowledge: 92 verified facts / 20 rejected** —
  `kvs_structure_function` 14 · `kvs_sequence` 17 · `kvs_comparison` 8 · governed `kvs_assertion` 53 ·
  **`distractor_dna` 274**. Subjects: Biology 54 · Chemistry 27 · Physics 11.

## C. Boundary regression found and fixed (decision A hardening)

Injecting governed chapters as in-scope concepts initially produced **UNCLEAN_CONCEPT boundary breaches**
(`boundary_ok=False`, 3 rejected slots): filename-derived chapter titles are verbose/repetitive
("Adv Current Electricity Current Current Density Drift Velocity…") and failed qpgen's concept sanitizer
(`MAX_WORDS=5`), as did pronoun-laden real chapters ("Excretory Products And Their Elimination").

**Fix:** `qp_bridge._clean_title` (drop lead noise, dedupe OCR-repeated words, drop trip pronouns, cap at 5
words) + governed concepts must pass **the same `sanitize.is_clean_concept` gate as every other in-scope
concept**. A chapter that cannot be cleaned is skipped — its items become an honest shortfall, never a boundary
breach. Regression-tested.

## D. Re-measured paper balance (real QIE → qpgen path, seed 7)

| exam | baseline | batch 1 | +decision A | batch 2 + fix | **+assertion gen** | Chemistry | boundary |
|---|---|---|---|---|---|---|---|
| NEET | 5 | 11 | 16 | 21 | **26** (Bio 17 · Phy 6 · Chem 3) | 0 → **3** | ok, 0 rejected |
| JEE Main | — | 14 | 16 | 17 | **17** (Phy 6 · Math 8 · Chem 3) | 0 → **3** | ok, 0 rejected |
| JEE Advanced | — | — | — | 17 | **17** (Phy 6 · Math 8 · Chem 3) | 0 → **3** | ok, 0 rejected |

**NEET: 5 → 26 filled** across 26 distinct concepts (16 from governed-KVS), boundary clean, 0 forced fills.
565 tests green.

## E. Assertion generation with AUTHENTIC distractors (built — closes the admission→generation gap)

The assertions were admitted but not generatable. Solved by authoring a fresh stem from the verified fact and
reusing **the source item's REAL wrong options** as distractors (authentic exam misconception evidence — the
owner's "use authentic exam evidence for distractor evidence, not cloning"). This is only sound when the source
asked "what is X?", so `kvs_compose._assert_usable` gates it:
- answer must be a clean short entity — **matching-pair/list answers rejected** ("Aschelminthes : Ancylostoma,
  Enterobius, Tubifex" produced an incoherent stem);
- **no giveaway** — no significant answer word may appear in the authored stem (rejected "Ethyl alcohol- Yeast"
  where the stem said *yeast*);
- ≥3 distinct real distractors ≠ answer.

10 of 52 assertions pass the gate today and generate cleanly, e.g.:
> *Which of the following is the TCA-cycle enzyme located in the inner mitochondrial membrane?*
> (isocitrate dehydrogenase · malate dehydrogenase · **succinate dehydrogenase** · lactate dehydrogenase)

> *Which of the following are not a normal constituent of the glomerular filtrate?*
> (**Red blood cells** · Sodium ion · Urea · Glucose)

Fresh stems, real exam distractors, Tier-1 deterministic re-derivation against the KVS fact. Gate regression-tested.

## F. Exact remaining gap
1. **Scale.** ~1,660 clean candidates remain queued (mostly `CONCEPTUAL_GENERIC`), at the proven 76–88% yield.
2. **Assertion direction.** 42 of 52 assertions still don't generate — the source asked in the inverse direction
   (term→definition), so the real distractors aren't parallel to an authored stem. Re-authoring the structured
   slots in the source's direction at examiner time would unlock most of these (cheap fix, next batch).
3. **JEE Main / Advanced are numeric-bound.** Both sit at 17 filled and barely move on qualitative facts: their
   papers are dominated by Physics/Maths numerics, which is exactly the blocked notation lane (§A).

## Owner decision required — quantitative notation lane
Deterministic arithmetic induction is proven unsafe and yields **zero** admissible relations. To convert the
3,606 numeric candidates (and the notation-damaged NCERT 11–12 formula chunks) we must **provision a
math-capable extractor** (render source page-images → LaTeX/math OCR → symbol/unit binding → dimensional +
answer-key verification). Options: (A) provision a math-OCR capability/tool for the recovery pipeline;
(B) curate the ~60–90 canonical named-law relations directly from NCERT (human/curated, like `chem_data.py`),
skipping image recovery; (C) leave the numeric lane closed and continue qualitative-only. **Recommend (B) then
(A)** — (B) is fast, safe and unlocks the Physics/Chemistry numeric concepts the papers most need.
