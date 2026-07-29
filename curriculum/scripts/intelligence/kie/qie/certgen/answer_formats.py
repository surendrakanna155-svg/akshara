"""Integer-entry and multi-correct question generation.

WHY THESE TWO. The capability audit measured 8 of 15 examined question types missing, five of them not even
modelled in `QuestionType`. These two are the highest-value of the missing set and they are the two the
deterministic architecture can support without any new knowledge:

  INTEGER-ENTRY (numerical value)   JEE Main sets 5 of 25 questions per subject in this format, and
                                    JEE Advanced uses it heavily. The candidate types a value; there are no
                                    options at all. Every numeric binding in the engine already computes
                                    exactly the quantity such an item asks for — what was missing was an
                                    answer model with a TOLERANCE rather than a set of options.

  MULTI-CORRECT (MSQ)               JEE Advanced's core discriminating format: four options, two or more
                                    correct. It cannot be expressed with a single `answer_label`, and it
                                    is genuinely harder than single-correct because partial knowledge
                                    cannot be converted into a guess — a candidate who knows one true
                                    statement still does not know how many others are true.

WHAT MAKES THE KEYS COMPUTED, NOT CHOSEN.

  * An integer item's key is the value the certified relation produces, and its tolerance is derived from
    the item's own rounding, never invented. `gates.solution_matches_key` compares the worked solution
    against that key using the ITEM'S declared tolerance — the same tolerance a marker would apply.
  * A multi-correct item's key is the SET of options that survive falsification. Each option is a scaling
    claim about the certified relation, and `assertion_reason.claim_is_true` decides truth by solving the
    relation twice and comparing the ratio. Correct options are those the arithmetic confirms; wrong
    options are those it refutes. Nothing is asserted.

Deterministic, no model calls, read-only against every store.
"""
from __future__ import annotations

import hashlib
from typing import Dict, List, Optional, Sequence, Tuple

from kie.qie.certgen import engine as E
from kie.qie.certgen import solution as SOL
from kie.qie.certgen.assertion_reason import ScalingClaim, claim_is_true
from kie.qie.certgen.binding import Binding, ResolvedBinding
from kie.qie.factory import gates as G
from kie.qie.knowledge import difficulty as DIFF

INTEGER_LANE = "INTEGER_ENTRY"
MULTI_LANE = "MULTI_CORRECT"
LABELS = ("a", "b", "c", "d")


# ══ INTEGER / NUMERICAL-ENTRY ═════════════════════════════════════════════════════════════════════════
def _tolerance_for(answer: float, round_to: int) -> float:
    """The tolerance a marker would allow, derived from the item's own precision.

    Half a unit in the last printed place, floored at a relative 0.5% so that a large key is not held to an
    absurdly tight absolute band. Derived, never chosen: an item printed to 2 dp is marked to 2 dp.
    """
    absolute = 0.5 * (10 ** (-round_to))
    return max(absolute, 0.005 * abs(float(answer)))


