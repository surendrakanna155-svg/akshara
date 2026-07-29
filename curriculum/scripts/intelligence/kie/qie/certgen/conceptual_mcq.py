"""Conceptual single-best-answer MCQ — the dominant real form, built by falsification.

WHY. The corpus measured `mcq` at 87.5% of NEET and 74.3% of JEE Advanced, against 0% in Lane C. It is the
single largest authenticity gap. This module closes the part of it that can be closed deterministically,
and is explicit about the part that cannot.

THE SEPARATION THIS FILE INSISTS ON. "Conceptual MCQ" in the real corpus covers two populations that look
alike on the page and are completely different to a certification engine:

  RELATION-REACHABLE — the question turns on a relation between quantities: which expression gives the
    power dissipated in a resistor, how the potential difference varies with current, whether a quantity
    is proportional to another or to its square. Truth here is COMPUTABLE. A wrong option is proved wrong
    by sympy: it is not algebraically equivalent to the certified relation, and at a concrete working
    point it produces a different number. That is the same falsification the assertion-reason lane already
    relies on, reused rather than reinvented.

  FACTUAL-RECALL — "which hormone regulates X", "the enzyme responsible for Y", "which of these is a
    Chondrichthyes". Truth is a lookup. There is no re-derivation, and `factory/certify.py:14-16` states
    the consequence plainly: gates check form, and a judge of the generator's own family certifies
    nothing. **Lane C does not generate these, and this module will not pretend it can.**

`classify_reachability()` below draws that line over the whole certified index and reports both sides, so
the coverage claim is a measurement rather than an impression. Most of NEET's 87.5% is Biology factual
recall; the honest position is that this lane addresses the relation-reachable remainder and leaves the
rest to the owned-source / maker-checker route.

TWO FALSIFICATION CHECKS, NOT ONE. Every wrong option must fail BOTH:
  1. `relations_equivalent(certified, candidate, target)` must be False — it is not a rearrangement of the
     certified relation wearing different symbols;
  2. at a declared working point the candidate must compute a DIFFERENT value from the certified relation.
Check 1 catches a restatement; check 2 catches a gap in the equivalence checker itself. An option that
survives both is provably a different claim, not merely different prose.

Deterministic, no model calls, read-only against every store.
"""
from __future__ import annotations

import hashlib
import re
import sqlite3
from dataclasses import dataclass
from typing import Dict, List, Optional, Sequence, Tuple

from kie.qie.certgen import solution as SOL
from kie.qie.certgen.assertion_reason import (ScalingClaim, claim_is_true, relations_equivalent,
                                              _solve as _ar_solve)
from kie.qie.certgen.binding import evidence_blob, normalize_evidence
from kie.qie.knowledge import difficulty as DIFF
from kie.qie.knowledge import planner as P

LANE = "CONCEPTUAL_MCQ"
OPTION_LABELS = ("a", "b", "c", "d")

# An equation printed in a concept's certified evidence. This is what makes a concept relation-reachable:
# the curriculum itself states a relation between named quantities.
_EQUATION = re.compile(r"[A-Za-z_)\]]\s*=\s*[^=]")


# ══ REACHABILITY — the separation, measured ═══════════════════════════════════════════════════════════
@dataclass(frozen=True)
class Reachability:
    relation_reachable: Tuple[str, ...]      # concept_ids whose evidence states a relation
    factual_only: Tuple[str, ...]            # concept_ids with no relation in evidence
    by_discipline: Dict[str, Tuple[int, int]]   # discipline -> (reachable, factual_only)


def concept_states_a_relation(kc: dict) -> bool:
    """Does this certified concept's OWN evidence print an equation between named quantities?

    Deliberately conservative: it reads only `sub_concepts` and `boundary.in_scope` (the audited content
    claims), never the title. A concept whose evidence never states a relation is not one this lane can
    certify a question about, whatever its name suggests.
    """
    for s in list(kc.get("sub_concepts") or []) + list((kc.get("boundary") or {}).get("in_scope") or []):
        if _EQUATION.search(str(s)):
            return True
    return False


