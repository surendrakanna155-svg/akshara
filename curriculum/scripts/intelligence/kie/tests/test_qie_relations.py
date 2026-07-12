"""QIE relation library v0 — INDEPENDENT numeric verification (GATE 4/5 backbone)."""
import unittest

from kie.qie import relations as R


class TestParse(unittest.TestCase):
    def test_plain_numbers(self):
        self.assertEqual(R.parse_numbers("mass 12 kg, a 3 m/s"), [12.0, 3.0])

    def test_thousands_and_dash_minus(self):
        self.assertEqual(R.parse_numbers("10,000 V and -5"), [10000.0, -5.0])

    def test_ocr_flattened_scientific(self):
        # "9 x 10-31" (superscript lost) -> 9e-31 (magnitude; sign as written)
        vals = R.parse_numbers("me = 9 × 10-31 kg")
        self.assertAlmostEqual(vals[0], 9e-31, places=40)


class TestVerify(unittest.TestCase):
    def test_ohm_direct(self):
        self.assertEqual(R.verify([9, 30], 270, subject="Physics"), "V=IR")

    def test_ohm_reverse(self):
        # R = V/I: from 270 and 9 -> 30
        self.assertEqual(R.verify([270, 9], 30, subject="Physics"), "R=V/I")

    def test_kinematics_multistep_relation_present(self):
        # v = u + at : (u=5, a=3, t=4) -> 17
        self.assertEqual(R.verify([5, 3, 4], 17, subject="Physics"), "v=u+at")

    def test_mole(self):
        # n = m/M : 36 g / 18 -> 2 mol
        self.assertEqual(R.verify([36, 18], 2, subject="Chemistry"), "n=m/M")

    def test_area_triangle(self):
        self.assertEqual(R.verify([16, 4], 32, subject="Mathematics"), "area_tri")

    def test_wrong_target_returns_none(self):
        self.assertIsNone(R.verify([9, 30], 9999, subject="Physics"))

    def test_no_given_returns_none(self):
        self.assertIsNone(R.verify([], 5))

    def test_subject_scope_returns_subject_appropriate_relation(self):
        # Scoping restricts the search to a subject's relations. 9*30=270 matches BOTH V=IR (Physics)
        # and m=nM (Chemistry) — multiply-relations collide across subjects — so verify() must return the
        # requested subject's relation, never another subject's. (A real item calls verify with its own
        # subject, so the collision is harmless; this locks that scoping is honored.)
        chem_names = {r.name for r in R.LIBRARY if r.subject == "Chemistry"}
        res = R.verify([9, 30], 270, subject="Chemistry")
        self.assertIn(res, chem_names)
        self.assertEqual(R.verify([9, 30], 270, subject="Physics"), "V=IR")

    def test_library_nontrivial(self):
        self.assertGreaterEqual(R.library_size(), 50)

    def test_verify_is_generator_independent(self):
        # verify() takes only (given numbers, target) — it cannot see any generator/answer_function.
        import inspect
        params = list(inspect.signature(R.verify).parameters)
        self.assertEqual(params[:2], ["given", "target"])
        self.assertNotIn("item_model", params)
        self.assertNotIn("answer_function", params)


if __name__ == "__main__":
    unittest.main()
