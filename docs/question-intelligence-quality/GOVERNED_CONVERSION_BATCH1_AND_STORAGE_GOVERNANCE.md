# Governed conversion — scaled execution (batch 1) + evidence-storage governance reconciliation

**Date:** 2026-07-14 · Baseline: `cef5edc0` (architecture validated). This checkpoint (a) executes the owner's
mid-turn **evidence-storage & knowledge-governance correction** non-destructively, and (b) runs the **first
scaled governed-conversion batch** end-to-end: owned evidence → verified structured knowledge → KVS → the
unified engine → the real qpgen path → re-measured paper balance. `qpgen` frozen; `kie.db` untouched; bank not
promoted; broad acquisition + Classes 1–5 / state boards remain HELD.

## A. Evidence-storage & knowledge-governance reconciliation (owner correction)

**One canonical inventory now exists.** `curriculum/EVIDENCE_REGISTRY.{json,md}` is a deterministic,
re-runnable, store-level source of truth spanning **22 stores / 59.4 GB** — every owned evidence location incl.
the previously "invisible" ones (Cursor downloads, archive, NCERT/CBSE, JEE Main, JEE Advanced, NEET, kie.db,
qie.db). Built by `kie.evidence.registry`; **read-only** (never moves/renames/deletes).

**It distinguishes lifecycle state per store** — `1_raw → 2_ocr → 3_extracted → 4_recovered → 5_verified →
6_concept_bound → 7_qie_available` (`q_quarantine`). A downloaded file (state 1), an OCR'd/extracted question
(state 3), and a QIE-available knowledge record (state 7) can never again be confused: the state answers it.

**No files were moved.** Active code hard-references current paths (qcorpus_adapter, staging configs,
kie/config, repository_verifier) and the in-flight conversion depends on them; a naive move breaks running
pipelines for no benefit. `EVIDENCE_MIGRATION_MAP.md` records the deterministic old→canonical path map, the
target lifecycle-first layout, the code dependencies, and the safe one-store-at-a-time move procedure —
**deferred** to a safe checkpoint. Logical `canonical_id`s (stable across any future move) are established now.

**Not a duplicate registry.** The existing per-file/per-doc manifests remain the DETAIL layer and are
referenced, not copied: `PROVENANCE_MANIFEST.json` (839 curriculum resources), `indexes/`, `reports/`,
qcorpus `manifests/*.jsonl`, and the DBs. This registry is the missing TOP layer (store-level lifecycle) that
none of them provided. Git tracks only the compact governance layer; raw/derived bulk stays gitignored/local.

## B. Governed conversion — scaled pipeline (deterministic-first, bounded examiner)

New package `kie.qie.convert` (all read-only on evidence; writes only qie.db):
- **`docmeta`** — safe-binding substrate: deterministic per-doc SUBJECT (hard gate) + EXAM + CHAPTER from
  rel_path/priority/filename. 863 docs → 797 subject-confident; the 66 unknown (Allen mixed mocks, JEE-Adv AAT)
  are correctly excluded so a homonym can never slip through on item text alone.
- **`candidates`** — deterministic funnel: subject gate → OCR-quality filter → chapter-grounded concept
  candidate (`Subject :: Chapter`, never item-text substring) → fact-type lane → dedup. Numeric answers split
  to the notation lane.
- **`examiner`** — bounded, cached governed examiner harness: prioritized batch selection (structured lanes +
  Chemistry-first), worksheet emit, verdict ingest. Every verdict cached by `item_hash`; refuted evidence is
  never re-examined.
- **`register`** — single admission path: writes the provenance+verification-complete `governed_fact` record,
  PROJECTS verified facts into the typed KVS store for their lane, and seeds `distractor_dna` from the item's
  REAL wrong options (misconception evidence — learned, never cloned).
- **`kvs_compose`** — generates FRESH questions from the verified KVS facts through the SAME engine (new stems,
  in-category proven-≠ distractors, deterministic re-derivation); registered as per-chapter templates the
  qp_bridge picks up.

