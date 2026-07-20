# Question Planning Layer — Audit & Implementation Roadmap

**Date:** 2026-07-20 · **Branch:** `feature/qp-content-readiness` · **Foundation:** NCERT Knowledge
Foundation **v1.4 — PERMANENTLY FROZEN** (2,023 certified concepts, fingerprint `e3a146f3…`, `immutable=true`).
**Status:** DESIGN (audit complete; no code written). **Author phase discipline:** Audit → **Design (this doc)** →
Implement → Verify → Certify. Each phase must reach production quality before the next.

> This document is the authoritative design gate for the **Question Planning Layer (QPL)**. It records what
> already exists (audited first-hand against code + live DBs), what to preserve, what to remove, the confirmed
> architectural gaps, the deterministic **Question Blueprint** schema, and a phased plan. It ends with the genuine
> **owner decisions** that must be resolved before Phase 1 begins.

---

## 0. Scope & standing law (unchanged, carried into QPL)

- **Frozen foundation is READ-ONLY.** QPL reads only `ki_concept WHERE status='certified'` in
  `curriculum/knowledge/kie/knowledge_index.db` (v1.4). Never mutate; any knowledge change = a new version v1.5+
  as a separate build. No new discovery.
- **AI proposes; deterministic checks certify.** Wrong knowledge is worse than missing knowledge. Never weaken a
  gate for yield. No source-question cloning. Every certified artifact keeps provenance + per-gate verification.
- **The planner's output is deterministic.** Given the same certified inputs (foundation vX, Exam-DNA vY,
  QDI vZ) + exam + seed, the planner must always emit the **identical** set of Question Blueprints.
- **`qpgen/` internals stay frozen**; integrate only through `kie/qie/qp_bridge.py`. The pilot bank is not promoted.

---

## 1. The target pipeline and where QPL sits

```
Knowledge Foundation (Frozen v1.4)                     ← DONE (2,023 certified, JEE/NEET band = 968)
   → Exam DNA (JEE Main / JEE Adv / NEET)              ← GAP: only subject-level marks-shells exist today
   → QUESTION PLANNING LAYER  → Question Blueprint     ← THIS DELIVERABLE (half-built + undriven + RNG)
   → Candidate Question Generation                     ← factory/ generate stage (external model)
   → Independent Solution Verification                 ← factory/ gates.independent_solve (sympy) — BUILT
   → Independent Judge & Certification                 ← factory/ judge + certify — BUILT
   → Certified Question Bank                            ← factory_corpus.db 'certified' (15 so far)
   → Question Papers → DPP → Daily Practice → Adaptive ← qpgen + qp_bridge downstream — BUILT/partial
```

**QPL is the contract between the frozen curriculum and every downstream generator.** Everything upstream of it
(the foundation) is done. Much downstream of it (deterministic verification, judge, certify, paper assembly)
is already built. **QPL is the missing deterministic middle** — and it is *half-built* today, not greenfield.

---

## 2. Ground truth — the data state (measured against live DBs, not docs)

All counts read directly from disk on 2026-07-20.

### 2.1 Frozen foundation — `knowledge_index.db` (v1.4, immutable)
- `ki_concept`: **2,023 certified** (+743 quarantined, +70 rejected). Columns include everything a blueprint's
  WHAT-half needs: `concept_id` (stable `KC_sha14(subject|class|canonical_name)`), `chapter_id`, `subject`,
  `taught_at_class` (PROVEN, not "mentioned"), `canonical_name`, `aliases`, **`sub_concepts`**, **`prerequisites`**,
  **`boundary{in_scope[],out_of_scope[]}`**, `evidence_chunks/pages`, `section_heading`, `academic_discipline`.
- `ki_chapter`: **284 chapters** (`chapter_no`, `title`, `subject`, `taught_at_class`) — **no weightage column.**
- **Certified class distribution (corrects the stale "thin 9–12" doc claim):**
  6:145 · 7:336 · 8:283 · 9:140 · 10:151 · **11:523 · 12:445**. The **JEE/NEET band (11–12) = 968 concepts**
  (Physics 306, Chemistry 283, Biology 238, Mathematics 141). **Coverage is real.**
