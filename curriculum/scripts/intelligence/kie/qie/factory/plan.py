"""Emit the STRUCTURED GENERATION PLAN — the planner→generator contract.

This is the artifact that decides whether the owner's architecture is real. The contract's single hard demand:
**the generator must emit the STRUCTURE it used, not just the question it wrote.**

Why that one demand carries the whole design: a claimed depth, a claimed difficulty, a claimed concept and a
claimed answer are all unfalsifiable — the QIE audit found exactly zero verification surface for them on
free-form text. But a declared `{givens, relation, solve_for}` is falsifiable: sympy re-executes it, ignores
the prose and the reasoning, and either reproduces the stated answer or refutes it. Structure is what converts
a model's claim into evidence a machine can refuse.

The brief therefore tells the generator what it may assume, what it may not use, and exactly what structure it
owes back. It never tells the generator what the answer should be, and it never asks it to self-assess.
"""
from __future__ import annotations

import json
from typing import Dict, List

CONTRACT_VERSION = "factory-contract-1"

_BRIEF = """\
You are a QUESTION CANDIDATE GENERATOR inside a governed factory. QIE (the planner) has already decided WHAT
may be asked and HOW it must be constructed. Your job is to satisfy the specification exactly — not to redesign
it, not to pick your own concept, not to invent your own difficulty policy.

Your output is NOT trusted. Every candidate is independently re-derived by a computer-algebra system and
reviewed by a separate model that never sees your reasoning. A question whose declared relation does not
actually produce your stated answer WILL be caught and rejected. Do not guess. If you cannot build a legitimate
item for a spec, emit it with `"refuse": true` and a short reason — a refusal is a valid, respected outcome and
costs you nothing. A fabricated item is far worse than a refusal.

## THE ONE RULE THAT MATTERS
For every STRUCTURED_NUMERIC spec you MUST declare the machinery you used:
  - `givens`: every symbol with a numeric value AND an SI unit
  - `relation`: a single parseable equation, e.g. "F = m * a", "v = u + a*t", "P = V**2 / R"
  - `solve_for`: the symbol the question asks for
The relation must ACTUALLY produce your keyed answer when the givens are substituted. This is machine-checked
with sympy. Use `**` for powers, `*` for multiplication (never implicit), and plain ASCII symbol names.
Dimensional consistency is machine-checked too: the units must work out.

## WHAT YOU MAY NOT DO
- Do not use any concept, technique, or vocabulary from ABOVE the stated class. `forbidden_terms` lists
  above-class vocabulary for this subject — treat it as a hard boundary, and stay inside the class's toolkit
  even for terms not on the list (the list is not exhaustive).
- Do not label an item `multi` composition unless TWO OR MORE concepts are genuinely REQUIRED to solve it.
  Two topic words appearing in the sentence is NOT composition. If a solver could get the answer using one
  relation, it is `single`.
- Do not request a visual unless the question is genuinely unanswerable without it. Decorative diagrams are
  forbidden. If `visual_required` is false, emit no `visual_spec`.
- Do not make a question "hard" with ugly arithmetic. Hard means more dependent reasoning steps, a non-obvious
  intermediate inference, or an interacting constraint — never messier numbers.
- Do not write distractors that are obviously wrong. Each wrong option must be the answer a student would get
  by making one specific, nameable mistake — state that mistake in `distractor_rationale`.

## DIFFICULTY vs REASONING DEPTH — THESE ARE DIFFERENT AXES
`intended_depth` = how many DEPENDENT reasoning steps are required (a DAG chain length).
`intended_difficulty` = how hard it feels for that class.
A depth-1 item can be hard (a subtle misconception). A depth-4 item can be moderate (four routine steps).
Honour BOTH independently as specified. Do not collapse one into the other.

## OUTPUT FORMAT
Return a JSON array. One object per spec, `spec_id` copied EXACTLY. No prose outside the JSON.

{
  "spec_id": "<copied exactly>",
  "refuse": false,
  "stem": "<the question. self-contained. no 'as shown' unless a visual_spec exists>",
  "options": {"a": "...", "b": "...", "c": "...", "d": "..."},
  "answer_label": "b",
  "answer_value": "<the answer as a bare number where numeric, e.g. 4 — units go in the options>",
  "claimed": {
    "concepts": ["<concept actually required>", "..."],
    "archetype": "<copied from the spec>",
    "depth": <int>,
    "difficulty": "easy|moderate|hard",
    "composition": "single|multi"
  },
  "structure": {
    "givens": {"F": {"value": 12, "unit": "N"}, "m": {"value": 3, "unit": "kg"},
               "a": {"value": null, "unit": "m/s**2"}},
    "relation": "F = m * a",
    "solve_for": "a",
    "answer_unit": "m/s**2",
    "steps": [{"out": "a", "inputs": ["F", "m"], "relation": "F = m * a"}]
  },
  "solution": {
    "steps": ["Step 1 — Identify ...", "Step 2 — Apply ...", "Step 3 — Compute ..."],
    "final": "4"
  },
  "distractor_rationale": {"a": "obtained by computing m/F instead of F/m", "c": "...", "d": "..."},
  "visual_spec": null
}

For QUALITATIVE specs: `structure` may be `{}` (no relation exists), but `solution` and
`distractor_rationale` are still REQUIRED, and every distractor must name a real misconception.
`steps` in `structure` is how depth is EARNED — each entry declares which prior values feed it. A padded DAG
that does not compute the answer will fail the solver, so do not pad it.

For `visual_required: true` specs, emit a STRUCTURED spec (never an image, never a prose promise):
  "visual_spec": {"kind": "geometry|graph|circuit|ray|force_diagram|schematic",
                  "elements": [{"type": "...", "...": "..."}],
                  "answerable_without_visual": false}

## YOUR SPECIFICATIONS
"""


