"""Adversarial controls for the REPAIRED pre-generation gate.

The 1,000-spec trial's decisive negative result: the deterministic gates caught 20.0% of a
known-garbage probe arm vs 20.1% of the legitimate arm — statistically identical. They were blind to a
bad plan. Every defect below is one the OLD pipeline shipped to Opus and paid tokens for; each must now
be refused for free, BEFORE generation.

These run before any planning batch. If a known-bad plan survives, the run aborts — a gate that cannot
fail a known-bad plan is not a gate, and any yield measured through it is meaningless.
"""
from __future__ import annotations

from typing import Dict, List, Tuple

from kie.qie.knowledge import planner as P


class PlanControlBreach(Exception):
    """A known-garbage plan survived the pre-generation gate."""


def _universe() -> Dict[str, dict]:
    return {
        "KC_good": {"concept_id": "KC_good", "canonical_name": "Properties of Rational Numbers",
                    "subject": "Mathematics", "taught_at_class": 8, "chapter_id": "CH_MAT_8_01",
                    "sub_concepts": [], "prerequisites": [], "boundary": {}},
        "KC_partner8": {"concept_id": "KC_partner8", "canonical_name": "Multiplying a Monomial by a Polynomial",
                        "subject": "Mathematics", "taught_at_class": 8, "chapter_id": "CH_MAT_8_08",
                        "sub_concepts": [], "prerequisites": [], "boundary": {}},
        "KC_class11": {"concept_id": "KC_class11", "canonical_name": "Binomial Theorem",
                       "subject": "Mathematics", "taught_at_class": 11, "chapter_id": "CH_MAT_11_08",
                       "sub_concepts": [], "prerequisites": [], "boundary": {}},
        "KC_physics": {"concept_id": "KC_physics", "canonical_name": "Gauss's law",
                       "subject": "Physics", "taught_at_class": 12, "chapter_id": "CH_PHY_12_01",
                       "sub_concepts": [], "prerequisites": [], "boundary": {}},
    }


def _base() -> dict:
    return {"concept_id": "KC_good", "concept_name": "Properties of Rational Numbers",
            "subject": "Mathematics", "class_level": 8, "chapter_id": "CH_MAT_8_01",
            "archetype": "property_application", "intended_depth": 2, "composition": "single",
            "compose_with": []}


def controls() -> List[Tuple[str, str, dict]]:
    """(name, violation-substring that MUST be raised, spec)"""
    out = []

    # The national anthem as a Class-10 Mathematics concept — the defect that motivated this rebuild.
    c = _base(); c["concept_name"] = "Gahe tava jaya gatha"; c["concept_id"] = "KC_missing"
    out.append(("national_anthem_as_concept", "uncertified_concept", c))

    c = _base(); c["concept_name"] = "Contributors"; c["concept_id"] = "KC_missing"
    out.append(("front_matter_as_concept", "uncertified_concept", c))

    # junk NAME even when the id resolves — the name gate must fire on its own
    c = _base(); c["concept_name"] = "Try These"
    out.append(("activity_label_name", "junk_record", c))

    c = _base(); c["concept_name"] = "Telateltelt"
    out.append(("ocr_garbage_name", "junk_record", c))

    # subject mis-binding — 49.7% of the trial's refusals
    c = _base(); c["subject"] = "Biology"
    out.append(("subject_mismatch", "subject_mismatch", c))

    # doc-label grade leaking in as truth
    c = _base(); c["class_level"] = 11
    out.append(("class_mismatch", "class_mismatch", c))

    # incoherent archetype x depth — the planner's own bug, caught by the generator at token price
    c = _base(); c["archetype"] = "direct_recall"; c["intended_depth"] = 3
    out.append(("archetype_depth_incoherent", "archetype_depth_incoherent", c))

    c = _base(); c["archetype"] = "super_hard_reasoning"
    out.append(("unknown_archetype", "unknown_archetype", c))

    # composition across subjects — "Newton's law composed with Aufbau's principle"
    c = _base(); c["composition"] = "multi"; c["compose_with"] = ["KC_physics"]
    out.append(("cross_subject_composition", "unsupported_composition", c))

    # composition reaching ABOVE the class
    c = _base(); c["composition"] = "multi"; c["compose_with"] = ["KC_class11"]
    out.append(("above_class_composition", "unsupported_composition", c))

    # multi with no partner at all
    c = _base(); c["composition"] = "multi"; c["compose_with"] = []
    out.append(("empty_composition", "unsupported_composition", c))

    # concept that simply is not in the certified index
    c = _base(); c["concept_id"] = "KC_notreal"
    out.append(("uncertified_concept", "uncertified_concept", c))

    return out


def check_plan_controls() -> dict:
    uni = _universe()
    results = []
    for name, must_raise, spec in controls():
        v = P.check_plan(spec, uni)
        hit = any(must_raise in x for x in v)
        results.append({"control": name, "expected": must_raise, "raised": v, "caught": hit})
        if not hit:
            raise PlanControlBreach(
                f"plan control {name!r} SURVIVED the pre-generation gate: expected {must_raise!r}, got {v!r}")

    # the legitimate plan must pass — a gate that refuses everything is equally useless
    good = P.check_plan(_base(), uni)
    if good:
        raise PlanControlBreach(f"the known-GOOD plan was refused: {good!r}")

    # a legitimate SAME-CLASS, SAME-SUBJECT composition must pass
    c = _base(); c["composition"] = "multi"; c["compose_with"] = ["KC_partner8"]
    good_multi = P.check_plan(c, uni)
    if good_multi:
        raise PlanControlBreach(f"a legitimate in-class composition was refused: {good_multi!r}")

    return {"controls": len(results), "all_caught": True, "good_plan_passes": True,
            "good_composition_passes": True, "results": results}