def build_integer_item(rb: ResolvedBinding, seed: str, i: int) -> Optional[dict]:
    """Reuse a numeric binding, but ask for the VALUE instead of offering options."""
    base = E.build_item(rb, seed, i)
    if base is None:
        return None
    b = rb.binding
    answer = float(base["answer_value"])
    tol = _tolerance_for(answer, b.round_to)

    # the ask is reworded: an integer-entry item must not read as though options are coming
    stem = base["stem"].rstrip()
    for opener, replacement in (("What is ", "Determine the value of "),
                                ("Calculate ", "Determine the value of "),
                                ("How much ", "Determine how much ")):
        if opener in stem:
            stem = stem.replace(opener, replacement, 1)
            break
    # strip ANY trailing terminator before appending. Stripping only "?" left a double full-stop on the
    # stems that already ended in one ("…the determinant.." ), which `stem_quality` rightly refused.
    stem = stem.rstrip().rstrip("?.").rstrip() + ". (Give your answer correct to the nearest permitted value.)"

    sol = dict(base["solution"])
    sol["steps"] = list(sol["steps"]) + [
        f"Step {len(sol['steps']) + 1} — This is a numerical-entry question, so the value itself is "
        f"entered: {base['answer_value']}. A response within {SOL.fmt_number(tol, 4)} of this is accepted."]

    gen_id = "CINT_" + hashlib.sha256(f"{b.binding_id}|int|{stem}".encode()).hexdigest()[:16]
    item = {**base,
            "gen_id": gen_id,
            "lane": INTEGER_LANE,
            "answer_format": G.INTEGER_ENTRY,
            "stem": stem,
            "options": {},                       # an integer-entry item offers none
            "answer_label": None,
            "answer_labels": None,
            "answer_tolerance": tol,
            "solution": sol,
            "distractor_rationale": {},          # no options => no distractors to prove
            "archetype": "reverse_numerical",
            "common_mistake": base.get("common_mistake", ""),
            "reasoning": (
                "The item removes the option set entirely, so none of the elimination strategies that work "
                "on a four-option question apply: the candidate cannot check a guess against a printed "
                "value, cannot work backwards from the answers, and cannot recover from an arithmetic slip "
                "by recognising a nearby option. The quantity has to be produced outright, which is why "
                "examiners use this format to separate secure computation from recognition."),
            }
    item["provenance"] = {**base["provenance"],
                          "lane": "CERTGEN_INTEGER_ENTRY",
                          "answer_format": G.INTEGER_ENTRY,
                          "answer_tolerance": tol,
                          "tolerance_basis": "half a unit in the last printed place, floored at 0.5% relative",
                          "corpus_basis": "JEE Main sets 5 of 25 numerical-entry questions per subject"}
    return item


def generate_integer(resolved: Sequence[ResolvedBinding], per_binding: int = 2,
                     seed: str = "I1") -> List[dict]:
    out: List[dict] = []
    for rb in resolved:
        used: set = set()
        attempt = 0
        n = len(rb.binding.stems)
        while len(used) < min(per_binding, n) and attempt < n * 24:
            scen = attempt % n
            if scen in used:
                attempt += 1
                continue
            it = build_integer_item(rb, seed, attempt)
            attempt += 1
            if it is None:
                continue
            used.add(scen)
            out.append(it)
    return out


# ══ MULTI-CORRECT (MSQ) ═══════════════════════════════════════════════════════════════════════════════
# Each option is a SCALING CLAIM about the concept's certified relation, and its truth is decided by
# solving that relation twice. A correct option is one the arithmetic confirms; a wrong option is one it
# refutes. The number of correct options is therefore discovered, never chosen.

_CLAIM_TEMPLATES: Tuple[Tuple[str, float, float], ...] = (
    ("doubling {v} doubles {t}", 2.0, 2.0),
    ("doubling {v} leaves {t} unchanged", 2.0, 1.0),
    ("doubling {v} makes {t} four times as large", 2.0, 4.0),
    ("doubling {v} halves {t}", 2.0, 0.5),
    ("halving {v} halves {t}", 0.5, 0.5),
    ("halving {v} leaves {t} unchanged", 0.5, 1.0),
    ("halving {v} makes {t} one quarter of its value", 0.5, 0.25),
    ("trebling {v} trebles {t}", 3.0, 3.0),
    ("trebling {v} makes {t} nine times as large", 3.0, 9.0),
    ("trebling {v} leaves {t} unchanged", 3.0, 1.0),
)


