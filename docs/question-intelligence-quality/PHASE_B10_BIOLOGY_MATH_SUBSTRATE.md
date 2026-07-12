# Phase B10 — Targeted Biology & Mathematics Verification Substrate: Final Yield

**Date:** 2026-07-12 · **Status:** DONE; **retained gate 2/4 — Biology & Mathematics FAIL** → STOP for owner.
Physics & Chemistry frozen (byte-identical: 20 / 12, verified). Engine frozen (`qpgen` untouched);
`kie.db`/`qie.db` read-only; no threshold weakened; **no coarse bucket relabeled as a canonical concept**; no
fabrication. **452 tests green.** Evidence: `phase0_evidence/yield_gate_B10_final.json`,
`corpus_reconciliation.json` (B9).

| Subject | Verified models | Gate | Change vs B9 |
|---|---|---|---|
| Physics | **20** | ✅ | frozen |
| Chemistry | **12** | ✅ | frozen |
| **Biology** | **2** | ❌ | **1 → 2** (better resolution) |
| **Mathematics** | **6\*** | ❌ | unchanged (\*the 6 are false matches; genuine = 0) |

---

## BIOLOGY — the blocker moved, and is now precisely located

**Built (committed, tested): `qie/bio_resolve.py`** — governed specific-entity concept resolution. The B7
strict answer-title resolver had **low recall** (mapped ~103/2283 items) because it fires only when the
correct-ANSWER text equals a concept title. Most NEET Biology questions name their concept via a **specific
entity in the STEM** (glucagon, nephron, glycolysis, seminiferous, chlorophyll…). `bio_resolve` links those
to an existing canonical concept via a curated 168-term lexicon of **unambiguous** entities → one concept
each, **excluding generic tokens** (plant/system/hormone/cell alone) that make naive resolvers force noise
("plant growth regulator" → wastewater). Fires only on a specific entity with a clear winner; returns None on
absence/ambiguity; maps only to existing active concepts.

**Result — the resolution-recall blocker is genuinely FIXED:**
- resolves **524 items** to **17 canonical concepts** each with **≥5 DISTINCT-stem / ≥2-doc** support (vs the
  B7/B8 answer-title ceiling of 4). The prior "corpus depth ceiling = 4" was a **resolver artifact**, not a
  corpus limit — the diverse per-concept evidence is real (endocrine 30 distinct stems, photosynthesis 26,
  reproduction 25, excretory 22, circulatory 17, neural 17, respiration 17, cell 15, …).
- Biology verified models **1 → 2** (endocrine now verified via an existing cached Tier-2 verdict).

**The remaining blocker (measured): the diverse evidence is FACTUAL-RECALL, which the frozen 11-lane
STRUCTURED-archetype gate does not count.** The lane taxonomy models structured archetypes (causal, taxonomic,
sequence, structure-function, assertion-reason, comparative) verifiable by KVS mechanisms; plain
single-best-answer recall ("The functional unit of the kidney is nephron") classifies as `CONCEPTUAL_GENERIC`
and is deliberately excluded. Consequently:
- **436 distinct** resolved-concept Biology stems are factual-recall in `CONCEPTUAL_GENERIC` (excluded).
- Even with a **generous** principled structure classifier, only **4** (lane, concept) clusters reach ≥5
  DISTINCT stems / ≥2 docs. The (lane, concept) clusters that reach ≥5 *DNA* under the current classifier are
  replication-dominated (endocrine-classification 2 distinct, BIO_CUTTING 1, mitochondria 1) — counting them
  would be inflation, which is forbidden.

**Owner decision point (quantified):** admitting a **factual-recall / single-best-answer** archetype — verified
by KVS multi-source corroboration + governed Tier-2 agreement — would make **≥28 genuine, diverse Biology
concepts** (each ≥5 distinct semantic-answer stems / ≥2 docs) countable, far past 8. Under the **unchanged**
structured-archetype gate it stays at ~2–4. This is a **frozen-design decision the owner must make**, not
something to force by adding a lane or counting replication. Reported, not taken.

## MATHEMATICS — genuine school-profile evidence is essentially absent

**Audited first (as instructed), then declined to extend — because the evidence does not support it.**
Categorizing the full Math stream by structure + profile:
- **51 distinct calculus stems** (integrals/derivatives/maxima-minima) — **out of the school profile; not
  counted** (per instruction).
- The "highest-support" school categories are **misattributed physics/chemistry noise**, not school math:
  *coordinate_geometry* (19 distinct) is mostly physics ("mass whirled in a vertical **circle**", "angular
  acceleration along the **circumference**") + JEE conics (ellipse foci, parabola — out of profile);
  *arithmetic* (6 distinct) is **entirely** physics/chem "**ratio**" problems (lens/pipe/transformer/diffusion
  ratios).
- Running the B8 topic-gated, science-vetoed, topic-relation-consistent structure model over the FULL stream
  (kie + qcorpus + deglue + stranded) yields **1** genuine school-profile verified item; a profile-valid
  coordinate-geometry distance-formula extension yields **0** genuine hits. **Genuine school-profile Math
  verified models = 0.**

Per the task ("extend only where evidence supports"; "do not invent relations merely to increase model
count"; "do not count JEE calculus"), **no verification extension was built** — it would only false-match
physics (already vetoed by the B8 model) or count out-of-profile calculus/conics. The retained gate's Math=6
remains the known B8 false-match inflation; the honest genuine count is **0**. The blocker is a **corpus
profile mismatch**: the acquired corpus is JEE calculus/conics + physics noise; genuine school-profile Math is
essentially absent (1 item).

## Determination & STOP

- **Physics 20 ✅, Chemistry 12 ✅** — frozen, verified, unchanged.
- **Biology ❌ (2)** — resolution FIXED; blocker is the factual-recall vs structured-archetype design boundary.
  Reaching ≥8 requires an **owner decision** to admit a factual-recall archetype (would yield ~28 concepts).
- **Mathematics ❌ (genuine 0)** — no genuine school-profile evidence to verify; extension unwarranted.

Neither subject reaches ≥8 genuine verified Item Models under the unchanged gate. Per instruction I report the
exact measured blockers and **STOP for owner approval**. No large-scale generation; no production families; the
Certified Question Bank is untouched; no market-quality claim; `qpgen` unchanged; AI was **not** spent to
inflate replicated clusters. Regression: 452 tests green; Physics/Chemistry byte-identical.
