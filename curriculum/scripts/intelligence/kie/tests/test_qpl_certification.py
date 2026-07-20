"""QPL CERTIFICATION suite (Phase 5) — the deterministic evidence that the Question Planning Layer meets its
contract. Every claim is proven by a deterministic check, never by model agreement.

Certifies: (1) all adversarial control floors hold; (2) the planner is byte-for-byte deterministic for all
three exams; (3) every issued blueprint passes the pre-generation gate and carries a complete, provenanced
contract; (4) the plan matches the Exam-DNA distributions where reachable and reports honest shortfalls where
not; (5) the frozen foundation is read-only; (6) no fabricated design DNA.
"""
from __future__ import annotations

import os
import shutil
import tempfile
import unittest
from collections import Counter

from kie import config
from kie.qie.knowledge import examdna as ED
from kie.qie.knowledge import examdna_controls as EC
from kie.qie.knowledge import plan_controls as PC
from kie.qie.knowledge import planner as P
from kie.qie.knowledge import qdi as QDI
from kie.qie.knowledge import qdi_controls as QC
from kie.qie.knowledge import run_planner as R

_IDX = config.KIE_HOME / "knowledge_index.db"
_EXAMS = ("NEET", "JEE_MAIN", "JEE_ADVANCED")
_CONTRACT_FIELDS = ("exam", "class_level", "subject", "chapter_id", "chapter_title", "concept_id",
                    "concept_name", "sub_concept", "composition", "prerequisites", "curriculum_boundary",
                    "chapter_weight", "concept_weight", "archetype", "lane", "question_type",
                    "reasoning_depth", "difficulty", "difficulty_drivers", "difficulty_basis",
                    "learning_objective", "expected_solving_path", "misconceptions_to_evaluate",
                    "pattern_id", "blueprint_fingerprint", "blueprint_id", "planner_evidence", "status")


class ControlFloorsHold(unittest.TestCase):
    """Every adversarial control suite across the QPL must pass (a gate that can't fail a known-bad is no gate)."""

    def test_plan_controls(self):
        self.assertTrue(PC.check_plan_controls()["all_caught"])

    def test_qdi_controls(self):
        self.assertTrue(QC.check_all()["all_ok"])


class GateHardening(unittest.TestCase):
    """Regression locks for the fail-open holes / false-positives found in Phase-5 adversarial verification."""

    _UNI = {
        "KC_good": {"concept_id": "KC_good", "canonical_name": "Properties of Rational Numbers",
                    "subject": "Mathematics", "taught_at_class": 8, "chapter_id": "CH_MAT_8_01"},
        "KC_phys": {"concept_id": "KC_phys", "canonical_name": "Gauss's law", "subject": "Physics",
                    "taught_at_class": 12, "chapter_id": "CH_PHY_12_01"},
    }

    def _base(self, **o):
        base = {"concept_id": "KC_good", "concept_name": "Properties of Rational Numbers",
                "subject": "Mathematics", "class_level": 8, "chapter_id": "CH_MAT_8_01",
                "archetype": "property_application", "intended_depth": 2, "composition": "single",
                "compose_with": []}
        base.update(o)
        return base

    def test_good_plan_still_passes(self):
        self.assertEqual(P.check_plan(self._base(), self._UNI), [])

    def test_hole_a_unknown_composition_does_not_fail_open(self):
        # an unknown composition token must not smuggle a cross-subject partner past partner validation
        v = P.check_plan(self._base(composition="dual", compose_with=["KC_phys"]), self._UNI)
        self.assertTrue(any("unsupported_composition" in x for x in v))

    def test_hole_b_name_id_consistency(self):
        v = P.check_plan(self._base(concept_name="Newton's Law of Gravitation"), self._UNI)
        self.assertTrue(any("name_mismatch" in x for x in v))

    def test_hole_c_blank_chapter_is_a_violation(self):
        self.assertTrue(any("chapter_missing" in x for x in P.check_plan(self._base(chapter_id=""), self._UNI)))

    def test_ocr_filter_no_longer_refuses_certified_concepts(self):
        for legit in ("Cell Membrane (Plasma Membrane)", "Gametogenesis (Spermatogenesis)",
                      "Multiples and Common Multiples", "Elasticity and Plasticity"):
            self.assertFalse(P.is_ocr_garbage(legit), f"false-refused {legit!r}")
        for garbage in ("Telateltelt", "Scescescececert", "answeranswer"):
            self.assertTrue(P.is_ocr_garbage(garbage), f"missed garbage {garbage!r}")

    def test_anti_copying_catches_heavy_paraphrase(self):
        src = ("A particle moves with speed v at angle theta to the axis find the acceleration produced by "
               "the constant net force")
        para = ("particle XX moves with XX speed v XX at angle XX theta to XX the axis XX find the XX "
                "acceleration produced XX by the XX constant net force")
        self.assertIsNotNone(QDI.assert_no_copying({"design_summary": para}, src))
        abstract = {"design_summary": ("An observable is named against a symbolic baseline so the unknown "
                                       "scale must be eliminated by ratio before the residual is solved.")}
        self.assertIsNone(QDI.assert_no_copying(abstract, src))


