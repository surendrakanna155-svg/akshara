"""STAGE 2b — the structured generation brief: CURRICULUM BOUNDARY + QUESTION DESIGN INTELLIGENCE.

    Certified Curriculum Boundary (ki_*)   -> WHAT may legitimately be asked at this class/subject
  + Certified Question Design Intelligence (qdi_*) -> HOW a genuinely good item of this kind is BUILT
  -> QIE planner -> structured brief -> Opus original construction -> lane verification -> certified bank

Concept-only generation is insufficient for top-quality JEE/NEET, hard/twisted items and genuine
multi-concept composition. The 1,000-spec trial demonstrated the gap precisely: with a concept-only
planner the generator produced clean, correct, class-appropriate items with 0% fake compositions and 0%
implausible distractors — but nothing told it what makes an item *good* rather than merely *valid*, and
the hard cells stayed empty because a single relation is depth-1 by construction.

Both layers are certified independently and stay physically separate. This module only ever JOINS them
at brief-time; it never merges the stores.

Every spec is checked by `planner.check_plan` BEFORE it is written into a brief. A plan that cannot be
defended is never issued, and costs zero tokens.
"""
from __future__ import annotations

import json
from typing import Dict, List, Optional

from kie.qie.knowledge import planner as P

BRIEF_HEADER = """\
You are constructing ORIGINAL question candidates inside a governed factory. Two certified layers bound you:

  CURRICULUM BOUNDARY  — what may legitimately be asked at this class. Certified from owned NCERT
                         textbooks: the class is proven (it is that class's own single-subject book), and
                         an independent auditor accepted the concept and its scope.
  DESIGN INTELLIGENCE  — how a genuinely good question of this kind is BUILT, abstracted from real
                         previous-year exam items we own. This is MACHINERY, never wording. No source
                         question's text, numbers or options exist anywhere in this brief, and you must
                         not attempt to reconstruct one. Build an ORIGINAL item using the machinery.

## THE ONE RULE THAT MAKES YOUR ANSWER CHECKABLE
For every STRUCTURED_NUMERIC spec you MUST declare the machinery you used:
  - `givens`: every symbol with a numeric value AND a unit (target symbol gets "value": null)
  - `relation`: ONE parseable equation, e.g. "F = m * a", "v = u + a*t", "P = V**2 / R"
  - `solve_for`: the symbol the question asks for
The relation must ACTUALLY produce your keyed answer. It is re-executed by a computer-algebra system that
never reads your prose. Use `**` for powers, explicit `*`, plain ASCII names, and declare EVERY symbol you
use. Avoid bare single letters that collide with CAS builtins (N, S, E, I, O, Q) — prefer `Nt`, `Es`, `Qc`.
Write `answer_value` as a bare number; scientific notation as `5.27e-10` (never "5.27 x 10^-10").

## COMPACT STAGE — do NOT write solutions
Do NOT write step-by-step solutions, distractor rationales, or common-mistake explanations. Those are
constructed later, and only for items that survive verification. Emit exactly the schema below.

## HARD RULES
- `boundary.out_of_scope` on your spec is CERTIFIED curriculum evidence from that class's own textbook.
  Treat it as a wall. Same for `forbidden_terms` — and stay inside the class's toolkit even for terms not
  listed, because the list is not exhaustive.
- `multi` composition ONLY when the design pattern's dependency genuinely holds: concept B must CONSUME
  concept A's output. Two topic names in one sentence is not composition. If one relation answers it, it
  is `single`.
- Difficulty must come from the pattern's `difficulty_mechanism` — a non-obvious inference, an implicit
  case/state change, a discovered constraint, a trap that punishes a shortcut. NEVER from uglier arithmetic.
- Difficulty and reasoning depth are INDEPENDENT axes. Honour both as specified.
- Distractors must be the answers a real, nameable misconception produces. Use the pattern's
  `distractor_structure` where given.
- No visual unless `visual_required` is true. Decorative diagrams are forbidden.
- REFUSING IS RESPECTED and costs nothing: {"spec_id":"...","refuse":true,"reason":"..."}. A fabricated
  item is far worse than a refusal. Do not pad to hit a count.

## OUTPUT — a JSON array, one object per spec, spec_id copied EXACTLY, no prose outside the JSON:
{
  "spec_id": "<copied exactly>",
  "stem": "<self-contained ORIGINAL question>",
  "options": {"a": "...", "b": "...", "c": "...", "d": "..."},
  "answer_label": "b",
  "answer_value": "<bare number where numeric>",
  "claimed": {"concepts": ["..."], "archetype": "<copied>", "depth": <int>,
              "difficulty": "easy|moderate|hard", "composition": "single|multi"},
  "structure": {"givens": {"F": {"value": 12, "unit": "N"}, "m": {"value": 3, "unit": "kg"},
                           "a": {"value": null, "unit": "m/s**2"}},
                "relation": "F = m * a", "solve_for": "a", "answer_unit": "m/s**2",
                "steps": [{"out": "a", "inputs": ["F", "m"], "relation": "F = m * a"}]},
  "visual_spec": null
}

## YOUR SPECIFICATIONS
"""


