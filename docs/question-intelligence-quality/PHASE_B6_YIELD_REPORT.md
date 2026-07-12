# Phase B6 — Tier-2 Verification + qcorpus Integration: Final Yield

**Date:** 2026-07-12 · **Status:** DONE; **retained gate 2/4 — Biology & Mathematics FAIL** → STOP (no auto
scope expansion, per owner instruction). Engine unchanged; 412-test regression green; kie.db received **no**
qcorpus data; qcorpus staging read only. Evidence: `phase0_evidence/yield_gate_B6_final.json`,
`tier2_biology_verdicts.json`.

## What was built (both blockers, in priority order)
1. **Tier-2 model-verification lane** (`tier2_verify.py`) — governed, cached, **offline** independent-model
   agreement for non-numeric Biology (the Phase-0b architecture). Verdicts cached by item hash; a fact is
   verified only on model **agree with no disagree**. Ran on the 36 Biology facts the deterministic KVS
   couldn't reach: **33 agree / 0 disagree / 3 unverifiable = 91.7%** (matches Phase-0b's 91.7%). Verification
   works.
2. **Read-only qcorpus adapter** (`qcorpus_adapter.py`) — **reused** the existing isolated `qcorpus_noncert`
   staging lane (~819 PDFs already parsed with boundaries/options/answers/visuals preserved). **No duplicate
   PDF/OCR/visual pipeline built.** Subject attributed via `priority`/`rel_path`; `visual_dependent` items
   excluded from text verification; answers used only where the source associated one. The miner now consumes
   a unified kie.db + qcorpus item stream; KVS corroborates across both (promotable facts 53 → **71**).
   Contributed **6,449** answer-associated items (Biology 1,642, Physics 4,601, Chemistry 944, Math 102).

## Retained verification-backed yield gate (unchanged thresholds; ≥8 distinct-lane VERIFIED models/subject)

| Subject | Structural | **Verified** | Gate | Verification path |
|---|---|---|---|---|
| Physics | 32 | **19** | ✅ | numeric relation-match + KVS |
| Chemistry | 34 | **12** | ✅ | numeric + KVS |
| Biology | 9 | **1** | ❌ | Tier-2 works (91.7%) but stranded — see below |
| Mathematics | 9 | **6** | ❌ | numeric relation-match |

**2/4 clear.** No structural cluster was counted as verified; KVS and Tier-2 requirements were not weakened;
no fact or answer was fabricated.

## Precise measured blockers (reported, not worked around)

**Biology (1/8) — the blocker is CONCEPT RESOLUTION, not verification.** Tier-2 verification succeeded
(33/36 facts, 91.7%, 0 disagreements). But Biology's *abundant* evidence is stranded in **coarse keyword
concept buckets** that verification (deliberately) cannot use: the largest Biology clusters are
`Biology:cell` (26 DNA), `Biology:cell` (21), `Biology:plant` (17), `Biology:hormone` (17) — all coarse
buckets, not resolved concepts. Only resolved-concept clusters can be verified (to avoid the B5 over-
corroboration), and Biology has few resolved concepts because its OCR'd stems don't map to canonical
concepts. Net: only **1** resolved Biology cluster (`BIO_MITOCHONDRIA`, 12 DNA) reached the verified bar. The
missing capability is **Biology concept resolution / entity-linking** (mapping noisy stems to canonical
concepts) so the coarse-bucket evidence becomes verifiable resolved clusters — a distinct NLP investment, not
a verification gap.

**Mathematics (6/8) — the blocker is verifiable-evidence depth.** All 6 verified are numeric relation-match
models (`area_rect`, `area_trap`, `mean2`, `ap_sum`, `area_tri`, `sum_n`). It is 2 short. Its large non-
numeric clusters are coarse buckets (`Mathematics:sequence` 32 DNA, `Mathematics:vector` 8) — same concept-
resolution issue — and qcorpus added only 102 Math items (the studentbro Math corpus is image/DPP-heavy, so
few text MCQs). Tier-2 was **not** run on Math (Biology was priority 1). Math needs either (a) more numeric-
verifiable evidence / relations, (b) Tier-2 on Math non-numeric, or (c) Math concept resolution — each a
scope expansion I did **not** undertake automatically.

## Honest notes
- Tier-2 is an independent-model agreement proxy (offline, cached), NOT teacher validation — which remains
  mandatory before any production/market claim. Physics/Chemistry pass on numeric relation-match + KVS multi-
  source corroboration (deterministic) plus, for a few, model agreement.
- Isolation held: qcorpus is read-only → qie.db only; kie.db received no qcorpus/DPP data; the only kie.db
  writes remain the earlier authorized, reversible concept-canon quarantine.

## STOP — decision for owner
The retained gate is **2/4** (Physics, Chemistry). **Biology and Mathematics fail for precisely diagnosed,
non-overlapping reasons** — Biology on concept resolution, Math on verifiable-evidence depth. Per your
instruction I am **not expanding scope automatically**. The clearing steps, if you approve them, are:
1. **Biology concept resolution** (entity-link noisy Biology stems → canonical concepts) so the existing
   large coarse-bucket clusters (26/21/17 DNA) become resolved clusters the working Tier-2 lane can verify.
2. **Math**: run Tier-2 on Math non-numeric + Math concept resolution, and/or extend numeric evidence.

No scaling or production generation was started. Holding for your direction.
