# Question Paper Generation Engine — Verification Report

**Date:** 2026-07-10 · **Status:** ✅ implementation-complete (pre-audit) · **Package:**
`curriculum/scripts/intelligence/kie/qpgen/` (13 modules, ~1.4k LOC) · **Tests:** 48 qpgen
tests, part of **166/166** green KIE suite · **Env:** `curriculum/.venv` (py3.14), stdlib-only.

The engine generates question papers **deterministically** from the local **certified**
Knowledge Intelligence Engine (`kie.db`) — its ONLY knowledge source, opened **read-only**
(the certified KB is never mutated). It **reuses** the completed KIE components (concepts,
Concept Graph, Question Intelligence) and rewrites none of them. AI **enhances, never
replaces**, the deterministic pipeline and is never invoked unless explicitly authorized.

> Per owner directive, this is the build phase. A **dedicated QP-engine audit** follows;
> improvements from it land before any promotion of the knowledge base to production.

---

## 1. Architecture (pipeline)

```
PaperRequest
  │  (exam/board/class · subjects · chapters · blueprint · difficulty · seed)
  ▼
scope        resolve_scope → exam profile → subjects → CLEAN, evidence-backed in-scope
             concept set  ← the HARD syllabus boundary. Unknown/empty scope is REFUSED.
  ▼
blueprint    preset or profile-default; structural validation + per-type feasibility.
  ▼
pool         candidates from Question Intelligence (patterns ⋈ clean concepts) + Concept
             Graph degree, one per (concept, type). Objective = spec_only; descriptive = deterministic.
  ▼
select       deterministic blueprint-fill: subject-balanced, frequency+centrality priority,
             each concept used once, difficulty as a soft target, reproducible by seed.
  ▼
materialize  descriptive → ORIGINAL stems grounded in the concept (deterministic, FILLED);
             objective  → validated authoring SPECS for a GATED AI (never called by default).
  ▼
validate     hard gate: rejects out-of-syllabus / wrong-subject / garbage / ungrounded /
             duplicate / exam-mismatch. Rejected slots are EXCLUDED from the paper.
  ▼
assemble     renumber per section → GeneratedPaper → render JSON / Markdown (+ answer key).
```

Modules: `models · presets · sanitize · scope · blueprint · pool · select · materialize ·
validate · assemble · engine · cli`.

## 2. Grounded in the real certified data (verify-first)

The engine was built against what `kie.db` actually holds, not the schema's aspirations:
- Corpus = **JEE/NEET foundation** (Class 11–12 competitive PCB/PCM). Primary scope dims are
  **Exam × Subject × Chapter/Concept × Difficulty × Type/Bloom**. Board/class requests resolve
  onto exam profiles; scopes with no certified data are refused.
- Concepts carry only `subject_domain`; **grade/boundary come from `source_documents` via the
  concept→doc linkage**, and admission additionally requires **evidence** (Question-Intelligence
  frequency, a named law, or a definition).
- The concept layer is **noisy** — a deterministic **sanitizer** (OCR garbage, boilerplate,
  section fragments, sentence fragments) is the quality/boundary linchpin. On the real corpus:
  **2548 concepts → ~913 usable** (clean + evidence-backed).
- **Question patterns are structure-only** (copyright-safe) and drive selection (type/bloom/
  difficulty/frequency/years). **Templates/distractors/formula-expressions = 0**, so numeric/
  objective *values* cannot be instantiated deterministically without fabrication → objective
  items are **specs**, not fabricated questions.

## 3. Determinism, boundaries, and the AI gate

- **Deterministic + reproducible:** identical `(request, seed)` → identical paper (stems and
  ordering). Tie-breaks use a stable hash, not `hash()`/RNG.
