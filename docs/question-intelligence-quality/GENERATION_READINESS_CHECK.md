# Generation-Readiness Check — against the JEE/NEET design goal (measured, read-only)

**Date:** 2026-07-13 · **Status:** read-only audit; no generation, no corpus, no Certified-Bank change, no
architecture redesign. Proves whether the current generation path can generate with Class 6–12 boundary-aware
concept intelligence under a target JEE Main / JEE Advanced / NEET profile. Evidence = kie.db + qpgen code +
the corrected capability run.

## The six required capabilities — measured verdict

| # | Capability | Verdict | Measured evidence |
|---|---|---|---|
| 1 | Class 6–12 concept progression + prerequisites | **PARTIAL** | `concepts.typical_grade_low/high` **97% populated** (grades 6→12 present). BUT prerequisites are **near-absent: 10 `prerequisite` edges** (vs 1,482 generic `related`, 162 `parent_child`), and qpgen `scope.py` scopes by **document grade-band**, not concept-level progression. |
| 2 | Lower-class foundation without violating exam boundary | **BLOCKED** | `foundation_boundary` **0% populated**; no prerequisite graph to pull foundation concepts; qpgen boundary = a flat in-band `concept_codes` set. No mechanism to safely include foundation prerequisites. |
| 3 | Target-profile boundaries (JEE Main / Advanced / NEET) | **PARTIAL** | qpgen `presets.EXAM_PROFILES` **defines JEE_MAIN, JEE_ADVANCED, NEET** (subjects + grade_band + blueprint), so profile *scaffolding* exists. BUT the **concept boundary data does not differentiate them**: all **3,006 `concept_board_mappings` are `jee_neet_foundation`**, and all three grade_bands are (11,12). Profiles differ only in blueprint (paper structure), **not concept/depth boundary**. |
| 4 | Subject and concept scoping | **READY** | `scope.resolve_scope` enforces subjects-within-profile + a hard `concept_codes` boundary; validation rejects out-of-scope/wrong-subject items. |
| 5 | Certified archetype/model capability | **BLOCKED** | The Phase-C certified Item Models live in **qie.db `item_model`**; qpgen generates from **kie.db `question_patterns` + concept definitions + in-code templates**. `models.py:149 item_model_id` is an explicit **placeholder** ("later phases will populate; nothing uses it yet"). **No certified-model → question-instance generator exists** anywhere. The certified capability is a *measurement*, not a generator. |
| 6 | Verification gates (answer + solution correctness) | **PARTIAL** | `validate.py` enforces NO_ANSWER / ANSWER_NOT_IN_OPTIONS / AMBIGUOUS_ANSWER + grounding; `select.py` ranks solver-verified templates first. BUT the **independent relation-solver / KVS / Tier-2 verification that certified the capability is NOT in the generation loop**, and **`distractors` = 0** (no distractor bank → MCQ distractor generation unsupported). |

## Generation content (measured, kie.db)

`question_patterns` **4,853** · `question_templates` (in-DB) **0** (templates are in-code, ~80) · concepts with
`definition` **57 / 1,692 (3%)** · `distractors` **0**. Conceptual/MCQ generation is content-starved.

## Certified models by profile (corrected capability run, 2026-07-13)

| Profile | Certified models |
|---|---|
| NEET | Biology **20**, Physics **11**, Chemistry **~1** |
| FOUNDATION | Physics **13** |
| **JEE_MAIN** | **0** |
| **JEE_ADVANCED** | **0** |

## Per-profile readiness verdict

| Profile × Subject | Verdict | Blocking reason |
|---|---|---|
| **JEE Main — Physics** | **BLOCKED** | 0 certified models; certified capability not wired to generation (#5); profile boundary not differentiated from foundation (#3). |
| **JEE Main — Chemistry** | **BLOCKED** | Same as above. |
| **JEE Main — Mathematics** | **BLOCKED** | Same + Math evidence is JEE calculus with **0 school-library-verifiable models**; no template/certified coverage. |
| **JEE Advanced — Physics** | **BLOCKED** | 0 certified models; JEE_ADVANCED profile is owner-gated (permitted=false); not wired (#5). |
| **JEE Advanced — Chemistry** | **BLOCKED** | Same. |
| **JEE Advanced — Mathematics** | **BLOCKED** | Same + calculus depth, 0 verifiable models. |
| **NEET — Physics** | **PARTIAL** | 11 certified numeric models EXIST but **not wired to generation** (#5); profile scoping + validation work; prerequisite/foundation boundary absent (#1/#2). |
| **NEET — Chemistry** | **PARTIAL** | Thin certified count; same wiring gap. |
| **NEET — Biology** | **PARTIAL** | The strongest cell — **20 certified factual models** — but **not wired to generation** (#5), and conceptual content is starved (definitions 57, distractors 0). |

## Can the engine safely begin a controlled 100–300 question pilot using Class 6–12 boundary-aware concept intelligence?

### **NO.**

The generation engine (qpgen) can scope and validate boundary-safe papers, but it **cannot use the certified
capability we just proved**, and the **boundary-aware concept intelligence the goal requires is not present**.
A pilot today would run the old template/definition path (content-starved, no distractors, no certified
models), not the certified, boundary-aware, profile-controlled generation the goal describes.

### Minimum verified blockers to fix before a pilot (only the essential, measured)

1. **No certified-model → question-instance generator (the wiring gap).** Build the bridge that instantiates
   the qie.db certified Item Models into new questions and runs them back through the independent
   solver/KVS/Tier-2 verification. Without this, the pilot cannot use the certified capability. *(Capability
   #5 — primary blocker; affects all 9 cells.)*
2. **Profile boundaries do not differentiate JEE Main / Advanced / NEET.** All concept mappings are
   `jee_neet_foundation`; there is no per-profile concept/depth boundary for the target profile to control
   behaviour. *(Capability #3.)*
3. **Prerequisite / foundation-boundary intelligence is near-absent** — 10 `prerequisite` edges,
   `foundation_boundary` 0%. Class 6–12 boundary-aware selection and safe foundation inclusion cannot be
   enforced. *(Capabilities #1, #2.)*

*(Secondary, content — not structural blockers but they cap quality: definitions 57/1,692, distractors 0,
in-DB templates 0; and JEE Mathematics evidence is calculus with 0 verifiable school models.)*

**Narrowest viable first pilot once blocker #1 is fixed** (noted for planning only, not started): NEET Biology
factual_single_best_answer, drawing from the 20 certified models — it is the single cell with both certified
capability and diverse verified evidence. It still needs blocker #1 (the generator + in-loop verification) and
a distractor source before it can run.

**STOP for owner review.** No code changed, no generation run, no corpus acquired, Certified Bank untouched,
no difficulty/visual/board work started.