- **Relationship/boundary density (certified):** prerequisites on **1,188/2,023 (59%)**, sub_concepts on
  **1,857 (92%)**, boundary on **2,023 (100%)**. (The docs' "10 prerequisite edges" figure came from the old
  `kie.db`, not this frozen index — it is stale.)
- Namespace already present but **empty/seed**: `qdi_pattern` **12 rows, all `JEE_Main`/`Mathematics`,
  all `status='proposed'`, 0 certified**; `qdi_source` 0; `qdi_scope_link` 0.

### 2.2 The factory corpus — `factory_corpus.db` (the 1,000-candidate trial)
- `generation_spec` (**1,000 rows** — the *existing* blueprint): `spec_id, run_id, lane, board, exam_profile,
  class_level, subject, concept_code, concept_title, concept_codes_all, composition, archetype, question_type,
  intended_depth, intended_difficulty, visual_required, boundary, planner_evidence`. Spans SCHOOL 626 /
  JEE_MAIN 239 / NEET 135; single 875 / multi 125; easy 374 / moderate 499 / hard 127. **`concept_code`
  points at the old noisy `kie.db`, NOT the frozen `ki_concept`.**
- `candidate` (1,000), `gate_result` (7,649), `independent_answer` (684), `judge_verdict` (91).
- **Yield of the trial run: 15 certified / 1,000 (1.5%)** (368 rejected, 161 quarantined, 456 still candidate).
  Low yield is consistent with planning against the noisy kie.db + the qualitative lane being non-certifiable.

### 2.3 Track-1 store — `qie.db`
- `question_dna` **2,996 rows** but `difficulty_drivers` 0/2,996, `assessment_profile` empty on all → **not a usable
  distribution source as-is.** `item_model` 84, `pilot_verified_item` 1,496 (Track-1 bank, not promoted),
  `governed_fact` 152, `governed_relation` 49, `distractor_dna` 379.

### 2.4 Tests & repo hygiene
- **681 tests, OK** (re-run 2026-07-20). But **zero tests cover `factory/` or `knowledge/planner|plan_specs|
  plan_controls|qdi|brief`** — the entire Track-2 planning layer is unpinned.
- **Preservation risk (critical):** `factory/` has **0 files tracked in git**; `knowledge/` planning code is
  **actively gitignored** by the unanchored rule `knowledge/` at `curriculum/.gitignore:54` (confirmed via
  `git check-ignore`). The whole QPL substrate is one `git clean` from deletion.

---

## 3. What already exists — PRESERVE (evolve, do not rebuild)

| Asset | Location | Role for QPL | Keep as-is? |
|---|---|---|---|
| Frozen WHAT-index | `ki_concept` (v1.4) | class/subject/chapter/concept/sub-concept/prereqs/boundary | **Read-only, immutable** |
| Deterministic pre-generation gate | `knowledge/planner.py:131` `check_plan()` + `_ARCH_DEPTH` | 6 refusals: junk name, not-certified, subject, class+chapter, archetype×depth legality, composition legality | **Reuse verbatim** |
| Adversarial plan controls | `knowledge/plan_controls.py` | 12 known-bad specs must be refused; known-good must pass → raises `PlanControlBreach` | **Reuse + extend** |
| Two-layer JOIN-at-brief | `knowledge/brief.py:87` | joins certified boundary (`ki_*`) + design DNA (`qdi_*`) without merging stores | **Reuse pattern** |
| Certified-universe reader | `knowledge/planner.py:109` `certified_universe()` | the only sanctioned way to read the foundation | **Reuse** |
| DNA schema (the richest in repo) | `knowledge/qdi_schema.sql` | archetype, composition_kind, dependency, reasoning_chain, step_depth, **difficulty_mechanism/band**, distractor_structure, misconceptions, solution_structure, evidence_refs; `qdi_scope_link` = JEE/NEET seam | **Keep schema; populate + certify** |
| Deterministic verification spine | `factory/gates.py`, `gates.independent_solve` (sympy, 96.6% reproduced), `controls.py` (`ControlBreach`), `certify.py` | downstream of QPL — the reason structured specs are certifiable | **Keep** |
| Blueprint persistence | `factory/corpus_schema.sql` `generation_spec` + `corpus.py` | the row shape to evolve into `question_blueprint` | **Evolve schema** |
| Exam paper structure DNA | `qpgen/blueprints.py` (NEET/JEE Main/JEE Adv/CBSE), `qpgen/models.py` | sections, marks, subject weightage, negative marking, per-cell difficulty | **Consume; extend to chapter-level** |
| Per-exam archetype allow-lists | `qie/profiles.py` `PROFILES` (11) | which archetypes are legal/core per exam (qualitative, no weights) | **Consume as the archetype gate** |
| Archetype canon + classifier | `qie/archetypes.py` `ARCHETYPES` (20) + lane map | the archetype vocabulary and lane routing | **Reuse** |
| Computed reasoning depth | `qie/compose.reasoning_depth` (FOUNDATIONAL ≤1 / INTERMEDIATE 2–3 / ADVANCED ≥4) | depth is *structural/earned*, never asserted | **Reuse** |
| Sole integration seam | `qie/qp_bridge.py` `generate_paper()` | QPL → papers/DPP path | **Integrate only here** |
| Governance model | propose → independent-audit → `status` lifecycle | applies to Exam DNA + QDI + blueprints | **Reuse everywhere** |

