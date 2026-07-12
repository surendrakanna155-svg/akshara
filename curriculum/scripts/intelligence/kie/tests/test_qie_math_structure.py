"""Phase B8 Track 2 — Math-appropriate deterministic structure model tests.

Covers: topic-signature resolution, hard science veto, section-heading/OCR-noise veto, topic-relation
consistency (the false-match killer), algebraic-equivalence normalisation, single- and 2-step verification,
and the strict "return None when uncertain" contract."""
import unittest

from kie.qie import math_structure as MS


class TestMathTopic(unittest.TestCase):
    def test_genuine_topics_resolve(self):
        self.assertEqual(MS.math_topic("Find the area of a rectangle of length 6 and breadth 4"), "geometry_area")
        self.assertEqual(MS.math_topic("Find the sum of the first 20 terms of the AP 3, 7, 11 ..."),
                         "sequence_progression")
        self.assertEqual(MS.math_topic("Find the average of 10, 20 and 30"), "statistics_mean")

    def test_science_veto_blocks_physics(self):
        # physics items carrying numbers must never resolve to a Math topic
        self.assertIsNone(MS.math_topic("A body moving with velocity 20 m/s and acceleration 5 m/s^2"))
        self.assertIsNone(MS.math_topic("The radius of the innermost orbit of a hydrogen atom is 5.3e-11 m"))
        self.assertIsNone(MS.math_topic("Two moles of an ideal gas at a pressure of 2 atm"))

    def test_section_heading_noise_veto(self):
        self.assertIsNone(MS.math_topic("A Note for the Teacher"))
        self.assertIsNone(MS.math_topic("Constitution of India"))

    def test_no_topic_signal_is_unresolved(self):
        self.assertIsNone(MS.math_topic("Two heaters A and B have power rating of 1 kW and 2 kW"))


class TestResolveStructure(unittest.TestCase):
    def test_genuine_rectangle_area_verifies(self):
        rec = MS.resolve_math_structure("Find the area of a rectangle of length 6 and breadth 4", [6.0, 4.0], 24.0)
        self.assertIsNotNone(rec)
        self.assertEqual(rec["topic"], "geometry_area")
        self.assertEqual(rec["schema"], "product_ab")     # area_rect normalises to product_ab
        self.assertFalse(rec["multi_step"])

    def test_algebraic_equivalence_collapses_forms(self):
        # rectangle and parallelogram both a*b -> same schema key (no double count)
        r1 = MS.resolve_math_structure("Find the area of a rectangle of sides 6 and 4", [6.0, 4.0], 24.0)
        r2 = MS.resolve_math_structure("Find the area of a parallelogram of base 6 and height 4", [6.0, 4.0], 24.0)
        self.assertEqual(r1["schema"], r2["schema"])

    def test_false_match_rejected_no_topic(self):
        # the real corpus false positive: an optics item whose numbers fit 0.5*(1+10)*2 = 11 (area_trap)
        rec = MS.resolve_math_structure(
            "Light travels a distance x in time t1 in air and 10x in time t2 in another denser medium",
            [1.0, 10.0, 2.0], 11.0)
        self.assertIsNone(rec)     # no geometry-area topic -> not counted, despite the numeric coincidence

    def test_false_match_rejected_science_veto(self):
        rec = MS.resolve_math_structure(
            "A disc of radius 2 m and mass 100 kg rolls on a horizontal floor", [2.0, 100.0, 20.0], 3.0)
        self.assertIsNone(rec)

    def test_calculus_not_verifiable_by_school_library(self):
        # genuine advanced math, but the school relation library cannot verify it -> unresolved (honest)
        rec = MS.resolve_math_structure("Find the derivative of F(x) = 6x^3 - 9x + 4 w.r.t. x",
                                        [6.0, 3.0, 9.0, 4.0], 18.0)
        self.assertIsNone(rec)

    def test_uncertain_returns_none(self):
        self.assertIsNone(MS.resolve_math_structure("some unstructured text", [1.0], None))
        self.assertIsNone(MS.resolve_math_structure("area of a rectangle", [], 10.0))

    def test_two_step_chain_genuine_same_family(self):
        # genuine same-family (statistics_mean) linear chain: mean of (mean of 4,6 = 5) and 9 -> 7.
        # avg->avg is topic-coherent, on the chain allowlist, consumes all three givens.
        rec = MS.resolve_math_structure("Find the mean of the average of 4 and 6, and the value 9",
                                        [4.0, 6.0, 9.0], 7.0)
        self.assertIsNotNone(rec)
        self.assertTrue(rec["multi_step"])
        self.assertEqual(rec["steps"], ["mean2", "mean2"])

    def test_two_step_chain_no_false_match_on_garbage_target(self):
        # the hardening case: nonlinear chains are off the allowlist and consume-all + tight tol hold, so an
        # arbitrary target is never brute-forced.
        self.assertIsNone(MS.resolve_math_structure(
            "Find the area of a rectangle region 6 by 2 combined with 8", [6.0, 2.0, 8.0], 999.0))

    def test_two_step_excludes_nonlinear_relations(self):
        # a cylinder surface-area (nonlinear) target must not be reachable by a chain (allowlist blocks it)
        self.assertIsNone(MS.resolve_math_structure(
            "Find the area of a rectangle 6 by 2 and value 8", [6.0, 2.0, 8.0], 1005.0))


if __name__ == "__main__":
    unittest.main()
