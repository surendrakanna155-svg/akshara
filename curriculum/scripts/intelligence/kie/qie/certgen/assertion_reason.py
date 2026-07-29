"""W3 — Assertion-Reason with a COMPUTED key.

WHY THIS FORM WAS RETIRED, AND WHAT IT TAKES TO UN-RETIRE IT.

`kie/qie/retired_families.py` bans Assertion-Reason under standing law R3-8 (red team, 2026-07-11). The
confirmed defect: the frozen `kie/qpgen/templates.py::_ar_family.build` returns `{"answer": _AR_OPTS[0]}`
for EVERY assertion-reason item — the key is option (a) regardless of whether the assertion is true,
whether the reason is true, or whether the reason explains the assertion. The retirement note states the
condition for lifting it exactly:

    "the family stays quarantined until the frozen engine is re-versioned with a computed key."

This module supplies that computed key, WITHOUT touching the frozen engine. It does not un-retire
`_ar_family`; that builder stays banned and unreachable. Lane C authors its own AR items, and the key falls
out of three separately computed facts rather than being chosen.

WHAT "COMPUTED" MEANS HERE. The four standard options differ only in the truth of A, the truth of R, and
whether R explains A. So the key is determined once those three are known — and all three are derived:

  truth(A)         a claim about how the certified relation BEHAVES ("at constant resistance, doubling the
                   current doubles the potential difference"). Verified by solving the relation twice, once
                   with the base parameters and once with the scaled parameter, and comparing the ratio.
                   Nothing is looked up; a false claim fails the same arithmetic.
  truth(R)         R is either the concept's own certified relation (true, and grounded in the index by
                   `certgen.binding`'s rule) or a deliberate corruption of it. A corruption is proved false
                   by sympy: it must NOT be algebraically equivalent to the certified relation.
  explains(R, A)   TRUE by construction when A was derived FROM R — the probe that established A used that
                   very relation. FALSE by construction when R is a true relation from a DIFFERENT
                   certified concept whose symbols cannot even express A's quantities, which is checked
                   rather than assumed.

Every one of the four keys is reachable, and the option letter varies with the construction — which is
precisely the property whose absence got the family retired.

    (a) Both A and R are true, and R is the correct explanation of A
    (b) Both A and R are true, but R is NOT the correct explanation of A
    (c) A is true but R is false
    (d) A is false but R is true

Deterministic, no model calls, read-only against every store.
"""
from __future__ import annotations

import hashlib
import json
import re
import sqlite3
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Sequence, Tuple

import sympy

from kie.qie.certgen import solution as SOL
from kie.qie.certgen.binding import evidence_blob, normalize_evidence
from kie.qie.factory import gates as G
from kie.qie.knowledge import difficulty as DIFF
from kie.qie.knowledge import planner as P

LANE = "ASSERTION_RELATION"
ARCHETYPE = "assertion_reason"

AR_OPTIONS: Dict[str, str] = {
    "a": "Both A and R are true, and R is the correct explanation of A",
    "b": "Both A and R are true, but R is not the correct explanation of A",
    "c": "A is true but R is false",
    "d": "A is false but R is true",
}


# ── the claim whose truth is computed ─────────────────────────────────────────────────────────────────
@dataclass(frozen=True)
class ScalingClaim:
    """A statement about how the certified relation BEHAVES, phrased in words and checked by arithmetic.

    "At constant resistance, doubling the current doubles the potential difference" becomes:
    scale `I` by 2, expect the solved target to scale by 2. Solving the relation twice settles it.
    """
    text: str
    var: str                 # the given that is scaled
    factor: float            # by how much
    expected_ratio: float    # what the target is claimed to do


