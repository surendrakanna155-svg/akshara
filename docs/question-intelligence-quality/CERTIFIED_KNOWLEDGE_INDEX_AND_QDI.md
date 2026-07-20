# Certified Knowledge Index + Question Design Intelligence — Maths Vertical Slice

**Date:** 2026-07-16 · **Status:** Stages 1, 1.5, 2, 2b, 6 DONE and proven. Stages 1.5b/3/5 BLOCKED on the
API session limit (resets 1:10am IST) — they are model stages; the harness is built, controlled and ready.

QIE was **redefined, not rebuilt**. Preserved and reused: archetypes (20-value canon), reasoning-depth work,
composition/operator work, the factory harness + its 3 control suites, the certified/rejected corpus
evidence, and every existing OCR chunk. No re-download. No re-OCR. The frozen engine was not edited.

Slice = **Mathematics**: the only lane with provable single-subject sources across Classes 6–12 AND a real
deterministic verifier (sympy + the 9 algebra/calculus operators; 96.6% agreement in the 1,000-spec trial).

---

## The architecture now built

```
  Certified Curriculum Boundary (ki_*)      WHAT may be asked   — from owned NCERT single-subject books
+ Certified Question Design Intelligence    HOW to build it well — from owned real JEE/NEET papers
                    (qdi_*)                 (structure only; never wording)
  -> repaired QIE planner (pre-generation gate)
  -> structured brief -> Opus original construction
  -> lane verification -> survivor solutions -> Certified Question Bank
```
The two layers are certified independently and stored separately. `brief.py` joins them only at brief-time.

---

## STAGE 1 — CERTIFIED KNOWLEDGE INDEX (done)

| | |
|---|---|
| Source books admitted (subject **proven** from NCERT filename code) | **12** |
| Chapters (deterministic spine) | **49** |
| Numbered curriculum topics found | **330** |
| Junk rejected **before any token was spent** | **1,761** |
| Concepts proposed by the knowledge engineer | 206 |
| Independently audited | 203 |
| **CERTIFIED** | **175** (86.2% accept) |
| Quarantined / rejected by the audit | 21 / 7 |
| Class corrections by the audit | 5 |
| Certified concepts carrying an **evidenced `out_of_scope` wall** | **175 / 175** |
| Certified concepts carrying **evidenced prerequisites** | **133** |
| Rejected-knowledge evidence (separate, permanent store) | **1,921** |

Certified by class: **6 → 52 · 7 → 98 · 8 → 24 · 9 → 1**.

### How the process (not a patch-list) fixes the contamination
- **Subject** is derived from the NCERT filename code, never from `source_documents.subject`. Integrated
  Science (`sc`/`cu`) is structurally excluded — no filename can say whether a concept inside an integrated
  book is physics or biology. Proof it works: `Class8_hegp1dd` — the Ganita Prakash **maths** book whose
  concepts the old table filed as `CHE_SQUARE_NUMBERS`, `CHE_CUBIC_NUMBERS` — is now correctly
  `Mathematics :: A Square and A Cube :: Square Numbers`.
- **taught_at_class** means "a NUMBERED taught section of THAT class's own single-subject textbook",
  proposed by an engineer and accepted by an independent auditor. `mentioned_in_source` is provenance only
  and never reaches a brief.
- **Junk dies deterministically, upstream.** In the maths corpus: 330 numbered topics vs 5,722 activity/
  furniture segments. The engineer never sees the junk, so it never has to be trusted to filter it.
- **Nothing was patched by hand.** `Gahe tava jaya gatha`, `Contributors`, `Gauss's law ×3` were never
  individually removed — they simply cannot enter a spine built from numbered curriculum headings.

### What the independent audit refused (a second model, blind to the engineer)
> *"'More on the Decimal System' is a pure navigational section header"* ·
> *"Activity label (a paper-folding exploration), not an assessable concept"* ·
> *"Section header with empty sub-concepts and a vacuous in_scope"*

### Example of the certified output
`Class 8 · A Square and A Cube · Square Numbers`
- sub-concepts: *"a square never ends in 2, 3, 7 or 8"*, *"the sum of the first n odd numbers is n²"*
- prerequisites: *"Area of a square as the product of its sides"*
- **out_of_scope**: *square roots and methods of finding them · irrational numbers and surds · the
  identity (a+b)² · Pythagoras theorem*
- It even captured a one-way-test nuance: *"using the units digit to prove a number IS a square — the
  evidence states the test is one-way (26 ends in 6 but is not a square)"*

---

## STAGE 1.5 — QUESTION DESIGN INTELLIGENCE (built; certification blocked)

The curriculum index is the boundary layer. It cannot make an item *good*. QDI is the separate layer that
learns **how real JEE/NEET items are built**, from ~20k owned, already-chunked exam papers.

**Why a new layer rather than reusing what exists (measured, not assumed):**
- `qie.db question_dna` (2,996 rows): `construction` = `{"relation":"sum_n","answer":3.0}`; distractor
  transforms are the literal string `"other"`; `provenance` EMPTY; `solution_dna` 0/2996;
  `difficulty_drivers` 0/2996.
- `kie.db question_patterns` (4,853 rows): `stem_skeleton` = `"mcq|bloom=analyze|difficulty=hard|options=4"`
  — a metadata string, not a structure. All rows `exam='foundation'`, subject blank.

Neither is design intelligence. The **raw** material is rich and owned: NEET Physics 7,598 chunks · JEE Main
4,868 · NEET Chemistry 2,661 · JEE Advanced Physics 371 · Practice Maths 223 — many carrying the question
*and* its answer.

