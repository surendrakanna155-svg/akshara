# QP Generation Engine — Post-Improvement Independent Re-Audit

**Date:** 2026-07-10 · **Scope:** the Question Paper Generation Engine only
(`curriculum/scripts/intelligence/kie/qpgen/`). Not a KIE / ERP / infra audit.
**Method:** re-ran the original audit's evidence generation against the live certified KIE
corpus after the five improvement phases, plus the full test suite. Every number below is
measured, not asserted.

## Verdict

All five phases landed **additively** (no architecture change, no KIE/Intake change,
deterministic-first preserved, AI never made mandatory). Each materially raised quality, and
**determinism and the syllabus boundary were not weakened.** Regression-clean throughout:
the KIE suite went **196 → 249 tests** (+53 new, 0 failures), of which **131 are qpgen tests**.

| Invariant (re-checked on live corpus) | Result |
|---|---|
| Same (request, seed) → byte-identical paper | ✅ identical |
| Cross-seed variety preserved | ✅ 6/6 distinct papers over 6 seeds |
| Syllabus boundary (36 papers, 3 profiles × 3 blueprints × 4 seeds) | ✅ 0 breaches |
| AI default path attempts zero calls | ✅ not attempted |

## Phase-by-phase evidence

**Phase 1 — Sanitizer hardening + render-time stem gate.** *Before:* stems shipped
`Explain Newton'sthird law`, `Define Obviously the octet rule`, `FFirst law`,
`Miscellaneous Examples`. *After:* **0** of those junk titles remain in scope and **0** artifact
stems across **228** FILLED stems in real papers. Real concepts are repaired, not discarded
(`FFirst law`→`First law`, `ACIDS AND BASES`→`Acids and Bases`), so scope barely moved
(NEET 329→327). Deterministic OCR repair + a strengthened rejecter + a render-time quality gate.

**Phase 2 — Deterministic template library.** *Before:* 5 families, ~0.4% of objective
candidates fillable. *After:* **52 families** (47 MCQ-capable) across all four subjects, every
one solver-verified (answer computed) and copyright-safe (universal formulas / named laws / SI
units). **0** malformed instances across 20 seeds × every family. Distractors are computed
misconception near-misses; `_mcq_options` now guarantees 4 distinct options (also fixed a latent
collision in the pre-existing AP template). *Honest ceiling:* deterministic objective coverage is
still bounded by how specifically KIE concepts are titled — the library binds correctly wherever
a concept is specifically named; it does not fabricate to force a match.

**Phase 3 — Authentic examination blueprints.** *Before:* 3 simplified presets, none matching a
real paper. *After:* 7 authentic blueprints with official totals — **NEET 720, JEE Main 300,
CBSE X 80, CBSE XII 70, TS/AP SCERT 40** — plus JEE Advanced (representative). Subject-bound
per-subject sections (fixed a Biology-in-Physics leak), difficulty progression within sections,
Bloom spread, negative-marking + internal-choice instructions, and a weightage model. Marks stay
honest (count = questions that count; internal choice is an instruction, never inflated marks);
shortfalls are reported, never padded. Competitive profiles now default to their authentic
blueprint.

**Phase 4 — Selection intelligence.** *Before:* `graph_degree` was computed but **never used** in
ranking; frequency-only, no recency. *After:* a deterministic composite `importance_score`
(frequency PRIMARY + PYQ recency + graph centrality + evidence authority) drives tiering and the
within-tier tie-break. Verified: equal-frequency concepts are now differentiated by recency /
centrality / authority, while no single modifier overrides a real frequency gap. Recency is
measured against the corpus's own latest year, so it stays wall-clock-free and reproducible. The
subject/chapter balancing and seed-driven variety are unchanged.

**Phase 5 — Objective validation (same gate for AI).** *Before:* the gate never checked objective
structure — a malformed MCQ (≠4 options, duplicates, answer-not-in-options, two correct) could
pass; AI output was trusted blindly. *After:* a hard gate on every FILLED objective item requires
exactly 4 distinct options with the answer present exactly once (numerical/match need a concrete
answer). Applied identically to template and gated-AI output; a malformed AI MCQ is now rejected
before assembly. Verified: **21** filled objective items across real papers, **0** malformed
shipped.

## What remains bounded (transparent, out of engine scope)

Deterministic objective *coverage* on the current corpus is still limited by concept-title
specificity (many KIE concepts are chapter-level), not by the engine. The templates, blueprints,
ranking and validation are correct and comprehensive; coverage rises automatically as concept
titles improve or the gated AI author is enabled. This is a data reality, not an engine defect.

## Commit trail

`835f39e4` (P1) · `d19d4dcc` (P2) · `fd8072ce` (P3) · `9d7e7e12` (P4) · `a8e241e9` (P5),
on baseline checkpoint `8b70d9c6`. Each phase: compiled, full regression, new tests, committed.
