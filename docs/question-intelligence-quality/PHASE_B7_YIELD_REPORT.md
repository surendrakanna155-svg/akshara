# Phase B7 — Concept Resolution + Tier-2 (Biology & Math): Final Yield

**Date:** 2026-07-12 · **Status:** DONE; **retained gate 2/4 — Biology & Mathematics FAIL** → STOP (precise
blocker, no auto scope expansion). Engine unchanged; 416-test regression green; kie.db uncontaminated by
qcorpus; thresholds/confidence/verification requirements all unchanged. Evidence:
`phase0_evidence/yield_gate_B7_final.json`, `tier2_biology_verdicts.json`.

## What was built (both blockers, as instructed)
1. **Strict Biology/Math concept resolver** (`concept_resolve.py`) — confidence-gated entity-linking to
   **existing active** concepts (no new concepts invented). Answer-signal-first (bio/chem answers are often
   the concept name, e.g. "mitochondrion"→`BIO_MITOCHONDRIA`) with a strict whole-phrase stem fallback;
   returns None below the 0.85 bar (**never forces an uncertain mapping**). Wired through the miner, KVS, and
   Tier-2 via a single `item_concept()` path.
2. **Tier-2 extended to Math** (attempted, honestly): the answer-based path yields **0 Math non-numeric
   candidates** — Math answers are numbers/expressions (not concept names) and the Math concept index is
   polluted with textbook section headings ("a note for the teacher", "constitution of india"); only **1 of
   129** Math non-numeric stems names a canonical concept (a false hit). So concept-resolution+Tier-2 does not
   apply to Math non-numeric evidence, and forcing it would violate the strict-confidence rule.

## Retained verification-backed yield gate (unchanged thresholds; ≥8 verified models/subject)

| Subject | Verified models | Gate |
|---|---|---|
| Physics | **20** | ✅ |
| Chemistry | **12** | ✅ |
| Biology | **1** | ❌ |
| Mathematics | **6** | ❌ |

**2/4.** Structural clusters were never counted as verified; KVS and Tier-2 agreement, the ≥5-DNA/≥2-resource
support, and the resolver confidence gate were **not weakened**; no fact/answer fabricated.

## The precise measured blocker — it is CORPUS DEPTH, not resolution or verification

Both new capabilities **work**:
- **Concept resolution works:** 207 Biology items linked to **21** canonical concepts (strict gate; the other
  ~90% correctly stayed unresolved rather than being force-mapped).
- **Tier-2 verification works:** **46 of 48** Biology facts agreed = **95.8%, zero disagreements** (matches
  Phase-0b's 91.7%).

But the resolved evidence is **too sparse per concept** to meet the (unweakened) ≥5-DNA/≥2-resource support:
- **0** resolved Biology concepts reach ≥5 distinct source docs. The densest have **2** docs; **17 of 21 are
  single-document**. Only 1 Biology concept (`mitochondria`, reached via title-match) clears the full bar.
- Root cause: strict resolution correctly **fragments** the large coarse buckets (`Biology:cell` 26 DNA) into
  many small canonical concepts, and the available corpus does not contain ≥5 questions from ≥2 independent
  documents for ≥8 distinct canonical Biology concepts.

**Mathematics (6/8):** all 6 verified are numeric relation-match models; the non-numeric evidence has no
concept-resolvable path (above), and numeric Math evidence caps at 6 distinct verifiable relations with ≥5
support. It is 2 short.

## What would clear it (each = scope expansion; NOT taken automatically, per instruction)
- **Biology:** more Biology **source depth** so each canonical concept accumulates ≥5 questions from ≥2 docs.
  The resolution and Tier-2 verification are already proven; only per-concept evidence density is missing.
  This means ingesting more Biology evidence (e.g. the image-heavy DPP/board corpus via a visual pipeline, or
  additional Biology question sources) — not weakening the ≥5/≥2 support.
- **Mathematics:** a Math-appropriate concept model (numeric-parameter/topic tagging, since answers aren't
  concept names) + more numeric-verifiable evidence; the answer-based resolver is bio/chem-shaped.

## STOP
Retained gate = **2/4** (Physics, Chemistry). Biology and Mathematics fail for a single, precisely-measured
reason — **insufficient per-concept corpus depth to meet the ≥5-DNA/≥2-resource support without weakening it**
— on top of Math's lack of a concept-resolvable non-numeric path. Resolution and Tier-2 verification are
proven to work. Per your instruction I am reporting the precise blocker and stopping rather than expanding
scope. No scaling or production generation was started; teacher validation remains mandatory before any
market claim. Holding for your direction.
