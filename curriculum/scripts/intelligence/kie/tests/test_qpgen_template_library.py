"""QP engine — Phase 2 expanded deterministic template library.

Locks the Phase-2 expansion (5 -> 50+ certified families across Physics/Chemistry/Biology/
Mathematics). Every family must be:
  * deterministic + reproducible for a given (concept_code, seed);
  * solver-verified (the numeric answer is recomputed here from the SAME parameters and must
    match — a regression guard against a broken formula);
  * well-formed for MCQ (exactly four DISTINCT options, the correct answer among them);
  * copyright-safe / fabrication-free (universal formulas, SI units, named laws only);
  * conservatively bound (an unrelated concept never picks up an off-topic template).
"""
import unittest

from kie.qpgen import templates as T
from kie.qpgen.templates import _p, _n, instantiate, find_template
from kie.qpgen.models import QuestionType as QT


class TestRegistry(unittest.TestCase):
    def test_library_is_large(self):
        self.assertGreaterEqual(len(T.REGISTRY), 50)

    def test_keeps_original_families(self):
        ids = {t.template_id for t in T.REGISTRY}
        for original in ("phy_newton_2law", "phy_ohms_law", "phy_uniform_speed",
                         "chem_mole_concept", "math_ap_nth_term"):
            self.assertIn(original, ids)

    def test_every_subject_covered(self):
        subjects = {t.subject for t in T.REGISTRY}
        self.assertEqual(subjects, {"Physics", "Chemistry", "Biology", "Mathematics"})


class TestWellFormedAndDeterministic(unittest.TestCase):
    def test_all_families_wellformed_over_many_seeds(self):
        for tmpl in T.REGISTRY:
            for seed in range(20):
                cc = "C_" + tmpl.template_id
                for qt in tmpl.types:
                    out = instantiate(tmpl, cc, seed, qt)
                    self.assertTrue(out.get("stem"), (tmpl.template_id, qt))
                    self.assertTrue(out.get("answer"), (tmpl.template_id, qt))
                    self.assertTrue(out.get("solution"), (tmpl.template_id, qt))
                    self.assertTrue(out.get("solver_verified"))
                    if qt == QT.MCQ:
                        opts = out.get("options")
                        self.assertIsInstance(opts, list)
                        self.assertEqual(len(opts), 4, (tmpl.template_id, opts))
                        self.assertEqual(len(set(opts)), 4, (tmpl.template_id, opts))
                        self.assertIn(out["answer"], opts, (tmpl.template_id, opts))
                    # determinism
                    self.assertEqual(instantiate(tmpl, cc, seed, qt), out)


class TestSolverMathIsCorrect(unittest.TestCase):
    """Recompute each answer INDEPENDENTLY from the same parameters — catches a broken formula."""

    def _tmpl(self, tid):
        return next(t for t in T.REGISTRY if t.template_id == tid)

    def test_kinetic_energy(self):
        for s in range(15):
            cc = "K"; m = _p(cc, s, "m", 2, 20); v = _p(cc, s, "v", 2, 12)
            out = instantiate(self._tmpl("phy_kinetic_energy"), cc, s, QT.NUMERICAL)
            self.assertEqual(out["answer"], f"{_n(0.5*m*v*v)} J")

    def test_pythagoras_is_a_real_triple(self):
        import re
        for s in range(15):
            out = instantiate(self._tmpl("math_pythagoras"), "P", s, QT.NUMERICAL)
            a, b = map(int, re.findall(r"measure (\d+) cm and (\d+) cm", out["stem"])[0])
            c = int(out["answer"].split()[0])
            self.assertEqual(a * a + b * b, c * c, out["stem"])

    def test_ph_from_concentration(self):
        for s in range(15):
            cc = "H"; nexp = _p(cc, s, "e", 1, 13)
            out = instantiate(self._tmpl("chem_ph"), cc, s, QT.NUMERICAL)
            self.assertEqual(out["answer"], f"{nexp}")

    def test_discriminant(self):
        for s in range(15):
            cc = "D"; a = _p(cc, s, "a", 1, 5); b = _p(cc, s, "b", 2, 9); c = _p(cc, s, "c", 1, 5)
            out = instantiate(self._tmpl("math_discriminant"), cc, s, QT.NUMERICAL)
            self.assertEqual(out["answer"], f"{b*b - 4*a*c}")

    def test_neutrons(self):
        for s in range(15):
            cc = "Nn"; z = _p(cc, s, "z", 3, 30); nn = _p(cc, s, "n", 2, 40)
            out = instantiate(self._tmpl("chem_neutrons"), cc, s, QT.NUMERICAL)
            self.assertEqual(out["answer"], f"{nn}")   # neutrons = (z+nn) - z

    def test_cardiac_output(self):
        for s in range(15):
            cc = "CO"; hr = _p(cc, s, "h", 60, 90); sv = _p(cc, s, "s", 60, 90)
            out = instantiate(self._tmpl("bio_cardiac_output"), cc, s, QT.NUMERICAL)
            self.assertEqual(out["answer"], f"{hr*sv} mL/min")


class TestUniversalFormats(unittest.TestCase):
    def test_assertion_reason_has_standard_key(self):
        ar = next(t for t in T.REGISTRY if t.template_id == "ar_ohm")
        out = instantiate(ar, "AR", 1, QT.ASSERTION_REASON)
        self.assertEqual(len(out["options"]), 4)
        self.assertIn(out["answer"], out["options"])
        self.assertIn("Assertion", out["stem"])
        self.assertIn("Reason", out["stem"])

    def test_match_columns_pair_correctly(self):
        import re
        mt = next(t for t in T.REGISTRY if t.template_id == "phy_match_si_units")
        units = dict(T._SI_UNITS)   # quantity -> correct SI unit

        def _items(line):
            return {m.group(1): m.group(2).strip() for m in
                    re.finditer(r"\(([a-z]+)\)\s*([^()]+?)(?=\s*\([a-z]+\)|$)", line)}

        for seed in range(20):
            out = instantiate(mt, "M", seed, QT.MATCH)
            col_i_line = out["stem"].split("\nColumn I:")[1].split("\nColumn II:")[0]
            col_ii_line = out["stem"].split("\nColumn II:")[1]
            col_i, col_ii = _items(col_i_line), _items(col_ii_line)
            pairs = re.findall(r"\(([a-z]+)\)-\(([a-z]+)\)", out["answer"])
            self.assertEqual(len(pairs), 4, out["answer"])
            for rl, cl in pairs:      # each answered pairing must be the true SI unit
                self.assertEqual(units[col_i[rl]], col_ii[cl], (out["stem"], out["answer"]))


class TestConservativeBinding(unittest.TestCase):
    def test_no_template_for_generic_concept(self):
        self.assertIsNone(find_template("Biology", "Photosynthesis", "mcq"))
        self.assertIsNone(find_template("Biology", "Photosynthesis", "numerical"))

    def test_newton_template_not_matched_by_other_second_laws(self):
        # the classic false-positive the conjunctive keyword groups must avoid
        for title in ("Kepler's second law", "Second law of thermodynamics"):
            t = find_template("Physics", title, "numerical")
            self.assertNotEqual(getattr(t, "template_id", None), "phy_newton_2law", title)

    def test_subject_scoped(self):
        # a physics formula template never fires on a chemistry/biology concept of the same words
        self.assertIsNone(find_template("Chemistry", "Kinetic Energy", "numerical"))


if __name__ == "__main__":
    unittest.main()
