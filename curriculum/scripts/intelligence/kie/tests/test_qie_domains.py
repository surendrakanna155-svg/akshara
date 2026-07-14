"""Golden tests — universal substrate: Physics & Chemistry on the SAME compositional engine.
Contract: domain modules only REGISTER operators/templates (engine unchanged); generated items are verified
per-step AND by a genuinely independent end-to-end (physics: independent physical principle; chemistry:
round-trip mass/dilution conservation); tampering is caught; subjects are tagged correctly.
"""
import unittest

from kie.qie import chemistry as CH
from kie.qie import compose as C
from kie.qie import compositions as K
from kie.qie import physics as P


class TestRegistration(unittest.TestCase):
    def test_domains_registered_into_shared_registries(self):
        # operators landed in the SAME engine registry, tagged by domain
        self.assertEqual(C.OPERATORS["newton_accel"].domain, "physics")
        self.assertEqual(C.OPERATORS["moles_from_mass"].domain, "chemistry")
        # templates landed in the SAME cross-domain template registry
        for name in P.TEMPLATES:
            self.assertIn(name, K.TEMPLATE_REGISTRY)
        for name in CH.TEMPLATES:
            self.assertIn(name, K.TEMPLATE_REGISTRY)


class TestPhysics(unittest.TestCase):
    def test_generates_verified_physics_items(self):
        cands = K.generate(P.TEMPLATES, per_template=5, seed="T")
        frames = {c["frame_id"] for c in cands}
        for f in ("phys_force_to_kinetic_energy", "phys_force_to_momentum", "phys_power_from_v_r"):
            self.assertIn(f, frames, f)
        for c in cands:
            self.assertEqual(c["subject"], "Physics")
            self.assertEqual(K.verify_composition(c), "agree", c["stem"])
            self.assertEqual(len(c["options"]), 4)
            self.assertIn(c["answer_text"], c["options"].values())

    def test_cross_principle_end_to_end_catches_tamper(self):
        # the independent physical-principle check must reject a fabricated answer
        for c in K.generate(P.TEMPLATES, per_template=2, seed="X"):
            bad = dict(c)
            bad["_answer"] = c["_answer"] * 2 + 1
            self.assertEqual(K.verify_composition(bad), "disagree", c["frame_id"])


class TestChemistry(unittest.TestCase):
    def test_generates_verified_chemistry_items(self):
        cands = K.generate(CH.TEMPLATES, per_template=5, seed="T")
        frames = {c["frame_id"] for c in cands}
        for f in ("chem_mass_to_molecules", "chem_stoichiometry_mass", "chem_dilution_molarity"):
            self.assertIn(f, frames, f)
        for c in cands:
            self.assertEqual(c["subject"], "Chemistry")
            self.assertEqual(K.verify_composition(c), "agree", c["stem"])
            self.assertEqual(len(c["options"]), 4)
            self.assertIn(c["answer_text"], c["options"].values())

    def test_roundtrip_end_to_end_catches_tamper(self):
        for c in K.generate(CH.TEMPLATES, per_template=2, seed="X"):
            bad = dict(c)
            bad["_answer"] = c["_answer"] * 3 + 1
            self.assertEqual(K.verify_composition(bad), "disagree", c["frame_id"])


class TestEngineUnchangedServesAllDomains(unittest.TestCase):
    def test_same_run_machinery_three_subjects(self):
        subjects = set()
        for tmap in (K.TEMPLATES, P.TEMPLATES, CH.TEMPLATES):
            res = K.run(tmap, per_template=4, seed="R")
            self.assertGreater(res["passed"], 0)
            subjects |= {it["subject"] for it in res["verified_bank"]}
        self.assertEqual(subjects, {"Mathematics", "Physics", "Chemistry"})


if __name__ == "__main__":
    unittest.main()
