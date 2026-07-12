# Phase B1 — Full-Corpus Yield Report (retained yield gate)

**Date:** 2026-07-12 · **Status:** B1 DONE; **retained yield gate NOT yet cleared** → STOP for owner direction.
**Governed by:** `OPUS_FABLE_RECONCILIATION_RECORD.md` §6 (Phase B), `PHASE_A_CHARTER.md` (yield gate retained).
**What ran:** `kie/qie/mine.py` on the **post-canonicalization** `kie.db` (junk quarantined), **full corpus**
(not a 200-item slice): recover MCQs → classify lane → numeric-verify via the relation library → extract
Question DNA → cluster into candidate Item Models (≥5 DNA / ≥2 resources) → measure the ≥8-per-subject gate.
1,429 DNA extracted (470 numeric, 959 non-numeric); persisted to local `qie.db`. Engine untouched; 398-test
regression green. Evidence: `phase0_evidence/yield_gate_B1_2026-07-12.json`.

---

## The two yield numbers (report both; do not conflate)

| Subject | Recovered | **Structural** clusters (≥5 DNA/≥2 res) | **Verified** models (numeric relation-match) | Structural ≥8? | Verified ≥8? |
|---|---|---|---|---|---|
| Physics | 2,647 | **17** | 6 | ✅ | ❌ |
| Chemistry | 5,394 | **28** | 4 | ✅ | ❌ |
| Biology | 1,292 | **8** | 0 | ✅ | ❌ |
| Mathematics | 328 | 3 | 1 | ❌ | ❌ |

- **Structural yield (clustering only): 3/4 subjects clear ≥8** — a large jump from **0/4** at Phase-0/0b.
  Concept canonicalization (A2) + full-corpus lane mining works: Biology reaches 8 **entirely via non-numeric
  lanes** (CONCEPTUAL_CAUSAL, PROCESS_SEQUENCE, STRUCTURE_FUNCTION, CLASSIFICATION_TAXONOMIC, COMPARATIVE,
  ASSERTION_RELATION) — the lane architecture is producing structural diversity where the old numeric-only
  engine produced none.
- **Verification-backed yield: 0/4 subjects clear ≥8.** Numeric-verified Item Models (relation-match
  reproduces the key) are Physics 6, Chemistry 4, Biology 0, Mathematics 1 — none reaches 8. **The non-numeric
  clusters — the bulk of every subject's count, and ALL of Biology's 8 — are structurally clustered but NOT
  independently verified**, because the KVS is 0-promotable (A3: no assertion has ≥2 independent evidence
  sources yet). An unverified cluster is a *candidate*, not a certifiable Item Model.

## Honest verdict

**The retained yield gate is NOT cleared.** A genuine Item Model must be independently verified; by that bar
the yield is 0/4. What B1 *did* prove is equally important and genuinely positive: on the cleaned full corpus
the lane architecture produces **abundant structural yield (3/4 ≥8, incl. Biology via non-numeric lanes)** —
so the ceiling is no longer "the engine can't express these archetypes." The remaining blocker is now precise:

1. **The KVS is not functional** (0 promotable assertions). Non-numeric verification — the thing that turns
   Biology/Chemistry clusters into certifiable Item Models — needs a **real multi-source assertion base /
   taxonomy / structure-function / sequence store**, mined and cross-corroborated (not harvested from the thin
   single-source edges A3 had). This is the single highest-value next investment.
2. **Mathematics corpus is thin** (328 recovered vs 2.6–5.4k for the others) and/or under-attributed by the
   subject lexicon — Math fails even the structural bar. Needs more Math source coverage or better attribution.
3. **Numeric verification breadth** (relation library) caps numeric-verified models at 4–6/subject; a larger
   relation library would lift the verified numeric count.

## Caveats (do not over-read the structural number)
- Non-numeric clusters use coarse concept keys (title-match OR `subject:keyword`); `:misc` and unclassified
  `CONCEPTUAL_GENERIC` were **excluded** from counts, but two clusters could still be the same concept under
  different keyword buckets. The structural count is a rough upper bound, not a certified inventory.
- These are AI/deterministic-clustering results, not teacher-validated. Teacher validation remains mandatory
  before any production/market claim.

## Recommended next step (owner decision)
Build a **functional KVS v1** (Phase-B continuation): mine a multi-source assertion base + taxonomy +
structure-function + sequence stores from the corpus MCQ answer keys (cross-corroborated across ≥2 resources)
and the (cleaned) concept graph, so non-numeric clusters can be independently verified; then re-measure the
**verification-backed** yield gate. In parallel, widen Math coverage and the relation library. **No scaling and
no production claim until the verification-backed yield gate clears.** Awaiting your direction before that
investment.