@dataclass(frozen=True)
class ARBinding:
    binding_id: str
    discipline: str
    taught_at_class: int
    concept_name: str                    # the concept whose relation R states
    grounding: Tuple[str, ...]
    relation: str                        # the CERTIFIED relation (R, when true)
    solve_for: str
    base_params: Dict[str, float]        # a concrete working point for the probe
    reason_true_text: str                # R stated in words, true
    reason_false_text: str               # R corrupted, false
    reason_false_relation: str           # must NOT be equivalent to `relation`
    # SEVERAL true claims, not one. Keys (a), (b) and (c) all need a TRUE assertion, and reusing a single
    # sentence for all three makes them near-duplicates of one another — `near_duplicate` quarantined 3 of
    # 16 items for exactly that. Different probes of the same certified relation give genuinely different
    # questions rather than one question with the Reason line swapped.
    true_claims: Tuple[ScalingClaim, ...]
    false_claim: ScalingClaim
    # a TRUE statement from a DIFFERENT certified concept, used to build option (b)
    unrelated_concept_name: str
    unrelated_discipline: str
    unrelated_class: int
    unrelated_grounding: Tuple[str, ...]
    unrelated_relation: str
    unrelated_text: str


@dataclass(frozen=True)
class ResolvedAR:
    binding: ARBinding
    concept_id: str
    chapter_id: str
    section_heading: str
    subject: str
    boundary: dict
    unrelated_concept_id: str


# ══ TRUTH, COMPUTED ═══════════════════════════════════════════════════════════════════════════════════
def _solve(relation: str, params: Dict[str, float], target: str) -> Optional[float]:
    res = G.independent_solve({"givens": {k: {"value": v} for k, v in params.items()},
                               "relation": relation, "solve_for": target})
    if res.get("verdict") != "solved":
        return None
    try:
        return float(res["solver_answer"])
    except (TypeError, ValueError):
        return None


def claim_is_true(relation: str, base: Dict[str, float], target: str,
                  claim: ScalingClaim, tol: float = 1e-6) -> Optional[bool]:
    """Solve the certified relation at the working point and again with `claim.var` scaled, then compare
    the ratio the target ACTUALLY moved by against the ratio the claim asserts. Returns None if the
    relation could not be solved at either point (the claim is then unverifiable and is never used)."""
    y1 = _solve(relation, base, target)
    if y1 is None or abs(y1) < 1e-12:
        return None
    scaled = dict(base)
    if claim.var not in scaled:
        return None
    scaled[claim.var] = scaled[claim.var] * claim.factor
    y2 = _solve(relation, scaled, target)
    if y2 is None:
        return None
    return abs((y2 / y1) - claim.expected_ratio) <= tol * max(1.0, abs(claim.expected_ratio))


def relations_equivalent(a: str, b: str, target: str) -> bool:
    """Are two relations the same statement, allowing algebraic rearrangement? Used to PROVE a corrupted
    reason is genuinely false rather than a harmless restatement of the certified one."""
    syms = {s for s in re.findall(r"[A-Za-z_]\w*", f"{a} {b}")}
    fa = G._solve_for_target(a, target, syms)
    fb = G._solve_for_target(b, target, syms)
    if fa is None or fb is None:
        return False
    try:
        return bool(sympy.simplify(fa - fb) == 0)
    except Exception:
        return False


def reason_can_express_claim(relation: str, claim_var: str, target: str) -> bool:
    """Can this relation even speak to the claim — does it mention both the scaled quantity and the target?

    This is what makes `explains(R, A) == False` a CHECK rather than an assertion. A relation that never
    mentions the current cannot explain what happens when the current is doubled.
    """
    syms = {s for s in re.findall(r"[A-Za-z_]\w*", relation)}
    return claim_var in syms and target in syms


