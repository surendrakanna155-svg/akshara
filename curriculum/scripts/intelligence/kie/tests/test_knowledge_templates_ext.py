"""Knowledge Layer Phase 4 — expanded certified template library (curate/templates_ext).

Locks the knowledge-layer families: they are loaded into the engine REGISTRY, well-formed +
deterministic for every seed, SOLVER-CORRECT (answers independently recomputed here), and
conservatively bound (they never fire on the engine's 'stays a spec' fixtures). The engine's
own test suite continues to pass unchanged (this file only adds coverage for the new content).
"""
import math
import re
import unittest

from kie.qpgen import templates as T
from kie.qpgen.templates import _p, _n, instantiate, find_template
from kie.qpgen.models import QuestionType as QT

_NEW_IDS = {
    "phy_parallel_resistance", "phy_displacement_motion", "phy_acceleration", "phy_impulse",
    "phy_pressure_liquid", "phy_efficiency", "phy_latent_heat", "phy_lens_power",
    "phy_refractive_index", "phy_frequency_period", "chem_molality", "chem_mass_percent",
    "chem_boyles_law", "chem_charles_law", "chem_half_life", "chem_percent_yield",
    "chem_normality", "math_distance_points", "math_slope", "math_midpoint", "math_triangle_area",
    "math_cube_surface_area", "math_compound_interest", "math_arithmetic_mean", "math_hcf",
    "math_gp_sum", "bio_gamete_types", "bio_respiratory_quotient",
}


def _tmpl(tid):
    return next(t for t in T.REGISTRY if t.template_id == tid)


class TestExtensionLoaded(unittest.TestCase):
    def test_all_new_families_registered(self):
        ids = {t.template_id for t in T.REGISTRY}
        self.assertTrue(_NEW_IDS <= ids, _NEW_IDS - ids)

    def test_library_grew_well_beyond_original(self):
        self.assertGreaterEqual(len(T.REGISTRY), 78)

    def test_subjects_unchanged(self):
        self.assertEqual({t.subject for t in T.REGISTRY}, {"Physics", "Chemistry", "Biology", "Mathematics"})


class TestNewFamiliesWellFormed(unittest.TestCase):
    def test_wellformed_and_deterministic(self):
        for tid in _NEW_IDS:
            tmpl = _tmpl(tid)
            for seed in range(25):
                cc = "C_" + tid
                for qt in tmpl.types:
                    out = instantiate(tmpl, cc, seed, qt)
                    self.assertTrue(out.get("stem") and out.get("answer") and out.get("solution"), (tid, qt))
                    self.assertTrue(out.get("solver_verified"))
                    self.assertEqual(instantiate(tmpl, cc, seed, qt), out)          # deterministic
                    if qt == QT.MCQ:
                        opts = out["options"]
                        self.assertEqual(len(opts), 4, (tid, opts))
                        self.assertEqual(len(set(opts)), 4, (tid, opts))
                        self.assertIn(out["answer"], opts, (tid, opts))


class TestSolverCorrectness(unittest.TestCase):
    """Recompute each answer INDEPENDENTLY from the same parameters — catches a broken formula."""

    def test_parallel_resistance(self):
        for s in range(15):
            cc = "R"; a = _p(cc, s, "a", 2, 20); b = _p(cc, s, "b", 2, 20)
            out = instantiate(_tmpl("phy_parallel_resistance"), cc, s, QT.NUMERICAL)
            self.assertEqual(out["answer"], f"{_n((a*b)/(a+b))} Ω")

    def test_displacement(self):
        for s in range(15):
            cc = "S"; u = _p(cc, s, "u", 0, 15); a = _p(cc, s, "a", 2, 10); t = _p(cc, s, "t", 2, 8)
            out = instantiate(_tmpl("phy_displacement_motion"), cc, s, QT.NUMERICAL)
            self.assertEqual(out["answer"], f"{_n(u*t + 0.5*a*t*t)} m")

    def test_distance_is_pythagorean(self):
        for s in range(15):
            out = instantiate(_tmpl("math_distance_points"), "D", s, QT.NUMERICAL)
            pts = re.findall(r"\((-?\d+), (-?\d+)\)", out["stem"])
            (x1, y1), (x2, y2) = [(int(a), int(b)) for a, b in pts]
            d = int(out["answer"].split()[0])
            self.assertEqual((x2 - x1) ** 2 + (y2 - y1) ** 2, d * d, out["stem"])

    def test_compound_interest(self):
        for s in range(15):
            cc = "CI"; pr = _p(cc, s, "p", 1, 20) * 100; r = _p(cc, s, "r", 1, 5) * 5
            amount = pr * (1 + r / 100) ** 2
            out = instantiate(_tmpl("math_compound_interest"), cc, s, QT.NUMERICAL)
            self.assertEqual(out["answer"], f"₹{_n(amount - pr)}")

    def test_half_life(self):
        for s in range(15):
            cc = "HL"; base = _p(cc, s, "b", 2, 10); half = _p(cc, s, "h", 1, 5); n0 = base * (2 ** half)
            out = instantiate(_tmpl("chem_half_life"), cc, s, QT.NUMERICAL)
            self.assertEqual(out["answer"], f"{_n(n0 / (2 ** half))} g")

    def test_gp_sum(self):
        for s in range(15):
            cc = "G"; a = _p(cc, s, "a", 1, 6); r = _p(cc, s, "r", 2, 4); nn = _p(cc, s, "n", 2, 6)
            out = instantiate(_tmpl("math_gp_sum"), cc, s, QT.NUMERICAL)
            self.assertEqual(out["answer"], f"{_n(a * (r ** nn - 1) // (r - 1))}")

    def test_hcf_divides_both(self):
        for s in range(15):
            out = instantiate(_tmpl("math_hcf"), "H", s, QT.NUMERICAL)
            a, b = map(int, re.findall(r"HCF\) of (\d+) and (\d+)", out["stem"])[0])
            h = int(out["answer"])
            self.assertEqual(a % h, 0); self.assertEqual(b % h, 0)
            self.assertEqual(h, math.gcd(a, b))

    def test_gametes_is_power_of_two(self):
        for s in range(15):
            cc = "GA"; k = _p(cc, s, "k", 1, 6)
            out = instantiate(_tmpl("bio_gamete_types"), cc, s, QT.NUMERICAL)
            self.assertEqual(out["answer"], f"{2 ** k}")

    def test_boyle(self):
        for s in range(15):
            cc = "B"; p1 = _p(cc, s, "p", 2, 20); v2 = _p(cc, s, "v", 2, 10); k = _p(cc, s, "k", 2, 5)
            v1 = v2 * k
            out = instantiate(_tmpl("chem_boyles_law"), cc, s, QT.NUMERICAL)
            self.assertEqual(out["answer"], f"{_n(p1 * v1 / v2)} atm")


class TestConservativeBinding(unittest.TestCase):
    def test_new_families_do_not_capture_spec_fixtures(self):
        for subj, title in [("Biology", "Photosynthesis"), ("Physics", "Gravitation"),
                            ("Physics", "Work Energy Theorem"), ("Physics", "Work and Energy"),
                            ("Chemistry", "Kinetic Energy")]:
            for qt in ("numerical", "mcq"):
                t = find_template(subj, title, qt)
                self.assertNotIn(getattr(t, "template_id", None), _NEW_IDS, (subj, title, qt))

    def test_snells_law_maps_to_refractive_index(self):
        t = find_template("Physics", "Snell's law", "numerical")
        self.assertEqual(getattr(t, "template_id", None), "phy_refractive_index")


if __name__ == "__main__":
    unittest.main()