---

## 4. What to REMOVE / RECONCILE — duplication

1. **Two planners → converge on the certified-index stack.**
   - OLD: `factory/manifest.py` (plans off noisy `kie.db.concepts` 3,006 rows; synthesized `derived_heuristic`
     boundaries; **no archetype×depth gate**) + `factory/plan.py` (mis-named — it is the generator *brief emitter*,
     not a planner).
   - NEW: `knowledge/planner.py` + `plan_specs.py` (certified `ki_concept` only; evidenced boundary;
     adversarial gate).
   - **Action:** the NEW stack becomes the single planner. `factory/manifest.py`'s planning role is retired;
     if kept at all, it becomes a thin adapter that emits the reconciled `question_blueprint` rows. `factory/plan.py`
     and `knowledge/brief.py` (two near-identical generator briefs) converge to **one** brief emitter.
2. **Duplicated helpers → single source of truth.** `_sid()` (identical in both), `forbidden_terms()` (heuristic
   vs evidenced — keep evidenced), archetype pools (`manifest.STRUCTURED/QUALITATIVE_ARCHETYPES` vs
   `plan_specs._STRUCTURED/_QUALITATIVE` — **membership differs**; unify against `profiles.py`), difficulty logic.
3. **Two spec schemas → one.** `generation_spec` (`concept_code/board/exam_profile/planner_evidence`) vs the
   knowledge spec dict (`concept_id/compose_with/pattern_id/class_level`). Reconcile into the single
   `question_blueprint` schema (§6).
4. **Naming collision (hard rule).** In `qpgen`, `Blueprint`/`BlueprintCell` already mean the **paper-level** slot
   layout. The QPL per-question artifact MUST use a distinct name — this doc uses **`QuestionBlueprint`** (a
   single-item plan row). Do not overload `Blueprint`.
5. **Dead code:** `factory/plan.py` legacy full `_BRIEF`/`brief()` (superseded by `compact_brief` + solutions
   stage); confirm-then-delete. Empty `factory/__init__.py` is a package marker (keep).

---

## 5. Confirmed architectural gaps (what QPL must BUILD)

| # | Gap | Evidence | Consequence |
|---|---|---|---|
| G1 | **Planner is undriven** — no CLI orchestrates `certified_universe → allocate → build_blueprints → gate → persist` | nothing outside `knowledge/` imports the planner | QPL cannot run end-to-end today |
| G2 | **Planner is RNG-sampled, not deterministically allocated** | `plan_specs.py` uses `random.Random(seed)` for lane/archetype/depth/difficulty/composition | violates the "same inputs → same blueprint" law |
| G3 | **No Exam-DNA distribution layer** — chapter weightage, concept weightage/frequency, per-exam difficulty / reasoning-depth / archetype *distributions* | only subject-level `weightage` in `qpgen/blueprints.py`; `ki_chapter` has no weight column; `question_dna.difficulty_drivers` 0/2,996 | the planner has no evidenced targets to allocate against |
| G4 | **QDI is a 12-row uncertified seed** (JEE_Main/Math), `qdi_scope_link` empty | live DB counts | no certified design DNA → no evidenced difficulty / misconceptions / expected-solving-path / exam-profile legality |
| G5 | **No cross-concept relationship graph** for multi-concept composition; single-vs-multi not stored | only per-concept `prerequisites` (59%) exist; no co-occurrence/edge table | multi-concept planning relies on the gate's "same-subject/≤class" heuristic, not evidenced pairings |
| G6 | **Missing blueprint fields**: chapter & sub-concept & prerequisites not *consumed*; learning_objective absent everywhere; expected_solving_path only generator-declared; misconceptions absent as data (`common_misconceptions` 0/3,006) | §1c of factory audit | blueprint is thinner than the required contract |
| G7 | **Difficulty model split-brain**: independent-axis (docs + planners) vs depth-proxy (`qp_bridge._difficulty` = HARD iff depth≥4) | two shipped code paths disagree | must be resolved before difficulty can be a real blueprint field |
| G8 | **Track-2 code uncommitted / untested** | §2.4 | work can be lost; determinism & controls unpinned |