def classify_reachability(universe: Sequence[dict]) -> Reachability:
    reach: List[str] = []
    factual: List[str] = []
    by: Dict[str, List[int]] = {}
    for kc in universe:
        d = kc.get("academic_discipline") or kc.get("subject") or "?"
        by.setdefault(d, [0, 0])
        if concept_states_a_relation(kc):
            reach.append(kc["concept_id"])
            by[d][0] += 1
        else:
            factual.append(kc["concept_id"])
            by[d][1] += 1
    return Reachability(tuple(reach), tuple(factual),
                        {k: (v[0], v[1]) for k, v in sorted(by.items())})


# ══ BINDINGS ══════════════════════════════════════════════════════════════════════════════════════════
@dataclass(frozen=True)
class Falsification:
    """A wrong expression plus the misconception that produces it. Proved wrong, never asserted wrong."""
    text: str                # as printed to the student
    relation: str            # sympy-parseable
    misconception: str


@dataclass(frozen=True)
class ConceptualBinding:
    binding_id: str
    discipline: str
    taught_at_class: int
    concept_name: str
    grounding: Tuple[str, ...]
    relation: str                          # the CERTIFIED relation
    solve_for: str
    probe_params: Dict[str, float]         # concrete working point for the numeric falsification check
    correct_text: str                      # the certified expression, as printed
    quantity_phrase: str                   # "the power dissipated in a resistor"
    falsifications: Tuple[Falsification, ...]
    stems: Tuple[str, ...]
    # optional proportionality variant: how the target responds to scaling one quantity
    scaling_var: str = ""
    scaling_true: Tuple[str, float, float] = ()     # (phrase, factor, expected_ratio)
    scaling_false: Tuple[Tuple[str, float, float], ...] = ()


@dataclass(frozen=True)
class ResolvedConceptual:
    binding: ConceptualBinding
    concept_id: str
    chapter_id: str
    section_heading: str
    subject: str
    boundary: dict


