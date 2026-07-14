"""Golden tests — Compositional Question Generation (CQG) engine + curated templates.
Contract: typed operators each verify by an INDEPENDENT method; compositions verify per-step AND end-to-end;
reasoning depth is computed from structure; only fully-verified items bank; tampering is caught; no fabrication.
"""
import unittest

import sympy as sp

from kie.qie import compose as C
from kie.qie import compositions as K


class TestOperators(unittest.TestCase):
    def test_each_operator_verify_accepts_correct_rejects_tampered(self):
        f = sp.expand(2 * C.x ** 2 + 3 * C.x - 5)
        d = C.OPERATORS["differentiate"]
        self.assertTrue(d.verify([f], d.apply(f)))
        self.assertFalse(d.verify([f], d.apply(f) + C.x ** 5))          # tampered derivative
        i = C.OPERATORS["integrate_def"]
        self.assertTrue(i.verify([f, 0, 2], i.apply(f, 0, 2)))
        self.assertFalse(i.verify([f, 0, 2], i.apply(f, 0, 2) + 10))    # tampered integral
        e = C.OPERATORS["evaluate"]
        self.assertTrue(e.verify([f, 3], e.apply(f, 3)))
        self.assertFalse(e.verify([f, 3], e.apply(f, 3) + 1))
        r = C.OPERATORS["real_roots"]
        g = sp.expand((C.x - 1) * (C.x + 4))
        self.assertTrue(r.verify([g], r.apply(g)))
        self.assertFalse(r.verify([g], [sp.Integer(2)]))               # 2 is not a root of g

    def test_verify_is_a_numeric_second_method_not_symbolic_echo(self):
        # integrate_def's independent check must reject a value that is off by a small NON-symbolic amount
        # (a symbolic re-run would only catch exact-form differences; quadrature catches numeric ones).
        f = sp.expand(3 * C.x ** 2 + 1)
        i = C.OPERATORS["integrate_def"]
        correct = i.apply(f, 0, 2)
        self.assertTrue(i.verify([f, 0, 2], correct))
        self.assertFalse(i.verify([f, 0, 2], correct + sp.Rational(1, 1000)))   # 0.001 off → quadrature catches


class TestDepth(unittest.TestCase):
    def test_depth_is_computed_from_structure(self):
        self.assertEqual(C.reasoning_depth(K.TEMPLATES["ftc_integral_of_derivative"].pipeline,
                                           {"f", "lo", "hi"}), 2)
        self.assertEqual(C.reasoning_depth(K.TEMPLATES["area_between_roots"].pipeline,
                                           {"f", "a", "p", "q"}), 4)
        # adding one operator (subtract_poly) extended the ladder to depth 5 with no engine change
        self.assertEqual(C.reasoning_depth(K.TEMPLATES["area_between_curve_and_line"].pipeline,
                                           {"f", "g", "a", "p", "q"}), 5)
        self.assertEqual(C.depth_band(2), "INTERMEDIATE")
        self.assertEqual(C.depth_band(5), "ADVANCED")


class TestGenerate(unittest.TestCase):
    def test_all_templates_generate_verified_multi_step_items(self):
        cands = K.generate(per_template=5, seed="T")
        frames = {c["frame_id"] for c in cands}
        for f in ("area_between_roots", "min_value_quadratic", "tangent_slope_at_root",
                  "ftc_integral_of_derivative", "area_between_curve_and_line"):
            self.assertIn(f, frames, f)
        self.assertTrue(any(c["reasoning_depth"] >= 5 for c in cands))   # depth ladder extends to 5
        self.assertTrue(any(c["depth_band"] == "INTERMEDIATE" for c in cands))
        for c in cands:
            self.assertEqual(K.verify_composition(c), "agree", c["frame_id"] + " | " + c["stem"])
            self.assertEqual(c["subject"], "Mathematics")
            self.assertEqual(c["profile"], "JEE_MAIN")
            self.assertEqual(c["archetype"], "multi_step_numerical")
            self.assertEqual(len(c["options"]), 4)
            self.assertIn(c["answer_text"], c["options"].values())

    def test_tampered_answer_is_caught(self):
        for c in K.generate(per_template=3, seed="X"):
            bad = dict(c)
            bad["_answer"] = c["_answer"] + 3
            self.assertEqual(K.verify_composition(bad), "disagree", c["frame_id"])


class TestRun(unittest.TestCase):
    def test_only_verified_items_bank_and_are_stripped(self):
        res = K.run(per_template=6, seed="R")
        self.assertGreater(res["passed"], 0)
        self.assertEqual(res["passed"], len(res["verified_bank"]))
        for it in res["verified_bank"]:
            self.assertEqual(it["status"], "PASS")
            self.assertIn("reasoning_depth", it)
            self.assertNotIn("_env0", it)          # sympy internals not persisted
            self.assertNotIn("_answer", it)


if __name__ == "__main__":
    unittest.main()