### Funnel (deterministic, no model)
| stage | count |
|---|---|
| answer-keyed MCQs seen (qcorpus adapter) | 6,558 |
| → numeric (routed to notation-recovery lane) | 3,606 |
| → OCR-rejected / non-semantic / dup | 1,178 |
| → **clean non-numeric candidate facts** | **1,774** (Bio 938 · Phys 569 · Chem 267) |
| &nbsp;&nbsp;of which structured lanes (SF/SEQ/CMP/TAX) | 353 |
| deterministic ≥2-doc corroboration at (chapter, exact-answer) grain | 0 → examiner required |

### Batch 1 (structured lanes, Chemistry-first) — the bounded model-examiner pass
- **54 examined → 41 verified (75.9% survival) · 13 rejected.** Independent re-derivation, not agreement:
  rejects were OCR-garbled formula soup, ambiguous/multi-answer questions, a wrong "order-from-stoichiometry"
  key, and a mis-bound chapter. No fact certified by agreement alone; no gate weakened.
- **Admitted into the previously-EMPTY typed KVS stores:** `kvs_sequence` 0→13, `kvs_structure_function` 0→6,
  `kvs_comparison` 0→2, `kvs_assertion (governed)` +20, **`distractor_dna` 0→121**.
- **By subject verified:** Chemistry 27 (off 0), Biology 13, Physics 1.

## C. QIE → qpgen (real path) — re-measured balance
`kvs_compose` wired into `qp_bridge` (chapter-aware binding). Full `kie` suite green (**562 tests**), boundary
intact, 0 rejected slots.
- **NEET:** filled slots **5 → 11** (Biology 5 · Physics 5 · **Chemistry 0 → 1**); 11 distinct concepts; 3 from
  governed-KVS.
- **JEE Main:** **Chemistry 0 → 1** (Physics 5 · Math 8); 12 distinct concepts.
- 11 / 19 generated KVS items bind to a certified in-scope concept; the 8 unbound are **gaps in the certified
  concept universe** (e.g. NEET has no "Breathing and Exchange of Gases" concept title), not a pipeline failure.

## D. Honest assessment — what improved, what remains
**Materially proven:** the state-6 structuring step the reconciliation flagged as never-built now exists and
runs end-to-end; verified structured knowledge flows to real papers; Chemistry is off 0 in both exams.
**Still short of balanced full papers** — the absolute lift is small because:
1. **Scale** — only 41 of 1,774 clean candidates admitted (batch 1). ~299 more structured-lane + 1,421 generic
   candidates are queued; each further examiner batch adds ~30 verified facts at the proven ~64–76% yield.
2. **Certified-concept binding universe** — kie.db's concept list is noisy/misaligned to chapter-level facts,
   so ~40% of clean generated items can't honestly bind. This is a kie.db data-quality limit, precisely
   measured, now the dominant coverage constraint (not knowledge possession).
3. **Quantitative notation** — the 3,606 numeric candidates + NCERT 11–12 formula chunks remain notation-
   damaged; recovery from source PDFs/page-images (math-capable extractor + dimensional/answer-key verify) is
   the separate next workstream.

## Owner decision — RESOLVED (2026-07-14): Option A
**Syllabus-boundary source of truth = kie.db certified concepts + verified governed-fact chapters.** The owner
chose **A**: verified governed-fact chapters (`Subject :: Chapter`, subject-gated real NEET/JEE syllabus topics)
are now first-class in-scope concepts for the qpgen boundary, guarded by the deterministic subject gate.
Implemented in `qp_bridge._governed_concepts` (read-only qie.db) + `_bind` exact chapter binding; qpgen
internals stay frozen. Result (same seed):

| exam | filled (baseline → batch1 → +decision A) | Chemistry | from governed-KVS |
|---|---|---|---|
| NEET | 5 → 11 → **16** | 0 → 1 → **3** | 7 |
| JEE Main | — → 14 → **16** | 0 → 1 → **3** | 2 |

All governed-KVS items now bind; boundary_ok, 0 rejected slots, 562 tests green. The dominant remaining
constraint is now **scale** (admit more of the 1,720 queued candidates) + the **notation-recovery lane** (3,606
numeric candidates + NCERT 11–12 formula chunks) — both continue autonomously.