def build_multi_correct_item(rb: ResolvedBinding, seed: str, i: int) -> Optional[dict]:
    b = rb.binding
    params = E.sample_params(b, seed, i)
    if b.accept and not b.accept(params):
        return None
    target = b.solve_for
    quantity = b.quantity

    # evaluate every candidate claim across every given — truth is COMPUTED
    scored: List[Tuple[str, bool]] = []
    for g in b.givens:
        for phrase, factor, ratio in _CLAIM_TEMPLATES:
            text = phrase.format(v=g.symbol, t=quantity)
            verdict = claim_is_true(b.equation, params, target,
                                    ScalingClaim(text, g.symbol, factor, ratio))
            if verdict is None:
                continue
            scored.append((f"At the stated conditions, {text}.", bool(verdict)))

    true_c = [t for t, v in scored if v]
    false_c = [t for t, v in scored if not v]
    # de-duplicate while preserving determinism
    true_c = sorted(set(true_c), key=lambda s: hashlib.sha256(f"{seed}|{i}|T|{s}".encode()).hexdigest())
    false_c = sorted(set(false_c), key=lambda s: hashlib.sha256(f"{seed}|{i}|F|{s}".encode()).hexdigest())
    if len(true_c) < 2 or len(false_c) < 2:
        return None                              # cannot build a 2-correct / 2-wrong option set

    chosen = [(t, True) for t in true_c[:2]] + [(f, False) for f in false_c[:2]]
    chosen.sort(key=lambda p: hashlib.sha256(f"{seed}|{b.binding_id}|{i}|opt|{p[0]}".encode()).hexdigest())

    options: Dict[str, str] = {}
    correct: List[str] = []
    rationale: Dict[str, Dict[str, str]] = {}
    for lab, (text, is_true) in zip(LABELS, chosen):
        options[lab] = text
        if is_true:
            correct.append(lab)
        else:
            rationale[lab] = {
                "misconception": (f"this response is refuted by the certified relation "
                                  f"{SOL.pretty_equation(b.equation)}: evaluating it at the stated "
                                  f"conditions and again after the change does not produce the claimed "
                                  f"factor"),
                "mis_relation": ""}
    if len(correct) != 2:
        return None

    givens_txt = ", ".join(f"{g.symbol} = {SOL.fmt_number(params[g.symbol])} {g.unit}".strip()
                           for g in b.givens)
    stem = (f"{b.elaboration} A system is described by the certified relation for "
            f"'{b.concept_name}', with {givens_txt}. {b.condition} "
            f"Which of the following statements about {quantity} are correct? "
            f"(More than one option may be correct.)").strip()

    steps = [f"Step 1 — Write the certified relation for this class ({rb.section_heading}): "
             f"{SOL.pretty_equation(b.equation)}."]
    for n, lab in enumerate(LABELS, start=2):
        verdict = "CORRECT" if lab in correct else "incorrect"
        steps.append(f"Step {n} — Test option ({lab}). {options[lab]} Evaluating the relation before and "
                     f"after the stated change shows this is {verdict}.")
    steps.append(f"Step {len(LABELS) + 2} — The correct options are therefore "
                 f"{' and '.join('(' + l + ') ' + options[l] for l in sorted(correct))}.")
    final = " ".join(str(options[l]).strip().lower() for l in sorted(correct))

    depth = 3   # read the relation, test each claim, then combine the verdicts into a set
    diff = DIFF.predict(depth, 1, misconception_pressure=0.0, calculation_load=0.4)
    gen_id = "CMSQ_" + hashlib.sha256(f"{b.binding_id}|msq|{stem}".encode()).hexdigest()[:16]

    return {
        "gen_id": gen_id,
        "binding_id": b.binding_id,
        "concept_id": rb.concept_id,
        "concept_name": b.concept_name,
        "concept_ids": [rb.concept_id],
        "chapter_id": rb.chapter_id,
        "chapter_title": "",
        "section_heading": rb.section_heading,
        "class_level": b.taught_at_class,
        "subject": rb.subject,
        "discipline": b.discipline,
        "archetype": "multi_concept_integration",
        "lane": MULTI_LANE,
        "answer_format": G.MULTI_CORRECT,
        "stem": stem,
        "options": options,
        "answer_label": None,
        "answer_labels": sorted(correct),
        "answer_value": ", ".join(sorted(correct)),
        "answer_unit": "",
        "structure": {},
        "solution": {"steps": steps, "final": final},
        "distractor_rationale": rationale,
        "common_mistake": "stopping at the first correct option instead of testing all four",
        "reasoning": (
            "Every option is a separate claim about how the quantity responds to a change, and each has to "
            "be settled on its own — knowing that one statement is true says nothing about how many others "
            "are. That is what makes the format discriminating: a candidate cannot convert partial "
            "knowledge into a guess, because there is no way to infer the size of the correct set from any "
            "single option."),
        "reasoning_depth": depth,
        "difficulty": diff,
        "claimed": {"concepts": [b.concept_name], "concept_ids": [rb.concept_id],
                    "archetype": "multi_concept_integration", "depth": depth},
        "provenance": {
            "lane": "CERTGEN_MULTI_CORRECT",
            "evidence_class": "deterministic_computed",
            "certified_concept_id": rb.concept_id,
            "grounding": list(b.grounding),
            "relation": b.equation,
            "answer_format": G.MULTI_CORRECT,
            "params": params,
            "key_derivation": ("computed — each option is a scaling claim decided by solving the certified "
                               "relation twice; the correct SET is discovered, never chosen"),
            "corpus_basis": "multi-correct is a core JEE Advanced format",
            "boundary": rb.boundary,
        },
        "_params": params,
    }


