"""Phase 4 tests — QDI deterministic floor: anti-copying, structural, scope-link controls; and the
deterministic certified-pattern attachment (with honest nulls when no certified pattern matches)."""
from __future__ import annotations

import unittest

from kie import config
from kie.qie.knowledge import qdi as QDI
from kie.qie.knowledge import qdi_controls as QC
from kie.qie.knowledge import qdi_link as QL
from kie.qie.knowledge import run_planner as R

_IDX = config.KIE_HOME / "knowledge_index.db"


class QdiControlFloor(unittest.TestCase):
    def test_all_controls_hold(self):
        self.assertTrue(QC.check_all()["all_ok"])

    def test_anti_copying_rejects_echo_accepts_abstract(self):
        src = ("A particle moves with speed v at angle theta to the axis. Find the acceleration produced by "
               "the constant net force acting along the field.")
        self.assertIsNotNone(QDI.assert_no_copying({"design_summary": src}, src))
        abstract = {"design_summary": ("An observable is named against a symbolic baseline so the unknown "
                                       "scale must be eliminated by ratio before the residual is solved.")}
        self.assertIsNone(QDI.assert_no_copying(abstract, src))


class ScopeLinking(unittest.TestCase):
    def test_scope_link_maps_exam_to_profile(self):
        self.assertEqual(QL.scope_link_for({"pattern_id": "P", "exam": "JEE_Main"})["exam_profile"], "JEE_MAIN")
        self.assertEqual(QL.scope_link_for({"pattern_id": "P", "exam": "AIIMS"})["exam_profile"], "NEET")
        self.assertEqual(QL.scope_link_for({"pattern_id": "P", "exam": "JEE_Advanced"})["exam_profile"],
                         "JEE_ADVANCED")

    def test_validate_scope_link(self):
        self.assertIsNone(QL.validate_scope_link(
            {"pattern_id": "P", "subject": "Physics", "min_class": 11, "exam_profile": "NEET"}))
        for bad in ({"pattern_id": "P", "min_class": 11, "exam_profile": "NOPE"},
                    {"pattern_id": "P", "min_class": 99, "exam_profile": "NEET"},
                    {"pattern_id": "", "min_class": 11, "exam_profile": "NEET"}):
            self.assertIsNotNone(QL.validate_scope_link(bad))


class PatternAttachment(unittest.TestCase):
    def _pat(self):
        return {"pattern_id": "QDP_a", "subject": "Physics", "archetype": "multi_step_numerical",
                "difficulty_band": "hard", "solution_structure": ["set up F=ma", "chain to kinematics"],
                "misconceptions": ["drops the sign"]}

    def _bp(self, **over):
        base = {"subject": "Physics", "archetype": "multi_step_numerical", "difficulty": "hard",
                "pattern_id": None, "expected_solving_path": None, "misconceptions_to_evaluate": [],
                "planner_evidence": {}}
        base.update(over)
        return base

    def test_match_attaches_certified_design_dna(self):
        idx = QL.index_by_key([self._pat()])
        bp = QL.attach_pattern(self._bp(), idx)
        self.assertEqual(bp["pattern_id"], "QDP_a")
        self.assertEqual(bp["expected_solving_path"], ["set up F=ma", "chain to kinematics"])
        self.assertEqual(bp["misconceptions_to_evaluate"], ["drops the sign"])

    def test_no_match_keeps_honest_nulls(self):
        idx = QL.index_by_key([self._pat()])
        bp = QL.attach_pattern(self._bp(difficulty="easy"), idx)
        self.assertIsNone(bp["pattern_id"])
        self.assertIsNone(bp["expected_solving_path"])
        self.assertEqual(bp["misconceptions_to_evaluate"], [])

    def test_attachment_is_deterministic_by_pattern_id(self):
        p1 = dict(self._pat(), pattern_id="QDP_b")
        p2 = dict(self._pat(), pattern_id="QDP_a")
        idx = QL.index_by_key([p1, p2])
        self.assertEqual(QL.attach_pattern(self._bp(), idx)["pattern_id"], "QDP_a")  # first by id


@unittest.skipUnless(_IDX.exists(), "frozen knowledge_index.db not present (gitignored / local only)")
class AttachmentThroughPlanner(unittest.TestCase):
    def test_blueprints_carry_honest_null_design_dna_until_qdi_certified(self):
        # 0 certified QDI patterns today -> every blueprint carries null design DNA, never fabricated
        out = R.plan_blueprints("JEE_MAIN", 60)
        self.assertTrue(out["issued"])
        for b in out["issued"]:
            self.assertIsNone(b["pattern_id"])
            self.assertIsNone(b["expected_solving_path"])
            self.assertEqual(b["misconceptions_to_evaluate"], [])


if __name__ == "__main__":
    unittest.main()
