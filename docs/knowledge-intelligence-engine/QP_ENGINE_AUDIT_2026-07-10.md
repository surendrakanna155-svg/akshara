# Question Paper Generation Engine — Dedicated Audit

**Date:** 2026-07-10 · **Scope:** `curriculum/scripts/intelligence/kie/qpgen/` ONLY (not the
wider KIE/ERP) · **Method:** adversarial code review + empirical probes against the real
certified `kie.db` (read-only) + a 60-paper stress matrix · **Auditor stance:** challenge the
implementation; assume nothing is optimal.

## Verdict: ❌ NOT CERTIFIED — 2 P0 + 4 P1 must be resolved first

The engine's **safety** is solid: across 5 profiles × 3 blueprints × 4 seeds (60 papers) there
were **0 crashes, 0 out-of-scope breaches, 0 empty papers**, and `boundary_ok` held everywhere;
the validation gate never let an out-of-scope/garbage item into a paper. But its **fitness for
purpose** has real defects — grade isolation leaks, generated papers are identical across seeds,
and Bloom/difficulty/chapter compliance is partly cosmetic. These block certification.

---

## P0 — blocking (correctness / core use-case broken)

### P0-1 · Grade isolation FAILS — Class 6–10 content in Class 11–12 papers
**Evidence:** In the resolved NEET (Class 11–12) scope, **333/678 concepts (49%) are evidenced by
Class ≤10 material**; **572/678 (84%) come from mixed-grade NCERT textbooks**, not NEET/AIIMS
papers. A real generated NEET Biology paper contained **4/13 questions from Class 7–9** sources
("The momentum of an object" — Class 9, "RATIONALISATION OF CONTENT" — Class 7, "Motion"/"Power" —
Class 9).
**Root cause:** `scope.resolve_scope` never filters by the profile's `grade_band`, even though
`source_documents.class_label` **is populated** for the NCERT-derived majority; and
`presets.EXAM_PROFILES[*].source_exams` includes mixed-grade `NCERT` in **every** profile.
**Impact:** Directly violates the audit objective "grade isolation." A NEET paper reads like a
middle-school worksheet in places.
**Fix:** Filter scope by `grade_band` using the evidencing doc's `class_label` (and, for docs
without one, a path/grade heuristic); handle NCERT by grade rather than wholesale inclusion;
prefer concepts attested by actual in-profile exam papers over textbook-only concepts. Attribute
grade across **all** docs a concept appears in (see P3-2), not just `evidence.doc`.

### P0-2 · No cross-paper uniqueness — seeds produce IDENTICAL papers
**Evidence:** Papers for seeds 0–5 (NEET Biology, descriptive) had **100% concept overlap** (13/13
identical every pair); 5 "different" papers covered only **13 distinct concepts total**.
**Root cause:** `select._priority` orders by `(subject_usage, -frequency, -graph_degree,
seed_hash, concept_code)` — `seed_hash` is the **4th** key, but `frequency`/`graph_degree` almost
never tie, so the top-N frequent concepts win regardless of seed (`select.py:38-45`).
**Impact:** Cannot produce Set A / Set B, per-student practice, or non-repeating papers — a core
product requirement ("uniqueness across multiple generated papers").
**Fix:** Make the seed a first-class selection driver — seeded weighted sampling within
frequency/importance bands (keep quality, add variety) — and add an `exclude_concepts` / variant
parameter plus an optional cross-paper "already used" ledger so successive papers diverge.

---

## P1 — blocking (blueprint compliance / robustness)

### P1-1 · Bloom is STAMPED, not selected — fake compliance
**Evidence:** A blueprint cell requesting `bloom=analyze` produced 8 MCQs all *labeled* "analyze"
regardless of the candidates' real Bloom level. **Root cause:** `select.py:79`
`bloom=cell.bloom or best.bloom` overwrites the slot's Bloom with the requested value and never
filters candidates by Bloom. **Impact:** Bloom's-taxonomy targeting is illusory; metadata lies.
**Fix:** Filter/prefer candidates by `cell.bloom` (as difficulty is), label slots with the
**actual** candidate Bloom, and report shortfalls.

### P1-2 · Difficulty relaxation is masked in output
**Evidence:** 8 short-answers requested "easy" → all 8 **labeled "easy"** with a single "relaxed"
note, though few easy candidates exist. **Root cause:** `select.py:80` `difficulty=cell.difficulty
or best.difficulty` stamps the requested difficulty even when a non-matching candidate was taken.
**Impact:** A paper's rendered/JSON difficulty misrepresents reality (a "medium" that is actually
hard). **Fix:** Label with the candidate's true difficulty; keep the requested target in
provenance; surface the mismatch, not just an internal note.

### P1-3 · Unknown blueprint preset → uncaught `KeyError` (CLI traceback)
**Evidence:** `generate(..., blueprint_preset="does_not_exist")` raises a raw `KeyError`, which the
CLI's `except (ScopeError, QpGenError)` does not catch. **Root cause:** `engine.generate` calls
`blueprint.resolve_blueprint` → `presets.get_blueprint` (`presets.py:115`) which raises `KeyError`;
not wrapped. **Fix:** Validate the preset up front and raise `QpGenError` with the valid list.