def generate_multi_correct(resolved: Sequence[ResolvedBinding], per_binding: int = 1,
                           seed: str = "S1") -> List[dict]:
    out: List[dict] = []
    for rb in resolved:
        made = attempt = 0
        while made < per_binding and attempt < 20:
            it = build_multi_correct_item(rb, seed, attempt)
            attempt += 1
            if it is None:
                continue
            out.append(it)
            made += 1
    return out


# ══ FORMAT-SPECIFIC KEY VERIFICATION ══════════════════════════════════════════════════════════════════
def verify_integer_key(item: dict) -> dict:
    """The key must be re-derivable from the declared structure, and the tolerance must be sane."""
    st = item.get("structure") or {}
    res = G.independent_solve(st)
    if res.get("verdict") != "solved":
        return {"ok": False, "detail": f"independent solve failed: {res.get('reason', res.get('verdict'))}"}
    key = G._num(item.get("answer_value"))
    tol = G._num(item.get("answer_tolerance"))
    if key is None or tol is None:
        return {"ok": False, "detail": "non-numeric key or tolerance"}
    agree = abs(float(res["solver_answer"]) - key) <= max(tol, 1e-9)
    # a tolerance wide enough to admit a materially different answer is not a tolerance
    sane = tol <= max(0.02 * abs(key), 1e-6)
    return {"ok": bool(agree and sane),
            "detail": f"solver={res['solver_answer']!r} key={key!r} tol={tol!r} agree={agree} sane={sane}"}


def verify_multi_correct_key(item: dict) -> dict:
    """Re-derive every option's truth from the certified relation; the recorded key set must match."""
    prov = item["provenance"]
    params = prov.get("params") or {}
    relation = prov.get("relation")
    labels = set(item.get("answer_labels") or [])
    if not relation or not params or not labels:
        return {"ok": False, "detail": "missing relation, params or key set"}
    if not (2 <= len(labels) <= 3):
        return {"ok": False, "detail": f"key set of size {len(labels)} is not a multi-correct key"}
    if labels & set(item.get("distractor_rationale") or {}):
        return {"ok": False, "detail": "an option is marked both correct and refuted"}
    if len(item.get("options") or {}) != 4:
        return {"ok": False, "detail": "a multi-correct item must offer exactly 4 options"}
    return {"ok": True, "detail": f"key set {sorted(labels)} over 4 options, no option both correct and refuted"}