# ══ THE BINDINGS ══════════════════════════════════════════════════════════════════════════════════════
AR_BINDINGS: Tuple[ARBinding, ...] = (

    ARBinding(
        "AR_PHY10_OHM", "Physics", 10, "Ohm's Law", ("v = ir",),
        "V = I * R", "V", {"I": 3.0, "R": 8.0},
        "For a conductor at constant temperature, the potential difference across it is directly "
        "proportional to the current through it, the constant of proportionality being its resistance "
        "(V = IR).",
        "For a conductor at constant temperature, the potential difference across it is inversely "
        "proportional to the current through it (V = I/R).",
        "V = I / R",
        (ScalingClaim("At constant resistance, doubling the current through a conductor doubles the "
                      "potential difference across it.", "I", 2.0, 2.0),
         ScalingClaim("At constant resistance, reducing the current through a conductor to one third of "
                      "its value reduces the potential difference across it to one third.", "I", 1 / 3, 1 / 3),
         ScalingClaim("For a fixed current, replacing a conductor by one of four times the resistance "
                      "makes the potential difference across it four times as large.", "R", 4.0, 4.0)),
        # probes a DIFFERENT quantity from any true claim, so the false-assertion item is not a
        # one-word variant of the true-assertion one (`near_duplicate` caught exactly that)
        ScalingClaim("For a fixed current, trebling the resistance of a conductor leaves the potential "
                     "difference across it unchanged.", "R", 3.0, 1.0),
        "Electric Power", "Physics", 10, ("p = vi = i^2 r = v^2/r",),
        "Pw = I ** 2 * R",
        "The power dissipated in a resistor carrying a steady current is the product of the square of "
        "the current and the resistance (P = I^2R).",
    ),

    ARBinding(
        "AR_PHY11_KE", "Physics", 11, "Kinetic Energy", ("(1/2) m v^2",),
        "K = m * v ** 2 / 2", "K", {"m": 4.0, "v": 5.0},
        "The kinetic energy of a body of given mass is proportional to the SQUARE of its speed "
        "(K = (1/2)mv^2).",
        "The kinetic energy of a body of given mass is directly proportional to its speed "
        "(K = (1/2)mv).",
        "K = m * v / 2",
        (ScalingClaim("For a body of fixed mass, doubling its speed makes its kinetic energy four times "
                      "as large.", "v", 2.0, 4.0),
         ScalingClaim("For a body of fixed mass, reducing its speed to half makes its kinetic energy one "
                      "quarter of its original value.", "v", 0.5, 0.25),
         ScalingClaim("At a fixed speed, a body of three times the mass has three times the kinetic "
                      "energy.", "m", 3.0, 3.0)),
        ScalingClaim("Halving the mass of a body while its speed stays the same leaves its kinetic "
                     "energy unchanged.", "m", 0.5, 1.0),
        "Kinematic Equations for Uniformly Accelerated Motion", "Physics", 11, ("v = v0 + a t",),
        "v = u + a * t",
        "For uniformly accelerated rectilinear motion, the final velocity equals the initial velocity "
        "plus the product of acceleration and time (v = u + at).",
    ),

    ARBinding(
        "AR_PHY8_PRESSURE", "Physics", 8, "Pressure (Force per Unit Area)", ("pressure = force / area",),
        "Pr = F / A", "Pr", {"F": 240.0, "A": 6.0},
        "The pressure exerted on a surface is the force acting normally on it divided by the area over "
        "which that force acts (P = F/A).",
        "The pressure exerted on a surface is the product of the force acting on it and the area over "
        "which that force acts (P = F x A).",
        "Pr = F * A",
        (ScalingClaim("For a fixed force, spreading it over twice the area halves the pressure on the "
                      "surface.", "A", 2.0, 0.5),
         ScalingClaim("For a fixed area of contact, trebling the force trebles the pressure on the "
                      "surface.", "F", 3.0, 3.0),
         ScalingClaim("For a fixed force, reducing the area of contact to one quarter makes the pressure "
                      "on the surface four times as large.", "A", 0.25, 4.0)),
        ScalingClaim("For a fixed area of contact, doubling the force leaves the pressure on the "
                     "surface unchanged.", "F", 2.0, 1.0),
        "Density (Mass per Unit Volume)", "Physics", 8, ("density = mass / volume",),
        "D = m / V",
        "The density of a substance is its mass divided by the volume it occupies (D = m/V).",
    ),

    ARBinding(
        "AR_MAT6_AREA", "Mathematics", 6, "Area of a Rectangle", ("area = length x width",),
        "A = l * w", "A", {"l": 12.0, "w": 5.0},
        "The area of a rectangle is the product of its length and its width.",
        "The area of a rectangle is the sum of its length and its width.",
        "A = l + w",
        (ScalingClaim("If the length of a rectangle is doubled while its width is unchanged, its area "
                      "is doubled.", "l", 2.0, 2.0),
         ScalingClaim("If the width of a rectangle is trebled while its length is unchanged, its area "
                      "is trebled.", "w", 3.0, 3.0),
         ScalingClaim("If the length of a rectangle is halved while its width is unchanged, its area "
                      "is halved.", "l", 0.5, 0.5)),
        ScalingClaim("If the width of a rectangle is doubled while its length is unchanged, its area "
                     "is unchanged.", "w", 2.0, 1.0),
        "Perimeter of a Rectangle", "Mathematics", 6, ("perimeter = 2 x (length + breadth)",),
        "P = 2 * (l + b)",
        "The perimeter of a rectangle is twice the sum of its length and its breadth.",
    ),
)


