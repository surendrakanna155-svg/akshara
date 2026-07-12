# Phase B — Verification-Backed Yield Report (B1–B5)

**Date:** 2026-07-12 · **Status:** DONE (B1–B5); **retained yield gate 2/4 — NOT cleared** → STOP for owner.
**Supersedes** `PHASE_B1_YIELD_REPORT.md` (B1 structural-only). Engine untouched; 405-test regression green;
all derived data local (`qie.db` gitignored). Evidence: `phase0_evidence/yield_gate_B5_filtered.json`,
`dpp_stage_B4.json`.

## What was done
- **B2 relation breadth** — library 56 → 86 relations.
- **B3 Math attribution** — expanded lexicon + word-boundary math-notation booster: Math recovered 328 →
  1,617.
- **B5 KVS v1** — multi-source assertion base from corpus MCQ answer keys, cross-corroborated across docs
  (≥2 independent docs → promotable). A non-numeric Item Model is verification-backed when ≥50% of its DNA
  facts are KVS-promotable; numeric via relation-match. **A spot-check caught over-corroboration** (junk
  pseudo-concepts A2 missed + option-label answer collisions); adding semantic-answer + resolved-concept
  filters and extending the canon quarantine cut promotable facts 232 → **53 (honest)**.
- **B4 staged DPP** — bounded miner over all 4 DPP corpora; **0 verifiable facts** (image-heavy, no inline keys).

## The retained yield gate (≥8 distinct-lane VERIFIED Item Models per subject)

| Subject | Structural clusters | **Verified models** | Gate | Why |
|---|---|---|---|---|
| Physics | 17 | **10** | ✅ | numeric relation-match + KVS-corroborated facts |
| Chemistry | 28 | **10** | ✅ | numeric + KVS-corroborated facts |
| Biology | 8 | **1** | ❌ | 0 numeric; deterministic KVS can't verify poorly-resolved Biology concepts |
| Mathematics | 7 | **4** | ❌ | thin text-minable corpus; DPPs image-heavy (0 yield) |

**Verification-backed yield: 2/4 subjects clear (Physics, Chemistry).** Up from 0/4 at Phase-0/B1. **The gate
is NOT cleared.** Both misses now have a precise, architectural cause — not "the engine can't express these":

1. **Biology (and non-numeric where concepts are poorly resolved).** Deterministic KVS corroboration needs
   resolved concepts + semantic answers; Biology has few clean concepts and many option-label answers, so it
   collapses to 1 verified. **Biology needs the Tier-2 independent-model verification lane** (offline,
   governed) — which Phase-0b already proved works at **91.7% agreement** on Biology. The architecture always
   specified *both* KVS entailment AND Tier-2 agreement; B5 shows the deterministic half alone is insufficient
   for Biology.
2. **Mathematics + DPP.** Math's extractable corpus is thin, and the DPP corpora (~700 PDFs) are **image-heavy
   with no inline answer keys** — text mining yields **0** verifiable facts. DPPs need the **visual ingestion
   pipeline (Phase E-full)** — image/figure extraction + answer-key association — to become usable. E-lite
   (A4) captures boundaries but not yet the images/keys these need.

## Honest caveats
- KVS verification is **multi-source corroboration** (independent source docs agree on a concept→answer
  fact), a deterministic analogue of model-agreement — NOT per-question independent solving, and NOT teacher-
  validated. It is a screening proxy; teacher validation remains mandatory before any production/market claim.
- Structural clusters use coarse concept keys; the verified count already excludes coarse buckets and option-
  label answers, but concept-quality debt still limits Biology.

## Recommended next steps (owner decision)
To clear the remaining 2/4:
1. **Tier-2 model-verification lane for non-numeric** (Biology-critical): run the Phase-0b-style independent-
   model agreement oracle offline at certification for non-numeric clusters whose facts the deterministic KVS
   can't reach. Governed, cached, offline (I9-compliant). This is the highest-value next step and directly
   targets Biology.
2. **Phase E-lite→E extension for DPP/visual**: image + answer-key association so the ~700 DPP sheets (and
   incoming board PDFs) become minable — lifts Math and adds cross-corroboration everywhere.
3. **Continued concept canonicalization**: the B5 spot-check shows more junk concepts exist than A2/its
   extension caught; an evidence-based concept-quality pass would raise Biology's resolved-concept rate.

**No scaling, no production claim until the verification-backed gate clears.** Awaiting your direction on
whether to build the Tier-2 model-verification lane next (targets Biology) and/or the visual/DPP pipeline
(targets Math).
