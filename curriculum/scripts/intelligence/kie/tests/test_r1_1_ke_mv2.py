"""R1-1 regression lock (audit P0 · C0) — blocking grounding + deterministic truth-checking.

The audit's central demo: a wrong-but-self-consistent numeric item (KE = m*v**2, keyed 18 J for m=2 kg, v=3 m/s
— true kinetic energy ½mv² = 9 J) passed the ENTIRE gate battery, because sympy only re-solves the generator's
OWN declared relation (18 == 18), the dimensional check cannot tell ½mv² from mv² (½ is dimensionless), and
relation grounding was ADVISORY. These tests prove the DETERMINISTIC LAYER ALONE now refuses it — no model
call — and that blocking grounding does not false-quarantine legitimate algebraic rearrangements.
"""
from __future__ import annotations

import copy
import sqlite3
import unittest

from kie import config
from kie.qie.factory import gates as G

_QIE = config.KIE_HOME / "qie.db"


def _registry():
    """Real certified-relation index + equations (read-only), or empty. KE refusal holds either way; the
    order-swap survivor needs the real registry (F=m*a) and is gated on qie.db separately."""
    if not _QIE.exists():
        return {}, []
    q = sqlite3.connect(f"file:{_QIE}?mode=ro", uri=True)
    q.row_factory = sqlite3.Row
    try:
        return G.load_certified_relations(q), G.load_certified_relation_eqs(q)
    finally:
        q.close()


_SPEC = {"lane": "STRUCTURED_NUMERIC", "class_level": 11, "subject": "Physics", "visual_required": 0,
         "boundary": '{"forbidden_terms": []}'}

# The audit demo item, verbatim: KE = m*v**2 (missing the 1/2), keyed to its own wrong answer 18 J.
_KE_MV2 = {
    "stem": "A body of mass 2 kg moves at 3 m/s. Find its kinetic energy.",
    "options": {"a": "9 J", "b": "18 J", "c": "6 J", "d": "36 J"},
    "answer_label": "b", "answer_value": "18",
    "claimed": {"concepts": ["Kinetic energy"], "archetype": "single_step_numerical", "depth": 1,
                "difficulty": "easy", "composition": "single"},
    "structure": {"givens": {"m": {"value": 2, "unit": "kg"}, "v": {"value": 3, "unit": "m/s"},
                             "K": {"value": None, "unit": "J"}},
                  "relation": "K = m*v**2", "solve_for": "K", "answer_unit": "J"},
}

# A well-formed momentum item (p = m*v is certified) whose givens match its stem — the must-not-cry-wolf case.
_MOMENTUM = {
    "stem": "An object of mass 3 kg moves at 4 m/s. Find the magnitude of its linear momentum.",
    "options": {"a": "7 kg m/s", "b": "12 kg m/s", "c": "1 kg m/s", "d": "0.75 kg m/s"},
    "answer_label": "b", "answer_value": "12",
    "claimed": {"concepts": ["Linear momentum"], "archetype": "single_step_numerical", "depth": 1,
                "difficulty": "easy", "composition": "single"},
    "structure": {"givens": {"m": {"value": 3, "unit": "kg"}, "v": {"value": 4, "unit": "m/s"},
                             "p": {"value": None, "unit": "kg*m/s"}},
                  "relation": "p = m*v", "solve_for": "p", "answer_unit": "kg*m/s"},
}


def _ctx(**over):
    cr, ceq = _registry()
    ctx = {"spec": _SPEC, "seen_norm": {}, "corpus": [],
           "certified_relations": cr, "certified_relation_eqs": ceq}
    ctx.update(over)
    return ctx


def _by(cand, ctx):
    return {g["gate"]: g for g in G.run_gates(cand, ctx)}