- **Strict syllabus boundary (requirement #6):** the validation gate rejects any
  out-of-syllabus / wrong-subject / garbage / duplicate / exam-mismatch / ungrounded item; the
  golden suite proves **no out-of-scope or garbage question is ever emitted across 3 blueprints ×
  12 seeds**. Unsupported or empty scopes raise rather than fabricate.
- **AI enhances, never replaces:** the entire descriptive path is deterministic. Objective items
  become specs; the `ai_fill` seam is **gated** (needs `KIE_AI_AUTHORIZED=1` *and* request opt-in
  *and* a wired governed provider) and any AI output must re-pass the validation gate. Default runs
  make **zero** AI calls (minimizing cost / maximizing reuse — requirement #5).

## 4. What it produces today

- Fully-materialized **descriptive papers** (short/long answer) for NEET/JEE/AIIMS/FOUNDATION ×
  subject × (optional) chapter, with a blueprint, section layout, marks, instructions, and an
  answer key (certified definition as model answer, else an honest rubric — no fabricated facts).
- **Objective papers** as blueprint-conformant, syllabus-validated specifications (each item
  bound to an in-scope concept + real PYQ pattern) ready for a gated AI author.
- Verified live on the real `kie.db` (read-only): a NEET Biology descriptive paper (13 Q / 40
  marks), all in-syllabus, `boundary_ok`, reproducible; baseline DB unmodified.

## 5. Known limitations (→ audit targets)

- **Output quality is bounded by concept-layer quality.** phase-5 extraction still yields some
  imperfect concept *names* (e.g. "The momentum of an object", all-caps headings). The sanitizer
  filters the worst; the remainder is a **concept-cleanup** problem for the audit + a future KIE
  reprocess — the engine's boundaries/determinism are unaffected.
- **No deterministic objective instantiation** (no templates/distractors/formula-values in the KIE
  yet). Delivering real MCQs/numericals needs either certified parametric templates (deterministic)
  or the gated AI author (both are seams already in place).
- **No chapter taxonomy** — chapter scoping is title/section substring matching; a curated
  chapter→concept map would sharpen it.
- Difficulty labels in the KIE are skewed "hard"; difficulty is treated as a soft target with a
  reported shortfall rather than a hard constraint.

## 6. How to run

```
python -m kie.qpgen.cli presets
python -m kie.qpgen.cli scope    --exam NEET --subjects Biology
python -m kie.qpgen.cli generate --exam NEET --subjects Biology,Physics \
    --blueprint descriptive_40 --seed 1 --format md --out paper.md
# gated AI fill (off by default): add --allow-ai-fill AND KIE_AI_AUTHORIZED=1 (provider must be wired)
```

Tests: `PYTHONPATH=curriculum/scripts/intelligence curriculum/.venv/bin/python3 -m unittest
discover -s curriculum/scripts/intelligence/kie/tests -p 'test_qpgen_*.py'`.

## 7. Verification evidence

| Guarantee | Test |
|---|---|
| Sanitizer accepts real concepts, rejects garbage/boilerplate/fragments | `test_qpgen_scope` |
| Scope: subject-in-profile; unknown + empty scope refused (no fabrication) | `test_qpgen_scope` |
| Blueprint validation + honest per-type feasibility | `test_qpgen_blueprint` |
| Pool reuses Question Intelligence + Concept Graph; best-pattern collapse | `test_qpgen_pool` |
| Selection: no-dup coverage, subject balance, seed determinism, shortfall reported | `test_qpgen_select` |
| Materialize: deterministic stems; objective→spec; AI gated; default no-AI | `test_qpgen_materialize` |
| Validation gate rejects out-of-syllabus/wrong-subject/garbage/duplicate/ungrounded | `test_qpgen_validate` |
| Engine E2E: descriptive fill, reproducible, JSON+MD render, scope errors raise | `test_qpgen_engine` |
| Golden paper stable + **no out-of-scope across 3 blueprints × 12 seeds** | `test_qpgen_golden` |

**Regression:** full KIE suite **166/166 green**; certified `kie.db` never mutated (all tests
use temp/in-memory stores; the engine and CLI open production read-only). Frozen KIE phases 1–7,
the Intake Center, and core schema are untouched.

**EOS gate:** PASS — deterministic, reuse-first, boundary-safe, regression-safe; the one honest
constraint (concept-layer naming quality) is documented and handed to the dedicated audit.
