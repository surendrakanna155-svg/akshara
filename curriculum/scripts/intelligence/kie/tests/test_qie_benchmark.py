"""Gold-benchmark harness — blind packet, Krippendorff alpha, aggregation + pre-registered thresholds."""
import unittest

from kie.qie import benchmark as B


class TestBlindPacket(unittest.TestCase):
    def test_strips_labels_and_assigns_uids(self):
        items = [{"engine": "A", "lane": "NUMERIC_RELATIONAL", "subject": "Physics", "stem": "x"},
                 {"engine": "B", "lane": "CONCEPTUAL_CAUSAL", "subject": "Biology", "stem": "y"}]
        blind, key = B.build_blind_packet(items)
        for b in blind:
            self.assertNotIn("engine", b)
            self.assertNotIn("lane", b)
            self.assertIn("uid", b)
            self.assertIn("stem", b)          # item content survives
        self.assertEqual(len(key), 2)
        self.assertEqual({k["engine"] for k in key.values()}, {"A", "B"})

    def test_deterministic(self):
        items = [{"engine": "A", "stem": str(i)} for i in range(10)]
        b1, k1 = B.build_blind_packet(items)
        b2, k2 = B.build_blind_packet(items)
        self.assertEqual([x["stem"] for x in b1], [x["stem"] for x in b2])


class TestAlpha(unittest.TestCase):
    def test_perfect_agreement(self):
        self.assertAlmostEqual(B.krippendorff_interval([[5, 5, 5], [3, 3, 3], [1, 1, 1]]), 1.0, places=9)

    def test_strong_disagreement_low(self):
        self.assertLess(B.krippendorff_interval([[1, 5, 3], [5, 1, 3], [3, 3, 1]]), 0.5)

    def test_empty_none(self):
        self.assertIsNone(B.krippendorff_interval([]))


def _judges_where_B_beats_A():
    # 3 judges; A items shallow (depth 1), B items deep (depth 4); all abs-bar dims high; no regression.
    uids = {"Q001": "A", "Q002": "A", "Q003": "B", "Q004": "B"}
    key = {u: {"engine": e, "subject": "Physics"} for u, e in uids.items()}
    hi = dict(correctness=5, syllabus_alignment=5, concept_precision=5, ambiguity=5)
    A = {**hi, "cognitive_depth": 1, "distractor_quality": 3, "difficulty_accuracy": 2, "solution_quality": 3,
         "originality": 2}
    Bi = {**hi, "cognitive_depth": 4, "distractor_quality": 5, "difficulty_accuracy": 4, "solution_quality": 4,
          "originality": 3}
    judges = []
    for _ in range(3):
        judges.append({"Q001": dict(A), "Q002": dict(A), "Q003": dict(Bi), "Q004": dict(Bi)})
    return judges, key


class TestAggregate(unittest.TestCase):
    def test_clear_B_win_passes(self):
        judges, key = _judges_where_B_beats_A()
        res = B.aggregate(judges, key)
        self.assertTrue(res["passed"])
        self.assertEqual(set(res["proven_lift_dims"]), set(B.LIFT_DIMS))
        self.assertEqual(res["evidence_kind"], "ai_panel_proxy")
        self.assertTrue(res["teacher_validation_required"])

    def test_no_lift_fails(self):
        # B equals A on lift dims -> no proven lift -> fail (this is the Phase-0 first-run situation)
        judges, key = _judges_where_B_beats_A()
        for jd in judges:
            for u in ("Q003", "Q004"):
                jd[u]["difficulty_accuracy"] = 2   # kill the lift on one required dim
        res = B.aggregate(judges, key)
        self.assertFalse(res["passed"])
        self.assertNotIn("difficulty_accuracy", res["proven_lift_dims"])

    def test_extra_gate_can_block(self):
        judges, key = _judges_where_B_beats_A()
        res = B.aggregate(judges, key, extra_gate={"biology_bar": False})
        self.assertFalse(res["passed"])   # extra gate ANDs in

    def test_thresholds_are_the_preregistered_values(self):
        self.assertEqual(B.ABSOLUTE_BAR, 4.0)
        self.assertEqual(B.LIFT_MIN, 1.0)
        self.assertEqual(B.ALPHA_FLOOR, 0.6)
        self.assertEqual(set(B.LIFT_DIMS),
                         {"cognitive_depth", "distractor_quality", "difficulty_accuracy", "solution_quality"})


if __name__ == "__main__":
    unittest.main()