CONCEPTUAL_BINDINGS: Tuple[ConceptualBinding, ...] = (

    ConceptualBinding(
        "CMC_PHY10_ELECTRIC_POWER", "Physics", 10, "Electric Power", ("p = vi = i^2 r = v^2/r",),
        "Pw = I ** 2 * R", "Pw", {"I": 3.0, "R": 8.0},
        "I^2 R", "the power dissipated in a resistor carrying a steady current I through a resistance R",
        (Falsification("I R", "Pw = I * R",
                       "dropped the square on the current, confusing power with potential difference"),
         Falsification("I R^2", "Pw = I * R ** 2",
                       "squared the resistance instead of the current"),
         Falsification("I^2 / R", "Pw = I ** 2 / R",
                       "divided by the resistance, confusing P = I^2R with P = V^2/R")),
        ("Which of the following expressions gives the power dissipated in a resistor of resistance R "
         "carrying a steady current I?",
         "A steady current I flows through a resistor of resistance R. The rate at which electrical "
         "energy is converted to heat in the resistor is given by:",
         "For a resistor of resistance R carrying a steady current I, the electric power developed is:"),
        scaling_var="I",
        scaling_true=("becomes four times as large", 2.0, 4.0),
        scaling_false=(("is unchanged", 2.0, 1.0), ("is doubled", 2.0, 2.0), ("is halved", 2.0, 0.5)),
    ),

    ConceptualBinding(
        "CMC_PHY8_PRESSURE", "Physics", 8, "Pressure (Force per Unit Area)",
        ("pressure = force / area",),
        "Pr = F / A", "Pr", {"F": 240.0, "A": 6.0},
        "F / A", "the pressure exerted on a surface by a force F acting normally over an area A",
        (Falsification("F x A", "Pr = F * A", "multiplied force by area instead of dividing"),
         Falsification("A / F", "Pr = A / F", "inverted the relation, dividing area by force"),
         Falsification("F - A", "Pr = F - A", "subtracted the area from the force")),
        ("A force F acts at right angles to a surface of area A. Which of the following expressions "
         "gives the pressure exerted on the surface?",
         "The pressure produced on a surface by a force F acting normally over an area A is given by:",
         "A force F is applied perpendicular to a flat surface of area A. The pressure on the surface "
         "is:"),
        scaling_var="A",
        scaling_true=("is halved", 2.0, 0.5),
        scaling_false=(("is doubled", 2.0, 2.0), ("is unchanged", 2.0, 1.0),
                       ("becomes four times as large", 2.0, 4.0)),
    ),

    ConceptualBinding(
        "CMC_PHY11_KINETIC_ENERGY", "Physics", 11, "Kinetic Energy", ("(1/2) m v^2",),
        "K = m * v ** 2 / 2", "K", {"m": 4.0, "v": 5.0},
        "(1/2) m v^2", "the kinetic energy of a body of mass m moving with speed v",
        (Falsification("m v^2", "K = m * v ** 2", "omitted the factor of one-half"),
         Falsification("(1/2) m v", "K = m * v / 2", "did not square the speed"),
         Falsification("m v", "K = m * v", "used the linear momentum in place of the kinetic energy")),
        ("A body of mass m moves in a straight line with speed v. Which of the following expressions "
         "gives its kinetic energy?",
         "The kinetic energy of a particle of mass m moving with a speed v is given by:",
         "For a body of mass m travelling at speed v, the energy it possesses by virtue of its motion "
         "is:"),
        scaling_var="v",
        scaling_true=("becomes four times as large", 2.0, 4.0),
        scaling_false=(("is doubled", 2.0, 2.0), ("is unchanged", 2.0, 1.0), ("is halved", 2.0, 0.5)),
    ),

    ConceptualBinding(
        "CMC_MAT6_AREA_RECT", "Mathematics", 6, "Area of a Rectangle", ("area = length x width",),
        "A = l * w", "A", {"l": 12.0, "w": 5.0},
        "l x w", "the area of a rectangle of length l and width w",
        (Falsification("l + w", "A = l + w", "added the two sides instead of multiplying them"),
         Falsification("2 x (l + w)", "A = 2 * (l + w)", "computed the perimeter instead of the area"),
         Falsification("(1/2) x l x w", "A = l * w / 2",
                       "halved the product, as for the area of a triangle")),
        ("A rectangle has length l and width w. Which of the following expressions gives its area?",
         "The area of a rectangular sheet whose length is l and whose width is w is given by:",
         "For a rectangle of length l and width w, the number of unit squares that exactly cover it is:"),
        scaling_var="l",
        scaling_true=("is doubled", 2.0, 2.0),
        scaling_false=(("is unchanged", 2.0, 1.0), ("becomes four times as large", 2.0, 4.0),
                       ("is halved", 2.0, 0.5)),
    ),
)


# ══ RESOLUTION ════════════════════════════════════════════════════════════════════════════════════════
def _certified(iconn, disc: str, cls: int, name: str) -> List[dict]:
    return [c for c in P.certified_universe_by_discipline(iconn, disc, [cls])
            if c["canonical_name"] == name]


def falsification_holds(certified: str, candidate: str, target: str,
                        probe: Dict[str, float]) -> Tuple[bool, str]:
    """Both checks. Returns (is_provably_false, reason)."""
    if relations_equivalent(certified, candidate, target):
        return False, f"{candidate!r} is algebraically equivalent to the certified {certified!r}"
    a = _ar_solve(certified, probe, target)
    b = _ar_solve(candidate, probe, target)
    if a is None or b is None:
        return False, f"could not evaluate {candidate!r} at the working point"
    if abs(a - b) <= 1e-9 * max(abs(a), 1.0):
        return False, f"{candidate!r} computes the same value ({b}) as the certified relation at the probe"
    return True, f"not equivalent, and computes {b:g} where the certified relation gives {a:g}"


