"""Adversarial controls for the factory gate battery — run BEFORE any trial batch.

Borrowed directly from the repo's best governance mechanic: `notation/batches.check_controls` certifies
deliberately-DAMAGED relations first and raises ControlBreach if any of them passes. A gate battery that
cannot fail a known-bad item is not evidence, and a trial run through it would be theatre.

Each control is a candidate that MUST be caught, naming the gate that must catch it. If a control survives,
the trial aborts — we do not report yield from a battery with a hole in it.
"""
from __future__ import annotations

from typing import List, Tuple

from kie.qie.factory import gates as G


class ControlBreach(Exception):
    """A deliberately-broken candidate passed the battery. The battery — not the candidate — is wrong."""


def _base() -> dict:
    """A well-formed structured-numeric candidate that SHOULD survive the deterministic battery."""
    return {
        "stem": "A constant net force of 12 N acts on a block of mass 3 kg resting on a frictionless surface. "
                "What is the magnitude of the acceleration produced?",
        "options": {"a": "2 m/s^2", "b": "4 m/s^2", "c": "6 m/s^2", "d": "36 m/s^2"},
        "answer_label": "b",
        "answer_value": "4",
        "claimed": {"concepts": ["Newton's second law"], "archetype": "single_step_numerical",
                    "depth": 1, "difficulty": "easy", "composition": "single"},
        "structure": {
            "givens": {"F": {"value": 12, "unit": "N"}, "m": {"value": 3, "unit": "kg"},
                       "a": {"value": None, "unit": "m/s**2"}},
            "relation": "F = m * a", "solve_for": "a", "answer_unit": "m/s**2",
        },
        "solution": {"steps": ["Identify Newton's second law: F = m a.",
                               "Substitute F = 12 N, m = 3 kg.",
                               "a = F/m = 12/3."], "final": "4"},
    }


def _spec() -> dict:
    return {"lane": "STRUCTURED_NUMERIC", "class_level": 9, "subject": "Physics", "visual_required": 0,
            "boundary": '{"forbidden_terms": ["calculus", "derivative"]}'}


# gates that only exist at the solution stage — their controls must be run there
_SOLUTION_STAGE_GATES = {"solution_present", "solution_matches_key"}


def controls() -> List[Tuple[str, str, dict]]:
    """(control_name, gate_that_must_catch_it, candidate)"""
    out = []

    # 1. the relation does not produce the stated answer (the核 falsifiability test)
    c = _base(); c["answer_label"] = "c"; c["answer_value"] = "6"; c["solution"]["final"] = "6"
    out.append(("wrong_key_vs_relation", "independent_solve", c))

    # 2. dimensionally impossible relation (a = F*m instead of F/m)
    c = _base(); c["structure"]["relation"] = "F = a / m"
    out.append(("dimensional_violation", "dimensional", c))

    # 3. answer keyed to an option that the solution itself contradicts
    c = _base(); c["solution"]["final"] = "9"
    out.append(("solution_contradicts_key", "solution_matches_key", c))

    # 4. duplicate options (structure gate)
    c = _base(); c["options"]["c"] = "4 m/s^2"
    out.append(("duplicate_options", "option_structure", c))

    # 5. answer label not among options
    c = _base(); c["answer_label"] = "e"
    out.append(("answer_label_absent", "option_structure", c))

    # 6. fabricated archetype outside the canon
    c = _base(); c["claimed"]["archetype"] = "super_hard_reasoning"
    out.append(("unknown_archetype", "archetype_known", c))

    # 7. curriculum boundary leak — a Class-9 item reaching for calculus
    c = _base(); c["stem"] = c["stem"] + " Use the derivative of velocity from calculus to justify."
    out.append(("boundary_leak", "curriculum_boundary", c))

    # 8. multi-concept claimed but structurally single (two terms in text != composition)
    c = _base(); c["claimed"]["composition"] = "multi"
    c["claimed"]["concepts"] = ["Newton's second law", "friction"]
    out.append(("fake_multi_concept", "composition_backed", c))

    # 9. missing solution
    c = _base(); c["solution"] = {}
    out.append(("no_solution", "solution_present", c))

    # 10. undetermined system — a symbol left unbound (solver must refuse, not guess)
    c = _base(); c["structure"]["relation"] = "F = m * a * k"
    out.append(("undetermined_symbol", "independent_solve", c))

    return out


# FALSE-POSITIVE controls: correct answers written in notation the comparator must not misread.
# These assert the battery does NOT cry wolf. A validator that rejects right answers destroys yield and
# credibility at once — and this exact bug (reading "3e-06" as 3) fired on real trial data.
_NOTATION_CONTROLS = (
    ("sci_e_lower", "4e-7", 4e-7),
    ("sci_e_upper", "3.2E-5", 3.2e-5),
    ("sci_x10_caret", "4.0 x 10^-7 m", 4e-7),
    ("sci_times_unicode", "5.27 × 10^-10 m", 5.27e-10),
    ("sci_star_pow", "6.6 * 10**-34 J s", 6.6e-34),
    ("plain_decimal", "12.5 m/s", 12.5),
    ("comma_grouped", "1,000 s", 1000.0),
    ("negative", "-9.8 m/s^2", -9.8),
)


