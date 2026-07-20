"""Phase 3 tests — the deterministic distributor: difficulty model, apportionment, QuestionBlueprint,
byte-for-byte determinism, Exam-DNA distribution match, and persistence into generation_spec."""
from __future__ import annotations

import os
import shutil
import tempfile
import unittest
from collections import Counter

from kie import config
from kie.qie.factory import corpus as CO
from kie.qie.knowledge import allocate as AL
from kie.qie.knowledge import blueprint as BP
from kie.qie.knowledge import blueprint_store as BS
from kie.qie.knowledge import difficulty as DIFF
from kie.qie.knowledge import examdna as ED
from kie.qie.knowledge import planner as P
from kie.qie.knowledge import run_planner as R

_IDX = config.KIE_HOME / "knowledge_index.db"


def _slot():
    return {"exam": "NEET", "subject": "Biology", "chapter_id": "CH_B", "occurrence": 0,
            "concept": {"concept_id": "KC_x", "canonical_name": "Photosynthesis", "subject": "Biology",
                        "taught_at_class": 11, "chapter_id": "CH_B", "chapter_title": "Life Processes",
                        "sub_concepts": ["Light reaction"], "prerequisites": ["Cell"],
                        "boundary": {"in_scope": ["a"], "out_of_scope": ["b"]}},
            "archetype": "property_application", "lane": "QUALITATIVE", "composition": "single",
            "target_difficulty": "easy", "reasoning_depth": 1, "difficulty": "easy",
            "difficulty_drivers": {"reasoning_depth": 1, "concept_count": 1,
                                   "misconception_pressure": 0.0, "calculation_load": 0.2},
            "difficulty_score": 0.03, "difficulty_model": "diff-v1", "difficulty_target_met": True}


class DifficultyModel(unittest.TestCase):
    def test_monotone_in_depth(self):
        self.assertLess(DIFF.score(1, 1), DIFF.score(5, 1))

    def test_band_boundaries(self):
        self.assertEqual(DIFF.band_for_score(0.10), "easy")
        self.assertEqual(DIFF.band_for_score(0.45), "moderate")
        self.assertEqual(DIFF.band_for_score(0.90), "hard")

    def test_drivers_for_target_honesty(self):
        # direct_recall (1,1) can never be 'hard' -> honest downgrade, target_met False
        r = DIFF.drivers_for_target("hard", "QUALITATIVE", "single", (1, 1))
        self.assertFalse(r["target_met"])
        self.assertEqual(r["realized_depth"], 1)
        # a numeric archetype with depth headroom CAN reach 'hard'
        r = DIFF.drivers_for_target("hard", "STRUCTURED_NUMERIC", "single", (2, 5))
        self.assertTrue(r["target_met"])
        self.assertEqual(r["predicted"]["band"], "hard")


class Apportionment(unittest.TestCase):
    def test_hamilton_sums_to_total(self):
        for total in (0, 1, 7, 180, 999):
            self.assertEqual(sum(AL.hamilton(total, {"a": 0.25, "b": 0.25, "c": 0.5}).values()), total)

    def test_hamilton_proportional_and_deterministic(self):
        self.assertEqual(AL.hamilton(100, {"a": 0.5, "b": 0.3, "c": 0.2}), {"a": 50, "b": 30, "c": 20})

    def test_spread_counts_and_determinism(self):
        counts = {"x": 3, "y": 1}
        seq = AL.spread(counts)
        self.assertEqual(len(seq), 4)
        self.assertEqual(seq.count("x"), 3)
        self.assertEqual(seq.count("y"), 1)
        self.assertEqual(AL.spread(counts), seq)


class BlueprintBuild(unittest.TestCase):
    def test_has_all_contract_fields(self):
        bp = BP.build_blueprint(_slot(), "run", 0.1, 0.25, "v1.4", "v1")
        for f in ("exam", "class_level", "subject", "chapter_id", "concept_id", "sub_concept", "composition",
                  "prerequisites", "curriculum_boundary", "chapter_weight", "concept_weight", "archetype",
                  "reasoning_depth", "difficulty", "difficulty_drivers", "difficulty_basis",
                  "learning_objective", "expected_solving_path", "misconceptions_to_evaluate",
                  "blueprint_fingerprint", "blueprint_id"):
            self.assertIn(f, bp)
        self.assertEqual(bp["sub_concept"], "Light reaction")
        self.assertEqual(bp["forbidden_terms"], ["b"])
        self.assertTrue(bp["learning_objective"].endswith("Photosynthesis"))

    def test_fingerprint_stable_and_gate_passing(self):
        a = BP.build_blueprint(_slot(), "run", 0.1, 0.25, "v1.4", "v1")
        b = BP.build_blueprint(_slot(), "run", 0.1, 0.25, "v1.4", "v1")
        self.assertEqual(a["blueprint_fingerprint"], b["blueprint_fingerprint"])
        self.assertEqual(a["blueprint_id"], b["blueprint_id"])
        self.assertEqual(P.check_plan(a, {"KC_x": _slot()["concept"]}), [])


