# QIE Architecture Verification — Milestone 1 (Pre-Generation)

**Date:** 2026-07-29 · **Branch:** `feature/program-d-knowledge-bank-integration` @ `28f71ffd`
**Scope:** Full-stack inspection of the Question Intelligence Engine before any generation run.
**Method:** Direct read of source + direct query of the frozen stores. No claim below is inferred; every
number is reproducible by the query shown.

---

## 0. Premise verification (owner's stated baseline)

| Owner's claim | Verified value | Source of truth | Verdict |
|---|---|---|---|
| 2,041 certified facts | **2041** | `qie.db governed_fact WHERE status='verified'` | ✅ exact |
| 1,739 certified concepts (86.6%) | **1739 / 2009 = 86.56%** | `QIE_CERTIFICATION_FINAL_RECONCILIATION.md` §1 | ✅ exact |
| 0 external source gaps | **0** ("Needs Authorized Sources") | same report §1 | ✅ |
| 0 impossible concepts | **0** | same report §1 | ✅ |
| Knowledge base frozen | `kie.db` mode `-r--r--r--`; registry `certified_knowledge_fingerprint_v1.5` | filesystem + report §7 | ✅ |

**Regression baseline re-run this session:** `python kie/tests/run_kie_suite.py`
→ `ran=1318 failures=0 errors=0 skipped=1`. Green.

The premise holds. One qualification is recorded in **W5** below.

---

## 1. The layers that exist, and whether they are connected

### 1.1 Certified Knowledge (authoritative input)

Two physically separate stores, both frozen:

| Store | Table | Rows | Role |
|---|---|---|---|
| `knowledge_index.db` | `ki_concept` (certified) | **2,009** | the curriculum spine — *what is taught, at which class* |
| `knowledge_index.db` | `ki_chapter` (accepted) | 284 | chapter binding |
| `qie.db` | `governed_fact` (verified) | **2,041** | the fact bank — *what is true, with provenance* |

`ki_concept` carries the fields that make curriculum-bounded generation possible at all:
`taught_at_class` (authoritative, never the document label), `boundary{in_scope[],out_of_scope[]}`,
`prerequisites[]`, `evidence_chunks[]`, and `academic_discipline`.

Class × discipline coverage of the certified spine (**this is the real generation universe**):

| Discipline | 6 | 7 | 8 | 9 | 10 | 11 | 12 |
|---|---|---|---|---|---|---|---|
| Mathematics | 86 | 182+1 | 138 | 57 | 33 | 61 | 80 |
| Physics | 28 | 56 | 58 | 28 | 38 | 153 | 153 |
| Chemistry | 7 | 34 | 22 | 18 | 50 | 192 | 81 |
| Biology | 19 | 52 | 57 | 28 | 29 | 110 | 128 |
| Interdisciplinary | 5 | 9 | 7 | 9 | — | — | — |

**The knowledge to serve the owner's full request (6–12 × Maths/Phys/Chem/Bio) exists.** For classes
6–10 it lives under `subject='Science'` (the integrated NCERT book) with the discipline carried on
`academic_discipline`. This matters — see **W4**.

Fact→concept binding, verified by cross-database join:

```sql
-- all 1424 facts carrying provenance.concept_id resolve to a CERTIFIED ki_concept
facts_with_concept_id              1424
resolving_to_certified_ki_concept  1424   -- 100%, no dangling ids
distinct_concepts_filled           1362
```

### 1.2 Planner — `qie/knowledge/planner.py`

**Connected and sound.** `certified_universe()` reads *only* `ki_concept.status='certified'`
JOIN `ki_chapter.status='accepted'`. The module explicitly forbids reading `kie.db.concepts` and
forbids inferring curriculum truth from `source_documents.class_label`.

`check_plan()` runs six deterministic pre-generation refusals, each of which was previously a defect
caught only by paying generator tokens: junk/OCR-garbage concept names, uncertified concept id,
subject mismatch, name mismatch, class/chapter mismatch, archetype×depth incoherence, and unsupported
composition (partner must be same-subject and not above-class). `PlanRefused` costs zero tokens.

This is the strongest layer in the system.

### 1.3 Constraints — `qie/profiles.py` + `qie/archetypes.py`

**Connected.** 11 assessment profiles, each with a validated `valid_archetypes` / `core_archetypes`
set; archetype names are validated against `archetypes.ARCHETYPES` (20 archetypes) at import, so the
two vocabularies cannot drift. `planner._ARCH_DEPTH` binds each archetype to a legal reasoning-depth
range (`direct_recall` 1–1, `multi_step_numerical` 2–5, …).