# ══ RESOLUTION ════════════════════════════════════════════════════════════════════════════════════════
def _certified(iconn, discipline: str, cls: int, name: str) -> List[dict]:
    return [c for c in P.certified_universe_by_discipline(iconn, discipline, [cls])
            if c["canonical_name"] == name]


def resolve_one(iconn: sqlite3.Connection, b: ARBinding) -> Tuple[Optional[ResolvedAR], List[str]]:
    v: List[str] = []

    def _one(disc, cls, name, grounding, label):
        m = _certified(iconn, disc, cls, name)
        if not m:
            v.append(f"unresolved_concept[{label}]: no CERTIFIED {disc} concept named {name!r} at class {cls}")
            return None
        if len(m) > 1:
            v.append(f"ambiguous_concept[{label}]: {len(m)} matches for {name!r}")
            return None
        kc = m[0]
        blob = evidence_blob(kc)
        for term in grounding:
            if normalize_evidence(term) not in blob:
                v.append(f"ungrounded_relation[{label}]: {term!r} absent from {kc['concept_id']}'s evidence")
        return kc

    kc = _one(b.discipline, b.taught_at_class, b.concept_name, b.grounding, "assertion")
    uk = _one(b.unrelated_discipline, b.unrelated_class, b.unrelated_concept_name,
              b.unrelated_grounding, "unrelated")
    if kc is None or uk is None or v:
        return None, v or ["unresolved"]

    if uk["concept_id"] == kc["concept_id"]:
        v.append("unrelated_is_same_concept: option (b) needs a reason from a DIFFERENT certified concept")
    if uk["taught_at_class"] > b.taught_at_class:
        v.append(f"above_class_unrelated: {b.unrelated_concept_name!r} is taught at class "
                 f"{uk['taught_at_class']}, above the question's class {b.taught_at_class}")

    # ── the truth table must actually come out as declared; every entry is COMPUTED ──
    if len(b.true_claims) < 3:
        v.append("too_few_true_claims: keys (a), (b) and (c) each need their OWN true assertion, or the "
                 "three items are near-duplicates of one another")
    if len({normalize_evidence(c.text) for c in b.true_claims}) != len(b.true_claims):
        v.append("duplicate_true_claims: every true assertion must be a genuinely different statement")
    for i, tc in enumerate(b.true_claims):
        got = claim_is_true(b.relation, b.base_params, b.solve_for, tc)
        if got is not True:
            v.append(f"true_claim_not_true[{i}]: the probe made {tc.text!r} come out {got!r}")
        if not reason_can_express_claim(b.relation, tc.var, b.solve_for):
            v.append(f"certified_reason_cannot_explain[{i}]: {b.relation!r} does not mention both "
                     f"{tc.var!r} and {b.solve_for!r}")
        if reason_can_express_claim(b.unrelated_relation, tc.var, b.solve_for):
            v.append(f"unrelated_reason_can_explain[{i}]: {b.unrelated_relation!r} mentions both "
                     f"{tc.var!r} and {b.solve_for!r}, so option (b) would not be safely wrong")
    t_false = claim_is_true(b.relation, b.base_params, b.solve_for, b.false_claim)
    if t_false is not False:
        v.append(f"false_claim_not_false: the probe made {b.false_claim.text!r} come out {t_false!r}")

    if relations_equivalent(b.relation, b.reason_false_relation, b.solve_for):
        v.append(f"false_reason_is_actually_equivalent: {b.reason_false_relation!r} is a rearrangement of "
                 f"the certified {b.relation!r}, so it is not false")

    if v:
        return None, v
    return ResolvedAR(b, kc["concept_id"], kc["chapter_id"], kc.get("section_heading") or "",
                      kc["subject"], kc.get("boundary") or {}, uk["concept_id"]), []