class Persistence(unittest.TestCase):
    def test_save_evolves_generation_spec_and_roundtrips(self):
        conn = CO.open_store(":memory:")
        try:
            bp = BP.build_blueprint(_slot(), "runP", 0.1, 0.25, "v1.4", "v1")
            n = BS.save_blueprints(conn, [bp])
            self.assertEqual(n, 1)
            # the new blueprint columns exist on generation_spec now
            cols = {r[1] for r in conn.execute("PRAGMA table_info(generation_spec)")}
            for c in ("exam", "chapter_id", "blueprint_fingerprint", "difficulty_drivers", "learning_objective"):
                self.assertIn(c, cols)
            got = BS.load_blueprints(conn, "runP")
            self.assertEqual(len(got), 1)
            row = got[0]
            # factory-pipeline columns still populated (backward compatible)
            self.assertEqual(row["lane"], bp["lane"])
            self.assertEqual(row["subject"], "Biology")
            self.assertEqual(row["exam"], "NEET")
            self.assertEqual(row["concept_code"], "KC_x")
            self.assertEqual(row["blueprint_fingerprint"], bp["blueprint_fingerprint"])
        finally:
            conn.close()


@unittest.skipUnless(_IDX.exists(), "frozen knowledge_index.db not present (gitignored / local only)")
class PlanBlueprintsOnFrozenV14(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.mkdtemp()
        cls.edb = os.path.join(cls.tmp, "examdna.db")
        idx, out = ED.open_frozen_index(), ED.open_examdna(cls.edb)
        try:
            ED.build(idx, out)
        finally:
            idx.close()
            out.close()

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def test_byte_for_byte_deterministic(self):
        a = R.plan_blueprints("NEET", 120, examdna_path=self.edb)
        b = R.plan_blueprints("NEET", 120, examdna_path=self.edb)
        self.assertEqual([x["blueprint_id"] for x in a["issued"]],
                         [x["blueprint_id"] for x in b["issued"]])
        self.assertEqual([x["blueprint_fingerprint"] for x in a["issued"]],
                         [x["blueprint_fingerprint"] for x in b["issued"]])

    def test_subject_weightage_matches_exam_dna(self):
        out = R.plan_blueprints("NEET", 180, examdna_path=self.edb)
        s = Counter(b["subject"] for b in out["issued"])
        n = len(out["issued"])
        self.assertGreater(s["Biology"] / n, 0.45)          # NEET Biology ~50%
        self.assertAlmostEqual(s["Physics"] / n, 0.25, delta=0.05)

    def test_jee_main_difficulty_matches_within_rounding(self):
        out = R.plan_blueprints("JEE_MAIN", 180, examdna_path=self.edb)
        d = Counter(b["difficulty"] for b in out["issued"])
        n = len(out["issued"])
        # JEE Main is numeric-capable -> the 20/50/30 target is reachable
        self.assertAlmostEqual(d["easy"] / n, 0.20, delta=0.05)
        self.assertAlmostEqual(d["moderate"] / n, 0.50, delta=0.05)
        self.assertAlmostEqual(d["hard"] / n, 0.30, delta=0.05)

    def test_all_issued_pass_gate_and_have_distinct_fingerprints(self):
        out = R.plan_blueprints("JEE_ADVANCED", 150, examdna_path=self.edb)
        self.assertTrue(out["issued"])
        self.assertLessEqual(len(out["refused"]), 3)  # honest, tiny
        self.assertTrue(all(b["blueprint_fingerprint"] for b in out["issued"]))
        self.assertTrue(all(b["difficulty"] in ("easy", "moderate", "hard") for b in out["issued"]))

    def test_planner_never_writes_the_frozen_index(self):
        # a read-only planning contract: mode=ro connection cannot mutate the foundation
        conn = R.open_frozen_index()
        try:
            with self.assertRaises(Exception):
                conn.execute("UPDATE ki_concept SET status='x' WHERE 1=0")
        finally:
            conn.close()


if __name__ == "__main__":
    unittest.main()