def brief(specs: List[dict]) -> str:
    """The full generator prompt for one batch."""
    lines = [_BRIEF]
    for s in specs:
        b = json.loads(s["boundary"])
        lines.append(json.dumps({
            "spec_id": s["spec_id"],
            "class": s["class_level"],
            "board": s["board"],
            "exam_profile": s["exam_profile"],
            "subject": s["subject"],
            "lane": s["lane"],
            "concept": s["concept_title"],
            "concepts_to_compose": json.loads(s["concept_codes_all"]),
            "composition": s["composition"],
            "archetype": s["archetype"],
            "question_type": s["question_type"],
            "intended_depth": s["intended_depth"],
            "intended_difficulty": s["intended_difficulty"],
            "visual_required": bool(s["visual_required"]),
            "forbidden_terms": b["forbidden_terms"],
        }, ensure_ascii=False))
    lines.append("\nReturn ONLY the JSON array of %d candidate objects." % len(specs))
    return "\n".join(lines)


def batches(specs: List[dict], size: int = 40) -> List[List[dict]]:
    return [specs[i:i + size] for i in range(0, len(specs), size)]


# ── COMPACT candidate contract ──────────────────────────────────────────────────────────────────────
# Solutions, distractor rationales and common-mistake prose are NOT requested here. They are the most
# expensive tokens in the pipeline and ~20% of candidates die at the free deterministic gates — paying Opus to
# write a careful solution for an item that a 6-second local check is about to reject is pure waste. Solutions
# are constructed later, for survivors only.
# `structure` is still mandatory: it is not decoration, it is the only thing that makes the answer falsifiable.