def build_brief(specs: List[dict], universe_by_id: Dict[str, dict],
                patterns_by_id: Dict[str, dict], path: str) -> Dict[str, int]:
    """Write a generation brief. Specs that fail the pre-generation gate are REFUSED here and never
    reach the model — that is the whole point: garbage plans cost zero tokens."""
    m = {"issued": 0, "refused_pre_generation": 0, "violations": {}}
    lines: List[str] = []
    for s in specs:
        viol = P.check_plan(s, universe_by_id)
        if viol:
            m["refused_pre_generation"] += 1
            for x in viol:
                k = x.split(":")[0]
                m["violations"][k] = m["violations"].get(k, 0) + 1
            continue

        kc = universe_by_id[s["concept_id"]]
        pat = patterns_by_id.get(s.get("pattern_id") or "")
        partners = [universe_by_id[p]["canonical_name"] for p in (s.get("compose_with") or [])
                    if p in universe_by_id]

        entry = {
            "spec_id": s["spec_id"],
            # ── certified curriculum boundary ──
            "class": kc["taught_at_class"],
            "subject": kc["subject"],
            "chapter": kc.get("chapter_title"),
            "concept": kc["canonical_name"],
            "sub_concepts": kc.get("sub_concepts") or [],
            "prerequisites_available": kc.get("prerequisites") or [],
            "boundary": kc.get("boundary") or {},
            "forbidden_terms": s.get("forbidden_terms") or [],
            # ── plan ──
            "lane": s.get("lane"),
            "archetype": s["archetype"],
            "question_type": s.get("question_type", "MCQ"),
            "intended_depth": s["intended_depth"],
            "intended_difficulty": s["intended_difficulty"],
            "composition": s["composition"],
            "compose_with": partners,
            "visual_required": bool(s.get("visual_required")),
        }
        # ── certified design intelligence (structure only; never source wording) ──
        if pat:
            entry["design_pattern"] = {
                "name": pat.get("pattern_name"),
                "how_this_kind_of_item_is_built": pat.get("design_summary"),
                "composition_kind": pat.get("composition_kind"),
                "dependency": pat.get("dependency"),
                "reasoning_chain": pat.get("reasoning_chain"),
                "operators": pat.get("operators"),
                "constraints": pat.get("constraints"),
                "difficulty_mechanism": pat.get("difficulty_mechanism"),
                "transformation": pat.get("transformation"),
                "distractor_structure": pat.get("distractor_structure"),
                "evidenced_by_real_items": pat.get("evidence_count"),
                "NOTE": "This is abstract machinery learned from real exam items. Build an ORIGINAL "
                        "question with it. Do not attempt to reconstruct any source item.",
            }
        lines.append(json.dumps(entry, ensure_ascii=False))
        m["issued"] += 1

    with open(path, "w") as f:
        f.write(BRIEF_HEADER)
        f.write("\n".join(lines))
        f.write(f"\n\nReturn ONLY the JSON array of {m['issued']} candidate objects.\n")
    return m
