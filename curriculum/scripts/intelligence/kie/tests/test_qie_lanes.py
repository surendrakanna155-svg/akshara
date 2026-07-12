"""QIE lane taxonomy — identity, tiers, verification strategy, AR relation classes."""
import unittest

from kie.qie import lanes


class TestLanes(unittest.TestCase):
    def test_exactly_eleven_lanes(self):
        self.assertEqual(len(lanes.LANES), 11)
        self.assertEqual(len(lanes.names()), 11)

    def test_required_lanes_present(self):
        for name in ("NUMERIC_RELATIONAL", "CONCEPTUAL_CAUSAL", "CLASSIFICATION_TAXONOMIC",
                     "PROCESS_SEQUENCE", "STRUCTURE_FUNCTION", "EXPERIMENT_OBSERVATION",
                     "DIAGRAM_VISUAL", "COMPARATIVE", "MISCONCEPTION_DIAGNOSTIC",
                     "ASSERTION_RELATION", "DATA_INTERPRETATION"):
            self.assertIn(name, lanes.LANES)

    def test_numeric_flag_partition(self):
        self.assertEqual(set(lanes.numeric_lanes()), {"NUMERIC_RELATIONAL", "DATA_INTERPRETATION"})
        self.assertNotIn("CONCEPTUAL_CAUSAL", lanes.numeric_lanes())
        self.assertEqual(len(lanes.numeric_lanes()) + len(lanes.non_numeric_lanes()), 11)

    def test_ar_lane_uses_truth_table_and_four_classes(self):
        self.assertEqual(lanes.lane("ASSERTION_RELATION").verify, lanes.Verify.KVS_TRUTH_TABLE)
        self.assertEqual(len(lanes.AR_RELATION_CLASSES), 4)
        # the always-"(a)" defect is structurally impossible: all four classes must be distinct + reachable
        self.assertEqual(len(set(lanes.AR_RELATION_CLASSES)), 4)

    def test_biology_covered_by_non_numeric_lanes(self):
        bio = [l for l in lanes.LANES.values() if "Biology" in l.subjects and not l.numeric]
        self.assertGreaterEqual(len(bio), 4)  # Biology must have a real non-numeric lane set

    def test_tier_a_lanes_are_deterministic_verifiable(self):
        for l in lanes.by_tier(lanes.Tier.A):
            self.assertIn(l.verify, (lanes.Verify.RELATION_SOLVER, lanes.Verify.DATA_RECOMPUTE,
                                     lanes.Verify.KVS_ASSERTION))

    def test_unknown_lane_raises(self):
        with self.assertRaises(KeyError):
            lanes.lane("NOT_A_LANE")


if __name__ == "__main__":
    unittest.main()
