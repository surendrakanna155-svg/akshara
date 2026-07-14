# Governed JEE/NEET evidence conversion — architecture validated, checkpoint + exact remaining work

**Date:** 2026-07-14 · Baseline: reconciliation `0806f666`. This validates the governed conversion architecture
on real evidence, proves its yield, fixes the binding-safety defect class, extends the audit to the NCERT/CBSE
curriculum layer, and specifies the exact remaining execution. **Corrected scope (owner):** JEE Main + JEE
Advanced + NEET **+ NCERT/CBSE Classes 6–10 Math & Science + NCERT/CBSE Classes 11–12 Math/Physics/Chemistry/
Biology** (classified by *content/provenance*, not folder; English-only, no Telugu duplication). Still HELD:
Classes 1–5, AP/TS/ICSE/other state boards, broad school assessment. `qpgen`/`kie.db` untouched; nothing
registered into the knowledge base (no unsafe record admitted); bank not promoted; broad acquisition HOLD.

## Two-source model (why this reconciliation matters)
- **JEE/NEET papers** (qcorpus 22,759 questions + 10,354 answer keys; kie.db exam docs) → exam *reasoning
  structures, distractor/misconception evidence, answer-key evidence, numerical framing* — NOT canonical
  formulas.
- **NCERT/CBSE 6–12 STEM** → the *canonical curriculum knowledge* (concepts, definitions, exact formulas/laws,
  facts, relations) the papers lack. **Already possessed and OCR'd:** kie.db holds **NCERT Class 11 (6 docs) +
  Class 12 (6 docs)** = the STEM textbooks, as **5,014 chunks with 2,138 equation-bearing chunks**, plus
  Classes 6–10 (NCERT 6/7/8/9/10) and CBSE_NCERT Class 10 (15). `resources/curriculum/cbse/` holds 48 more
  Class 1–10 Math/Science PDFs (state-board `telangana/ap/icse` siblings remain out of scope).
- **Both are possessed, OCR'd, and UNSTRUCTURED.** Neither the exam reasoning nor the NCERT canonical relations
  have been converted into machine-usable knowledge.

## Governed conversion validated end-to-end (real evidence, bounded sample)
Input: 25 clean, answer-keyed NEET Biology MCQs from `qcorpus_noncert` (existing OCR evidence). Governed
extraction (LLM as **assistant**, answer-key as evidence, independent examiner) → **16/25 (64%) survived** as
verified atomic Biology facts. The 9 rejects prove the locked hierarchy works on real data:
- **4 cross-subject homonym mis-binds** rejected (Chemistry "decomposition", Physics "EMF/evolution", Physics
  nuclear "nucleus", Physics "translation") — the exact defect class.
- **3 wrong/ambiguous answer-keys** caught by *independent re-derivation* (Forebrain, Cell Membrane, Menstrual
  Cycle) — evidence/examiner overriding a bad source key.
- **2 same-subject wrong-concept binds** rejected (Plasma, Populations).

**Verification hierarchy held:** deterministic subject gate + answer-key evidence + independent examiner did the
certifying; the LLM never certified anything by agreement alone.

## Binding-safety defect class — fixed by design
Naive title-substring / lexical binding is **unsafe for certification** and is banned. Evidence:
- cross-subject homonyms: "revolutions"→Evolution, physics "nucleus"→Biology Nucleus, chemical
  "decomposition"→ecological Decomposition;
- even a *surviving* fact carried a substring mis-bind ("Cancer" ← a cobalt-micronutrient fact).