### 1.4 Reasoning / Composition — `qie/compose.py` + `qie/compositions.py`

**Connected, and genuinely good.** An operator registry (`OPERATORS`) with typed steps wired
output→input; `reasoning_depth()` is *computed from the pipeline DAG*, not asserted. Every generated
item must satisfy **both** (a) a per-step independent check on every operator and (b) an independent
end-to-end recomputation by a *different route* — e.g. `min_value_quadratic` is solved by
differentiation and re-checked against the closed-form vertex formula; `area_between_roots` is
integrated symbolically and re-checked by `mpmath.quad` numerical quadrature.

Distractors carry real quality logic: physically-impossible negative values are dropped when the key
is positive, and magnitude-balance rejects anything outside [0.01×, 100×] of the key.

### 1.5 Difficulty Engine — `qie/knowledge/difficulty.py`

**Connected.** `diff-v1`: a deterministic, versioned, recomputable function of four drivers
(depth 0.50, concept_count 0.20, misconception_pressure 0.15, calculation_load 0.15) → easy/moderate/hard.
Honest by construction: `drivers_for_target()` returns the *closest achievable* band rather than
forcing an impossible difficulty. Caveat in **W9**.

### 1.6 Validator — `qie/factory/gates.py` (1,048 lines) + `qie/verifiers/`

**Connected. This is a serious battery.** 22 gates at three severities:

- **FATAL** (never certifiable): `schema`, `option_structure`, `stem_quality`, `archetype_known`,
  `duplicate_exact`, `solution_present`, `solution_matches_key`
- **QUARANTINE** (certification event, needs review): `near_duplicate`, `curriculum_boundary`,
  `dimensional`, `relation_grounded`, `composition_backed`, `visual_spec_present`,
  `stem_binding_givens`, `stem_binding_stem`
- **ADVISORY**: `archetype_agreement`, `depth_computable`, `depth_agreement`, `method_leak`

Plus `solution_verified` and `distractor_verified` (both FATAL) written by `factory/solutions.py`, and
seven independent verifier strategies under `qie/verifiers/` (deterministic_solver, symbolic_inverse,
independent_second_method, two_way, type_directed, per_step_e2e, kb_lookup).

`validate_run.py` runs **controls first, in both directions** — it proves the battery can still fail
known-bad items *and* that the comparator does not manufacture false disagreements — and aborts the
run if either control fails. That is correct discipline.

### 1.7 Certification — `qie/factory/certify.py`

**Connected and correctly paranoid.** Promotion requires the full conjunction, every link re-derived
rather than trusted, and every piece of evidence bound to the candidate's *current* `item_hash`
(so a replayed/stale verdict can never certify): gates ran with no FATAL and no QUARANTINE failure ∧
independent sympy re-derivation agreed ∧ `solution_verified` ∧ `distractor_verified` ∧ judge accepted
∧ the judge is provably cross-family ∧ row-level provenance complete ∧ not a bank-level duplicate.

Fail-closed defaults are correct: an absent/unknown judge family reads as *same*-family, not
cross-family.

---

## 2. The execution flow, as actually wired

There are **two** flows in this repository, not one. Both are real; they do not meet.

### Lane A — the Factory (model-proposed, deterministically certified)

```
ki_concept (certified)
  → run_planner.plan_blueprints        [class, chapter, boundary, archetype, depth, difficulty target]
  → blueprint_store.save_blueprints    → generation_spec rows
  → plan.compact_brief                 [concept + boundary + archetype; NEVER an answer]
  → ✱ MODEL proposes candidates ✱      → corpus.ingest (provenance enforced fail-closed)
  → validate_run: controls → 22 gates → sympy independent_solve
  → ✱ MODEL writes solution ✱ (key LOCKED first) → solution_verified + distractor_verified gates
  → ✱ CROSS-FAMILY MODEL judges ✱
  → certify_run(require_telemetry=True) → CERTIFIED
```

This lane satisfies **every** requirement on the owner's list — `class_level`, complete solution,
per-distractor named misconception with a machine-executed `mis_relation`, difficulty, concept
binding, provenance, full validator battery.

**Its current output is 0 rows.** `qie.db generated_item = 0`, `elite_question = 0`. It has two
mandatory live-model stages, one of which must be a *different model family* from the generator.
Per the standing owner decision recorded for Program C, no live call has ever been made ($0 spend),
and the 22 recalled items tested against the current gates passed 0/22. The lane is architecturally
complete and **operationally dormant**.

### Lane B — the Deterministic lane ($0, running today)