class KeMv2RefusedByDeterministicLayer(unittest.TestCase):
    def test_ke_mv2_refused_by_deterministic_layer(self):
        """THE done-when lock: the KE=mv² item is quarantined by the gate battery alone (no model call), and
        the reason is relation grounding (not self-consistency — sympy AGREES with its own wrong relation)."""
        gr = G.run_gates(_KE_MV2, _ctx())          # pure deterministic; no judge, no generator
        by = {g["gate"]: g for g in gr}
        status, reason = G.verdict(gr)
        self.assertEqual(status, "quarantined", f"KE=mv² must be quarantined, got {status} ({reason})")
        self.assertFalse(by["relation_grounded"]["ok"], "relation_grounded must FAIL on K = m*v**2")
        self.assertEqual(by["relation_grounded"]["severity"], G.QUARANTINE)
        # and the self-consistency trap is real: the generator's own relation reproduces its own wrong key,
        # so the independent solver AGREES — proving grounding, not the solver, is what refuses it.
        ind = G.independent_solve(_KE_MV2["structure"])
        self.assertEqual(ind["verdict"], "solved")
        agree, _ = G.answers_agree(ind["solver_answer"], _KE_MV2["answer_value"])
        self.assertTrue(agree, "sympy re-solves the DECLARED (wrong) relation to 18 and agrees with the key")

    def test_is_relation_grounded_refuses_ke_and_grounds_correct_ke(self):
        cr, ceq = _registry()
        bad, _ = G.is_relation_grounded("K = m*v**2", _KE_MV2["structure"], _SPEC, cr, ceq)
        self.assertFalse(bad)
        good_struct = {"givens": {"m": {"value": 2}, "v": {"value": 3}}, "solve_for": "K"}
        ok, name = G.is_relation_grounded("K = m*v**2/2", good_struct, _SPEC, cr, ceq)
        if ceq:                                    # only meaningful with the real registry present
            self.assertTrue(ok)


class TruthGatesKeyOnStructureNotLane(unittest.TestCase):
    """Adversarial-verifier regression (R1-1 hardening). The truth gates (relation_grounded, dimensional,
    stem_binding) must fire on the PRESENCE OF A CHECKABLE STRUCTURE, not the spec.lane label: the verifier
    certified the exact KE=m*v** item end-to-end by routing it under a QUALITATIVE-lane spec, where grounding
    never ran. independent_solve is lane-agnostic, so anything it can 'agree' on MUST be grounded here."""

    def test_ke_mv2_refused_under_qualitative_spec(self):
        qual = dict(_SPEC, lane="QUALITATIVE")
        gr = G.run_gates(_KE_MV2, _ctx(spec=qual))
        by = {g["gate"]: g for g in gr}
        self.assertIn("relation_grounded", by, "grounding must run on structure presence regardless of lane")
        self.assertFalse(by["relation_grounded"]["ok"], "K=m*v** must FAIL grounding even under a qualitative spec")
        status, reason = G.verdict(gr)
        self.assertEqual(status, "quarantined",
                         f"KE=mv² under a qualitative spec must still be quarantined, got {status} ({reason})")

    def test_genuine_qualitative_item_skips_the_structure_gates(self):
        """A real qualitative item (no relation/givens) must NOT be FATAL-failed for a missing structure nor
        run the numeric truth gates — they simply do not apply, so the qualitative lane is not broken."""
        qual_item = {"stem": "Which gland produces insulin?",
                     "options": {"a": "Pancreas", "b": "Liver", "c": "Kidney", "d": "Spleen"},
                     "answer_label": "a", "answer_value": "Pancreas",
                     "claimed": {"concepts": ["Endocrine system"], "composition": "single"},
                     "structure": {}}
        by = _by(qual_item, _ctx(spec=dict(_SPEC, lane="QUALITATIVE", subject="Biology")))
        self.assertNotIn("relation_grounded", by, "no numeric structure => no grounding gate")
        self.assertNotIn("structure_present", by, "structure_present is a structured-lane requirement only")


