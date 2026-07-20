"""Deterministic adversarial control floor for QDI certification (Phase 4).

QDI patterns are ultimately certified by an INDEPENDENT model auditor (design patterns are not sympy-verifiable
the way a numeric answer is), but a DETERMINISTIC floor still gates every pattern:
  * anti-copying  — structure is transferable; wording is not ours to reuse (5-gram shingle overlap).
  * structural    — a pattern with no design content is not a pattern.
  * scope-link    — the exam-profile / min-class binding must be legal.
These controls prove that floor cannot pass a known-bad pattern (and does not cry wolf on a good one).
"""
from __future__ import annotations

from kie.qie.knowledge import qdi as QDI
from kie.qie.knowledge import qdi_link as QL


class QdiControlBreach(Exception):
    """A known-bad QDI pattern survived the deterministic floor."""


def _abstract_pattern() -> dict:
    return {"pattern_id": "QDP_ctl", "exam": "JEE_Main", "subject": "Mathematics",
            "archetype": "multi_step_numerical", "difficulty_band": "hard",
            "design_summary": ("An observable is named against a symbolic baseline rather than computed, so "
                               "the unknown scale must be eliminated by ratio before the residual is solved."),
            "reasoning_chain": ["identify the conserved scale", "eliminate it via ratio", "solve residual"]}


def _structural_ok(p: dict) -> bool:
    return len((p.get("design_summary") or "").strip()) >= 20


def check_copying_controls() -> dict:
    source = ("A particle moves with speed v at angle theta to the axis. Find the acceleration produced by "
              "the constant net force acting on it along the privileged direction of the field.")
    echo = {"design_summary": source, "reasoning_chain": []}
    if QDI.assert_no_copying(echo, source) is None:
        raise QdiControlBreach("copying control SURVIVED: a verbatim-echo pattern passed the anti-copying gate")
    if QDI.assert_no_copying(_abstract_pattern(), source) is not None:
        raise QdiControlBreach("anti-copying gate rejected a legitimately-abstract pattern (cries wolf)")
    return {"copying_controls": 2, "all_ok": True}


def check_structural_controls() -> dict:
    if _structural_ok({"design_summary": "", "reasoning_chain": []}):
        raise QdiControlBreach("structural control SURVIVED: an empty pattern passed")
    if not _structural_ok(_abstract_pattern()):
        raise QdiControlBreach("a well-formed pattern failed the structural gate")
    return {"structural_controls": 1, "all_ok": True}


def check_scope_controls() -> dict:
    bad = [
        {"pattern_id": "QDP_x", "subject": "Physics", "min_class": 11, "exam_profile": "MADE_UP"},
        {"pattern_id": "QDP_x", "subject": "Physics", "min_class": 99, "exam_profile": "NEET"},
        {"pattern_id": "", "subject": "Physics", "min_class": 11, "exam_profile": "NEET"},
    ]
    for b in bad:
        if QL.validate_scope_link(b) is None:
            raise QdiControlBreach(f"scope control SURVIVED: {b!r}")
    good = QL.scope_link_for({"pattern_id": "QDP_x", "exam": "NEET", "subject": "Biology"})
    if QL.validate_scope_link(good) is not None:
        raise QdiControlBreach("a legitimate scope link was rejected")
    return {"scope_controls": len(bad), "all_ok": True}


def check_all() -> dict:
    return {"copying": check_copying_controls(), "structural": check_structural_controls(),
            "scope": check_scope_controls(), "all_ok": True}
