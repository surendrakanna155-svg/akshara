# Balanced full JEE/NEET papers — the precise coverage gap (STOP-and-REPORT)

**Date:** 2026-07-14 · Owner asked: broaden honest QIE concept span across the core subjects **using existing
certified scope/corpus/KVS/verified evidence** to reduce the Math skew and prove *balanced* full papers through
qpgen; and — *"if the existing evidence cannot support the concept coverage required for genuinely balanced full
papers, stop at that exact point and report the precise missing concept-layer/evidence scope needed to unblock
it, rather than requesting generic acquisition."* This is that report.

## What I did first — maximize coverage from existing evidence
Wired every existing verified qie source into the bridge (compositional templates across all 4 domains +
single-concept Math generators + the `generate_numeric` relation library V=IR/P=V²R/v=u+at/…). No force-binding;
no gate weakened. Result: Physics coverage rose 2→5 concepts (added *Ohm's law*, *Laws of Motion*, *Frequency*).

## Measured coverage ceiling (distinct certified in-scope concepts qie can honestly bind)

| Profile | Mathematics | Physics | Chemistry | Biology |
|---|---|---|---|---|
| **JEE_MAIN** | 6 / 48 | **5 / 112** | **0 / 36** | — |
| **NEET** | — | **5 / 144** | **0 / 59** | 3 / 93 |

Best-achievable papers (seed 7, through the real qpgen path, `boundary_ok`, 0 rejects): JEE_MAIN 13 printable
(8 Math + 5 Physics + **0 Chemistry**), NEET 8 (5 Physics + 3 Biology + **0 Chemistry**). **Balanced full
papers (JEE 75Q across 3 subjects, NEET 180Q across 3) are NOT achievable from existing evidence** — Chemistry
is completely uncovered and Physics is at ~4%.

## Root cause — the existing evidence has concept NAMES but not machine-usable CONTENT
Measured, read-only:
- **`formulas` (317 rows):** `expression` = the law's *name* ("Bernoulli's principle", "Stoke's law"),
  `symbols` = **NULL for all 317**, **0** rows carry an equation. → cannot ground a numeric item.
- **KVS structured tables** (`kvs_sequence`, `kvs_structure_function`, `kvs_comparison`): **empty**;
  `kvs_assertion`/`kvs_taxonomy`: document-structure noise.
- **`question_patterns`:** per-concept structure (type/bloom/frequency) but **no stems/answers**.
- **`tier2_verdict`:** 411 verified Biology facts, but **free text** — structuring them into deterministic MCQs
  would require an LLM as the truth source (forbidden by the locked hierarchy).
- **`generated_items`:** empty.

So qie can only cover the ~11–14 concepts for which qie itself hand-built a template/relation. Everything else
in the certified scope is a name without machine-usable content.

## The precise missing evidence-layer (NOT generic acquisition)
The concepts and raw corpus already exist; what is missing is a **structured, machine-usable layer keyed to the
certified `concept_code`s**, in two parts:

**(1) Quantitative relations for the certified named-law/formula concepts.** For each formula-concept, populate
`formulas.symbols` + a solvable relation `{equation, variables, units, valid ranges}`. This is the dominant gap
in Physics & Chemistry:
- Physics uncovered: **107 (JEE) / 139 (NEET)** concepts, of which **58 / 90 are named laws**
  (Coulomb's, Ampère's, Biot–Savart, Lenz's, Bernoulli's, Avogadro's, gas laws, optics, AC…).
- Chemistry uncovered: **36 (JEE) / 59 (NEET)**, of which **23 / 42 are named laws**
  (Kohlrausch, Charles's, Bohr's frequency, Nernst-type, equilibrium/kinetics relations…).
- Covering even the ~40–60 *core* quantitative laws per exam would let the **existing** relation-solver generate
  verified items bound to those exact concepts — no engine change.

**(2) Structured qualitative facts for the certified descriptive concepts.** (structure→function→system),
(process→ordered steps), (cause→effect), (taxon→rank) triples keyed to concept_codes — the layer the empty KVS
tables were meant to hold. This is the dominant gap in Biology:
- NEET Biology uncovered: **90** concepts, **75 descriptive** (Anaphase, Cardiac Cycle, Blood Groups,
  Biodiversity, Anatomy, Basidiomycetes…). `bio_data.py` curated ~10 of these by hand as a proof; scaling to the
  ~90 needs the structured-fact layer populated (the 411 free-text verified facts are the raw material, but must
  be structured into typed relations — a governed structuring task, not free acquisition).

**(3) Concept-layer hygiene (secondary).** A fraction of certified titles are OCR artifacts
("Ampere's circ law", "Biot-Sa law", "Applyingthe second law", "Answer Using the gas law"); these inflate the
denominator and would mis-label even if covered.

## The genuine owner-level decision (why I stop here)
Balanced full papers require **building the structured relation/fact layer above for the ~300 certified
concepts** — populating `formulas.symbols`/relations and the KVS fact tables, keyed to existing concept_codes,
from the existing corpus + the 411 verified facts. That is a **scoped evidence-structuring program**, not a
generic acquisition, and it is genuinely the owner's call on scope and method:
- **(A)** curated-canonical relations/facts for the core ~40–60 laws + ~90 Biology concepts (the sanctioned
  `chem_data`/`bio_data` pattern, extended — deterministic, fast, but hand-authored canonical knowledge), or
- **(B)** governed structured extraction from the existing corpus/411-facts into the relation/fact tables
  (uses only existing evidence; needs a governed extractor with the verification hierarchy, heavier).

Everything else is ready: the engine, the verification hierarchy, the honest binding, and the qpgen path all
work end-to-end (proven). The single blocker to *balanced* papers is this structured evidence-layer. **No broad
acquisition is requested.** `qpgen`/`kie.db` untouched; bank not promoted; acquisition remains HOLD.