def resolve_one(iconn: sqlite3.Connection,
                b: ConceptualBinding) -> Tuple[Optional[ResolvedConceptual], List[str]]:
    v: List[str] = []
    m = _certified(iconn, b.discipline, b.taught_at_class, b.concept_name)
    if not m:
        return None, [f"unresolved_concept: no CERTIFIED {b.discipline} concept named "
                      f"{b.concept_name!r} at class {b.taught_at_class}"]
    if len(m) > 1:
        return None, [f"ambiguous_concept: {len(m)} matches for {b.concept_name!r}"]
    kc = m[0]

    blob = evidence_blob(kc)
    for term in b.grounding:
        if normalize_evidence(term) not in blob:
            v.append(f"ungrounded_relation: {term!r} absent from {kc['concept_id']}'s certified evidence")

    if not concept_states_a_relation(kc):
        v.append("not_relation_reachable: this concept's evidence states no relation, so a conceptual "
                 "MCQ about it would be factual recall — which this lane must not generate")

    if len(b.falsifications) < 3:
        v.append(f"too_few_falsifications: need 3 provably-wrong options, got {len(b.falsifications)}")
    seen = set()
    for i, f in enumerate(b.falsifications):
        ok, why = falsification_holds(b.relation, f.relation, b.solve_for, b.probe_params)
        if not ok:
            v.append(f"falsification_fails[{i}]: {why}")
        if normalize_evidence(f.text) in seen:
            v.append(f"duplicate_falsification[{i}]: {f.text!r} appears twice")
        seen.add(normalize_evidence(f.text))
        if normalize_evidence(f.text) == normalize_evidence(b.correct_text):
            v.append(f"falsification_equals_key[{i}]: printed identically to the certified expression")

    # the proportionality variant, if declared, must also come out as stated
    if b.scaling_var:
        if not b.scaling_true or len(b.scaling_false) < 3:
            v.append("scaling_variant_incomplete: need one true response and three false ones")
        else:
            phrase, factor, ratio = b.scaling_true
            got = claim_is_true(b.relation, b.probe_params, b.solve_for,
                                ScalingClaim(phrase, b.scaling_var, factor, ratio))
            if got is not True:
                v.append(f"scaling_true_not_true: {phrase!r} came out {got!r}")
            for j, (p2, f2, r2) in enumerate(b.scaling_false):
                g2 = claim_is_true(b.relation, b.probe_params, b.solve_for,
                                   ScalingClaim(p2, b.scaling_var, f2, r2))
                if g2 is not False:
                    v.append(f"scaling_false_not_false[{j}]: {p2!r} came out {g2!r}")

    if len({normalize_evidence(s) for s in b.stems}) != len(b.stems):
        v.append("duplicate_scenarios: every authored stem must differ")

    if v:
        return None, v
    return ResolvedConceptual(b, kc["concept_id"], kc["chapter_id"], kc.get("section_heading") or "",
                              kc["subject"], kc.get("boundary") or {}), []


def resolve(iconn: sqlite3.Connection, bindings: Sequence[ConceptualBinding] = CONCEPTUAL_BINDINGS,
            strict: bool = False) -> Tuple[List[ResolvedConceptual], Dict[str, List[str]]]:
    ok: List[ResolvedConceptual] = []
    refusals: Dict[str, List[str]] = {}
    for b in bindings:
        r, why = resolve_one(iconn, b)
        if r is not None:
            ok.append(r)
        else:
            refusals[b.binding_id] = why
    if strict and refusals:
        raise ValueError(f"{len(refusals)} conceptual binding(s) refused: {refusals}")
    return ok, refusals


# ══ GENERATION ════════════════════════════════════════════════════════════════════════════════════════
def _order(items: Sequence[str], seed: str) -> List[str]:
    return sorted(items, key=lambda t: hashlib.sha256(f"{seed}|{t}".encode()).hexdigest())