---

## 6. The deterministic **Question Blueprint** schema (target contract)

`QuestionBlueprint` = a single, deterministic, fully-provenanced instruction to generate ONE candidate question.
It is the reconciliation of `generation_spec` (evolve) + the knowledge spec dict + the required fields. Every field
names its **certified source** so nothing is invented.

| Field | Type | Source (certified) | Notes |
|---|---|---|---|
| `blueprint_id` | TEXT PK | `sha256(foundation_ver|examdna_ver|qdi_ver|exam|concept_id|slot_index)` | content hash → deterministic identity |
| `run_id` | TEXT | planner run | groups a blueprint set |
| `exam` | TEXT | input ∈ {JEE_MAIN, JEE_ADVANCED, NEET} (+SCHOOL later) | drives distributions + `profiles.py` legality |
| `class_level` | INT | `ki_concept.taught_at_class` | PROVEN class, never "mentioned" |
| `subject` | TEXT | `ki_concept.subject` (+`academic_discipline`) | |
| `chapter_id` / `chapter_title` | TEXT | `ki_chapter` via `chapter_id` | **NEW: consume** |
| `concept_id` / `concept_name` | TEXT | `ki_concept` | stable id |
| `sub_concept` | TEXT? | `ki_concept.sub_concepts` | **NEW: consume** |
| `composition` | TEXT | planner (`single`\|`multi`) | multi ⇒ `compose_with` |
| `compose_with` | JSON[] | certified partners (same-subject, ≤class) [+ G5 relationship graph] | gate-checked |
| `prerequisites` | JSON[] | `ki_concept.prerequisites` | **NEW: consume** |
| `curriculum_boundary` | JSON | `ki_concept.boundary{in_scope,out_of_scope}` | **replaces** synthesized `forbidden_terms` |
| `exam_profile_legal` | BOOL+basis | `qie/profiles.py` + `qdi_scope_link` | archetype/scope legal for this exam |
| `chapter_weight` | REAL | **Exam DNA** (G3) | target share for the chapter |
| `concept_weight` / `concept_frequency` | REAL | **Exam DNA** (G3) | evidenced, not RNG |
| `archetype` | TEXT | `archetypes.ARCHETYPES` ∩ `profiles` allow-list; chosen by **archetype distribution** (Exam DNA) | |
| `reasoning_depth` | INT (band) | target from per-exam **depth distribution**; *earned back* by `compose.reasoning_depth` at verify | plan target ↔ structural check |
| `difficulty` | TEXT | **bounded driver model** (Decision 1): deterministic `f(reasoning_depth, concept_count, misconception_pressure, calculation_load)`, versioned; target band from **difficulty distribution** | verifiable & recomputed at GATE-9, not stamped |
| `difficulty_drivers` | JSON | the 4-driver vector used to derive `difficulty` | versioned weights; enables GATE-9 recheck |
| `difficulty_basis` | JSON | evidenced mechanism from certified `qdi_pattern.difficulty_mechanism` | why this is easy/moderate/hard |
| `question_type` | TEXT | exam blueprint cell (`qpgen/blueprints.py`) | MCQ/NUMERICAL/… |
| `learning_objective` | TEXT | **DERIVED** deterministically from (concept + archetype + Bloom) | **NEW** |
| `expected_solving_path` | JSON | certified `qdi_pattern.solution_structure`/`reasoning_chain` | design-level, abstract (no wording) — needs QDI (G4) |
| `misconceptions_to_evaluate` | JSON[] | certified `qdi_pattern.misconceptions`/`distractor_structure` | needs QDI (G4) |
| `constraints` | JSON | boundary (forbidden) + `lane` + `visual_required` + parameter constraints | positive + negative |
| `lane` | TEXT | `STRUCTURED_NUMERIC` \| `QUALITATIVE` (deterministic by discipline+archetype) | routes certifiability |
| `pattern_id` | TEXT? | certified `qdi_pattern` | the design DNA this item realizes |
| `planner_evidence` | JSON | per-input certification refs (foundation ver, exam-DNA ver, qdi ver, gate verdicts) | full provenance |
| `blueprint_fingerprint` | TEXT | hash of all selecting fields | determinism proof; excludes timestamps |
| `status` | TEXT | `planned` \| `gated` \| `issued` | lifecycle |

