# Question Paper Generation Engine — Certification

**Date:** 2026-07-10 · **Scope:** `curriculum/scripts/intelligence/kie/qpgen/` · **Method:**
resolve every audit finding (recovery-first · verify-first · compile · tests · regression ·
commit · checkpoint), then re-run the **identical** audit probes + 60-paper stress matrix.

## Verdict: ✅ CERTIFIED — every P0 and P1 finding demonstrably resolved

The [dedicated audit](QP_ENGINE_AUDIT_2026-07-10.md) found the engine boundary-safe but unfit
in six ways (2 P0 + 4 P1) plus quality/scale items. All are now resolved and re-verified with the
same methodology on the real certified `kie.db` (read-only). Full KIE suite **193/193 green**
(**75 qpgen tests**); frozen KIE Phases 1–7, the Intake Center, and the core schema are
**untouched**; the production `kie.db` was **never mutated** (362 docs / 33 870 chunks unchanged).

---

## Re-audit results (same probes as the original audit)

| Finding | Before | After | Status |
|---|---|---|---|
| **P0-1** grade isolation | 333 Class ≤10 concepts in NEET scope (49%) | **0** — NEET scope 678→345, grades {11,12} only | ✅ |
| **P0-2** cross-paper uniqueness | seeds → 100% identical papers | seed overlap ~57% avg; **generate_series → 0** overlap | ✅ |
| **P1-1/1-2** honest Bloom & difficulty | stamped (fake), relaxation masked | **selected-for + labelled with actual value**; `*_met` flags | ✅ |
| **P1-3** error handling | unknown preset → uncaught KeyError | **QpGenError** with valid list; CLI exits cleanly | ✅ |
| **P1-4** chapter balancing | impossible (no chapter model) | 20-Q Biology paper spans **7 chapters** | ✅ |
| Stress matrix (5 profiles × 3 blueprints × 4 seeds) | 0 crashes / 0 breaches | **60 papers, 0 crashes, 0 boundary breaches, 0 empty** | ✅ |
| Performance (batch) | 11 ms/paper, no caching | **1.3 ms/paper** with scope/pool cache | ✅ |

---

## What each fix changed

- **P0-1 — Absolute grade isolation** (`scope.py`, `presets.py`). Scope filters concepts by the
  profile's `grade_band` using the evidencing document's `class_label`; NCERT Class 6–10 is
  excluded from an 11–12 profile, competitive papers count as grade 11–12, and an **unresolvable
  grade is excluded** (never assumed in-band). Added deterministic `ORDER BY` (also P3-1).
- **P0-2 — Cross-paper uniqueness** (`select.py`, `engine.py`, `models.py`). Selection uses
  rank-based importance **tiers** with the **seed** driving order within a tier (variety without
  losing quality); `exclude_concepts` + `generate_series(count)` give **guaranteed** non-overlapping
  Set A/B/… papers. Subject/chapter balance and reproducibility preserved.
- **P1-1/1-2 — Honest Bloom & difficulty** (`select.py`). The engine now **selects** for the
  requested Bloom AND difficulty (graceful degradation) and **labels with the candidate's real
  value**, recording `requested_*` + `*_met` in provenance and per-constraint relax notes — no more
  stamping.
- **P1-3 — Error handling** (`engine.py`). Unknown blueprint preset raises `QpGenError` with the
  valid list instead of an uncaught `KeyError`.
- **P1-4 — Chapter taxonomy + balancing** (`chapters.py`, `scope.py`, `pool.py`, `select.py`). A
  curated canonical JEE/NEET chapter taxonomy maps concepts by keyword; selection balances
  `chapter_usage` alongside subjects so every paper spreads across the syllabus, and the chapter
  filter matches the canonical chapter (Genetics filter 2→17 concepts).
- **P2 — Quality/scale** (`sanitize.py`, `scope.py`, `engine.py`, `materialize.py`). Evidence
  frequency floor (≥2) + generic-word rejection tighten the concept universe; scope+pool are cached
  per scope key; ALL-CAPS titles are Title-Cased and leading articles lowercased for clean stems;
  missing-definition answers are explicit teacher **marking guidelines** (never fabricated / copied).
- **AI layer** (`templates.py`, `materialize.py`, `validate.py`). **Deterministic template registry
  first** — certified, solver-verified parametric families (Newton, Ohm, uniform speed, mole, AP)
  with conjunctive keyword matching (no off-concept false positives). The AI seam is a real
  **contract**: gated (`KIE_AI_AUTHORIZED` + wired provider), **cached by spec-hash** (reproducible
  + minimal calls), and every AI question **re-passes the same validation gate** (rogue
  out-of-syllabus AI output is rejected, proven with a fake provider). AI makes **zero** calls by default.

---

## Principles upheld (per the resolution mandate)

- **Boundary safety never weakened** — 0 out-of-scope items across 60 stress papers + adversarial suite.
- **Grade isolation is absolute** — unresolvable grades excluded; 0 Class ≤10 leakage.
- **Balanced coverage every paper** — subject + chapter + concept balancing in selection.
- **Uniqueness never costs balance/blueprint** — seeded tiers keep tier-0 importance; series stays in-scope.
- **Deterministic-first; AI optional** — templates + descriptive fill everything by default; AI gated.
- **Every AI question passes the same deterministic validation pipeline** — enforced + tested.
- **Reproducibility preserved** — same (request, seed) → identical paper; series reproducible.
- **Minimal AI via determinism + caching** — templates first; AI output cached by spec-hash.
- **Architecture reused, not rewritten** — all changes additive within `qpgen/`; KIE untouched.

## Residual notes (non-blocking; tracked)

- **Concept-layer naming quality** still bounds descriptive-item polish (some generic/"General"
  concepts remain). This is a KIE-extraction concern, not an engine defect; the sanitizer + evidence
  floor + chapter taxonomy mitigate it, and a future KIE reprocess would lift it further.
- **Template coverage** is deliberately conservative (5 families) — it fills only clearly-matched
  objective slots; broadening the curated registry is additive and needs no engine change.
- **P3 items** (single-doc grade attribution; richer chapter map) are improvements, not correctness
  gaps, and are recorded for future iterations.

---

## Certification statement

The Question Paper Generation Engine is **certified**: boundary-safe, grade-isolated, deterministic,
reproducible; it enforces syllabus/subject/grade boundaries absolutely, balances subject/chapter/
concept coverage, produces unique papers across a series, honestly reports Bloom/difficulty, and
confines AI to a gated, cached, fully-revalidated enhancement path. All P0 and P1 findings are
resolved and re-verified by the original audit's methodology.

Per the standing directive, promotion of the local knowledge base to the production `edu_*` tables
remains a **separate, later, owner-gated** step — not performed here.