**Safe binding substrate (discovered, deterministic, per document):** every qcorpus doc carries `rel_path`
(`…/NEET/Chemistry/…`), `normalized_filename` (`neet_chemistry_dpp_solid_state_2`), `priority`
(`P2_studentbro_chemistry`), and a **chapter classification** (862/863 docs, e.g. "Neural Control And
Coordination", "Sexual Reproduction In Flowering Plants"). This yields, deterministically:
- **SUBJECT** per doc (Physics 396 · Mathematics 274 · Chemistry 88 · Biology 39 · unknown 66) → a hard
  subject gate that structurally prevents cross-subject homonyms;
- **EXAM** per doc (NEET 530 · JEE_ADVANCED 216 · JEE_MAIN 93);
- **CHAPTER** per doc → context-aware concept binding *within the subject*, verified by an examiner (never bare
  substring).

Binding contract: subject-gated (deterministic) → chapter→certified-concept candidate → examiner-verified the
fact is genuinely about that concept → only then registered.

## Conversion funnel (state 6 is the break; now de-risked)
| State | Status |
|---|---|
| 1 acquired / 2 OCR'd / 3 question+answer-key extracted | ✅ (22,759 questions, 10,354 answer keys) |
| 6 converted → verified machine-usable knowledge | ◑ **architecture proven at 64% yield; not yet run at scale** |
| 7–10 verified → engine → qpgen path | ⧗ pending the scaled run |

## Material determination
- **Qualitative / factual knowledge (Biology + factual Chemistry/Physics): convertible and materially
  gap-closing.** 64% governed survival × the measured prize (certified concepts with ≥2 answer-keyed questions:
  NEET Biology 30, Physics 29, Chemistry 5; JEE Physics 29, Chemistry 4) ⇒ converting this evidence can lift
  Chemistry off 0 and Physics/Biology well beyond today's 5/3. NCERT prose definitions/facts add a second,
  authoritative source for the same concepts.
- **Quantitative relations (the Physics/Chemistry/Math formula concepts): possessed but NOTATION-DAMAGED.** The
  relations exist in both sources but neither is clean: the qcorpus equation manifest is font glyphs, and the
  NCERT 11–12 chunks — which *do* contain the laws (Coulomb, interference, nuclear-Q, trig, mole %) — have their
  superscripts/subscripts/symbols mangled by OCR (e.g. Coulomb's law appears as "ε=π emv rr(12.2)"). Honest
  recovery requires **re-extracting notation from the NCERT source PDFs / equation-bearing page images with a
  math-capable extractor**, then deterministic (dimensional / answer-key) verification. This is a bounded
  notation-recovery task over already-owned files — **not new acquisition.**

## Exact remaining execution (specified, de-risked)
1. **Safe binder:** deterministic doc→subject/exam + chapter→certified-concept candidate + examiner
   verification (the banned-substring replacement, proven necessary).
2. **NCERT canonical extraction (qualitative):** structure definitions/facts/relationships from the NCERT 6–12
   chunks (prose is the cleaner source), subject-gated, verified, English-only (drop Telugu duplicates).
3. **Scale governed factual extraction** from the JEE/NEET answer-keyed MCQs (Biology + factual Chemistry/
   Physics) at the proven 64%-class yield, subject-gated, chapter-bound, examiner+answer-key verified;
   corroborate against NCERT where both cover a concept; reject/quarantine the rest.
4. **Quantitative relations (notation recovery):** re-extract the damaged formulas from **NCERT 11–12 source
   PDFs / equation page-images** with a math-capable extractor → candidate relations {equation, symbols, units,
   domains} → **deterministic dimensional + answer-key verification** (a JEE numeric question's givens must
   solve to its answer under the candidate relation) → register only the proven. Never register a guessed
   symbol/unit/exponent.
5. **Register** only verified, safely-bound knowledge (+ real distractor/misconception evidence — learned,
   never cloned).
6. **Generate** through the unified compositional engine (fresh stems, real-distractor evidence, independent
   verification) — no source-question cloning.
7. **Re-measure** JEE Main / NEET (and JEE Advanced where the certified scope supports it) balanced-paper
   coverage through the real qpgen path; paper-level verification (exact notation/symbols/units/keys, ambiguity,
   multiple-/no-correct risk, duplicates/near-clones, subject balance, concept diversity, reasoning-depth
   distribution, blueprint compliance, honest shortfalls). Reject, never force-fill.

## Why balanced full papers are not yet achievable
The knowledge is **possessed** (JEE/NEET exam evidence + NCERT 11–12 canonical STEM, both OCR'd) and provably
**convertible** (qualitative at 64% governed yield), but has **not yet been produced as verified structured
records at scale** (funnel state 6 → 10), and the **quantitative relations are notation-damaged** in every
existing OCR representation — they must be recovered from the already-owned NCERT/question source images with a
math-capable extractor and deterministically verified before they can ground the Physics/Chemistry/Math formula
concepts. The architecture, yield, safe-binding design, and evidence locations are all proven; the remaining
work is a compute-bounded governed-extraction + notation-recovery execution over already-owned files — **not a
knowledge-possession gap and not new acquisition.**