**Result on the maths slice: 12 patterns extracted** (5 hard, 7 moderate; 5 constraint_coupled,
6 sequential_chain, 1 state_change) from real JEE Main/Advanced maths papers.

Example (machinery only — no source wording exists anywhere in it):
> **"oblique motion with an inert velocity component"** — hard · sequential_chain · evidenced by 2 real items
> **dependency**: *"The symmetry analysis outputs a unit direction; the vector decomposition consumes that
> direction and outputs a scalar effective rate; the rate law consumes that scalar."*
> **difficulty_mechanism**: *"A discovered constraint plus a trap that punishes a shortcut. The obliquity is
> not decoration: one component produces no effect at all, and nothing in the statement says so — it must be
> inferred."*
> **distractor**: *{"misconception": "treats the stated speed as the effective rate, ignoring that motion
> along the symmetry axis produces no change"}*

### The anti-copying rule is enforced in code, not asked for in a prompt
`assert_no_copying()` compares every stored text field against the source chunk at 5-gram shingle level.
Measured: a copied/paraphrased stem scores **77–100% → REJECTED**; genuine abstract machinery scores
**4.4% → stored**. Clean separation.

---

## STAGE 2 — REPAIRED QIE INPUT CONTRACT (done)

QIE now consumes **only** `ki_concept.status='certified'`. It may not read `kie.db.concepts`, and it never
infers curriculum truth from `source_documents.class_label`.

**12/12 adversarial pre-generation controls pass, with zero false positives.** Every defect the 1,000-spec
trial's generator had to catch *at token price* is now refused **for free**:

| control | now refused as |
|---|---|
| national anthem as a Class-10 maths concept | `uncertified_concept` |
| `Contributors` / `Try These` | `junk_record` |
| `Telateltelt` / `answeranswer` (repeated-syllable OCR) | `junk_record` |
| subject mis-binding (**49.7% of all trial refusals**) | `subject_mismatch` |
| doc-label class leaking in as truth | `class_mismatch` |
| `direct_recall` at depth 3 (the planner's own bug) | `archetype_depth_incoherent` |
| Newton's law × Aufbau's principle | `unsupported_composition` |
| partner concept above the class | `unsupported_composition` |

**Proven on real data:** 175 certified concepts → **120 specs planned → 120 issued, 0 refused**. The gate
finds nothing to refuse there because the junk died upstream; its power is proven by the controls.

**Governance visible in the output:** with 0 certified design patterns, the planner issued **0 hard specs** —
it refuses to claim "hard" without an evidenced mechanism rather than faking difficulty with bigger numbers.

---

## Defects found and fixed during this build (each caught by a control or by real data)

1. **Chapter-id collision** — `CH_<subj>_<class>_<no>` silently collapsed 39 ingested chapters into 22
   (Class 7 has three parallel books, all with a chapter 1). Now includes the doc.
2. **Worksheet→book mis-mapping** — write-time indexed over docs *with* chapters (10); ingest indexed over
   *all* docs (12). Class 6's output was being attributed to a **Class 11** book. This is precisely the
   silent mis-attribution the rebuild exists to eliminate. Fixed; re-ingested from scratch.
3. **OCR-garbage detector missed repeated-syllable artifacts** — `Telateltelt`, `answeranswer` are syllable
   repetition, invisible to char-repeat/consonant-run checks. Added an n-gram repetition measure
   (`answeranswer` 1.00, `Telateltelt` 0.82) with **zero false positives across 19 real maths concepts**.
4. **`^\w{0,3}$` false-positived on `Ray`** — a certified Class-6 geometry concept, and would equally have
   killed `Set`, `Arc`, `LCM`, `HCF`, `Pi`. Brevity is not a garbage signal. Removed.
5. **QDI ingest discarded structure-complete patterns** over a missing prose field. A pattern *is* its
   structured machinery; the summary is now composed from the structure instead of dropping 5 real patterns.

---

## BLOCKERS (exact)

| stage | blocker |
|---|---|
| **1.5b — independent QDI audit** | **API session limit** (resets 1:10am IST). 12 patterns remain `proposed`; **0 certified**, so no hard specs may be issued. Worksheet ready at `qdi/qaudit.md`. |
| **3 — candidate generation** | Same session limit. 3 briefs × 40 specs are written and validated (`gen/g0..g2.md`). |
| **5 — solution construction** | Same session limit. Harness ready. |

Stage 4 (verification) needs no model: the factory battery + 3 control suites (10 adversarial, 8 notation,
4 magnitude) are green and run in ~6 s at zero token cost.

**Coverage limitation (not a blocker, but real):** the certified index is strong at Classes 6–8 (174 of 175
concepts) and thin at 9–12 (1). The numbered-heading signal is weak in the senior books, so those need a
different spine strategy before JEE/NEET-level curriculum coverage is real.

---

## Artifacts

Code (committed): `curriculum/scripts/intelligence/kie/qie/knowledge/`
`spine.py` · `index_schema.sql` · `engineer.py` · `planner.py` · `plan_controls.py` · `plan_specs.py` ·
`brief.py` · `qdi.py` · `qdi_schema.sql`

Data (LOCAL-ONLY, gitignored): `curriculum/knowledge/kie/knowledge_index.db` — `ki_*` (curriculum) and
`qdi_*` (design) as distinct namespaces, each with its own separate rejected-evidence store.