```
hardcoded template tables (TEMPLATES / TEMPLATE_REGISTRY)
  → parametric sample (seeded by content hash)
  → relation library / sympy operator pipeline computes the answer
  → deterministic second-solver verification + independent end-to-end check
  → pilot_verified_item  (1,496 rows banked)
```

62 distinct frames across Maths (calculus, determinants, matrices, complex numbers, series, Vieta),
Physics (Ohm, kinematics, energy, power, resistance networks), Chemistry (mole, molarity, dilution,
stoichiometry), Biology (genetics Punnett, process-sequence, structure→system).

This lane is fast, free, deterministic, and its answers are provably correct.

### The gap

**Lane B never touches the certified knowledge base, and never touches the validator.**

Verified:
- Lane B's "concepts" are `REL_OHMS_LAW`, `COMPOSE_AREA_BETWEEN_ROOTS`, `V=IR` — hardcoded pseudo-codes.
  **Zero** of them are `KC_*` ids from the 2,009-concept certified spine.
- Lane B items never enter the `candidate` table, so `gates.py` never runs on them. The only consumers
  of `compositions.run` / `generate_numeric.run` outside their own modules are the test suite and
  `qp_bridge.py`.
- Lane B emits no `solution` key at all.

So of the nine-stage flow the owner asked me to verify —
*Certified Knowledge → Planner → Reasoning → Constraints → Templates → Composition → Difficulty →
Generator → Validator → Certified Question* — the chain is intact from **Certified Knowledge through
Constraints**, and intact again from **Validator through Certification**, but the **Generator that
actually runs today is not attached at either end.**

---

## 3. Weak points, ranked

### W1 — P0 · The generator that runs is not bound to the certified knowledge base
Lane B generates from a hardcoded relation/template library. The 2,041 certified facts and 2,009
certified concepts are not an input to it. Consequence: nothing Lane B produces can honestly claim
"the certified concepts used", and the curriculum-boundary guarantee the owner requires is unenforced
because there is no concept to bound it against.

### W2 — P0 · Lane B output cannot pass the validator even if wired
`solution_present` and `solution_matches_key` are **FATAL** gates. Lane B emits no solution. Wiring
Lane B into `gates.py` today would FATAL-fail 100% of its items. A deterministic solution constructor
does not exist anywhere in the repo — solutions are written only by a model, in Lane A.

**Related defect found:** `qp_bridge._slot()` sets `solution=None` and then assigns
`solution_steps=item["provenance"].get("concepts")` — it writes the *concept list* into the
solution-steps field. Any paper assembled from Lane B carries no solution and a mislabelled field.
(`qie/qp_bridge.py:319,327`)

### W3 — P0 · Assertion–Reason is retired and unreachable
The owner's request explicitly includes Assertion–Reason. `qie/retired_families.py` retires it under
standing law **R3-8** (red team 2026-07-11): the frozen `kie/qpgen/templates.py::_ar_family.build`
hard-codes the key to `_AR_OPTS[0]`, i.e. option (a), for *every* AR item regardless of whether the
reason explains the assertion. `RETIRED_ARCHETYPES = {"assertion_reason"}` and no sanctioned caller
may assemble one. **No AR question can be generated today.** The retirement is correct; the fix is a
new QIE-side AR generator with a computed key, never an edit to the frozen engine.

### W4 — P0 · The planner is blind to classes 6–10 Physics/Chemistry/Biology
`certified_universe()` filters `WHERE c.subject = ?`. For classes 6–10 the certified rows carry
`subject='Science'` with the real discipline on `academic_discipline`. Verified:

```sql
-- planner's own query, for the owner's requested scope
SELECT COUNT(*) … WHERE c.subject='Physics' AND taught_at_class IN (6,7,8,9,10);  → 0
SELECT … WHERE c.subject IN ('Chemistry','Biology') AND taught_at_class<=10;      → (no rows)
```

`academic_discipline` is written by the build lane and appears in reports, but **no planning code
reads it** (grep: only `build.py` and `engineer.py`). So 524 certified Physics/Chemistry/Biology
concepts in classes 6–10 are invisible to the planner. Roughly **40% of the owner's requested
generation surface is unreachable** until the planner learns the discipline axis.

### W5 — P1 · 377 of the 1,739 "certified concepts" rest on the matcher the report itself distrusts
The reconciliation defines certified = (matcher-covered 943) ∪ (explicitly bound 1,362) = 1,739. The
same report correctly identifies the keyword matcher as producing false negatives — but the union then
uses matcher hits as *positive* evidence. Only the **1,362** concepts with an explicit
`provenance.concept_id` binding are safe to plan against; the other 377 are keyword coincidence until
re-bound. This does not invalidate the 86.6% headline, but generation should draw from the 1,362.

