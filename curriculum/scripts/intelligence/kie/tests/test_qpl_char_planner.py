"""Characterization tests — Phase 0 preservation lock (Question Planning Layer: planning side).

These PIN the CURRENT behaviour of the certified-only planning stack so the Phase 1+ refactor cannot
silently change it:
    knowledge/planner.py       — the deterministic pre-generation gate + certified_universe reader
    knowledge/plan_controls.py — the adversarial self-test of that gate
    knowledge/plan_specs.py    — the (currently seed-stochastic) spec planner

They assert behaviour AS-IS. They are NOT a specification of desired behaviour — Phase 2/3 deliberately
change plan_specs from seed-sampled to deterministically allocated, and these tests are expected to be
updated *as part of* that change, not before it.
"""
from __future__ import annotations

import sqlite3
import unittest

from kie import config
from kie.qie.archetypes import ARCHETYPES
from kie.qie.knowledge import plan_controls as PC
from kie.qie.knowledge import plan_specs as PS
from kie.qie.knowledge import planner as P

_IDX = config.KIE_HOME / "knowledge_index.db"


class PlannerGateChar(unittest.TestCase):
    def test_arch_depth_table_is_pinned_and_coherent(self):
        # the archetype x reasoning-depth compatibility table is load-bearing for the gate; pin key rows
        self.assertEqual(P._ARCH_DEPTH["direct_recall"], (1, 1))
        self.assertEqual(P._ARCH_DEPTH["definition_recognition"], (1, 1))
        self.assertEqual(P._ARCH_DEPTH["single_step_numerical"], (1, 2))
        self.assertEqual(P._ARCH_DEPTH["multi_step_numerical"], (2, 5))
        self.assertEqual(P._ARCH_DEPTH["constraint_reasoning"], (2, 5))
        self.assertEqual(P._ARCH_DEPTH["multi_concept_integration"], (2, 5))
        # every archetype in the table must be a member of the canon (no drift)
        for a in P._ARCH_DEPTH:
            self.assertIn(a, ARCHETYPES, f"{a!r} in _ARCH_DEPTH is not a canonical archetype")

    def test_ocr_garbage_and_junk_name_classifiers(self):
        # repeated-syllable OCR artifacts are garbage; short real concepts are NOT
        self.assertTrue(P.is_ocr_garbage("Telateltelt"))
        self.assertTrue(P.is_ocr_garbage("Scescescececert"))
        self.assertFalse(P.is_ocr_garbage("Ray"))
        self.assertFalse(P.is_ocr_garbage("Binomial Theorem"))
        # book apparatus / activity labels are refused by name; real concepts are not
        self.assertTrue(P._JUNK_NAME.match("National Anthem"))
        self.assertTrue(P._JUNK_NAME.match("Try These"))
        self.assertIsNone(P._JUNK_NAME.match("Binomial Theorem"))

    def test_check_plan_good_passes_and_named_defects_are_caught(self):
        uni = PC._universe()
        self.assertEqual(P.check_plan(PC._base(), uni), [])

        bad = PC._base(); bad["concept_id"] = "KC_notreal"
        self.assertTrue(any("uncertified_concept" in x for x in P.check_plan(bad, uni)))

        bad = PC._base(); bad["archetype"] = "direct_recall"; bad["intended_depth"] = 3
        self.assertTrue(any("archetype_depth_incoherent" in x for x in P.check_plan(bad, uni)))

        bad = PC._base(); bad["subject"] = "Biology"
        self.assertTrue(any("subject_mismatch" in x for x in P.check_plan(bad, uni)))

    def test_plan_controls_adversarial_suite_holds(self):
        # the module's own adversarial suite: every known-bad plan refused, known-good passes.
        # raises PlanControlBreach if the gate has a hole — pinning the whole gate here.
        res = PC.check_plan_controls()
        self.assertTrue(res["all_caught"])
        self.assertTrue(res["good_plan_passes"])
        self.assertTrue(res["good_composition_passes"])
        self.assertEqual(res["controls"], 12)


class PlanSpecsDeterminismChar(unittest.TestCase):
    """Pins the CURRENT determinism model: same (args, seed) -> byte-identical specs. Phase 3 replaces the
    RNG with weightage-driven allocation; this documents what is being replaced."""

    def _uni(self):
        return [
            {"concept_id": f"KC_{i}", "canonical_name": f"Concept {i}", "subject": "Mathematics",
             "taught_at_class": 8, "chapter_id": "CH_MAT_8_01", "sub_concepts": [], "prerequisites": [],
             "boundary": {}}
            for i in range(6)
        ]

    def test_build_specs_is_seed_deterministic(self):
        uni = self._uni()
        a = PS.build_specs(uni, [], "runX", n=20, seed=123, subject="Mathematics")
        b = PS.build_specs(uni, [], "runX", n=20, seed=123, subject="Mathematics")
        self.assertEqual([s["spec_id"] for s in a["issued"]], [s["spec_id"] for s in b["issued"]])
        self.assertEqual(a["planned"], b["planned"])
        self.assertTrue(a["issued"], "expected at least one issued spec from a valid universe")
        self.assertTrue(all(s["spec_id"].startswith("SPEC_") for s in a["issued"]))

    def test_issued_specs_all_pass_the_gate(self):
        uni = self._uni()
        out = PS.build_specs(uni, [], "runX", n=20, seed=7, subject="Mathematics")
        by_id = {c["concept_id"]: c for c in uni}
        for s in out["issued"]:
            self.assertEqual(P.check_plan(s, by_id), [], f"issued spec failed the gate: {s['spec_id']}")


@unittest.skipUnless(_IDX.exists(), "frozen knowledge_index.db not present (gitignored / local only)")
class CertifiedUniverseChar(unittest.TestCase):
    """Pins that the planner reads the FROZEN v1.4 certified index (read-only) and nothing else. The v1.4
    DB is immutable, so these counts are stable ground truth; a change here means the foundation moved."""

    def setUp(self):
        self.c = sqlite3.connect(f"file:{_IDX}?mode=ro", uri=True)
        self.c.row_factory = sqlite3.Row

    def tearDown(self):
        self.c.close()

    def test_reads_v14_certified_counts(self):
        counts = {s: len(P.certified_universe(self.c, s))
                  for s in ("Mathematics", "Science", "Physics", "Chemistry", "Biology")}
        self.assertEqual(counts, {"Mathematics": 637, "Science": 559, "Physics": 306,
                                  "Chemistry": 283, "Biology": 238})

    def test_universe_records_are_wellformed_and_scoped(self):
        u = P.certified_universe(self.c, "Physics", classes=[11, 12])
        self.assertTrue(u)
        for d in u[:60]:
            self.assertEqual(d["subject"], "Physics")
            self.assertIn(d["taught_at_class"], (11, 12))
            self.assertIsInstance(d["sub_concepts"], list)
            self.assertIsInstance(d["prerequisites"], list)
            self.assertIsInstance(d["boundary"], dict)
            self.assertTrue(d["concept_id"].startswith("KC_"))


if __name__ == "__main__":
    unittest.main()
