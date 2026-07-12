# Phase B9 — Existing Question-Corpus Discovery & Utilization Audit

**Date:** 2026-07-12 · **Status:** DONE. Discovery + reconciliation + governed reuse bridge built, tested,
measured. **Retained verification-backed yield gate: 2/4 — UNCHANGED** after finding and bridging every
previously-acquired source. Engine frozen (`qpgen` untouched); `kie.db`/`qie.db` untouched (read-only); no
threshold weakened; AI OFF; A5 inert; no re-OCR (existing chunk text reused); no fabrication. **445 tests
green.** Evidence: `phase0_evidence/corpus_reconciliation.json`, `phase0_evidence/yield_gate_B9_stranded.json`.

## The objective, answered

> Before claiming Biology needs more source depth or Mathematics lacks usable evidence, prove that every
> question-paper PDF and OCR corpus we already acquired has been found, reconciled, and properly utilized.

**Every acquired source has now been found and reconciled. The 2/4 result holds.** The two blockers are not
caused by unfound corpus.

## What was previously downloaded, and where (discovery)

- **1,526 question-paper PDFs** in the workspace: 1,416 under `curriculum/resources/`, 110 under
  `curriculum/downloads/`. Two git worktrees exist (`Akshara_ERP`, `Akshara_ERP-drp`); corpus lives only in
  the main tree.
- **OCR/parsed text exists** already: `curriculum/knowledge/kie/parsed/` (379 files) and kie.db's **42,141
  chunks** — so reuse, not re-OCR, was the correct path (and the one taken).
- **Two DISTINCT corpora** (the key finding):
  - **qcorpus** (`curriculum/staging/qcorpus_noncert`, 863 docs) = the `Cursor_Downloads` **DPP crawl only**
    (studentbro NEET DPPs, physicsaholics, mathongo, jeeadv archive). Its **only Biology source is 39
    studentbro docs.**
  - **kie.db** (380 source docs) = the **foundation exam papers** — NEET (152), JEE_Main (74),
    Practice_Resources (54), NCERT (29), AIIMS (26), JEE_Advanced (20), AIPMT (6), boards — **plus** 18
    intake. These are **not** in qcorpus (confirmed by sha256: 0 overlap except 19 JEE-Advanced archive docs).
  - The miner already reads **both** (kie.db chunks + qcorpus adapter).

## Which sources are utilized, and which were stranded (utilization audit)

Per-exam recovered keyed MCQs (miner, over the existing chunks):

| exam | kie docs | in qcorpus | recovered MCQ | utilization | reason |
|---|---|---|---|---|---|
| **NEET** | 152 | 0 | **5,391** | utilized | native `(1)opt..(4)opt Answer(n)` format |
| JEE_Main | 74 | 0 | 0 | **stranded** | chunks are **answer-key tables** (`QUESTION_ID→OPTION_ID`); questions in separate docs |
| Practice_Resources | 54 | 0 | 1 | **stranded** | `1. opt` option format + answers in **separate solution docs** |
| NCERT | 29 | 0 | 0 | stranded | textbook corpus (≈no MCQs) — expected |
| AIIMS | 26 | 0 | 0 | **stranded** | scanned-image **solution** docs; noisy OCR |
| JEE_Advanced | 20 | 19 | 0 | **stranded** | **letter options (A)(B)(C)(D)** + separate keys |
| CBSE_NCERT / TS_SCERT | 18 | 0 | 0 | stranded | textbook corpus — expected |
| AIPMT | 6 | 0 | 34 | partial | mixed format |

**The stranding cause is format mismatch, not missing corpus:** the miner's recovery is tuned to the NEET/DPP
inline format, so entire exam sources with other option markers or separate answer keys yielded ~0. NEET —
the largest and most Biology-bearing source — is already fully utilized (5,391 recovered).

## The governed reuse bridge (recovery-first)

`qie/stranded_recover.py` — reuses the **existing kie.db chunk text (no re-OCR)** to recover stranded questions
with a flexible multi-format parser (`(1)opt` / `1. opt` / `(a)opt`), taking answers only from a **source**
(inline `Answer/Ans (n)`, or a same-document answer-key grid keyed by question number). It recovers **only
from question-paper doc types** (solution/answer-key docs excluded — their prose OCR produced noise), preserves
provenance (exam, doc_id, question number, recovery method), **never fabricates an answer**, and is READ-ONLY
on kie.db. Recovered **211 answer-bearing items** (Practice_Resources, AIPMT, small JEE/NTA); fed through the
**UNCHANGED** miner/KVS/Tier-2 with normalized-stem de-dup against the existing stream (**125 added, 86 deduped**
as NEET/qcorpus overlaps).

## Retained gate — before → after

| Subject | Verified models (before) | Verified models (after) | Gate |
|---|---|---|---|
| Physics | 20 | 20 | ✅ |
| Chemistry | 12 | 12 | ✅ |
| **Biology** | 1 | **1** | ❌ |
| **Mathematics** | 6 | **6** | ❌ |

**2/4 → 2/4.** Recovered-item counts rose (Biology 2,247→2,269; Math 465→478; Chem/Phys up too), but **no
verified-model count changed.** At the concept level:
- **Biology** resolved concepts reaching ≥5-DNA/≥2-docs stayed at **4** (BIO_CUTTING, BIO_MITOCHONDRIA,
  BIO_PROTEINS, BRD_PHY) — the +36 stranded Biology items created no new qualifying concept. The ceiling is
  per-concept corroboration depth under strict resolution + (AI-OFF) KVS ≥2-doc corroboration, not raw volume.
- **Mathematics** — the stranded sources added a handful (≈5) of genuinely library-verifiable school-math
  items, but they cluster into **0** ≥5/≥2 models; the stranded "Math" is otherwise the same calculus/physics
  mix the B8 structure model rejects as false matches. Genuine verified Math models remain **0** (retained
  gate's 6 remain the known false-match inflation).

## Honest determination

Every previously-acquired question-paper PDF and OCR corpus has been **found, reconciled, and tested for
utilization**. The largest Biology source (NEET) was already utilized; the stranded sources were recovered via
a governed no-re-OCR bridge and fed through the unchanged pipeline. **The gate stays 2/4.** The Biology and
Mathematics blockers are therefore confirmed **intrinsic** — Biology per-concept depth under strict verified
standards, and a calculus-heavy corpus with no school-library-verifiable Math — **not** an artifact of unfound
or unused corpus. No new content downloaded; no re-OCR; engine frozen; A5 inert; no threshold weakened.
Teacher validation remains mandatory before any market claim. Holding at **2/4** for owner direction.
