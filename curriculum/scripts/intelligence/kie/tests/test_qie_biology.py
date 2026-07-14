"""Golden tests — evidence-grounded qualitative Biology on the unified engine.
Contract: KB is consistent (functional relations → unambiguous); operators verify against the canonical KB;
multi-hop templates give reasoning depth; distractors are OTHER real entities; tampering caught; Biology subject;
no LLM in the truth path.
"""
import unittest

from kie.qie import bio_data as BD
from kie.qie import biology as B
from kie.qie import compose as C
from kie.qie import compositions as K


class TestBioData(unittest.TestCase):
    def test_kb_consistent_and_functional(self):
        BD.assert_consistent()                                   # relations functional → unambiguous questions
        # canonical spot-checks
        self.assertEqual(BD.FUNC_TO_STRUCT["photosynthesis"], "chloroplast")
        self.assertEqual(BD.GLAND_TO_HORMONE["thyroid gland"], "thyroxine")
        self.assertEqual(BD.HORMONE_TO_EFFECT["insulin"], "lowering of blood glucose level")


class TestBioOperators(unittest.TestCase):
    def test_operators_lookup_and_verify(self):
        nx = C.OPERATORS["next_step"]
        proc = tuple(BD.PROCESSES[0][1])           # alimentary canal
        self.assertEqual(nx.apply(proc, "stomach"), "small intestine")
        self.assertTrue(nx.verify([proc, "stomach"], "small intestine"))
        self.assertFalse(nx.verify([proc, "stomach"], "mouth"))
        so = C.OPERATORS["system_of"]
        self.assertTrue(so.verify(["nephron"], "excretory system"))
        self.assertFalse(so.verify(["nephron"], "nervous system"))


class TestBioTemplates(unittest.TestCase):
    def test_templates_generate_verified_multi_hop(self):
        cands = K.generate(B.TEMPLATES, per_template=10, seed="T")
        frames = {c["frame_id"] for c in cands}
        for f in ("bio_process_next_step", "bio_structure_to_system", "bio_gland_hormone_effect"):
            self.assertIn(f, frames, f)
        self.assertTrue(any(c["reasoning_depth"] >= 2 for c in cands))   # multi-hop chains
        for c in cands:
            self.assertEqual(c["subject"], "Biology")
            self.assertEqual(K.verify_composition(c), "agree", c["stem"])
            self.assertIn(c["answer_text"], c["options"].values())
            self.assertEqual(len(c["options"]), 4)

    def test_distractors_same_category_no_giveaway(self):
        real_systems = set(BD.HUMAN_SYSTEMS)
        for c in K.generate(B.TEMPLATES, per_template=8, seed="D"):
            if c["frame_id"] != "bio_structure_to_system":
                continue
            for opt in c["options"].values():
                # every option is a real HUMAN organ system (same category → can't category-spot the answer)
                self.assertIn(opt, real_systems)

    def test_tamper_caught(self):
        for c in K.generate(B.TEMPLATES, per_template=3, seed="X"):
            bad = dict(c)
            bad["_answer"] = "__not_a_real_answer__"
            self.assertEqual(K.verify_composition(bad), "disagree", c["frame_id"])


if __name__ == "__main__":
    unittest.main()
