"""Tests for the governed math-capable notation-recovery layer (owner decision A).

The load-bearing claim is that DETERMINISTIC certification — not the transcription model — decides what is
admitted. These tests pin that: correctly-recovered relations certify; OCR/transcription-damaged variants are
rejected by the dimensional gate even when arithmetic corroboration would have accepted them.
"""
import unittest

from kie.qie import store as S
from kie.qie.convert.notation import dimensions as D
from kie.qie.convert.notation import register as R
from kie.qie.convert.notation import sources as SRC
from kie.qie.convert.notation import verify as V

COULOMB = dict(
    name="Coulomb's law", subject="Physics", concept_candidate="Physics :: Electric Charges And Fields",
    equation="F = 1/(4*pi*eps0)*q1*q2/r**2", lhs_unit="N",
    symbols={"F": "N", "eps0": "C^2 N^-1 m^-2", "q1": "C", "q2": "C", "r": "m"},
    provenance={"store_path": "resources/foundation/x.zip", "entry": "a.pdf", "page": 7, "eq_label": "(1.2)"})


class TestUnitParsing(unittest.TestCase):
    def test_compound_and_negative_exponents(self):
        for u in ("N", "m s^-2", "C^2 N^-1 m^-2", "N m^2 kg^-2", "J mol^-1 K^-1", "m/s"):
            self.assertIsNotNone(D.parse_unit(u), u)

    def test_unknown_unit_is_rejected_not_guessed(self):
        self.assertIsNone(D.parse_unit("bananas"))


class TestDimensionalGate(unittest.TestCase):
    def test_certifies_correct_relation(self):
        r = D.check_relation("N", "1/(4*pi*eps0)*q1*q2/r**2",
                             {"eps0": "C^2 N^-1 m^-2", "q1": "C", "q2": "C", "r": "m"})
        self.assertTrue(r["ok"], r)

    def test_rejects_ocr_lost_exponent(self):
        r = D.check_relation("N", "1/(4*pi*eps0)*q1*q2/r",
                             {"eps0": "C^2 N^-1 m^-2", "q1": "C", "q2": "C", "r": "m"})
        self.assertFalse(r["ok"])

    def test_rejects_misplaced_constant(self):
        r = D.check_relation("N", "(4*pi*eps0)*q1*q2/r**2",
                             {"eps0": "C^2 N^-1 m^-2", "q1": "C", "q2": "C", "r": "m"})
        self.assertFalse(r["ok"])

    def test_like_unit_difference_does_not_cancel(self):
        # regression: substituting identical units made `K_f - K_i` collapse to 0 and lose its dimension
        r = D.check_relation("J", "K_f - K_i", {"K_f": "J", "K_i": "J"})
        self.assertTrue(r["ok"], r)

    def test_illegal_sum_of_unlike_units_rejected(self):
        r = D.check_relation("V", "I+R", {"I": "A", "R": "ohm"})
        self.assertFalse(r["ok"])


class TestCertificationHierarchy(unittest.TestCase):
    def test_full_certification(self):
        v = V.certify(COULOMB)
        self.assertEqual(v["status"], "certified", v["failed_gates"])

    def test_damaged_relation_rejected_by_dimensional_gate(self):
        bad = {**COULOMB, "equation": "F = 1/(4*pi*eps0)*q1*q2/r"}
        v = V.certify(bad)
        self.assertEqual(v["status"], "rejected")
        self.assertIn("dimensional", v["failed_gates"])

    def test_no_provenance_is_rejected(self):
        bad = {**COULOMB, "provenance": {}}
        v = V.certify(bad)
        self.assertEqual(v["status"], "rejected")
        self.assertIn("provenance", v["failed_gates"])

    def test_undeclared_symbol_rejected_never_guessed(self):
        bad = {**COULOMB, "equation": "F = 1/(4*pi*eps0)*q1*q2/r**2 + Z"}
        v = V.certify(bad)
        self.assertEqual(v["status"], "rejected")

    def test_signed_quantity_round_trips(self):
        # regression: `positive=True` symbols made the (negative) gravitational PE unsolvable
        rel = dict(name="Grav PE", subject="Physics", concept_candidate="Physics :: Gravitation",
                   equation="V = -G*m1*m2/r", lhs_unit="J",
                   symbols={"V": "J", "G": "N m^2 kg^-2", "m1": "kg", "m2": "kg", "r": "m"},
                   provenance={"store_path": "x.zip", "entry": "a.pdf", "page": 14})
        self.assertEqual(V.certify(rel)["status"], "certified")

    def test_answer_key_alone_cannot_certify(self):
        """The decisive guard: a DAMAGED relation that real questions arithmetically 'confirm' must still be
        rejected. This is the ~90%-false-positive trap that made blind relation-induction unsafe."""
        damaged = dict(name="spring PE (lost square)", subject="Physics",
                       concept_candidate="Physics :: Work Energy And Power",
                       equation="V = k*x/2", lhs_unit="J", symbols={"V": "J", "k": "N m^-1", "x": "m"},
                       provenance={"store_path": "x.zip", "entry": "a.pdf", "page": 15})
        items = [{"stem": "k = 6 and x = 4", "answer_text": "12"}] * 3      # arithmetic 'confirms' 6*4/2=12
        v = V.certify(damaged, corroboration_items=items)
        self.assertGreater(v["corroboration"]["confirmed"], 0)             # corroboration DID fire...
        self.assertEqual(v["status"], "rejected")                          # ...and was correctly overruled
        self.assertIn("dimensional", v["failed_gates"])


class TestRegistration(unittest.TestCase):
    def setUp(self):
        self.conn = S.open_store(":memory:")

    def test_only_certified_is_admitted_and_rejects_are_persisted(self):
        R.register(self.conn, COULOMB, "t", "test")
        bad = {**COULOMB, "name": "damaged", "equation": "F = 1/(4*pi*eps0)*q1*q2/r"}
        R.register(self.conn, bad, "t", "test")
        c = R.counts(self.conn)
        self.assertEqual(c["certified"], 1)
        self.assertEqual(c["rejected"], 1)
        self.assertEqual([r["name"] for r in R.certified(self.conn)], ["Coulomb's law"])


class TestSourceTargeting(unittest.TestCase):
    def test_math_damage_score_flags_flattened_equations(self):
        flattened = "0\n1\n2\n2\n1\n4\nq q\nF\nr\nε\n=\nπ\n(1.2)\n"
        prose = "Measurement of any physical quantity involves comparison with a reference standard."
        self.assertGreater(SRC.math_damage_score(flattened), SRC.math_damage_score(prose))


if __name__ == "__main__":
    unittest.main()