@unittest.skipUnless(_IDX.exists(), "frozen knowledge_index.db not present (gitignored / local only)")
class EndToEndCertification(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.mkdtemp()
        cls.edb = os.path.join(cls.tmp, "examdna.db")
        cls.qdi_none = os.path.join(cls.tmp, "none.db")  # nonexistent -> honest-null design DNA, isolated
        idx, out = ED.open_frozen_index(), ED.open_examdna(cls.edb)
        try:
            ED.build(idx, out)
        finally:
            idx.close()
            out.close()

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def test_examdna_controls_hold_on_frozen_index(self):
        idx = ED.open_frozen_index()
        try:
            self.assertTrue(EC.check_all(idx)["all_ok"])
        finally:
            idx.close()

    def test_deterministic_for_all_exams(self):
        for exam in _EXAMS:
            a = R.plan_blueprints(exam, 180, examdna_path=self.edb)
            b = R.plan_blueprints(exam, 180, examdna_path=self.edb)
            self.assertEqual([x["blueprint_id"] for x in a["issued"]],
                             [x["blueprint_id"] for x in b["issued"]], f"{exam} not deterministic")

    def test_every_blueprint_passes_gate_and_has_full_contract(self):
        for exam in _EXAMS:
            out = R.plan_blueprints(exam, 180, examdna_path=self.edb)
            self.assertTrue(out["issued"])
            # rebuild the certified universe to re-validate independently of the planner
            conn = R.open_frozen_index()
            try:
                by_id = {}
                for subject in ED.EXAM_SUBJECTS[exam]:
                    for c in P.certified_universe(conn, subject, [11, 12]):
                        by_id[c["concept_id"]] = c
            finally:
                conn.close()
            for b in out["issued"]:
                self.assertEqual(P.check_plan(b, by_id), [], f"{exam}: blueprint failed the gate")
                for f in _CONTRACT_FIELDS:
                    self.assertIn(f, b, f"{exam}: blueprint missing contract field {f!r}")
                # provenance completeness: every blueprint traces to certified sources + versions
                ev = b["planner_evidence"]
                self.assertTrue(ev.get("foundation_version"))
                self.assertTrue(ev.get("examdna_version"))
                self.assertTrue(b["blueprint_fingerprint"])
                self.assertIn(b["difficulty"], ("easy", "moderate", "hard"))
                # difficulty is DRIVER-derived (Decision 1), not stamped
                self.assertEqual(set(b["difficulty_drivers"]),
                                 {"reasoning_depth", "concept_count", "misconception_pressure",
                                  "calculation_load"})

    def test_no_fabricated_design_dna(self):
        # with NO certified QDI store, design DNA must be honest-null everywhere, never invented
        for exam in _EXAMS:
            out = R.plan_blueprints(exam, 120, examdna_path=self.edb, qdi_path=self.qdi_none)
            for b in out["issued"]:
                self.assertIsNone(b["pattern_id"])
                self.assertIsNone(b["expected_solving_path"])
                self.assertEqual(b["misconceptions_to_evaluate"], [])

    def test_distributions_match_or_report_honest_shortfall(self):
        idx = ED.open_examdna(self.edb)
        try:
            for exam in _EXAMS:
                out = R.plan_blueprints(exam, 180, examdna_path=self.edb)
                iss = out["issued"]
                n = len(iss)
                # subject weightage matches Exam DNA within rounding
                target_sw = ED.subject_weights(idx, exam)
                got_sw = Counter(b["subject"] for b in iss)
                for subj, w in target_sw.items():
                    self.assertAlmostEqual(got_sw.get(subj, 0) / n, w, delta=0.06,
                                           msg=f"{exam}/{subj} subject weightage off")
                # difficulty: numeric-capable exams match; NEET may report an honest hard shortfall (never faked)
                got_diff = Counter(b["difficulty"] for b in iss)
                tgt_diff = ED.distribution(idx, exam, "difficulty")
                if exam in ("JEE_MAIN", "JEE_ADVANCED"):
                    for band, p in tgt_diff.items():
                        self.assertAlmostEqual(got_diff.get(band, 0) / n, p, delta=0.06,
                                               msg=f"{exam}/{band} difficulty off")
                else:
                    # NEET: realized hard must never EXCEED target (a shortfall is honest; an overshoot = faking)
                    self.assertLessEqual(got_diff.get("hard", 0) / n, tgt_diff["hard"] + 1e-9)
                    self.assertGreaterEqual(out["difficulty_shortfall"], 0)
        finally:
            idx.close()

    def test_no_degenerate_duplicate_blueprints(self):
        # even at high N (chapters run out of distinct combos), issued blueprints are all distinct by
        # fingerprint; recycles are dropped and reported honestly, never salted through as distinct items.
        for exam in _EXAMS:
            out = R.plan_blueprints(exam, 600, examdna_path=self.edb)
            fps = [b["blueprint_fingerprint"] for b in out["issued"]]
            self.assertEqual(len(fps), len(set(fps)), f"{exam}: issued blueprints are not all distinct")
            self.assertEqual(len(out["issued"]), out["distinct_fingerprints"])
            self.assertGreaterEqual(out["duplicate_dropped"], 0)

    def test_frozen_foundation_is_read_only(self):
        conn = R.open_frozen_index()
        try:
            with self.assertRaises(Exception):
                conn.execute("UPDATE ki_concept SET status='x' WHERE 1=0")
        finally:
            conn.close()


if __name__ == "__main__":
    unittest.main()
