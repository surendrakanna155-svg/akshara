"""Phase D+ golden tests — broader JEE-Mathematics generation, each verified by an INDEPENDENT second method.
Contract: definite integrals / series / limits / determinants / Vieta; answer reproduced by a genuinely
different computation (quadrature, brute-force sum, finite-difference, alternate expansion, root-solving);
wrong distractors; JEE_MAIN profile; deterministic; no fabrication."""
import unittest

from kie.qie import generate_jee_math as JM


class TestGenerate(unittest.TestCase):
    def test_every_family_appears_and_is_independently_correct(self):
        cands = JM.generate(per_family=8, seed="T")
        fams = {c["frame_id"] for c in cands}
        for f in ("definite_integral", "finite_series", "limit", "determinant", "vieta",
                  "binomial_coeff", "counting", "matrix_inverse", "complex_modsq"):
            self.assertIn(f, fams, f)
        for c in cands:
            self.assertTrue(JM._agrees(c["_ans"], c["_payload"]), c["frame_id"] + " | " + c["stem"])
            self.assertEqual(c["subject"], "Mathematics")
            self.assertEqual(c["profile"], "JEE_MAIN")
            self.assertEqual(len(c["options"]), 4)
            self.assertIn(c["answer_text"], c["options"].values())

    def test_options_distinct_and_answer_present_once(self):
        for c in JM.generate(per_family=8, seed="D"):
            self.assertEqual(len(set(c["options"].values())), 4)
            self.assertEqual(list(c["options"].values()).count(c["answer_text"]), 1)


class TestIndependence(unittest.TestCase):
    def test_correct_verifies(self):
        for c in JM.generate(per_family=4, seed="V"):
            self.assertEqual(JM.verify_jee_math(c), "agree", c["frame_id"])

    def test_new_families_independent_methods(self):
        # binomial: coeff of x^2 in (2x+1)^4 = C(4,2)·2²·1² = 6·4 = 24
        self.assertTrue(JM._agrees(24, {"kind": "binom", "a": 2, "b": 1, "n": 4, "k": 2}))
        self.assertFalse(JM._agrees(6, {"kind": "binom", "a": 2, "b": 1, "n": 4, "k": 2}))
        # combinations 10C3 = 120 (verified by Pascal), permutations 10P3 = 720
        self.assertTrue(JM._agrees(120, {"kind": "ncr", "n": 10, "r": 3}))
        self.assertTrue(JM._agrees(720, {"kind": "npr", "n": 10, "r": 3}))
        # matrix inverse (1,1) entry via A·A⁻¹ == I : A=[[1,2],[3,4]], det=-2, entry = d/det = 4/-2 = -2
        self.assertTrue(JM._agrees(-2, {"kind": "matinv2", "M": [[1, 2], [3, 4]]}))
        self.assertFalse(JM._agrees(2, {"kind": "matinv2", "M": [[1, 2], [3, 4]]}))
        # complex |3+4i|² = 25 (verified by z·conj(z))
        self.assertTrue(JM._agrees(25, {"kind": "cmodsq", "a": 3, "b": 4}))

    def test_vieta_repeated_root_verifies(self):
        # regression: x²+10x+25 has the double root -5; sp.solve dedupes it, so the verifier must use
        # multiplicity or it would falsely reject a VALID item (product of roots = 25).
        self.assertTrue(JM._agrees(25, {"kind": "vieta", "b": 10, "c": 25, "want": "product"}))
        self.assertTrue(JM._agrees(-10, {"kind": "vieta", "b": 10, "c": 25, "want": "sum"}))

    def test_tampered_answer_rejected(self):
        # corrupt the answer so the independent method must disagree (works for int and sympy answers)
        for c in JM.generate(per_family=3, seed="X"):
            bad = dict(c)
            bad["_ans"] = c["_ans"] + 7
            self.assertEqual(JM.verify_jee_math(bad), "disagree", c["frame_id"])


class TestRun(unittest.TestCase):
    def test_only_pass_proceeds_and_provenanced(self):
        res = JM.run(per_family=8, seed="R")
        self.assertGreater(res["passed"], 0)
        self.assertEqual(res["passed"], len(res["verified_bank"]))
        for it in res["verified_bank"]:
            self.assertEqual(it["status"], "PASS")
            self.assertEqual(it["verification"]["method"], "independent_second_method")
            self.assertEqual(it["profile"], "JEE_MAIN")
            self.assertNotIn("_ans", it)      # internal objects stripped from the banked record
            self.assertNotIn("_payload", it)


if __name__ == "__main__":
    unittest.main()