Persistence: **evolve `factory/corpus_schema.sql generation_spec`** into `question_blueprint` (add the NEW columns).
`created_at` is metadata only and MUST NOT influence any selecting field or the fingerprint.

---

## 7. Determinism design (how "same inputs → same blueprint" is achieved)

The planning path is *already* deterministic **except** `plan_specs`'s RNG (G2). The fix is to make the planner a
**deterministic distributor**, not a sampler:

1. **Freeze the inputs to versioned, certified snapshots**: `foundation_ver` (v1.4 fingerprint), `examdna_ver`,
   `qdi_ver`. The blueprint set is a pure function of these + `exam` + `N` (+ an optional `seed` used *only* for
   stable ordering/tie-breaks, never for counts).
2. **Deterministic allocation (largest-remainder / Hamilton method):** distribute `N` items across
   chapters → concepts proportional to certified `chapter_weight`/`concept_frequency`; resolve remainders by a
   fixed rule; tie-break by `concept_id`. This replaces `rng.choices` for *how many* items per bucket.
3. **Deterministic per-item assignment:** walk each bucket's target archetype/difficulty/depth **distribution** in a
   fixed canonical order to assign each slot (a stable "distribution cursor"), never `rng.choice`. Seed influences
   only a SHA-256 ordering of equal-priority candidates (the pattern already used in `qpgen/select.py`).
4. **Content-hash identity:** `blueprint_id` and `blueprint_fingerprint` are hashes of selecting fields (no clock).
5. **Determinism test (pinned):** `plan(exam, N, versions, seed) == plan(exam, N, versions, seed)` byte-for-byte,
   and changing `seed` re-orders but never changes the multiset of `(concept, archetype, difficulty, depth)`.

---

## 8. Phased implementation roadmap

Each phase is production-quality-gated: it ships with tests + an adversarial control suite and leaves the tree
green before the next begins.

### Phase 0 — De-risk & preserve (no new features)
- Fix `curriculum/.gitignore:54`: anchor `knowledge/` → `/knowledge/` (curriculum-root-relative) so it stops
  swallowing `kie/qie/knowledge/`. Verify `git check-ignore` clears.
- Commit the existing Track-2 code (`factory/` + `knowledge/`) as-is, with a **characterization test suite** that
  pins current behaviour (planner gate, plan_controls, factory gates, sympy solve, certify logic) — so refactors
  are safe. Run the two control suites (`plan_controls.check_plan_controls`, `controls`/`ControlBreach`).
- **Exit:** Track-2 tracked, tests green (681 + new), controls pass, nothing behaviourally changed.

### Phase 1 — Repoint & unify the planner onto the frozen foundation
- Make `knowledge/planner.certified_universe()` the sole concept source; delete the `kie.db.concepts` planning path
  in `factory/manifest.py` (or reduce it to an adapter). Consume `chapter_id`, `sub_concepts`, `prerequisites`,
  `boundary` (retire synthesized `forbidden_terms`).
- Unify duplicated helpers (`_sid`, `forbidden_terms`, archetype pools, difficulty) into one module.
- **Exit:** one planner, reading only certified v1.4; blueprint carries chapter/sub-concept/prereqs/boundary;
  `plan_controls` still green.

