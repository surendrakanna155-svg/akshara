# Program B — PYQ Re-attribution & Re-mining · Execution Log

**Program:** B (PYQ Re-attribution & Re-mining) · implements roadmap **R5-4** (measured Exam DNA v2).
**Branch:** `feature/program-b-pyq-remining` (new, off the frozen QIE baseline `bbee4803`; NOT pushed).
**Plan (SSOT):** [`PROGRAM_B_PYQ_REMINING_ENGINEERING_PLAN.md`](PROGRAM_B_PYQ_REMINING_ENGINEERING_PLAN.md).
**Predecessor:** QIE/QDI Remediation — COMPLETE, OWNER-ACCEPTED, FROZEN (`42c93454`). Treated as immutable history.

This log is the running record of what has actually been implemented, verified, tested, certified, documented,
and committed — one section per milestone (B0…B6). It never re-plans (the plan is the SSOT).

---

## Owner authorization — plan ACCEPTED, implementation AUTHORIZED · 2026-07-22

The owner **accepted** the Program B Engineering Discovery and **approved the implementation plan**, confirming
the finding that the core issue is **provenance reconstruction**, not simple attribution cleanup. All eight owner
decisions are approved (with two concrete tightenings, recorded verbatim as binding):

| OD | Owner decision (binding) |
|---|---|
| **OD-1** | Process **only genuine PYQ papers**. DPP, mock tests, coaching sheets, practice material remain **separate datasets** (never mixed into exam DNA). |
| **OD-2** | Every certified pattern must maintain **deterministic provenance**: **Question → Chunk → Source Document → Exam → Year → Subject**. If provenance cannot be reconstructed → **Honest-Null**. |
| **OD-3** | Hybrid approved: implement **structural difficulty only**; **do not claim measured student difficulty**. Measured difficulty stays unavailable until sufficient learning evidence exists. |
| **OD-4** | **Subject is always determined from the source document BEFORE concept resolution.** Never derive subject from legacy prefixes. |
| **OD-5** | Minimum sample threshold = **30 independent PYQs**. Below that → report **"Insufficient Evidence."** Never fabricate statistics. |
| **OD-6** | Every mining pass creates a **new immutable version**. **Never mutate previously certified datasets.** |
| **OD-7** | Certification remains **deterministic**. Independent verification **mandatory**. **Model agreement may reject but never certify.** |
| **OD-8** | Proceed with the current owned corpus (**~188 PYQ docs**) as **Version 1**. The pipeline must remain **scalable** so future acquisitions incorporate **without redesign**. |

**Execution discipline (owner-mandated, per milestone B1→B6):** implementation · adversarial verification ·
regression tests · EOS gate · documentation · commit. **Stop only for a genuine owner decision or an external
dependency.**

**Engineering consequences locked in from the OD answers:**
- OD-2 ⇒ a `pyq_item` with no reconstructable Question→Chunk→Doc→Exam→Year→Subject chain **is not created** (or is
  written honest-null on the unreconstructable axis and excluded from measured weights). Provenance is a
  precondition, not an annotation.
- OD-5 ⇒ the small-sample floor is a **hard 30 independent PYQs** per measured cell; below → `insufficient_evidence`.
- OD-6 ⇒ examdna.db **v1 is never mutated**; because its `exam_weight`/`exam_distribution` PKs exclude `version`,
  the v2 measured layer is written to **new version-keyed tables in Program B's own derived store** (`pyq_corpus.db`),
  leaving v1 byte-identical.
- OD-1 ⇒ `dpp`/`mock`/practice are classified into a **separate dataset** and can never feed an `exam_dna_v2` weight.

---

## Baseline

- Branch created off `bbee4803`. Predecessor QIE branch left frozen (no commits added to it).
- Local test baseline: KIE suite established green before any Program B code (see B0).
- Frozen substrate opened **mode=ro** throughout; `kie.db` + `knowledge_index.db` asserted MD5 byte-identical.

---

## Progress ledger

Legend: ✅ done (committed) · 🔵 in progress · ⏸ owner-gated · ⏳ blocked (external) · ⬜ not started

| Milestone | Scope | State |
|---|---|---|
| **B0** | Owner approval recorded · execution log · plan committed · baseline established | 🔵 in progress |
| **B1** | Corpus role classification (`pyq_source_class`) | ⬜ |
| **B2** | Exam + subject + concept re-attribution | ⬜ |
| **B3** | Question re-mining with deterministic provenance chain + OCR fail-safe | ⬜ |
| **B4** | Structural difficulty (labelled) + marking-scheme extraction | ⬜ |
| **B5** | `exam_dna_v2` measured layer (N≥30 floor, v1 preserved) | ⬜ |
| **B6** | Integration (blueprints surface provenance_class; exam-representative gates on v2) + final EOS | ⬜ |

---

<!-- Milestone entries are appended below as each is executed. -->
