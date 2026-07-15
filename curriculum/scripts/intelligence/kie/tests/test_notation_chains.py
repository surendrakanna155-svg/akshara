"""Tests for the compositional CHAIN layer — the depth-4/5 (HARD) lane over certified relations.

The load-bearing claims:
  1. A chain earns HARD from the DAG (`compose.reasoning_depth`), never by assertion — so a single relation
     can never masquerade as hard.
  2. The JUNCTION gate is what makes a chain safe. Feeding joules into a joules-per-mole slot is arithmetically
     fine and answer-checking would never notice; only base-dimension reduction catches it.
  3. Nothing reaches a paper unless its wiring certified.
"""
import json
import unittest

from kie.qie import compositions as K
from kie.qie.convert.notation import batches as B
from kie.qie.convert.notation import chains as CH
from kie.qie.convert.notation import verify as V

SET = "depth4_chains"
RELATION_BATCHES = ("phys_batch1_2", "chem_batch3")


def _defs() -> dict:
    return json.loads((CH.DEF_DIR / f"{SET}.json").read_text())


def _certified_relations() -> dict:
    """Build the relation map from the COMMITTED batch files, not from qie.db (a gitignored derived store) —
    so these tests are reproducible from a fresh clone and cannot pass vacuously on an empty store."""
    out = {}
    for name in RELATION_BATCHES:
        for rel in B.load(name)["relations"]:
            assert V.certify(rel)["status"] == "certified", rel["name"]
            out[rel["name"]] = rel
    return out


