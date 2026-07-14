"""Golden tests — type-directed auto-composition (Option 1: curated phrasing-schema per shape).
Contract: slot fillings are TYPE-CHECKED against the operator registry; each admitted filling builds a concrete
pipeline whose every step is independently verified; phrasing is curated per shape; tampering is caught; only
verified items bank; the auto-composer multiplies shapes from few schemas.
"""
import unittest

from kie.qie import autocompose as AC
from kie.qie import compose as C


class TestTypeDirected(unittest.TestCase):
    def test_chain_out_type_threads_and_rejects(self):
        self.assertEqual(AC.chain_out_type(("differentiate", "differentiate"), C.POLY), C.POLY)
        self.assertEqual(AC.chain_out_type(("max_root",), C.ROOTSET), C.POINT)
        # type-incompatible: differentiate expects POLY, not ROOTSET
        self.assertIsNone(AC.chain_out_type(("differentiate",), C.ROOTSET))
        # unknown operator
        self.assertIsNone(AC.chain_out_type(("nonexistent_op",), C.POLY))

    def test_valid_fills_enumerated(self):
        self.assertEqual(len(AC._valid_fills(AC.SCHEMAS["deriv_at_reduced_root"])), 4)   # 2 TRANSFORM × 2 REDUCE
        self.assertEqual(len(AC._valid_fills(AC.SCHEMAS["integral_of_deriv_over_roots"])), 2)


class TestGenerate(unittest.TestCase):
    def test_multiple_shapes_from_two_schemas_all_verified(self):
        cands = AC.generate(per_fill=6, seed="T")
        shapes = {(c["frame_id"], tuple(sorted(c["provenance"]["fill"].items()))) for c in cands}
        self.assertEqual(len(shapes), 6)                # 4 + 2 distinct auto-composed pipeline shapes
        for c in cands:
            self.assertEqual(AC.verify_auto(c), "agree", c["stem"])
            self.assertEqual(c["subject"], "Mathematics")
            self.assertEqual(c["profile"], "JEE_MAIN")
            self.assertEqual(c["archetype"], "multi_step_numerical")
            self.assertEqual(len(c["options"]), 4)
            self.assertIn(c["answer_text"], c["options"].values())
            self.assertGreaterEqual(c["reasoning_depth"], 3)

    def test_tampered_answer_caught(self):
        for c in AC.generate(per_fill=3, seed="X"):
            bad = dict(c)
            bad["answer_text"] = AC._fmt(c["_answer"] + 3)      # answer no longer matches the re-run pipeline
            self.assertEqual(AC.verify_auto(bad), "disagree", c["frame_id"])


class TestRun(unittest.TestCase):
    def test_only_verified_bank_and_shapes_reported(self):
        res = AC.run(per_fill=8, seed="R")
        self.assertEqual(res["shapes"], 6)
        self.assertGreater(res["passed"], 0)
        self.assertEqual(res["passed"], len(res["verified_bank"]))
        for it in res["verified_bank"]:
            self.assertEqual(it["status"], "PASS")
            self.assertIn("reasoning_depth", it)
            self.assertNotIn("_env0", it)
            self.assertNotIn("_steps", it)


if __name__ == "__main__":
    unittest.main()
