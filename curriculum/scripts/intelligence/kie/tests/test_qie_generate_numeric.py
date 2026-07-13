"""Phase D golden tests — certified-relation numeric generation (NEET Physics/Chemistry).
Contract: parametric new instances, answer computed by the certified relation, governed numeric distractors,
DETERMINISTIC independent (second-solver) verification, originality/duplicate gates, no fabrication."""
import unittest

from kie.qie import generate_numeric as GN, relations as R


class TestGenerate(unittest.TestCase):
    def test_answer_is_relation_of_params(self):
        cands = GN.generate(per_template=2, seed="T")
        self.assertTrue(cands)
        for c in cands:
            rel = next(r for r in R.LIBRARY if r.name == c["relation"])
            # the stated answer equals the certified relation applied to the generated params
            import itertools
            ok = any(rel.fn(*p) is not None and abs(round(rel.fn(*p), 2) - c["answer_value"]) < 1e-6
                     for p in itertools.permutations(c["params"], rel.arity))
            self.assertTrue(ok, c["relation"])
            self.assertEqual(len(c["options"]), 4)
            self.assertEqual(len({v for v in c["options"].values()}), 4)      # 4 distinct options
            self.assertIn(c["answer_text"], c["options"].values())

    def test_distractors_are_transforms_distinct(self):
        d = GN.numeric_distractors(30.0, GN.TEMPLATES[0])
        self.assertGreaterEqual(len(d), 3)
        self.assertNotIn(30.0, d)
        self.assertEqual(len(d), len(set(d)))


class TestVerify(unittest.TestCase):
    def test_correct_item_verifies_deterministically(self):
        c = GN.generate(per_template=1, seed="V")[0]
        self.assertEqual(GN.verify_numeric(c), "agree")

    def test_tampered_answer_rejected(self):
        c = dict(GN.generate(per_template=1, seed="V")[0])
        c["answer_value"] = c["answer_value"] + 7                              # corrupt the key
        self.assertEqual(GN.verify_numeric(c), "disagree")

    def test_independent_of_generator_arithmetic(self):
        # verification uses relations.verify (the whole-library second solver), not the stored answer blindly
        c = GN.generate(per_template=1, seed="V")[0]
        # if params don't actually solve to the answer, it must fail regardless of stored answer_text
        c2 = dict(c, params=[c["params"][0] + 5] + list(c["params"][1:]))
        self.assertEqual(GN.verify_numeric(c2), "disagree")


class TestGates(unittest.TestCase):
    def test_near_copy_of_source_params_rejected(self):
        c = GN.generate(per_template=1, seed="G")[0]
        sig = {(c["relation"], tuple(round(float(p), 3) for p in c["params"]))}
        self.assertEqual(GN.gate_numeric(c, sig, set()), "NEAR_COPY_OF_SOURCE_PARAMS")

    def test_duplicate_generated_rejected(self):
        c = GN.generate(per_template=1, seed="G")[0]
        seen = set()
        self.assertIsNone(GN.gate_numeric(c, set(), seen))
        self.assertEqual(GN.gate_numeric(c, set(), seen), "DUPLICATE_GENERATED")


class TestRun(unittest.TestCase):
    def test_only_pass_proceeds(self):
        res = GN.run(per_template=4, seed="R")
        self.assertGreater(res["passed"], 0)
        self.assertEqual(res["passed"], len(res["verified_bank"]))
        self.assertTrue(all(i["status"] == "PASS" for i in res["verified_bank"]))
        # every banked item carries relation + params + deterministic verification provenance
        for it in res["verified_bank"]:
            self.assertIn("relation", it)
            self.assertEqual(it["verification"]["method"], "deterministic_relation_solver")


if __name__ == "__main__":
    unittest.main()