class TestChainCertification(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rels = _certified_relations()

    def test_every_shipped_chain_certifies(self):
        for ch in CH.load(SET):
            v = CH.certify(ch, self.rels)
            self.assertEqual(v["status"], "certified", f"{ch.name}: {v['failed_gates']}")

    def test_every_certified_chain_is_hard(self):
        for ch in CH.load(SET):
            self.assertGreaterEqual(CH.depth_of(ch), CH.HARD_DEPTH, ch.name)

    def test_controls_are_all_rejected(self):
        for d in _defs()["controls"]:
            v = CH.certify(CH._mk(d), self.rels)
            self.assertEqual(v["status"], "rejected", d["name"])

    def test_junction_gate_catches_joule_into_molar_slot(self):
        """The signature silent-nonsense failure: J -> J/mol is dimensionally wrong but arithmetically fine,
        so ONLY the junction gate can catch it."""
        d = next(c for c in _defs()["controls"] if c["name"] == "CONTROL joule into molar slot")
        v = CH.certify(CH._mk(d), self.rels)
        self.assertIn("junction", v["failed_gates"])

    def test_closure_gate_catches_unsupplied_symbol(self):
        d = next(c for c in _defs()["controls"] if c["name"] == "CONTROL unresolved free symbol")
        v = CH.certify(CH._mk(d), self.rels)
        self.assertIn("closure", v["failed_gates"])

    def test_uncertified_relation_cannot_enter_a_chain(self):
        ch = CH.load(SET)[0]
        v = CH.certify(ch, {})                       # nothing certified
        self.assertEqual(v["status"], "rejected")
        self.assertIn("steps_certified", v["failed_gates"])

    def test_ambiguous_branch_is_rejected_never_guessed(self):
        # T**2 = K_S*R**3 solves to ±sqrt(...): two real branches -> no unique solution, so no chain step
        rel = {"equation": "T**2 = K_S*R**3", "symbols": {"T": "s", "K_S": "s^2 m^-3", "R": "m"}}
        self.assertIsNone(CH.solve_step(rel, "T"))
        self.assertIsNotNone(CH.solve_step(rel, "K_S"))       # linear in K_S -> unique


class TestChainGeneration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from kie.qie.convert.notation import chain_compose as CC
        cls.CC = CC
        cls.bank = K.run(CC.TEMPLATES, per_template=2, seed="7")["verified_bank"]
        # candidates keep the private _env0/_answer that re-verification needs
        cls.cands = list(K.generate(CC.TEMPLATES, per_template=2, seed="7"))

    def test_items_generate_and_are_depth_4_plus(self):
        self.assertTrue(self.bank)
        for it in self.bank:
            self.assertGreaterEqual(it["reasoning_depth"], CH.HARD_DEPTH, it["concept"])
            self.assertEqual(it["depth_band"], "ADVANCED")

    def test_depth_is_earned_by_the_dag_not_asserted(self):
        from kie.qie.compose import reasoning_depth
        for name, tmpl in self.CC.TEMPLATES.items():
            env0, _ = tmpl.setup("7")
            self.assertGreaterEqual(reasoning_depth(tmpl.pipeline, env0.keys()), CH.HARD_DEPTH, name)

    def test_stem_never_reveals_the_route(self):
        """A stem states the givens and asks for the target. Printing a constituent relation (or naming it)
        would collapse a 4-step chain into substitution — the no-giveaway rule."""
        rels = _certified_relations()
        for it in self.bank:
            low = it["stem"].lower()
            for banned in ("ohm's law", "first law", "wheatstone bridge null", "raoult", "arrhenius"):
                self.assertNotIn(banned, low, it["stem"])
            for rel in rels.values():                     # no relation's equation/display may appear
                rhs = rel["equation"].split("=", 1)[1].strip().lower()
                self.assertNotIn(rhs, low, f"{it['stem']} leaks {rel['name']}")
                if rel.get("display"):
                    self.assertNotIn(rel["display"].lower(), low, f"{it['stem']} leaks {rel['name']}")

    def test_every_candidate_is_reproduced_by_independent_end_to_end(self):
        self.assertTrue(self.cands)
        for c in self.cands:
            self.assertEqual(K.verify_composition(c), "agree", c["concept"])

    def test_tampered_answer_is_rejected(self):
        c = dict(self.cands[0])
        c["_answer"] = c["_answer"] * 2 + 1
        self.assertEqual(K.verify_composition(c), "disagree")

    def test_a_broken_junction_fails_the_step_verifier(self):
        """Per-step verification is equation-satisfaction, INDEPENDENT of the solve that produced the value —
        so a corrupted intermediate is caught even though the forward arithmetic 'succeeded'."""
        from kie.qie.convert.notation import chain_compose as CC
        tmpl = next(iter(CC.TEMPLATES.values()))
        env0, _ = tmpl.setup("7")
        cfg = env0["c1"]
        good = CC._apply(cfg, *[1.0] * len(cfg["feed_syms"]))
        self.assertTrue(CC._verify([cfg] + [1.0] * len(cfg["feed_syms"]), good))
        self.assertFalse(CC._verify([cfg] + [1.0] * len(cfg["feed_syms"]), good * 2 + 1))


class TestChainsReachThePaper(unittest.TestCase):
    def test_chain_concepts_are_in_scope_and_bindable(self):
        """A chain that generates but cannot bind is invisible — this pins the qp_bridge wiring."""
        from kie.qie.qp_bridge import _clean_title
        from kie.qpgen import sanitize
        for ch in CH.load(SET):
            self.assertTrue(sanitize.is_clean_concept(_clean_title(ch.name)), ch.name)

    def test_hard_slots_are_filled_by_chains(self):
        from collections import Counter
        from kie.qie import qp_bridge as QB
        from kie.qpgen.models import PaperRequest
        paper, rep = QB.generate_paper(PaperRequest(exam="NEET", seed=7), per=18)
        hard = [s for s in paper.slots if s.status == "filled" and s.difficulty == "hard"]
        self.assertTrue(hard, "NEET Section B (hard) is starved — the chain lane is not reaching the paper")
        self.assertTrue(rep.boundary_ok)
        self.assertEqual(len(rep.violations), 0)
        by = Counter(s.subject for s in hard)
        self.assertIn("Chemistry", by)
        self.assertIn("Physics", by)


if __name__ == "__main__":
    unittest.main()
