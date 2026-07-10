# QP Generation Engine — Final Independent Production Audit & Feature-Freeze Certification

**Date:** 2026-07-10 · **Type:** external certification (customer / teacher / principal / examiner /
paper-setter lens), not an implementation review. **Scope:** the Question Paper Generation Engine
only (`curriculum/scripts/intelligence/kie/qpgen/`).

## Verdict

**CERTIFIED FOR FEATURE FREEZE.** No P0 and **no meaningful P1 engine-code defect** remains. The
engine is correct, deterministic, boundary-safe, robust under stress, performant, and safe. The one
P1-severity limitation (content coverage) is a **KIE-corpus / data ceiling that the engine surfaces
honestly** — it is out of the engine's scope, already owner-accepted, and does not block *engine*
feature-freeze. Remaining items are P2/P3 quality refinements.

## Audit scale & method

Generated **~3,000 papers** across 5 profiles × 10 blueprints × 60 seeds, plus targeted red-team,
edge-case, solver-verification, series, and quality-metric batteries. Every number below is measured.

| Check | Result |
|---|---|
| Papers generated (5 profiles × 10 blueprints × 60 seeds) | 3,000 · **0 crashes** |
| Marks conservation, no duplicate (concept,type), boundary, subject scope | **0 violations** |
| Same-seed reproducibility (re-generated every paper) | **0 nondeterministic** |
| Difficulty progression non-decreasing within every section | **0 violations** |
| Template solver math (independent recompute, 23 numeric families) | **6,900 checks · 0 wrong** |
| Objective structural validity of every FILLED objective item | **0 malformed shipped** |
| Stem artifacts across all FILLED stems | **0** |
| `generate_series` Set A…J (10 sets) pairwise concept overlap | **0** |
| Performance | 11 ms/paper avg · NEET 180-Q paper 38 ms cold / 52 ms warm · 50-paper series 376 ms |
| Red-team (bad chapter, subject-not-in-profile, unknown exam/blueprint, ±huge seed, unicode, near-total exclusion) | all **graceful**, no crash |
| Full qpgen test suite | **131/131 green** (249 KIE-wide) |

The engine's mechanical correctness, determinism, safety, and robustness are **production-grade**.

## Findings

### P0 — none.

### P1 — none in engine code.
One P1-severity **product/data** limitation, correctly attributed and out of engine scope:

- **[P1 · DATA, not engine] Real-world content coverage.** Measured on the live corpus: only **~1%
  of objective items are deterministically answerable** (99% are honest `[SPEC · author via approved
  AI]` placeholders), and **~98% of FILLED descriptive answers are "marking-guideline" placeholders**
  (no real model answer). A teacher cannot hand a generated NEET/JEE paper to students as-is.
  **Root cause:** the KIE corpus — concept titles are chapter-level (so the 52 solver-verified
  templates rarely keyword-bind) and only ~2-6% of concepts carry a usable definition. This is a
  *data* ceiling, not an engine defect: the engine correctly refuses to fabricate and labels every
  gap honestly. **Smallest additive lifts (all already available, none an engine feature):** enable
  the gated, validated AI author; broaden template keyword binding / add chapter-level template
  fallbacks; or reprocess the KIE for richer definitions and cleaner titles. **Does not block engine
  feature-freeze; it gates real-world deployment and belongs to the corpus/AI track.**

### P2 — quality gaps (post-freeze, additive; bug-fix-eligible).

- **[P2] Chapter weightage is largely nominal.** ~60% of in-scope concepts map to the "General
  Physics/Chemistry/Biology" catch-all, so real chapters are starved (e.g. a NEET paper shows
  Mechanics at ~2%). Blueprint `weightage` is display-only metadata; selection balances by chapter
  but the buckets are uninformative. **Root cause:** `chapters.py` keyword taxonomy classifies only
  ~40% of concepts. **Smallest fix:** expand the keyword map to shrink "General X"; optionally have
  selection honor blueprint `weightage`.
- **[P2] Long-answer model answers are one-line definitions.** A 5-mark LONG_ANSWER may show a
  one-line definition (e.g. "the product of its mass and velocity") as its "answer" while the
  solution says "award up to 5 marks for a complete account" — a mark-depth mismatch. **Root cause:**
  `render_deterministic` reuses the certified definition verbatim as the answer regardless of marks.
  **Smallest fix:** for LONG_ANSWER, frame the definition as a *starting point* + expected
  elaboration, rather than presenting a one-liner as the full answer.

### P3 — minor polish (post-freeze, additive).

- **[P3] Descriptive stem repetition.** Only 5 short-answer verbs + 4 long-answer frames → e.g.
  "State the meaning of …" appeared 6× in one 13-question paper. **Fix:** add more stem variants.
- **[P3] "Case-based" sections render as plain descriptive stems.** CBSE Section E is labelled
  case-based/source-based but renders "Define X" (no passage/scenario), because the deterministic
  engine cannot author a case without fabricating. **Fix:** render case-based items as specs (like
  objective items) or relabel honestly.
- **[P3] A few phrase-like concept titles / thin lowercase answers.** e.g. "The momentum of an
  object"; answer "the product of its mass and velocity" (lowercase fragment). **Fix:** tighten
  trailing-phrase handling in the sanitizer + capitalize/frame short answers.

## Feature-Freeze scope

The **engine** (scope → blueprint → pool → selection → materialization → validation → assembly),
its 52-family template library, 10 blueprints, ranking, and validation gates are **frozen**: no new
features. Going forward — bug fixes only, regression testing, and documentation updates. The P2/P3
items above are the post-freeze backlog; the P1 content-coverage lift is tracked on the separate
corpus / gated-AI track and is **not** an engine change.

**Certification:** the Question Paper Generation Engine is production-grade as an engine and is
**CERTIFIED FOR FEATURE FREEZE** as of 2026-07-10, on the standing, transparent caveat that
teacher-ready *content density* is corpus-gated (P1 · data), not engine-gated.

Baseline for this audit: `2c7a21c2` (post-Phase-5 re-audit). Engine unchanged during this audit
(read-only certification).
