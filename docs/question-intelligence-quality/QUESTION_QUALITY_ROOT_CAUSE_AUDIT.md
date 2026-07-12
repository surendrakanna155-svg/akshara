# Question Quality — Root-Cause Audit

**Date:** 2026-07-11 · **Author role:** Chief Assessment Intelligence Architect
**Type:** READ-ONLY audit. No code, DB, engine, or roadmap changed.
**Scope:** Why the Akshara Question Paper engine satisfies every constraint it checks and still
produces educationally weak questions.
**Evidence base:** first-hand read of `curriculum/scripts/intelligence/kie/qpgen/` +
`kie/phase7_questions.py` + `kie/curate/`; four independent read-only investigations (engine, knowledge
layer, docs, live DB + generated output); the mandatory inputs `KIE_BATCH0_STRUCTURE_INTELLIGENCE_STATE_2026-07-11.md`
(commit `775fd78e`) and `KIE_QUESTION_INTELLIGENCE_AUDIT_2026-07-11.md` (commit `da588ac3`).

> Per the owner's instruction, Batch-0 is treated as an **unimplemented hypothesis/prototype plan**,
> not an approved architecture. Its structure-mining idea is corroborated by this audit and folded into
> the roadmap as one phase among many — not adopted wholesale.

---

## 0. Verdict, up front

**The core hypothesis is proven true. The system confuses CONSTRAINT COMPLIANCE with QUESTION QUALITY,
and this is architectural, not incidental.**

Every gate the engine enforces is a *constraint* (in-syllabus, right subject, 4 distinct options,
answer-in-options, marks correct, no OCR artifact in the stem). **Not one mechanism in the entire
pipeline measures an educational property of a question** — not cognitive depth, not difficulty
realism, not distractor plausibility, not discrimination, not archetype diversity, not answer
correctness by independent solving. A question can be trivial, predictable, mislabeled, and shallow,
and pass every gate cleanly. We measured this on the live engine (§4).

A second, equally important finding sits underneath the first: **the engine is starved of content.**
Only **5.3% of active concepts (92 / 1,736)** can be filled by a template and **3.3% (57 / 1,736)** by a
usable definition. So the engine does two things badly at once — the small slice it *can* fill is
shallow-by-construction, and the 95% it *cannot* fill either ships as an authoring placeholder or, on
the descriptive path, ships raw OCR-damaged corpus text as a certified answer key.

Both problems trace to the **same root cause**: the pipeline throws away question *structure* at
ingestion and never builds a real *item model*. It reduces thousands of complete, solvable,
distractor-bearing exam problems to frequency-and-metadata tuples, then generates from ~94
hand-authored one-formula templates. There is no representation of what a question *is* as an
assessment object.

---

## 1. The 12 mandated questions, answered

### 1.1 Why does the current engine produce weak questions?

Six independent, compounding causes. Each is a code fact, not an opinion.

**C1 — There is no item model. The `QuestionSlot` object cannot represent quality.**
`kie/qpgen/models.py:124-143` defines the only question object. It carries `stem, options, answer,
solution` (all flat strings/lists), `bloom`, `difficulty` (bare enum labels), and a `provenance` dict.
It has **no field** for: cognitive-operation chain, assessment construct / learning outcome, difficulty
*drivers* (step count, concept count, calculation load), per-distractor rationale/misconception,
structured stepwise solution, or any visual/diagram spec. A property you cannot represent, you cannot
generate, validate, or improve. Quality is not modeled, so quality is not produced.

**C2 — Difficulty and Bloom labels are causally disconnected from the question content.**
The label is decided *before* the question text exists and is never reconciled against it.
- Origin: `kie/phase7_questions.py:66-81` computes `estimate_bloom` (verb keyword match) and
  `estimate_difficulty` ("text > 600 chars OR contains 'derive/prove' ⇒ hard") over *historical PYQ
  text* at ingest time, stores them on `question_patterns`.
- Flow: `pool.py:100-110` copies the label onto a `Candidate`; `select.py:165-177` stamps it onto the
  slot; `materialize.py` then writes a question for whatever label was already assigned.
