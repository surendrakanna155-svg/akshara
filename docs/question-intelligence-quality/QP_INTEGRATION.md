# Wiring the unified compositional engine into the QP/product generation path

**Date:** 2026-07-14 · Owner decision #2. Integrate the proven qie engine THROUGH the existing (frozen) qpgen
architecture and governance — **not** a parallel paper generator. Prove the end-to-end path
blueprint → verified compositional candidates → selection/assembly → final paper, with genuine paper-level
quality and depth balance, rejecting unsuitable items rather than filling quotas. Bank stays on-demand
(not promoted/materialized); acquisition stays HOLD; `qpgen` and `kie.db` untouched.

## The end-to-end path (`kie/qie/qp_bridge.py`)

```
PaperRequest ─▶ scope.resolve_scope ─▶ blueprint.resolve_blueprint ─▶ [qie engine: verified candidates]
             ─▶ honest concept-binding ─▶ blueprint-driven selection (depth-balanced, dedup, reject)
             ─▶ validate.validate_paper ─▶ assemble.assemble ─▶ render (student paper + answer key)
```

Everything except the two bracketed steps is qpgen, **reused unchanged**: the certified scope (syllabus
boundary), the authentic exam blueprint (structure/marks/sections/difficulty), the hard validation gate, the
assembler, and the render-honesty split (student paper vs authoring worklist). The bridge only supplies the
item source and the selection over it. `qpgen` is not modified (frozen); `kie.db` is opened read-only.

## How the two seams stay honest and governed

**1. qie as a FILLED item source.** qie items are independently verified (Tier-1 deterministic / Tier-2
evidence) and carry a real stem, four distinct options, and a real key — exactly what qpgen's
`is_student_printable` and `validate._objective_violations` require. They fill the reserved **Phase-A5
QuestionSlot seam** (`item_model_id`, `lane`, `gate_verdicts`, `solution_steps`) — the sanctioned extension
point — and are tagged `provenance.source="template"` (machine-verified, so exempt from the free-text
grounding check, exactly like qpgen's solver-verified templates; every other governance check still applies).

**2. Honest concept-binding.** qpgen's boundary gate requires every item to bind to an **in-scope certified
concept** (`scope.in_scope`). So each qie item is bound to the real syllabus concept it genuinely belongs to
(a definite integral → *Integrals*; F=ma chain → *Newton's laws*; a monohybrid cross → *Mendel's law*; a
structure→system item → *Human Excretory/Respiratory System*). Ambiguous keyword matches that would mis-place
an item (`force`→"Nuclear Force", `energy`→"capacitor energy") are deliberately excluded; a frame with **no
precise in-scope concept is skipped, never force-bound**.

## Governance discipline — reject, never fill quotas

- **Boundary:** items bound to out-of-scope concepts never appear (`boundary_ok`).
- **Per-concept diversity:** qpgen rejects a repeated `(concept, question_type)`; the bridge mirrors this, so
  at most one item per concept+type reaches a paper (even though the engine can make thousands per concept).
- **Difficulty/depth balance:** an item fills a cell only if its exam-difficulty matches (medium vs hard);
  a hard section is not padded with easy items.
- **Structure/quality:** malformed options, artifact stems, missing keys are rejected by qpgen's validate.
- **Honest shortfall:** the authentic JEE (75Q) / NEET (180Q) blueprints ask for far more than qie's certified
  concept span supplies; unfilled positions are reported (the render states *deterministic coverage: N of M*),
  never quota-filled.

## Proof (seed 7) — real papers through the reused pipeline

| Paper | Printable items | Concepts covered | Governance |
|---|---|---|---|
| **JEE_MAIN** | **10** | Integrals, Derivatives, Limits and Derivatives, Matrices, Binomial Theorem, Permutations & Combinations, Newton's law, Power | `boundary_ok`, **0 rejects**, medium+hard, 0 duplicate concepts |
| **NEET** | **5** | Mendel's law (genetics), Human Excretory System, Human Respiratory System, Newton's law, Power | `boundary_ok`, **0 rejects** |

Rendered papers: `phase0_evidence/pilot_bio_neet/qp_bridge_JEE_MAIN.md`, `qp_bridge_NEET.md`. Paper-level
independent examiner (`qp_examiner_verdict.json`): **10/10 JEE items independently re-derived correct**,
each with exactly one defensible answer present in the options, **no duplicates / near-duplicates** — genuine
per-item quality. It raised two honest, *pre-existing* caveats (below), not bridge defects.

## Honest limitations (measured, not hidden)

- **Coverage is concept-bounded, both ways.** Papers are partial because (a) qie's certified-concept span is
  focused (Math strong; Physics Newton/Power/Ohm; Biology genetics + a few physiology systems), and (b) the
  certified **Chemistry** concept layer is *named-law-centric* (Kohlrausch, Charles, Gay-Lussac…), so qie's
  mole/stoichiometry items have no honest in-scope concept to bind to and are **skipped** — an honest gap, not
  a defect to paper over. Deeper coverage needs more qie concept span and/or a topic-level chemistry concept
  layer (a data question, owner-gated), not a change to this path.
- **Subject balance is corpus-bounded.** With Math's broad concept span, thin Physics, and unbindable
  Chemistry, a JEE paper skews Math-heavy (examiner: "a lopsided Math-heavy fragment"). This is the honest
  coverage reality, reported by the render — it improves only with more qie concept span / a topic-level
  chemistry concept layer, not with this path.
- **One item per concept per paper** (qpgen diversity). Per-student *variation within a concept* (the engine's
  real strength) would use a different series mode than qpgen's whole-concept exclusion — a future enhancement.
- **Some certified concept *titles* are OCR-garbled** (e.g. "Newton's second cord law" for Newton's second law
  of motion). The bound item's physics is correct; the garbled string is a `kie.db` concept-label artifact
  (frozen corpus), surfacing only as metadata — not in the student stem. A cleaner-title Newton concept is used
  where the scope offers one (NEET); JEE's scope offers only the garbled label.

## What this establishes
The proven unified compositional engine now generates real papers **through** the existing QP architecture and
governance, with the locked verification hierarchy intact (deterministic/evidence first; LLM examiner-only) and
the reject-don't-fill discipline enforced end-to-end. `qpgen`/`kie.db`/Certified Bank untouched; pilot bank not
promoted. 549 tests green.