# Small-magnitude solves. Real science lives at 1e-10 .. 1e-34; a solver that rounds by DECIMAL PLACES
# silently mangles all of it and then blames the generator. Each entry must survive the round trip.
_MAGNITUDE_CONTROLS = (
    ("heisenberg_1e-10", {"h": 6.626e-34, "dp": 1e-25}, "dx = h/(4*pi*dp)", "dx", 5.2728e-10),
    # E = h*c/lam with h=6.626e-34, c=3e8, lam=1e-9  =>  E = 1.9878e-16 J  (inverted: solve back for h)
    ("planck_1e-34", {"E": 1.9878e-16, "lam": 1e-9, "c": 3e8}, "E = h*c/lam", "h", 6.626e-34),
    ("wavelength_1e-7", {"c": 3e8, "f": 5e14}, "c = f*lam", "lam", 6e-7),
    ("large_1e6", {"k": 2.303e-6, "r": 2.303}, "t = r/k", "t", 1e6),
)


def check_magnitude_controls() -> dict:
    """The solver must return small and large magnitudes intact."""
    results = []
    for name, givens, rel, tgt, expect in _MAGNITUDE_CONTROLS:
        st = {"givens": {k: {"value": v, "unit": ""} for k, v in givens.items()}, "relation": rel,
              "solve_for": tgt}
        st["givens"][tgt] = {"value": None, "unit": ""}
        out = G.independent_solve(st)
        got = out.get("solver_answer")
        ok = out.get("verdict") == "solved" and got is not None and abs(got - expect) <= 1e-3 * abs(expect)
        results.append({"control": name, "expected": expect, "got": got, "ok": ok})
        if not ok:
            raise ControlBreach(
                f"magnitude control {name!r}: solver returned {got!r}, expected ~{expect!r}. The solver is "
                f"mangling real-science magnitudes and would falsely refute correct answers.")
    return {"magnitude_controls": len(results), "all_ok": True, "results": results}


def check_notation_controls() -> dict:
    """The comparator must read every notation a generator legitimately uses."""
    results = []
    for name, text, expect in _NOTATION_CONTROLS:
        got = G._num(text)
        ok = got is not None and abs(got - expect) <= max(1e-12, 1e-6 * abs(expect))
        results.append({"control": name, "text": text, "expected": expect, "got": got, "ok": ok})
        if not ok:
            raise ControlBreach(
                f"notation control {name!r}: _num({text!r}) = {got!r}, expected {expect!r}. The comparator "
                f"would misreport a CORRECT answer as a disagreement.")
    # and agreement must still be refused when the values genuinely differ
    agree, _ = G.answers_agree(4e-7, "8e-7")
    if agree:
        raise ControlBreach("answers_agree accepted 4e-7 vs 8e-7 — the comparator is too loose")
    return {"notation_controls": len(results), "all_ok": True, "results": results}


def check_controls(ctx: dict) -> dict:
    """Run every control. Raise ControlBreach on the first one the battery fails to catch."""
    results = []
    for name, must_catch, cand in controls():
        stage = "solution" if must_catch in _SOLUTION_STAGE_GATES else "candidate"
        gr = G.run_gates(cand, ctx, stage=stage)
        by = {g["gate"]: g for g in gr}
        caught = False
        detail = ""

        if must_catch == "independent_solve":
            res = G.independent_solve(cand["structure"])
            if res["verdict"] in ("solver_failed", "no_valid_answer", "ambiguous"):
                caught, detail = True, res["reason"]
            elif res["verdict"] == "solved":
                agree, why = G.answers_agree(res["solver_answer"], cand["answer_value"])
                caught, detail = (not agree), why
        else:
            g = by.get(must_catch)
            caught = bool(g and not g["ok"])
            detail = (g or {}).get("detail", "gate did not run")

        results.append({"control": name, "gate": must_catch, "caught": caught, "detail": detail})
        if not caught:
            raise ControlBreach(
                f"control {name!r} survived: gate {must_catch!r} did NOT catch it. detail={detail!r}")

    # the healthy base item must SURVIVE — a battery that rejects everything is equally useless
    base_gr = G.run_gates(_base(), ctx)
    v, why = G.verdict(base_gr)
    res = G.independent_solve(_base()["structure"])
    agree, _ = G.answers_agree(res.get("solver_answer", 0), _base()["answer_value"])
    if v == "rejected" or not agree:
        raise ControlBreach(f"the known-GOOD control was rejected ({why}); the battery is over-tight")

    return {"controls_run": len(results), "all_caught": True, "results": results,
            "good_control_survives": True}
