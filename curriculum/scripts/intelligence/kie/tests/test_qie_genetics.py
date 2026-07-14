"""Golden tests — Biology genetics on the unified engine, DETERMINISTIC (Tier-1) two-way verification.
Contract: Punnett enumeration cross-checked by the independent probability rule / full-grid / subset count;
genuine reasoning depth; tampering caught; Biology subject; no AI in the truth path.
"""
import unittest
from fractions import Fraction

from kie.qie import compositions as K
from kie.qie import genetics as G


class TestGeneticsPrimitives(unittest.TestCase):
    def test_punnett_and_fractions(self):
        d = G._cross("Tt", "Tt")
        self.assertEqual(len(d), 4)
        self.assertEqual(G.C.OPERATORS["frac_recessive"].apply(d), Fraction(1, 4))
        self.assertEqual(G.C.OPERATORS["frac_dominant"].apply(d), Fraction(3, 4))
        self.assertEqual(G.C.OPERATORS["frac_homozygous_dominant"].apply(d), Fraction(1, 4))
        # test cross Tt × tt → recessive 1/2
        self.assertEqual(G.C.OPERATORS["frac_recessive"].apply(G._cross("Tt", "tt")), Fraction(1, 2))

    def test_operator_verifiers_independent(self):
        d = G._cross("Tt", "Tt")
        fr = G.C.OPERATORS["frac_recessive"]
        self.assertTrue(fr.verify([d], Fraction(1, 4)))
        self.assertFalse(fr.verify([d], Fraction(3, 4)))          # wrong value rejected by the 1−dominant check


class TestGeneticsTemplates(unittest.TestCase):
    def test_all_templates_generate_verified(self):
        cands = K.generate(G.TEMPLATES, per_template=8, seed="T")
        frames = {c["frame_id"] for c in cands}
        for f in ("gen_monohybrid_recessive", "gen_dihybrid_both_recessive", "gen_conditional_homozygous"):
            self.assertIn(f, frames, f)
        for c in cands:
            self.assertEqual(c["subject"], "Biology")
            self.assertEqual(K.verify_composition(c), "agree", c["stem"])
            self.assertIn(c["answer_text"], c["options"].values())
        # the dihybrid + conditional are genuine multi-step reasoning
        self.assertTrue(any(c["reasoning_depth"] >= 3 for c in cands))

    def test_known_answers(self):
        # dihybrid both-recessive is always 1/16, conditional homozygous-among-dominant always 1/3
        di = [c for c in K.generate(G.TEMPLATES, per_template=4, seed="V") if c["frame_id"] == "gen_dihybrid_both_recessive"]
        self.assertTrue(di and all(c["answer_text"] == "1/16" for c in di))
        cond = [c for c in K.generate(G.TEMPLATES, per_template=4, seed="V") if c["frame_id"] == "gen_conditional_homozygous"]
        self.assertTrue(cond and all(c["answer_text"] == "1/3" for c in cond))

    def test_tamper_caught(self):
        for c in K.generate(G.TEMPLATES, per_template=3, seed="X"):
            bad = dict(c)
            bad["_answer"] = c["_answer"] + 1
            self.assertEqual(K.verify_composition(bad), "disagree", c["frame_id"])


if __name__ == "__main__":
    unittest.main()