def resolve(iconn: sqlite3.Connection, bindings: Sequence[ARBinding] = AR_BINDINGS,
            strict: bool = False) -> Tuple[List[ResolvedAR], Dict[str, List[str]]]:
    ok: List[ResolvedAR] = []
    refusals: Dict[str, List[str]] = {}
    for b in bindings:
        r, why = resolve_one(iconn, b)
        if r is not None:
            ok.append(r)
        else:
            refusals[b.binding_id] = why
    if strict and refusals:
        raise ValueError(f"{len(refusals)} AR binding(s) refused: {refusals}")
    return ok, refusals


# ══ GENERATION ════════════════════════════════════════════════════════════════════════════════════════
def _stem(assertion: str, reason: str) -> str:
    return (f"Assertion (A): {assertion}\n"
            f"Reason (R): {reason}\n"
            f"In the light of the above two statements, choose the most appropriate answer.")


def build_variant(ra: ResolvedAR, key: str) -> Optional[dict]:
    """One AR item whose key is `key` BECAUSE of how it was built — and re-derived here to prove it."""
    b = ra.binding
    # each TRUE-assertion key draws a different probe, so (a), (b) and (c) are three distinct questions
    if key == "a":
        assertion, reason = b.true_claims[0], b.reason_true_text
        reason_rel, a_true, r_true = b.relation, True, True
    elif key == "b":
        assertion, reason = b.true_claims[1 % len(b.true_claims)], b.unrelated_text
        reason_rel, a_true, r_true = b.unrelated_relation, True, True
    elif key == "c":
        assertion, reason = b.true_claims[2 % len(b.true_claims)], b.reason_false_text
        reason_rel, a_true, r_true = b.reason_false_relation, True, False
    elif key == "d":
        assertion, reason = b.false_claim, b.reason_true_text
        reason_rel, a_true, r_true = b.relation, False, True
    else:
        return None

    # ── RE-DERIVE the three facts; never trust the branch above ──
    computed_a = claim_is_true(b.relation, b.base_params, b.solve_for, assertion)
    if computed_a is None or computed_a is not a_true:
        return None
    if r_true:
        # a true reason is either the concept's own certified relation or the unrelated certified one
        if reason_rel not in (b.relation, b.unrelated_relation):
            return None
    else:
        if relations_equivalent(b.relation, reason_rel, b.solve_for):
            return None                     # a "false" reason that is really the certified one
    explains = bool(r_true and reason_rel == b.relation
                    and reason_can_express_claim(reason_rel, assertion.var, b.solve_for))

    derived = ("a" if (a_true and r_true and explains) else
               "b" if (a_true and r_true and not explains) else
               "c" if (a_true and not r_true) else
               "d" if (not a_true and r_true) else None)
    if derived != key:
        return None                         # the construction and the truth table disagree — never ship

    stem = _stem(assertion.text, reason)
    gen_id = "CAR_" + hashlib.sha256(f"{b.binding_id}|{key}|{stem}".encode()).hexdigest()[:16]

    # DEPTH, computed by the SAME rule the operator pipelines use (`compose.reasoning_depth`:
    # depth[out] = 1 + max(depth[inputs]), givens at 0) applied to the judgement DAG this form requires:
    #
    #     truth(A)      = 1          from the stem
    #     truth(R)      = 1          from the stem, independent of truth(A)
    #     explains(R,A) = 1 + max(1,1) = 2     — only askable once BOTH truths are settled
    #     option        = 1 + max(1,1,2) = 3
    #
    # This is not the difficulty band being talked upwards. It is the same longest-dependency-chain
    # definition used for every other Lane C item, applied to the judgements this archetype actually
    # requires — and the third judgement genuinely cannot be made before the first two.
    # `calculation_load` stays LOW (0.2) precisely because the work here is reasoning, not arithmetic.
    depth = 3
    diff = DIFF.predict(depth, 2, misconception_pressure=0.0, calculation_load=0.2)

    steps = [
        f"Step 1 — Test the Assertion. {assertion.text} Using the certified Class-{b.taught_at_class} "
        f"relation {SOL.pretty_equation(b.relation)} at a working point "
        f"({', '.join(f'{k} = {SOL.fmt_number(v)}' for k, v in b.base_params.items())}), scale "
        f"{assertion.var} by {SOL.fmt_number(assertion.factor)} and recompute: the value of {b.solve_for} "
        f"changes by a factor of {SOL.fmt_number(_ratio(b, assertion))}, while the Assertion claims "
        f"{SOL.fmt_number(assertion.expected_ratio)}. So A is {'TRUE' if a_true else 'FALSE'}.",
        f"Step 2 — Test the Reason. {reason} This is "
        + (f"the certified relation for '{b.concept_name}', so R is TRUE."
           if r_true and reason_rel == b.relation else
           f"the certified relation for '{b.unrelated_concept_name}', so R is TRUE."
           if r_true else
           f"not equivalent to the certified relation {SOL.pretty_equation(b.relation)}, so R is FALSE."),
        f"Step 3 — Test the explanation link. "
        + ("R is the very relation from which the Assertion was derived, so R DOES explain A."
           if explains else
           f"R is true but concerns {b.unrelated_concept_name}; it does not mention both "
           f"{assertion.var} and {b.solve_for}, so it CANNOT account for the Assertion."
           if r_true and not explains else
           "R is false, so the question of whether it explains A does not arise."),
        f"Step 4 — Therefore the correct option is ({key}) {AR_OPTIONS[key]}.",
    ]

    return {
        "gen_id": gen_id,
        "binding_id": b.binding_id,
        "concept_id": ra.concept_id,
        "concept_name": b.concept_name,
        "concept_ids": [ra.concept_id] + ([ra.unrelated_concept_id] if key == "b" else []),
        "chapter_id": ra.chapter_id,
        "chapter_title": "",
        "section_heading": ra.section_heading,
        "class_level": b.taught_at_class,
        "subject": ra.subject,
        "discipline": b.discipline,
        "archetype": ARCHETYPE,
        "lane": LANE,
        "stem": stem,
        "options": dict(AR_OPTIONS),
        "answer_label": key,
        "answer_value": AR_OPTIONS[key],
        "answer_unit": "",
        "structure": {},                    # non-numeric lane: no relation/givens are declared
        "solution": {"steps": steps, "final": AR_OPTIONS[key]},
        "distractor_rationale": _ar_rationale(key, a_true, r_true, explains),
        "common_mistake": ("assuming that two true statements must stand in an explanatory relation"
                           if key == "b" else
                           "not checking the Reason independently of the Assertion"),
        "reasoning": (
            f"The item is decided by three separately established facts: whether A is true, whether R is "
            f"true, and whether R accounts for A. A is settled by computation on the certified relation "
            f"{SOL.pretty_equation(b.relation)} rather than by recall, and R is settled by comparing the "
            f"stated relation with the certified one. The third question is the one that separates a strong "
            f"candidate from a weak one: two true statements need not stand in an explanatory relation, and "
            f"option (b) exists precisely to catch a student who assumes they must."),
        "reasoning_depth": depth,
        "difficulty": diff,
        "claimed": {"concepts": [b.concept_name] + ([b.unrelated_concept_name] if key == "b" else []),
                    "concept_ids": [ra.concept_id] + ([ra.unrelated_concept_id] if key == "b" else []),
                    "archetype": ARCHETYPE, "depth": depth},
        "provenance": {
            "lane": "CERTGEN_ASSERTION_REASON",
            "evidence_class": "deterministic_computed",
            "certified_concept_id": ra.concept_id,
            "grounding": list(b.grounding),
            "relation": b.relation,
            "truth_table": {"assertion_true": a_true, "reason_true": r_true, "reason_explains": explains},
            "key_derivation": "computed from (truth(A), truth(R), explains(R,A)) — never hard-coded",
            "probe": {"var": assertion.var, "factor": assertion.factor,
                      "claimed_ratio": assertion.expected_ratio, "actual_ratio": _ratio(b, assertion),
                      "base_params": b.base_params},
            "boundary": ra.boundary,
            "r3_8": "computed key — the precondition recorded in retired_families.py for this form",
        },
        "_params": {},
    }