### Phase 2 — Build the **Exam DNA** layer (the critical path, G3)
- New certified tables (governed like the foundation): `exam_chapter_weight`, `exam_concept_frequency`,
  `exam_difficulty_dist`, `exam_depth_dist`, `exam_archetype_dist` — keyed by `exam × subject × (chapter|concept)`,
  each row carrying `evidence_refs`, `analyst_model`, `audit_verdict`, `status`. **Acquisition method = Owner
  Decision 2.**
- Ship an adversarial control suite: a distribution that doesn't sum to 1, a chapter absent from the syllabus, a
  weight attributed to the wrong exam → all must be REJECTED.
- **Exit:** certified per-exam distributions for JEE Main / JEE Advanced / NEET exist and are versioned.

### Phase 3 — Make the planner a deterministic distributor (G2)
- Replace RNG allocation/assignment with the §7 largest-remainder + distribution-cursor algorithm driven by the
  Phase-2 Exam DNA. Wire the driver CLI (`certified_universe → allocate → build_blueprints → check_plan → persist`)
  (G1).
- Persist the reconciled `question_blueprint` schema (§6).
- **Exit:** `plan()` is byte-for-byte reproducible; determinism test pinned; blueprint set matches Exam-DNA targets.

### Phase 4 — Certify the **QDI** design layer (G4) + resolve difficulty (G7) + derived fields (G6)
- Drive `qdi.py` to ingest + independently audit design patterns from owned PYQ chunks (analyst → auditor →
  `certified`), populate `qdi_scope_link` (exam_profile × min_class). Expand beyond the 12-row JEE_Main seed.
- Attach `difficulty_basis`, `expected_solving_path`, `misconceptions_to_evaluate`, `pattern_id` to blueprints from
  **certified** patterns only. Derive `learning_objective` deterministically.
- Implement the resolved difficulty model (Owner Decision 1).
- **Exit:** blueprints carry evidenced design DNA; difficulty is verifiable, not stamped.

### Phase 5 — Verify & certify the Planning Layer itself
- Full control suite: adversarial plans (national-anthem-as-concept, cross-subject multi, above-class composition,
  archetype×depth incoherence, out-of-syllabus, distribution drift) all refused; known-good plans pass.
- Determinism proof; provenance completeness (every blueprint field traces to a certified source + version).
- Run the **EOS gate** scoped to QPL (per `CLAUDE.md`). Produce a QPL certification package.
- **Exit:** QPL PASS → candidate generation may begin against certified blueprints.

### (Later) Phase 6 — Concept relationship graph (G5)
- Build an evidenced cross-concept co-occurrence/relationship layer for genuine multi-concept composition
  (beyond the same-subject/≤class heuristic). Deferred; single-concept + prerequisite-backed multi is enough to start.

---

## 9. Owner decisions — RESOLVED (owner, 2026-07-20)

All four locked. These now govern the build.

- **Decision 1 — Difficulty model → BOUNDED DRIVER MODEL.** `difficulty` is a deterministic, **versioned** function
  of a small evidenced driver vector: **`reasoning_depth` + `concept_count` + `misconception_pressure` +
  `calculation_load`**. The 3 self-downgraded drivers (`information_density`, `abstraction_level`, `context_novelty`)
  and `prerequisite_depth` are **excluded** until data supports them. Difficulty must be **recomputable and verified
  at gate time (GATE-9)** on the generated instance, never merely stamped. This resolves G7 (retires the
  `qp_bridge._difficulty` depth-collapse for planning; depth remains one *input* driver, not the whole model).
- **Decision 2 — Exam-DNA acquisition → CURATE v1, THEN MINE.** Phase 2 first authors **certified** weightage /
  frequency / distribution constants from published PYQ analyses (fast, auditable, governed like
  `qpgen/blueprints.py`), versioned as Exam-DNA v1, to unblock the deterministic planner. It is then **deepened**
  with evidence mined from owned PYQ chunks via the QDI analyst→independent-audit pipeline (Exam-DNA v2+). Both
  carry `evidence_refs` + audit verdict; nothing is trusted because a model wrote it.
- **Decision 3 — Blueprint store → EVOLVE `generation_spec` IN PLACE.** Extend `factory_corpus.db`'s
  `generation_spec` into the reconciled `question_blueprint` schema (§6). One corpus, one lifecycle; supersedes the
  two divergent spec shapes.