### W6 — P1 · 617 facts have no concept binding at all
617 of the 2,041 verified facts (the `corpus_MCQ`/examiner tier) carry no `provenance.concept_id`.
They bind only to a free-text `concept_candidate` such as `"Chemistry :: Biock Elements"` — note the
OCR corruption (*Biock* for *Block*), present in the live store. These cannot support
curriculum-bounded generation and must be excluded from the planning universe.

### W7 — P1 · `curriculum_boundary` is a term blacklist with a measured 0% hit rate
`spine.py` records the measured result of the 1,000-spec trial: the `curriculum_boundary` gate
"never fired once in 684 candidates," and the gate battery caught a known-garbage arm at 20.0% versus
20.1% for the legitimate arm — statistically identical. The gate derives from `forbidden_terms()`,
ranked above-class vocabulary. It is the weakest link in an otherwise strong battery, and it is
precisely the gate that enforces "stay within curriculum boundaries."

### W8 — P2 · No generator exists for four requested question forms
`case_interpretation` (case-study), `graph_interpretation`, `table_interpretation`,
`diagram_interpretation` are declared archetypes with profile bindings and lane mappings, but have no
generator in either lane. The visual lane is specification-only (`visual_spec_present` gates a spec,
it does not build one).

### W9 — P2 · Difficulty is effectively three-valued
`misconception_pressure` is hardcoded `0.0` ("until QDI v2") and `calculation_load` is a per-lane
constant, so in practice difficulty = f(depth, concept_count). For a single-concept numeric item only
a narrow band of scores is reachable. Usable, but it will not discriminate finely enough to claim
calibrated difficulty.

---

## 4. What this means for the generation objective

The owner's quality bar — *every question carries a complete solution, reasoning, the certified
concepts used, provenance, difficulty, and passes every deterministic validator* — is satisfiable by
**Lane A's contract** and by **no code path that currently runs**.

Two mutually exclusive routes forward:

**Route 1 — Build Lane C: a deterministic, certified-knowledge-bound generator ($0).**
Bind the generator to `ki_concept`, add a deterministic solution constructor (the operator pipeline
already knows every step it took — a solution is a rendering of the DAG it already computes, not new
knowledge), add discipline-aware planning (W4), add a computed-key Assertion–Reason builder (W3), and
route the output through the existing 22-gate battery. Reuses every layer; no new architecture. No API
spend. Ceiling: it can only generate forms the operator registry can *compute*, so case-study and
free-form conceptual HOTS stay out of reach.

**Route 2 — Open Lane A (live models).** Everything is already built and tested; it needs a generator
model, a cross-family judge model, and budget. This contradicts the standing $0 decision recorded for
Program C and would need an explicit owner reversal.

Route 1 is the recommendation: it is consistent with every standing decision (deterministic-first, no
request-path AI, no gate weakening, AI offline-only), and it is the only route that produces certified
output without an owner policy reversal.

---

## 5. Evidence appendix — commands used

```bash
# premise
sqlite3 qie.db "SELECT status, COUNT(*) FROM governed_fact GROUP BY 1;"
sqlite3 knowledge_index.db "SELECT status, COUNT(*) FROM ki_concept GROUP BY 1;"

# fact→concept binding integrity (cross-db join)
sqlite3 qie.db "ATTACH 'knowledge_index.db' AS ki; SELECT COUNT(*) FROM governed_fact gf
  JOIN ki.ki_concept c ON c.concept_id=json_extract(gf.provenance,'$.concept_id')
  WHERE gf.status='verified' AND c.status='certified';"

# W4 — planner blindness
sqlite3 knowledge_index.db "SELECT COUNT(*) FROM ki_concept c JOIN ki_chapter ch
  ON ch.chapter_id=c.chapter_id WHERE c.subject='Physics' AND c.status='certified'
  AND ch.status='accepted' AND c.taught_at_class IN (6,7,8,9,10);"   -- 0

# lane disconnect
grep -rn "compositions\.\|generate_numeric\." --exclude-dir=__pycache__ .   # tests + qp_bridge only

# regression baseline
python kie/tests/run_kie_suite.py   # ran=1318 failures=0 errors=0 skipped=1
```

---

**Verdict: ARCHITECTURE VERIFIED — NOT GENERATION-READY.**
The certified knowledge is real and correctly frozen. The planning, constraint, verification and
certification layers are well built and correctly paranoid. The generator that runs today is attached
to neither. Four P0 defects (W1–W4) stand between the current state and the owner's stated quality bar.