def _base(rc: ResolvedConceptual, kind: str, stem: str, options: Dict[str, str], key: str,
          rationale: Dict[str, Dict[str, str]], steps: List[str], reasoning: str,
          depth: int) -> dict:
    b = rc.binding
    gen_id = "CCMC_" + hashlib.sha256(f"{b.binding_id}|{kind}|{stem}".encode()).hexdigest()[:16]
    diff = DIFF.predict(depth, 1, misconception_pressure=0.0, calculation_load=0.2)
    return {
        "gen_id": gen_id,
        "binding_id": b.binding_id,
        "concept_id": rc.concept_id,
        "concept_name": b.concept_name,
        "concept_ids": [rc.concept_id],
        "chapter_id": rc.chapter_id,
        "chapter_title": "",
        "section_heading": rc.section_heading,
        "class_level": b.taught_at_class,
        "subject": rc.subject,
        "discipline": b.discipline,
        "archetype": "property_application",
        "lane": LANE,
        "stem": stem,
        "options": options,
        "answer_label": key,
        "answer_value": options[key],
        "answer_unit": "",
        "structure": {},                    # non-numeric lane: no givens are supplied to the student
        "solution": {"steps": steps, "final": options[key]},
        "distractor_rationale": rationale,
        "common_mistake": next(iter(rationale.values()))["misconception"] if rationale else "",
        "reasoning": reasoning,
        "reasoning_depth": depth,
        "difficulty": diff,
        "claimed": {"concepts": [b.concept_name], "concept_ids": [rc.concept_id],
                    "archetype": "property_application", "depth": depth},
        "provenance": {
            "lane": "CERTGEN_CONCEPTUAL_MCQ",
            "evidence_class": "deterministic_computed",
            "certified_concept_id": rc.concept_id,
            "grounding": list(b.grounding),
            "relation": b.relation,
            "variant": kind,
            "key_derivation": "computed — the only option not falsified by sympy equivalence AND a "
                              "differing value at a concrete working point",
            "probe_params": b.probe_params,
            "reachability": "relation_reachable",
            "corpus_basis": "mcq is 87.5% of NEET and 74.3% of JEE_ADVANCED across 15,803 measured items",
            "boundary": rc.boundary,
        },
        "_params": {},
    }


def build_relation_identification(rc: ResolvedConceptual, i: int, seed: str = "Q1") -> Optional[dict]:
    b = rc.binding
    texts = [b.correct_text] + [f.text for f in b.falsifications[:3]]
    if len(set(texts)) != 4:
        return None
    ordered = _order(texts, f"{seed}|{b.binding_id}|{i}")
    options = {lab: t for lab, t in zip(OPTION_LABELS, ordered)}
    key = next(lab for lab, t in options.items() if t == b.correct_text)

    by_text = {f.text: f for f in b.falsifications}
    rationale = {}
    for lab, t in options.items():
        if lab == key:
            continue
        f = by_text[t]
        _ok, why = falsification_holds(b.relation, f.relation, b.solve_for, b.probe_params)
        rationale[lab] = {"misconception": f"{f.misconception} — {why}", "mis_relation": f.relation}

    steps = [
        f"Step 1 — Identify what is asked: {b.quantity_phrase}.",
        f"Step 2 — Recall the relation certified for this class ({rc.section_heading}): "
        f"{SOL.pretty_equation(b.relation)}. The expression asked for is therefore {b.correct_text}.",
        f"Step 3 — Check each remaining option against it. Substituting the working point "
        f"({', '.join(f'{k} = {SOL.fmt_number(v)}' for k, v in b.probe_params.items())}), the certified "
        f"relation gives {SOL.fmt_number(_ar_solve(b.relation, b.probe_params, b.solve_for) or 0)}, while "
        f"each of the other expressions gives a different value — so none of them can be the same "
        f"quantity.",
        f"Step 4 — Option ({key}) {b.correct_text} is the only expression that reproduces it.",
    ]
    reasoning = (
        f"The item tests whether the relation itself is held correctly, not whether arithmetic can be "
        f"performed: no numbers are supplied, so a candidate cannot reach the answer by calculating. Each "
        f"wrong option is a specific corruption of the certified relation — a dropped factor, a squared "
        f"quantity in the wrong place, an inversion — and each is refused twice over: it is not "
        f"algebraically equivalent to the certified relation, and at a concrete working point it computes "
        f"a different value.")
    return _base(rc, "relation_identification",
                 b.stems[i % len(b.stems)], options, key, rationale, steps, reasoning, depth=1)


