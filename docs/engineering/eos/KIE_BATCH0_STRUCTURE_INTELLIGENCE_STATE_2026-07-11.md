# Batch-0 Question Structure Intelligence — Session State Checkpoint

**Date:** 2026-07-11 · **Branch:** `feature/qp-content-readiness` · **Status:** RECON COMPLETE — implementation NOT started (stopped on owner instruction).

Governing evidence: `docs/engineering/eos/KIE_QUESTION_INTELLIGENCE_AUDIT_2026-07-11.md` (commit `da588ac3`).
Engine remains FROZEN. AI remains OFF. No code, DB, or engine changes were made in this session.

## Completed (this session — read-only recon)

1. **Sanctioned extension path confirmed.** `kie/qpgen/templates.py` (frozen) loads
   `kie.curate.templates_ext.build_families(Template, _num_family, _mcq_options, _p, _n, QuestionType)`
   and appends the returned families to `REGISTRY`. Learned Batch-0 families can therefore be
   registered as **content-only** data-driven templates via the curate lane, with zero engine edits.
   `find_template` binds by conjunctive keyword groups against concept titles; `instantiate` marks
   `solver_verified`. `_mcq_options` guarantees 4 distinct options; distractor lists are family-supplied.
2. **Frozen output-quality matrix runner confirmed.** `curriculum/scripts/reports/qp_output_audit.py`
   — fixed 19 configs × 3 seeds = 57 papers; measures objective fill, print coverage, teacher-ready
   counts, diversity/repetition, difficulty/bloom honesty, and the 0-tolerance output-integrity gates.
   This is the before/after instrument for Batch-0 (baseline snapshot NOT yet captured this session).
3. **DB recon (`curriculum/knowledge/kie/kie.db`).**
   - `chunks` now = **42,141** (was 33,870 at audit time; growth from board ingestion + intake).
   - `block_type` carries only `paragraph` (29,731) and `table` (12,410) — question/option/solution
     block types are NOT populated, so Batch-0 must re-detect complete `(1)(2)(3)(4)` MCQs from raw
     chunk text (consistent with the audit's regex-measured ~7,746 complete / ~5,224 clean English
     computational MCQs).
   - `question_patterns` = metadata-only skeletons; `distractors` / `question_templates` wiped by
     Phase 7 — as per audit; nothing changed since.
4. **Environment verified.** `curriculum/.venv` python imports `kie` from
   `curriculum/scripts/intelligence`; sqlite3 CLI access to `kie.db` works.

## Partial

- None in code/tests (nothing was written or modified).
- Pre-Batch-0 baseline `qp_output_audit` JSON snapshot: **not yet run** — must be captured BEFORE
  any Batch-0 registration so the matrix delta is attributable.

## Pending (planned checkpoints, none started)

- **CP-A** — read-only structure-recovery audit over computational MCQ evidence: recover quantities/
  units/options/answer; measure OCR equation damage; fix a deterministic discovery/holdout split.
- **CP-B** — deterministic relation library + independent source-answer verification (reject
  inconsistent items; dimensional gate; unit normalization).
- **CP-C** — schema abstraction: normalize algebraically equivalent relations, learn parameter
  ranges/constraints from evidence, mine repeated wrong-option strategies, dedupe, rank families.
- **CP-D** — register only high-confidence families via `kie.curate.templates_ext` (content-only);
  generate; independent re-solve; originality/source-distance, dimensional, boundary gates.
- **CP-E** — holdout generalization evaluation + rerun the frozen 57-paper output-quality matrix;
  full honest report per the Batch-0 evaluation spec (counts, rejects, coverage, diversity).

## Constraints re-affirmed

- Engine (`kie/qpgen/`) frozen; growth only via the curate content lane.
- Derived/learned knowledge artifacts stay LOCAL-ONLY (gitignored) per the curriculum local-storage
  decision; only code/tests/docs are committed.
- Shared worktree: verify `git branch --show-current` = `feature/qp-content-readiness` before every
  commit; the separate curriculum-acquisition lane's uncommitted files must not be swept into commits.