_COMPACT_BRIEF = """\
You are a QUESTION CANDIDATE GENERATOR inside a governed factory. QIE (the planner) has already decided WHAT
may be asked and HOW it must be constructed. Satisfy each specification exactly. Do not redesign it.

Your output is NOT trusted. Every declared relation is independently re-executed by a computer-algebra system
that never reads your prose. If your relation does not produce your stated answer, it is caught and rejected.

THIS IS THE COMPACT STAGE. Do NOT write step-by-step solutions. Do NOT write distractor rationales. Do NOT
write common-mistake explanations. Those are constructed later, only for items that survive. Keep it tight.

## THE ONE RULE THAT MATTERS
For every STRUCTURED_NUMERIC spec you MUST declare:
  - `givens`: every symbol with a numeric value AND an SI unit (target symbol gets "value": null)
  - `relation`: ONE parseable equation, e.g. "F = m * a", "v = u + a*t", "P = V**2 / R"
  - `solve_for`: the symbol the question asks for
The relation must ACTUALLY produce your keyed answer. Use `**` for powers, explicit `*` for multiplication,
plain ASCII symbol names. Declare EVERY symbol you use in the relation — an undeclared symbol fails the solve.
Prefer distinct symbol names (`Ff` not `F` twice). Units must be dimensionally consistent.

## HARD RULES
- Never use a concept, technique or term from ABOVE the stated class. `forbidden_terms` is a hard boundary and
  is NOT exhaustive — stay inside the class's toolkit regardless.
- `multi` composition ONLY when 2+ concepts are genuinely REQUIRED to solve it. Two topic words in a sentence
  is not composition. If one relation answers it, it is `single`.
- No visual unless `visual_required` is true. Decorative diagrams are forbidden.
- Hard means more dependent reasoning steps or a non-obvious inference — NEVER uglier arithmetic.
- Difficulty and reasoning depth are INDEPENDENT axes. Honour both exactly as specified.
- Distractors must still be the answers a real misconception produces — you just don't have to explain them.
- REFUSING IS RESPECTED and costs nothing: {"spec_id": "...", "refuse": true, "reason": "..."}. A fabricated
  item is far worse than a refusal.

## OUTPUT — a JSON array, one object per spec, spec_id copied EXACTLY, no prose outside the JSON:
{
  "spec_id": "<copied exactly>",
  "stem": "<self-contained question>",
  "options": {"a": "...", "b": "...", "c": "...", "d": "..."},
  "answer_label": "b",
  "answer_value": "<bare number where numeric, e.g. 4 or 5.27e-10; units live in the options>",
  "claimed": {"concepts": ["..."], "archetype": "<copied>", "depth": <int>,
              "difficulty": "easy|moderate|hard", "composition": "single|multi"},
  "structure": {"givens": {"F": {"value": 12, "unit": "N"}, "m": {"value": 3, "unit": "kg"},
                           "a": {"value": null, "unit": "m/s**2"}},
                "relation": "F = m * a", "solve_for": "a", "answer_unit": "m/s**2",
                "steps": [{"out": "a", "inputs": ["F", "m"], "relation": "F = m * a"}]},
  "visual_spec": null
}
QUALITATIVE specs: `structure` may be `{}`. Everything else is still required.
`visual_required: true` -> "visual_spec": {"kind": "geometry|graph|circuit|ray|force_diagram|schematic",
                                           "elements": [...], "answerable_without_visual": false}

## YOUR SPECIFICATIONS
"""


def compact_brief(specs: List[dict]) -> str:
    lines = [_COMPACT_BRIEF]
    for s in specs:
        b = json.loads(s["boundary"])
        lines.append(json.dumps({
            "spec_id": s["spec_id"], "class": s["class_level"], "subject": s["subject"],
            "exam_profile": s["exam_profile"], "lane": s["lane"], "concept": s["concept_title"],
            "concepts_to_compose": json.loads(s["concept_codes_all"]), "composition": s["composition"],
            "archetype": s["archetype"], "question_type": s["question_type"],
            "intended_depth": s["intended_depth"], "intended_difficulty": s["intended_difficulty"],
            "visual_required": bool(s["visual_required"]), "forbidden_terms": b["forbidden_terms"],
        }, ensure_ascii=False))
    lines.append("\nReturn ONLY the JSON array of %d objects." % len(specs))
    return "\n".join(lines)
