"""Phase 1 tests — certified-only planner: enriched specs, the frozen-v1.4 driver, retired kie.db path.

Phase 1 repoints planning EXCLUSIVELY onto the frozen v1.4 certified index and removes the old kie.db
planning path (factory/manifest.py + factory/trust.py). These verify the NEW behaviour.
"""
from __future__ import annotations

import importlib
import unittest

from kie import config
from kie.qie.knowledge import plan_specs as PS
from kie.qie.knowledge import planner as P
from kie.qie.knowledge import run_planner as R

_IDX = config.KIE_HOME / "knowledge_index.db"
_ENRICHED = ("sub_concepts", "prerequisites", "curriculum_boundary", "chapter_title")


class EnrichedSpec(unittest.TestCase):
    def _uni(self):
        return [
            {"concept_id": f"KC_{i}", "canonical_name": f"Concept {i}", "subject": "Mathematics",
             "taught_at_class": 8, "chapter_id": "CH_MAT_8_01", "chapter_title": "Rational Numbers",
             "sub_concepts": ["s1"], "prerequisites": ["p1"],
             "boundary": {"in_scope": ["x"], "out_of_scope": ["y"]}}
            for i in range(6)
        ]

    def test_issued_specs_carry_certified_curriculum_context(self):
        out = PS.build_specs(self._uni(), [], "runE", n=12, seed=5, subject="Mathematics")
        self.assertTrue(out["issued"])
        for s in out["issued"]:
            for k in _ENRICHED:
                self.assertIn(k, s, f"enriched field {k!r} missing from issued spec")
            # rich fields come straight from the certified record, not synthesized
            self.assertEqual(s["sub_concepts"], ["s1"])
            self.assertEqual(s["prerequisites"], ["p1"])
            self.assertEqual(s["curriculum_boundary"], {"in_scope": ["x"], "out_of_scope": ["y"]})


class KieDbPlanningPathRetired(unittest.TestCase):
    def test_kie_db_planner_modules_are_gone(self):
        with self.assertRaises(ModuleNotFoundError):
            importlib.import_module("kie.qie.factory.manifest")
        with self.assertRaises(ModuleNotFoundError):
            importlib.import_module("kie.qie.factory.trust")

    def test_driver_targets_the_frozen_index(self):
        self.assertEqual(R.INDEX_DB_PATH, _IDX)
        self.assertEqual(R.INDEX_DB_PATH.name, "knowledge_index.db")


@unittest.skipUnless(_IDX.exists(), "frozen knowledge_index.db not present (gitignored / local only)")
class PlannerDriverOnFrozenV14(unittest.TestCase):
    def test_plan_physics_11_12_issues_gate_passing_enriched_specs(self):
        conn = R.open_frozen_index()
        try:
            uni = P.certified_universe(conn, "Physics", [11, 12])
        finally:
            conn.close()
        by_id = {c["concept_id"]: c for c in uni}

        out = R.plan("Physics", "t1", classes=[11, 12], n=30, seed=20260716)
        issued = out["issued"]
        self.assertTrue(issued)
        for s in issued:
            self.assertEqual(P.check_plan(s, by_id), [], f"issued spec failed the gate: {s['spec_id']}")
            for k in _ENRICHED:
                self.assertIn(k, s)
            self.assertIn(s["class_level"], (11, 12))
            self.assertEqual(s["subject"], "Physics")

    def test_plan_is_reproducible(self):
        a = R.plan("Chemistry", "t2", classes=[11, 12], n=25, seed=99)
        b = R.plan("Chemistry", "t2", classes=[11, 12], n=25, seed=99)
        self.assertEqual([s["spec_id"] for s in a["issued"]], [s["spec_id"] for s in b["issued"]])


if __name__ == "__main__":
    unittest.main()