class WaiverIsTheOnlyEscape(unittest.TestCase):
    def test_valid_waiver_allows_ungrounded_relation(self):
        ctx = _ctx(relation_waiver={"waived_by": "owner", "reason": "verified against NCERT Class-11 physics"})
        by = _by(_KE_MV2, ctx)
        self.assertTrue(by["relation_grounded"]["ok"], "a valid owner waiver must let the ungrounded relation through")
        self.assertIn("WAIVED", by["relation_grounded"]["detail"])

    def test_incomplete_waiver_does_not_ground(self):
        for bad in ({"waived_by": "owner"}, {"reason": "x"}, {"waived_by": "", "reason": ""}, True, "advisory"):
            ctx = _ctx(relation_waiver=bad)
            by = _by(_KE_MV2, ctx)
            self.assertFalse(by["relation_grounded"]["ok"], f"a bare/partial waiver must NOT ground: {bad!r}")

    def test_valid_waiver_helper(self):
        self.assertTrue(G._valid_waiver({"waived_by": "owner", "reason": "x"}))
        self.assertFalse(G._valid_waiver({"waived_by": "owner"}))
        self.assertFalse(G._valid_waiver("advisory"))
        self.assertFalse(G._valid_waiver(None))


class DimensionalNotCheckableQuarantines(unittest.TestCase):
    def test_units_stripped_quarantines(self):
        cand = copy.deepcopy(_MOMENTUM)
        for g in cand["structure"]["givens"].values():
            g["unit"] = ""
        cand["structure"]["answer_unit"] = ""
        by = _by(cand, _ctx())
        self.assertFalse(by["dimensional"]["ok"], "units-stripped item must not pass dimensional as 'not checkable'")
        self.assertEqual(by["dimensional"]["severity"], G.QUARANTINE)


class OrderSwapMustSurvive(unittest.TestCase):
    @unittest.skipUnless(_QIE.exists(), "qie.db not present (gitignored / local only)")
    def test_order_swapped_relation_still_grounds(self):
        # F = a*m is an algebraic rearrangement of the certified F = m*a — it must ground, not false-quarantine.
        cand = copy.deepcopy(_MOMENTUM)
        cand["stem"] = "A net force of 12 N acts on a 3 kg block. Find the acceleration."
        cand["options"] = {"a": "2 m/s^2", "b": "4 m/s^2", "c": "6 m/s^2", "d": "36 m/s^2"}
        cand["answer_label"] = "b"; cand["answer_value"] = "4"
        cand["structure"] = {"givens": {"F": {"value": 12, "unit": "N"}, "m": {"value": 3, "unit": "kg"},
                                        "a": {"value": None, "unit": "m/s**2"}},
                             "relation": "F = a * m", "solve_for": "a", "answer_unit": "m/s**2"}
        by = _by(cand, _ctx())
        self.assertTrue(by["relation_grounded"]["ok"], "order-swapped F=a*m must still ground")


class StemStructureBinding(unittest.TestCase):
    def test_passes_when_every_given_is_in_the_stem(self):
        by = _by(_MOMENTUM, _ctx())
        self.assertTrue(by["stem_binding_givens"]["ok"])
        self.assertTrue(by["stem_binding_stem"]["ok"])

    def test_catches_given_absent_from_stem(self):
        cand = copy.deepcopy(_MOMENTUM)
        cand["structure"]["givens"]["m"]["value"] = 99   # stem still says 3 kg — sympy would solve a number
        by = _by(cand, _ctx())                            # the student never sees
        self.assertFalse(by["stem_binding_givens"]["ok"])
        self.assertEqual(by["stem_binding_givens"]["severity"], G.QUARANTINE)

    def test_all_nums_is_sci_notation_aware(self):
        nums = G._all_nums("6.6 x 10^-7 m and mass 2 kg")
        self.assertEqual(len(nums), 2)                       # not [6.6, 10, -7, 2]
        self.assertAlmostEqual(nums[0], 6.6e-7, places=12)
        self.assertAlmostEqual(nums[1], 2.0, places=12)


if __name__ == "__main__":
    unittest.main()