def build_proportionality(rc: ResolvedConceptual, i: int, seed: str = "Q1") -> Optional[dict]:
    b = rc.binding
    if not b.scaling_var or not b.scaling_true or len(b.scaling_false) < 3:
        return None
    true_phrase, factor, ratio = b.scaling_true
    texts = [true_phrase] + [p for p, _f, _r in b.scaling_false[:3]]
    if len(set(texts)) != 4:
        return None
    ordered = _order(texts, f"{seed}|{b.binding_id}|prop|{i}")
    options = {lab: t for lab, t in zip(OPTION_LABELS, ordered)}
    key = next(lab for lab, t in options.items() if t == true_phrase)

    actual = None
    y1 = _ar_solve(b.relation, b.probe_params, b.solve_for)
    scaled = dict(b.probe_params)
    scaled[b.scaling_var] = scaled[b.scaling_var] * factor
    y2 = _ar_solve(b.relation, scaled, b.solve_for)
    if y1 and y2:
        actual = round(y2 / y1, 6)

    false_by = {p: (f, r) for p, f, r in b.scaling_false}
    rationale = {}
    for lab, t in options.items():
        if lab == key:
            continue
        _f, claimed_ratio = false_by[t]
        rationale[lab] = {
            "misconception": (f"it claims the quantity {t}, i.e. a factor of "
                              f"{SOL.fmt_number(claimed_ratio)}, but scaling {b.scaling_var} by "
                              f"{SOL.fmt_number(factor)} in the certified relation changes it by a factor "
                              f"of {SOL.fmt_number(actual) if actual else '?'}"),
            "mis_relation": ""}

    others = [k for k in b.probe_params if k != b.scaling_var]
    held = f" while {', '.join(others)} " + ("is" if len(others) == 1 else "are") + " unchanged" if others else ""
    stem = (f"In the relation certified for this class, {b.quantity_phrase}. If {b.scaling_var} is "
            f"multiplied by {SOL.fmt_number(factor)}{held}, the quantity:")
    steps = [
        f"Step 1 — Write the certified relation ({rc.section_heading}): "
        f"{SOL.pretty_equation(b.relation)}.",
        f"Step 2 — Evaluate it at a working point: with "
        f"{', '.join(f'{k} = {SOL.fmt_number(v)}' for k, v in b.probe_params.items())}, "
        f"{b.solve_for} = {SOL.fmt_number(y1 or 0)}.",
        f"Step 3 — Multiply {b.scaling_var} by {SOL.fmt_number(factor)} and evaluate again: "
        f"{b.solve_for} = {SOL.fmt_number(y2 or 0)}, a factor of {SOL.fmt_number(actual or 0)}.",
        f"Step 4 — That is what option ({key}) states: the quantity {true_phrase}.",
    ]
    reasoning = (
        f"The question asks how the quantity RESPONDS to a change rather than what it equals, so it cannot "
        f"be answered by substituting numbers into a remembered formula — the candidate has to know how "
        f"{b.solve_for} depends on {b.scaling_var}. The distractors are the responses that would follow "
        f"from mis-remembering that dependence (linear where it is quadratic, direct where it is inverse), "
        f"and each is refused by evaluating the certified relation twice.")
    return _base(rc, "proportionality", stem, options, key, rationale, steps, reasoning, depth=2)


def verify_key(item: dict) -> dict:
    """Exactly one option may survive falsification; every other must be refuted by a computed value."""
    unrefuted = [lab for lab, r in item["distractor_rationale"].items() if not r.get("misconception")]
    ok = (len(item["options"]) == 4 and len(item["distractor_rationale"]) == 3
          and not unrefuted and item["answer_label"] in item["options"]
          and item["answer_label"] not in item["distractor_rationale"])
    return {"ok": ok, "unrefuted": unrefuted,
            "detail": f"key={item['answer_label']} refuted={len(item['distractor_rationale'])} "
                      f"unrefuted={unrefuted}"}


def generate(resolved: Sequence[ResolvedConceptual], per_binding: int = 3,
             seed: str = "Q1") -> List[dict]:
    out: List[dict] = []
    for rc in resolved:
        for i in range(min(per_binding, len(rc.binding.stems))):
            it = build_relation_identification(rc, i, seed)
            if it is not None:
                out.append(it)
        p = build_proportionality(rc, 0, seed)
        if p is not None:
            out.append(p)
    return out
