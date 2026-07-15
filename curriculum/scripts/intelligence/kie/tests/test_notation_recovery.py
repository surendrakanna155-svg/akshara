"""Tests for the governed math-capable notation-recovery layer (owner decision A).

The load-bearing claim is that DETERMINISTIC certification — not the transcription model — decides what is
admitted. These tests pin that: correctly-recovered relations certify; OCR/transcription-damaged variants are
rejected by the dimensional gate even when arithmetic corroboration would have accepted them.
"""
import unittest
from unittest import mock

from kie.qie import store as S
from kie.qie.convert.notation import batches as B
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


class TestChemistryUnits(unittest.TestCase):
    """Chemistry's molar/electrochemical units must reduce, or a TRUE relation is falsely rejected
    (lesson: a missing unit silently rejected a correct relation — extend UNITS, never weaken the gate)."""

    def test_molar_and_electrochemical_units_parse(self):
        for u in ("J/mol", "J K^-1 mol^-1", "C/mol", "S m^2 mol^-1", "S/m", "mol m^-3", "Pa", "m^3"):
            self.assertIsNotNone(D.parse_unit(u), u)

    def test_molar_conductivity_reduces(self):
        # (S/m) / (mol/m^3) == S m^2 mol^-1 — only base-dimension reduction makes these compare equal
        self.assertTrue(D.check_relation("S m^2 mol^-1", "kappa/c",
                                         {"kappa": "S/m", "c": "mol m^-3"})["ok"])

    def test_faraday_times_volt_is_molar_energy(self):
        self.assertTrue(D.check_relation("J/mol", "-n*F*E_cell",
                                         {"n": "1", "F": "C/mol", "E_cell": "V"})["ok"])


class TestTranscendentalRelations(unittest.TestCase):
    """exp/log relations (Arrhenius, ΔrG⊖ = −RT ln K) certify only if their argument is DIMENSIONLESS —
    the gate must reduce the exponent rather than wave the transcendental through."""

    ARRHENIUS = dict(
        name="Arrhenius equation", subject="Chemistry", concept_candidate="Chemistry :: Chemical Kinetics",
        equation="k = A*exp(-Ea/(R*T))", lhs_unit="s^-1",
        symbols={"k": "s^-1", "A": "s^-1", "Ea": "J/mol", "R": "J K^-1 mol^-1", "T": "K"},
        provenance={"store_path": "resources/foundation/x.zip", "entry": "lech103.pdf", "page": 23})

    def test_arrhenius_certifies(self):
        self.assertEqual(V.certify(self.ARRHENIUS)["status"], "certified")

    def test_dimensional_exponent_is_rejected(self):
        # R moved into the numerator leaves the exponent carrying units -> must not certify
        bad = {**self.ARRHENIUS, "equation": "k = A*exp(-Ea*R/T)"}
        v = V.certify(bad)
        self.assertEqual(v["status"], "rejected")
        self.assertIn("dimensional", v["failed_gates"])

    def test_gibbs_log_equilibrium_certifies(self):
        rel = dict(name="Gibbs energy and equilibrium constant", subject="Chemistry",
                   concept_candidate="Chemistry :: Thermodynamics",
                   equation="dG_std = -R*T*log(K_eq)", lhs_unit="J/mol",
                   symbols={"dG_std": "J/mol", "R": "J K^-1 mol^-1", "T": "K", "K_eq": "1"},
                   provenance={"store_path": "resources/foundation/x.zip", "entry": "kech105.pdf", "page": 28})
        self.assertEqual(V.certify(rel)["status"], "certified")


class TestRecoveryBatches(unittest.TestCase):
    """A batch file is the only reproducible record of an admission (qie.db is a gitignored derived store),
    so replaying it must reproduce the same verdicts — and its adversarial controls must still be caught."""

    def test_chem_batch3_certifies_and_controls_hold(self):
        r = B.dry_run("chem_batch3")
        self.assertEqual(r["rejected"], 0, [v["failed_gates"] for v in r["verdicts"]])
        self.assertEqual(r["certified"], 14)
        self.assertEqual(r["controls_held"], 3)

    def test_every_control_is_caught_by_a_deterministic_gate(self):
        for c in B.load("chem_batch3")["controls"]:
            v = V.certify(c)
            self.assertEqual(v["status"], "rejected", c["name"])
            self.assertIn("dimensional", v["failed_gates"], c["name"])

    def test_a_control_that_certifies_aborts_the_batch(self):
        """Control discipline must be mechanical: if a gate regresses so a damaged control passes, the batch
        must refuse to admit ANYTHING rather than report a green run."""
        batch = B.load("chem_batch3")
        with mock.patch.object(B, "load", return_value={**batch, "controls": [COULOMB]}):
            with self.assertRaises(B.ControlBreach):
                B.dry_run("chem_batch3")

    def test_replay_is_idempotent_and_admits_only_certified(self):
        conn = S.open_store(":memory:")
        first = B.run("chem_batch3", conn, now="t")
        second = B.run("chem_batch3", conn, now="t")
        self.assertEqual([a["relation_id"] for a in first["admitted"]],
                         [a["relation_id"] for a in second["admitted"]])
        c = R.counts(conn)
        self.assertEqual(c["certified"], 14)          # replay does not duplicate
        self.assertEqual(c["rejected"], 3)            # controls persisted as rejects, never admitted
        self.assertNotIn("CONTROL damaged enthalpy relation", [x["name"] for x in R.certified(conn)])


class TestGovernedConceptTitles(unittest.TestCase):
    def test_every_certified_relation_name_passes_the_qpgen_sanitizer(self):
        """qpgen binds a relation at RELATION granularity ("Chemistry :: Molar conductivity") and applies the
        same concept sanitizer as every other in-scope concept — an unclean name silently costs paper slots."""
        from kie.qie.qp_bridge import _clean_title
        from kie.qpgen import sanitize
        for rel in B.load("chem_batch3")["relations"]:
            self.assertTrue(sanitize.is_clean_concept(_clean_title(rel["name"])), rel["name"])


if __name__ == "__main__":
    unittest.main()