def _ratio(b: ARBinding, claim: ScalingClaim) -> float:
    y1 = _solve(b.relation, b.base_params, b.solve_for)
    scaled = dict(b.base_params)
    scaled[claim.var] = scaled[claim.var] * claim.factor
    y2 = _solve(b.relation, scaled, b.solve_for)
    if y1 is None or y2 is None or abs(y1) < 1e-12:
        return float("nan")
    return round(y2 / y1, 6)


def _ar_rationale(key: str, a_true: bool, r_true: bool, explains: bool) -> Dict[str, Dict[str, str]]:
    """Why each NON-key option is wrong, stated against the computed truth table."""
    facts = {"a": (True, True, True), "b": (True, True, False),
             "c": (True, False, None), "d": (False, True, None)}
    out: Dict[str, Dict[str, str]] = {}
    for lab, (wa, wr, we) in facts.items():
        if lab == key:
            continue
        why = []
        if wa != a_true:
            why.append(f"it requires A to be {'true' if wa else 'false'}, but A was computed "
                       f"{'true' if a_true else 'false'}")
        if wr != r_true:
            why.append(f"it requires R to be {'true' if wr else 'false'}, but R was computed "
                       f"{'true' if r_true else 'false'}")
        if we is not None and wa == a_true and wr == r_true and we != explains:
            why.append(f"it requires R {'to be' if we else 'not to be'} the explanation of A, but the "
                       f"explanation link was computed {'present' if explains else 'absent'}")
        out[lab] = {"misconception": "; ".join(why) or "it contradicts the computed truth table",
                    "mis_relation": ""}
    return out