### P1-4 · No chapter model → chapter balancing impossible
**Evidence:** Concepts have no chapter/topic attribute; `concept_board_mappings.chapter` is empty
(0 rows); `chapters` is only a **substring filter** on titles (asking for chapter "cell" yielded 2
questions). **Root cause:** the engine has no chapter dimension in the pool or selection.
**Impact:** The objective "concept coverage and chapter balancing" cannot be met.
**Fix:** Build a chapter/topic taxonomy (from `document_sections` breadcrumbs and/or the
`parent_child` Concept-Graph and/or a curated chapter→concept map) and add chapter as a
coverage/weighting dimension in selection.

---

## P2 — quality / scalability (resolve or explicitly track)

- **P2-1 Answer key is ~77% placeholders** — only 43/2548 concepts carry a definition, so most
  descriptive "model answers" are `[Model answer: …]` stubs. Enrich definitions (from chunks / KIE
  reprocess) or present answers as explicit teacher rubrics.
- **P2-2 Descriptive stem grammar** — "Define The momentum of an object.", "Explain RATIONALISATION
  OF CONTENT." Normalize titles (case, leading-article handling, verb/title agreement) in
  `materialize.render_deterministic`.
- **P2-3 No scope/pool caching → O(corpus) per paper** — `resolve_scope` (12ms) + `build_pool`
  (11ms) rerun on **every** `generate` (~70% of the 30ms cost is redundant for batch runs). Cache
  by `(profile, subjects, chapters)`; invalidate on KB change. (Fine for single papers; a scale
  issue for batch/mock-exam generation.)
- **P2-4 Cross-type concept competition + overstated feasibility** — global concept de-dup means
  short & long answers can never share a concept, yet `type_availability` counts each type as the
  full concept set independently, so feasibility can pass and then starve. Model a shared concept
  budget across types.
- **P2-5 Sanitizer gaps** — "RATIONALISATION OF CONTENT" (all-caps boilerplate heading),
  "Characteristics"/"Motion"/"Power" (generic), "The momentum of an object" (clause) still pass.
  Add all-caps-heading + generic-word + leading-article rejects and an evidence-frequency floor.
- **P2-6 `class_label`-only requests are refused** even though grade data exists — support
  class-scoped generation (an NCERT class profile).
- **P2-7 Case-sensitive subjects** — "physics" is rejected; normalize case in the scope subject check.

## P3 — robustness / design hygiene

- **P3-1** `resolve_scope` concept query has **no `ORDER BY`** — determinism currently survives only
  because `select` imposes a total order; add `ORDER BY concept_code` for defense-in-depth.
- **P3-2** Grade/exam attribution uses a **single** `evidence.doc`; aggregate across all docs a
  concept appears in (via chunks) for correct grade/exam boundaries (compounds P0-1).
- **P3-3** `select.py` re-filters `available` by `used_concepts` on every pick (O(count×pool));
  maintain a running available list.

---

## AI integration seam — can it be strengthened without losing determinism?

Today `materialize.ai_fill` is a bare gated stub (raises). It can be strengthened substantially
while keeping the deterministic path authoritative:

1. **Deterministic parametric-template registry FIRST (highest value, zero AI).** Add certified
   question families — numerical templates with parameter ranges + a solver — so objective items
   (mcq/numerical) are instantiated deterministically and solver-verified ("one certified family →
   unlimited instances"). This removes most of the reason to call AI at all.
2. **Strict AI-fill contract.** Input = the validated spec; AI output MUST re-pass the **full
   validation gate** + a dedup/similarity check + (where possible) a solver check before it can
   enter a paper. AI never bypasses the gate.
3. **Cache + freeze by spec-hash.** Persist accepted AI questions keyed by spec hash so regeneration
   reuses them → determinism preserved even with AI in the loop, and API calls are minimized (reuse).
4. **Governed + off by default.** Route through the KIE governed gateway (auth/rate/cost); the
   deterministic default path makes zero AI calls.

## What is solid (do not regress)

- **Boundary safety** — 0 out-of-scope breaches across the 60-paper stress matrix + adversarial
  suite; unsupported/empty scopes are refused, never fabricated.
- **Crash-free** across profiles × subjects × blueprints × seeds; edge cases fail closed.
- **Determinism** holds for a fixed DB; **read-only** KB access (certified data never mutated).
- Clean staged architecture with genuine reuse of KIE Concept + Question Intelligence.

---

## Recommended resolution order (before re-audit → certification)

1. **P0-1 grade isolation** (scope grade-band filter + NCERT-by-grade) — biggest correctness win.
2. **P0-2 seed variety + cross-paper uniqueness** (seeded sampling + exclude/variant).
3. **P1-1/P1-2** honest Bloom/difficulty selection + labeling.
4. **P1-3** blueprint-preset error handling.
5. **P1-4 + P2-5** chapter taxonomy + sanitizer tightening (quality of what's selectable).
6. **P2-1/2-2** answer + stem quality; **P2-3** caching; **P2-4/2-6/2-7** feasibility + UX.
7. **AI seam**: build the deterministic template registry (item 1) before any AI wiring.

Re-audit after P0+P1 (minimum) with the same probes; certify only when grade isolation, multi-paper
uniqueness, and blueprint (Bloom/difficulty/chapter) compliance are demonstrably correct.