- Contradiction inside the engine's own taxonomy: `pool.py:116-117` hard-codes **every** long-answer
  candidate to `difficulty=HARD, bloom=ANALYZE` regardless of content — while the stems it generates
  ("Explain…", "Describe…", `materialize.py:29-31`) are classified `understand` by the engine's *own*
  Bloom verb table (`phase7_questions.py:33`).
- No verification: grep confirms `validate.py` never references `bloom`; `select.py`'s `difficulty_met`
  / `bloom_met` flags only compare the inherited label to the *requested* label — never to the actual
  question. **A slot labeled `hard`/`analyze` can be filled by "Calculate 25% of 120."**

**C3 — Every generated archetype is shallow by construction.**
Measured from the loaded registry: **94 template families total** (52 engine-native + 42 from the
curate extension — corrected 2026-07-12; see Reconciliation Amendment). Of these, **88 (94%) are single-formula direct substitution** ("given X, Y, compute
Z"); 4 are fixed-structure assertion-reason; 1 is match-the-column; 1 is a distractor-less numerical.
There are **zero** multi-step, reverse, missing-variable, graph/data-interpretation, case-study,
error-analysis, or multi-concept-integration families anywhere. The descriptive path
(`materialize.render_deterministic`, `materialize.py:116-137`) emits verb+title strings ("Define X.",
"Explain X in detail."). This is the entire expressive range of the deterministic engine.

**C4 — The Assertion-Reason family has a textbook item-writing flaw, uncaught.**
`templates.py:535-544`: every AR instance hard-codes `"answer": _AR_OPTS[0]` — the correct answer is
**always option (a)**, with no rotation (MCQ options *are* rotated; AR is not). A student who marks
"(a)" on every AR item scores 100% on that item type. No gate detects position bias because
`_objective_violations` (`validate.py:74-98`) only checks 4-distinct-non-blank-options + answer-present.

**C5 — Validation is 100% constraint-shaped; every educational check is absent.**
`validate.py` gates: `OUT_OF_SYLLABUS`, `WRONG_SUBJECT`, `UNCLEAN_CONCEPT`, `BAD_TYPE`, `BAD_MARKS`,
`EXAM_MISMATCH`, `UNGROUNDED_STEM`, `LOW_QUALITY_STEM`, `BAD_OPTION_COUNT`, `MALFORMED_OPTION`,
`DUPLICATE_OPTIONS`, `NO_ANSWER`, `ANSWER_NOT_IN_OPTIONS`, `AMBIGUOUS_ANSWER` (string count),
`DUPLICATE` (exact concept+type key). **Absent** (grep-confirmed across `qpgen/` + `curate/`):
independent blind-solve answer verification, distractor plausibility scoring, semantic ambiguity
detection, near-duplicate/similarity detection, difficulty-driver verification, Bloom verification,
item-writing-flaw rubric (longest-option-correct, grammatical cues, all/none-of-the-above), visual
consistency, dimensional/unit validation. "solver_verified" (`materialize.py:171`) means the answer was
computed by *the same expression* that generated it — self-consistent by construction, **not**
independently re-solved.

**C6 — Selection controls concept spread but not archetype diversity.**
`select.py:98-113` (`_priority`) balances fill-strength → subject → chapter → importance tier → seed.
Nothing tracks `template_id` or archetype, so a paper can legally be 100% one archetype (and in
practice mostly is, since 88/94 families are the same archetype). No cross-paper exposure control exists
(grep: zero "exposure" hits in `qpgen`/`curate`). The frozen audit measured the consequence: **76% of
all printed items (272/357 in the latest run) are cross-paper clones**, `max_single_concept_reuse = 21`.

### 1.2 Which existing assumptions were wrong?

1. **"Certified corpus + certified engine ⇒ quality questions."** False. The production-readiness
   certification is scoped to *constraint* compliance; the frozen output audit measured **0 of 57 papers
   full-coverage teacher-ready**, ever, across four same-day runs.
2. **"Definitions are the JEE/NEET bottleneck."** False (and already overturned by the governing QI
   audit). The corpus holds ~5,224 clean computational MCQs with real human-authored distractors; the
   bottleneck is that Phase 7 discards their structure. Backfilling definitions treats a symptom.
3. **"A high template/family count means rich generation capability."** False. `question_families` = 2,015
   rows, **all `draft`, referenced by the engine zero times** — dead metadata. The real generative asset
   is 94 hand-authored Python functions.
4. **"`formulas` table encodes formula knowledge."** False. 317 rows, all bare law *names*
   ("Bernoulli's principle"); **zero contain an equation or a variable** (`phase5_concept.py:155-163`
   writes the name string into `expression`, `symbols=None`).
5. **"`mcq`-typed deterministic output are genuine MCQs."** False. The deterministic MCQ path produces
   numeric-answer items; genuine conceptual MCQs with plausible distractors are effectively absent from
   the AI-OFF path outside the narrow definition-match family.
6. **"Bloom/difficulty labels are trustworthy paper metadata."** False (C2). The audit measured
   difficulty-met at ~40% and compute items simultaneously labeled `bloom=remember, difficulty=hard`.
7. **"The 5 curate 'quality' phases fixed concept quality."** Partially false. Live sample shows junk
   still marked `active` and eligible for generation: `BIO_TIVITYTIVITY` (OCR garbage),
   `PHY_YOUNG_ONES_TO_ADULTS` (a Biology chapter title tagged Physics), `CHE_TOTIPOTENCY` (a Biology term
   tagged Chemistry — which leaked onto a served Chemistry paper). ~4/15 sampled active concepts were
   noise or mis-tagged.

### 1.3 Which components must remain untouched?

These are correct and load-bearing. Redesigning them would be destructive and is explicitly out of scope.

- **The template mechanism** (`templates.py`: parameterize by seeded hash → compute answer → render
  original). This *is* the target architecture (deterministic, original, reproducible, copyright-safe).
  Its weakness is what feeds it (hand-authored, one archetype), not how it works.
- **The `templates_ext` content-lane hook** (`templates.py:695-699`). Sanctioned zero-engine-edit growth
  path. All new families register here.
- **The deterministic boundary / scope engine** (`scope.py`, `chapters.py`, `sanitize.py`). Syllabus
  isolation is correct and must stay hard.
- **The validation scaffold** (`validate.py` structure, reject-with-reasons, fail-closed). We *extend*
  it with new gates; we do not rewrite it.
- **The gated AI seam** (`materialize.ai_fill`, structured-spec contract, cache-by-hash, re-validation).
  The gating discipline is correct; the *spec it hands the model* is the weak part (§1.9).
- **The frozen 57-paper output-quality matrix** (`qp_output_audit.py`). Keep as the constraint/coverage
  regression instrument. It is **necessary but not sufficient** — it must be *complemented* (not replaced)
  by a quality benchmark (§1, GOLD_BENCHMARK_PLAN).
- **The dormant Postgres `edu_*` mirror** and the empty `question_templates`/`distractors` SQLite tables —
  their *shape* is close to what Item Models need; reuse, don't recreate.
- **The licence ledger** (`RESOURCE_STORAGE_POLICY.md`, `ACQUISITION_STRATEGY.md`, per-resource
  `license_status`, `LICENSE_REPORT.md`). Already implements the classification the mission requires.

### 1.4 Which schemas need extension?

Extension, not replacement (detail in `CURRENT_VS_REQUIRED_ARCHITECTURE.md` + `ITEM_MODEL_SPECIFICATION.md`):

| Table | Today | Extension needed |
|---|---|---|
| `question_templates` (empty) | never populated | becomes the **Item Model** store: variable schema, constraints, answer function ref, distractor generators, cognitive chain, difficulty drivers |
| `distractors` (empty) | never populated | becomes the **distractor DNA / misconception** store: text, misconception_type, provenance |
| `question_families` (2,015 draft, unused) | metadata stubs | link families → item models; promote draft → certified per A2 |
| `formulas` (names only) | law names | add real `expression` + `symbols` (relation library, §MULTIMODAL) |
| `chunks` | no bbox, char offsets NULL, block_type only paragraph/table | add question-boundary block types, populate provenance |
| NEW `visual_assets` | does not exist | image/figure/equation/table assets + chunk links + semantic spec |
| NEW `generated_items` (schema exists, empty) | not written | persist generated instances + verification verdicts for calibration/audit |
| NEW `item_statistics` | does not exist (D6 schema locked in vision) | p-value, discrimination, distractor stats — **Phase 2, response-fed** |

### 1.5 Does Question DNA require a new object or an extension?

**A new object, persisted alongside the extended schema.** Question DNA is the *analysis* artifact
extracted from source questions (identity, construct, archetype, cognitive chain, difficulty drivers,
construction model, distractor DNA, solution DNA, visual DNA). It is L2 reference intelligence — it must
be stored **separately from source wording** (copyright) and separately from the production item
(`QuestionSlot`). It cannot be shoehorned into `question_patterns` (a 4-field metadata string) or
`QuestionSlot` (a rendered instance). See `QUESTION_DNA_SPECIFICATION.md`. Item Models
(`ITEM_MODEL_SPECIFICATION.md`) are the *generative* clustering of DNA and extend the empty
`question_templates` table.

### 1.6 How will downloaded PDFs be processed?

Today: single PyMuPDF pass + Tesseract fallback (<20 chars/page) + pdfplumber tables; images and
equations are extracted into a transient JSON side-file and **dropped at the DB boundary**; no
multi-column reading-order reconstruction; question stems/options/solutions are never separated at
chunking. This is inadequate for equation- and diagram-heavy competitive material. The plan
(`MULTIMODAL_INGESTION_ARCHITECTURE.md`) is a **parser-routing** pipeline benchmarked per document class
(native/scanned/multi-column/equation-heavy/diagram-heavy), with question-boundary + option +
answer/solution + visual association, and full provenance (resource_id, page, bbox, confidence) on every
extracted unit. **Never silently lose a diagram; never convert a diagram-dependent question to
text-only.**

### 1.7 How will images, diagrams, equations, tables be preserved?

Via a new `visual_assets` store (`VISUAL_INTELLIGENCE_SPECIFICATION.md`) that persists each asset with
type, bbox, source page, digest, and a **link to its chunk/question**, plus an "answerable-without-visual"
flag. Source assets live in the **analytical (L2) corpus only**. Production questions (L3) reference
**internally generated semantic visuals** (geometry/circuit/graph/etc. specs → deterministic SVG), never
copied source images. Tables (already preserved as `block_type="table"` chunks) are extended into a
`table_spec`.

### 1.8 How will original questions be created without shallow paraphrasing?

By learning **structure**, never wording. Pipeline (`ITEM_MODEL_SPECIFICATION.md` + roadmap Phase B):
source problem → extract Question DNA → cluster into an Item Model (variable schema, constraint ranges
learned from *real observed values*, answer function, distractor generators derived from the real wrong
options) → deterministically parameterize a **fresh** instance → **independently solve** → originality /
source-distance gate. Copyright safety comes from the fact that only the abstract structure is reused and
every instance is a new parameterization that is solver-checked — the mission's explicit rule ("do not
solve copyright risk by synonym replacement") is satisfied structurally.

### 1.9 How can small models generate quality output?

By moving intelligence **into the engine** so the model only does language realization. Today the AI
contract (`materialize.spec_of`, `materialize.py:308-316`) hands the model only `{concept, subject, type,
bloom/difficulty label, marks, "be original"}` and asks it to invent the entire item — the hardest
possible ask, one only a frontier model does acceptably. The redesign hands the model a fully-specified
**generation contract**: the Item Model has already chosen the concept, archetype, cognitive chain,
concrete parameters, the computed answer, and the distractor *intents*; the model's job shrinks to
"phrase this stem naturally and age-appropriately." A small model succeeds because it is no longer
inventing assessment logic. See `MODEL_ROUTING_AND_COST_PLAN.md`.

### 1.10 How will difficulty be predicted, then empirically calibrated?

Two explicitly separated quantities (`PSYCHOMETRIC_CALIBRATION_SPECIFICATION.md`):
- **Predicted difficulty** — computed deterministically from measured difficulty *drivers* (step count,
  concept count, calculation load, misconception pressure, distractor similarity, representation shift).
  This replaces the current label heuristic and is *verifiable* against the generated item.
- **Empirically calibrated difficulty** — from real student responses via the **marks-grid** capture
  already locked in D1 (**not** per-student OMR, which D2 forbids): p-value, discrimination,
  point-biserial, distractor selection frequency, and IRT (Rasch/2PL/3PL) when volume and assumptions
  permit. Aligns to the D6 `edu_item_statistics` schema already in the vision doc. **No LLM ever fabricates
  a discrimination index.** This is Phase 2 and needs the response spine seeded first.

### 1.11 How will answers and 4-5 step solutions be independently verified?

A dedicated **Independent Blind Solve** gate (D7 Layer 4, `QUALITY_GATE_SPECIFICATION.md` GATE 4-5): a
second, independently-implemented solver (deterministic relation library / CAS for numeric; a separate
model pass for verbal) answers the item *without seeing the key*. Answer mismatch ⇒ **REJECT**. Solutions
become a **structured step array** (identify → apply → compute → answer → optional verify), each step
machine-checkable for numeric items; the one-line prose `solution` string is replaced by this structure.

### 1.12 Exact implementation sequence

See `QUALITY_FIRST_IMPLEMENTATION_ROADMAP.md`. Summary: **A** foundations (item-model schema, DNA
store, benchmark harness, gate scaffold) → **B** structure-mining + item models from the existing corpus →
**C** the new quality gates (blind solve, distractor plausibility, item-writing rubric, difficulty-driver
verification) → **D** paper-level diversity intelligence → **E** multimodal ingestion + visual
intelligence → **F** psychometric calibration (Phase 2, response-fed). Gate at every step on the **gold
benchmark**, not on the generation endpoint working.

---

## 2. The mechanism, traced end-to-end (code)

```
cli.cmd_generate                                 kie/qpgen/cli.py:34-48
  → engine.generate(request)                     engine.py:86-152
      1 scope.resolve_scope()                     scope.py:108      — syllabus boundary (CORRECT)
      2 blueprint.resolve_blueprint()             blueprint.py:39   — structure only
      3 pool.build_pool()                         pool.py:93        — attaches bloom/difficulty FROM phase7 metadata
      4 select.select()                           select.py:116     — decides concept+type+label; NO archetype diversity
      5 materialize.materialize()                 materialize.py:275— writes text for the ALREADY-DECIDED label
          template → definition-match → spec → (gated AI)
      6 validate.validate_paper()                 validate.py:110   — constraint gates only
      7 assemble.assemble()                       assemble.py:112   — number/section/print filter
```

The load-bearing defect is the ordering: **concept + difficulty + Bloom are fixed in step 4, before any
question text exists in step 5, and nothing in steps 5-7 ever re-derives the label from the text.** The
label and the content are produced by different subsystems that never reconcile.

Upstream, the information loss is even more severe (`phase7_questions.py:92-150`): for each of ~14,000
detected PYQ problems it computes `(concept, type, bloom, difficulty)`, aggregates a frequency tuple,
writes a 4-field `stem_skeleton` metadata string, and at the top of the transaction runs
`DELETE FROM distractors, question_templates, question_families, question_patterns` — repopulating only
the last two. **The problem's formula, variables, values, options, distractors, reasoning, and answer are
discarded.** ~15,000 real human-authored distractors and ~8,600 equation-bearing chunks never reach
generation.

---

## 3. Component classification (EXISTS_AND_SUFFICIENT … MISSING)

| Component | Status | Evidence |
|---|---|---|
| Syllabus boundary / scope engine | **EXISTS_AND_SUFFICIENT** | `scope.py`, `sanitize.py`; boundary gates in `validate.py:34-39` |
| Template mechanism (param→solve→render) | **EXISTS_AND_SUFFICIENT** (as a mechanism) | `templates.py:24-72,667-685` |
| `templates_ext` content-lane hook | **EXISTS_AND_SUFFICIENT** | `templates.py:695-699` |
| Gated AI seam (gating + cache + re-validate) | **EXISTS_AND_SUFFICIENT** (gating); **EXISTS_BUT_WEAK** (the spec it sends) | `materialize.py:308-365` |
| Constraint validation gates | **EXISTS_AND_SUFFICIENT** (for constraints) | `validate.py:32-98` |
| Frozen output/coverage matrix | **EXISTS_AND_SUFFICIENT** (coverage); insufficient for quality | `qp_output_audit.py` |
| Licence / provenance ledger | **EXISTS_AND_SUFFICIENT** | `RESOURCE_STORAGE_POLICY.md`, `license_status`, `LICENSE_REPORT.md` |
| Item model / Question DNA object | **MISSING** | no field in `models.py`; `question_templates` empty |
| Difficulty drivers | **MISSING** | bare enum `models.py:31-36`; no driver computation anywhere |
| Difficulty-label verification vs content | **MISSING** | absent in `select/materialize/validate` |
| Bloom verification vs content | **MISSING** | `validate.py` never reads `bloom`; internal contradiction `pool.py:117` |
| Cognitive-operation / reasoning chain | **MISSING** | no field, no computation |
| Assessment construct / learning outcome | **MISSING** | only free-text `chapter` |
| Distractor rationale / misconception mining | **MISSING** | `distractors` table empty; bare `List[str]` options |
| Structured stepwise solution | **MISSING** | `solution` is one string |
| Independent blind-solve verification | **MISSING** | "solver_verified" = self-consistent-by-construction |
| Distractor plausibility scoring | **MISSING** | only string-distinctness checked |
| Similarity / near-duplicate detection | **MISSING** | only exact `(concept,type)` dedup |
| Item-writing-flaw rubric | **MISSING** | AR always-answer-(a) flaw uncaught |
| Archetype-diversity control in selection | **MISSING** | `select._priority` has no archetype term |
| Exposure control (cross-paper/cohort) | **MISSING** | grep: zero hits |
| Multi-step / reverse / graph / case-study archetypes | **MISSING** | 88/94 families = single-substitution |
| Image / diagram / equation persistence | **MISSING** | dropped at DB boundary; no `visual_assets` table |
| `formulas.expression` = real equation | **EXISTS_BUT_WEAK** (names only) | `phase5_concept.py:155-163` |
| Question-boundary chunking (stem/option/solution) | **MISSING** | block_type only paragraph/table |
| Psychometric calibration (p/discrimination/IRT) | **PARTIAL** (D6 schema locked, dormant) | `Assessment-Intelligence-Platform.md` §10.1 |
| Gold benchmark / blind expert review | **MISSING** | not built; D7 §11 spec only |
| Model routing / cost tiers | **PARTIAL** | live ERP client exists; no KIE-side tiering |
| 2,015 draft `question_families` | **REDUNDANT** (as-is) | unused by engine; repurpose per A2 |
| `question_patterns` metadata index | **EXISTS_BUT_WEAK** | usable as a difficulty/frequency prior only |
| Batch-0 structure-mining plan | **CONFLICTS_WITH_CURRENT_ARCHITECTURE** only if treated as approved; **PARTIAL** as a hypothesis | folded into roadmap Phase B |

---

## 4. Live evidence — what the engine actually serves today

Generated by invoking the production `QuestionPaperEngine` read-only against `kie.db`, AI OFF, matrix
seeds. Verbatim.

**The correct-but-shallow slice (numeric MCQ, `neet_full`/`foundation_mixed`):**
```
STEM: A charge of 24 C flows through a conductor in 6 s. Calculate the electric current.
OPTIONS: ['4 A', '24 A', '144 A', '6 A']   ANSWER: 4 A   SOLUTION: I = Q/t = 24/6 = 4 A.

STEM: A triangle has a base of 16 cm and a height of 4 cm. Calculate its area.
OPTIONS: ['64 cm²','20 cm²','40 cm²','32 cm²']  ANSWER: 32 cm²  SOLUTION: Area = ½ × base × height = 32 cm².
```
Arithmetically correct — and every one is single-step plug-and-chug. Distractors are arithmetic
near-misses, not diagnosed misconceptions. No cognitive depth, no discrimination.

**The failing slice (descriptive path — the ONLY path for ~95% of concepts):**
```
STEM: Describe Power.
ANSWER: thetime rate at which work is done or energy istransferred          ← raw OCR-glued text, shipped as key

STEM: State the meaning of Bond length.
ANSWER: the equilibrium                                                      ← demonstrably WRONG/truncated key

STEM: Explain the power P ofa lens.
ANSWER: the tangent of the angle by which itconverges or diverges a beam ... falling at unit distance from the opticalcentre (Fig
                                                                            ← truncated at a figure ref; glued words

STEM: Define Totipotency.   (served on a CHEMISTRY paper)                   ← Biology concept, cross-subject leak
```
These pass every gate. The frozen matrix's `gate_stem_artifacts` checks the **stem only, never the
answer/solution**, so glued-word garbage in the answer key is invisible to it — a gap in the audit
instrument itself.

**Coverage reality (latest frozen run):** print coverage 21%, objective fill 14.1%, **teacher-ready
full-paper (≥99.9% coverage) = 0 of 57 in every run ever**; 272/357 printed items are cross-paper clones;
NEET Biology objective = 0% fillable; only Foundation configs (which happen to overlap the 92 templated
concepts) reach ~92-96%.

---

## 5. Bottom line

The engine is a well-built **constraint satisfier** sitting on top of a knowledge layer that **discarded
the very structure needed for quality**. It does not model what a question *is* as an assessment object,
so it cannot generate, measure, or improve educational strength — only format legality. The path forward
is not another prompt patch and not more definitions. It is: (1) a real **item model** and **Question
DNA**; (2) **learning** solver-verified parametric families (with real distractor strategies) from the
corpus the pipeline currently throws away; (3) **quality gates** that measure educational properties
(independent solve, distractor plausibility, difficulty drivers, item-writing rubric, diversity);
(4) a **gold benchmark with blind expert review** as the success metric — not the endpoint returning 200.

**Recommendation: approve the phased roadmap in `QUALITY_FIRST_IMPLEMENTATION_ROADMAP.md`. Do not scale
generation to lakhs of items until the benchmark shows a measured, blind-reviewed quality lift over the
current engine. 100 excellent questions before 100,000 weak ones.**

---

## Reconciliation Amendment (2026-07-12, post-Fable-5)

Governed by `OPUS_FABLE_RECONCILIATION_RECORD.md`. Corrections after independent re-measurement:

- **C3 count:** the native/extension split is **52 + 42 = 94** (not 46 + 42). Conclusion unchanged
  (88/94 = one direct-substitution archetype). (Record F1)
- **C4 deepened:** the Assertion-Reason flaw is **semantic, not merely positional** — every AR family is
  authored so assertion and reason are both true restatements of one law, so the correct answer is
  constantly "(a)". Position randomization is necessary but **insufficient**; the fix is genuine AR
  construction that produces and independently verifies all four relation classes (the ASSERTION_RELATION
  lane). (Record F2)
- **C6 within-paper duplication:** the earlier "within-paper 0" claim was true only for its snapshot;
  the latest frozen run has **10/54** papers with a duplicate stem, caused by two active concepts
  (`PHY_OHM_S_LAW`, `CHE_OHMS_LAW`) binding the same universal template while dedup keys on
  `(concept_code, question_type)`. Requires family-equivalence dedup + rendered-stem dedup. (Record F4)
- **Corpus scope:** active Biology = **525** (the "919" figure is all-status incl. rejected/merged); only
  20/525 carry a definition. Biology is served only by the **non-numeric lanes** (Record §2), which the
  original single numeric archetype could not express. (Record F8)
- **Root cause sharpened:** add a third compounding cause — *the sole generative lane is numeric-only and
  structurally cannot serve Biology / non-numeric science.* (Record §3)
- **Grounding bypass:** template-sourced MCQ/numerical items are exempt from the grounding check
  (`validate.py: if needs_grounding and src != "template"`), so a keyword-mismatched template item (e.g.
  "Volume of a Sphere" → cuboid formula) prints clean; concept binding moves to canonical concept-code
  scope. (Record F5)