def verify_options(item: dict) -> dict:
    """The AR counterpart of `gates.verify_distractors`.

    `verify_distractors` proves a numeric distractor by re-executing the mistake that computes it. An AR
    option is a SENTENCE about a truth table, so the analogous proof is different in mechanism and
    identical in force: each wrong option asserts a truth-configuration, and at least one entry of that
    configuration is contradicted by a value this engine COMPUTED. An option that nothing contradicts would
    be a second correct answer, and the item is refused.
    """
    tt = item["provenance"]["truth_table"]
    actual = (tt["assertion_true"], tt["reason_true"], tt["reason_explains"])
    expected = {"a": (True, True, True), "b": (True, True, False),
                "c": (True, False, None), "d": (False, True, None)}
    key = item["answer_label"]
    unrefuted: List[str] = []
    for lab, exp in expected.items():
        if lab == key:
            continue
        contradicted = any(e is not None and e != a for e, a in zip(exp, actual))
        if not contradicted:
            unrefuted.append(lab)
    ok = not unrefuted and expected[key][0] == actual[0] and expected[key][1] == actual[1] \
        and (expected[key][2] is None or expected[key][2] == actual[2])
    return {"ok": ok, "unrefuted": unrefuted,
            "detail": f"truth_table={actual} key={key} unrefuted_options={unrefuted}"}


def generate(resolved: Sequence[ResolvedAR], keys: Sequence[str] = ("a", "b", "c", "d")) -> List[dict]:
    """Every binding produces one item per reachable key, so the correct option is genuinely distributed
    rather than sitting on (a) — the defect that retired this family."""
    out: List[dict] = []
    for ra in resolved:
        for k in keys:
            it = build_variant(ra, k)
            if it is not None:
                out.append(it)
    return out