- **Decision 4 — v1 exam scope → ALL THREE AT ONCE (JEE Main + JEE Advanced + NEET).** Exam-DNA v1 (Phase 2) and the
  deterministic planner (Phase 3) cover all three competitive exams from the start. **Consequence:** Phase 2 must
  curate certified distributions for all three before Phase 3; the Phase 5 control suite + certification must
  green all three exams together before candidate generation begins.

---

## 10. Key file map (for the next session)

```
FROZEN (read-only):
  curriculum/knowledge/kie/knowledge_index.db          # v1.4 foundation — ki_concept / ki_chapter / qdi_*
  curriculum/scripts/intelligence/kie/qie/knowledge/{spine,engineer,build,schema,reconcile,toc_recover}.py

PRESERVE + EVOLVE (the QPL substrate — currently UNCOMMITTED / gitignored):
  kie/qie/knowledge/{planner,plan_specs,plan_controls,brief,qdi}.py  + qdi_schema.sql   # the NEW planner + DNA
  kie/qie/factory/{gates,controls,certify,judge,solutions,corpus,validate_run}.py + corpus_schema.sql  # verify spine
  kie/qie/{profiles,archetypes,compose}.py             # exam archetype legality, canon, computed depth

CONSUME (frozen; integrate only via qp_bridge):
  kie/qpgen/{blueprints,models,presets,chapters}.py    # paper-level exam structure DNA
  kie/qie/qp_bridge.py                                  # sole seam to papers/DPP

RETIRE / RECONCILE:
  kie/qie/factory/manifest.py   (OLD planner on kie.db) → adapter or delete
  kie/qie/factory/plan.py       (brief emitter; legacy full brief dead) → converge with knowledge/brief.py

DOCS:
  docs/question-intelligence-quality/QUESTION_PLANNING_LAYER_ROADMAP.md   # this file
  …/QIE_SCALE_STRATEGY_TRIAL.md · CERTIFIED_KNOWLEDGE_INDEX_AND_QDI.md · QP_INTEGRATION.md
```

---

## 11. Execution log

Autonomous build on branch `feature/qie-question-planning-layer`. Each phase: implement → test → verify →
certify (EOS) → commit → doc.

### Phase 0 — Preservation & De-risk — ✅ COMPLETE (2026-07-20) · EOS: PASS
- Anchored `curriculum/.gitignore` `knowledge/` → `/knowledge/` (data stays local; engine code committable).
- Committed the previously-uncommitted Track-2 substrate (`factory/` 13 + `knowledge/` 15) — preserved via the
  concurrent W0 lane-convergence wave; QPL branch cut from that tip.
- Added characterization suites `tests/test_qpl_char_{planner,factory}.py` (15 tests) pinning the planner gate,
  `plan_controls` (12 controls), `plan_specs` seed-determinism, sympy `independent_solve`, the notation
  comparator, the full gate battery, and the certify promotion matrix. **696 tests green** (was 681).

### Phase 1 — Repoint & unify the planner onto frozen v1.4 — ✅ COMPLETE (2026-07-20) · EOS: PASS
- **Retired the kie.db planning path:** deleted `factory/manifest.py` + `factory/trust.py` (undriven, superseded,
  forbidden source). No importers; no tests referenced them (verified repo-wide).
- **Enriched the certified spec** (`plan_specs.build_specs`) with `sub_concepts`, `prerequisites`,
  `curriculum_boundary`, `chapter_title` — consumed straight from the certified `ki_concept` record.
- **Added the single certified-only driver** `knowledge/run_planner.py`: opens frozen v1.4 **READ-ONLY**, wires the
  certified design-pattern reader (0 today), gate-validates every spec. Measured: Physics 11–12 → 40/40 issued /
  0 refused; all 5 subjects healthy (Biology honestly refuses 1/30).
- **Unified duplicated helpers** onto the knowledge stack (`_sid`, evidenced `forbidden_terms`, archetype pools)
  by removing the manifest copies.
- Tests: +5 (`tests/test_qpl_phase1_planner.py` — enriched specs, driver on v1.4, reproducibility, kie.db-path
  retired guard). **701 tests green** (was 696).
- Still seed-deterministic (RNG inside `build_specs`); the RNG → Exam-DNA-driven deterministic allocation is Phase 3.
