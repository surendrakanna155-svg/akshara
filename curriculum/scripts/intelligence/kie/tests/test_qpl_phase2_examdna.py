"""Phase 2 tests — Exam DNA (v1): validators, curated build, provenance honesty, adversarial controls."""
from __future__ import annotations

import sqlite3
import unittest

from kie import config
from kie.qie.knowledge import examdna as ED
from kie.qie.knowledge import examdna_controls as EC

_IDX = config.KIE_HOME / "knowledge_index.db"


def _tiny_index() -> sqlite3.Connection:
    """A minimal in-memory stand-in for the frozen index (no dependency on local data)."""
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    conn.executescript(
        "CREATE TABLE ki_chapter(chapter_id TEXT PRIMARY KEY, subject TEXT, taught_at_class INT,"
        " chapter_no INT, title TEXT, status TEXT);"
        "CREATE TABLE ki_concept(concept_id TEXT PRIMARY KEY, chapter_id TEXT, subject TEXT,"
        " taught_at_class INT, status TEXT);")
    chapters = [("CH_P1", "Physics", 11, "Kinematics"), ("CH_P2", "Physics", 12, "Optics"),
                ("CH_C1", "Chemistry", 11, "Thermodynamics"), ("CH_B1", "Biology", 12, "Genetics"),
                ("CH_M1", "Mathematics", 11, "Calculus")]
    for cid, subj, cls, title in chapters:
        conn.execute("INSERT INTO ki_chapter VALUES(?,?,?,1,?, 'accepted')", (cid, subj, cls, title))
    counts = {"CH_P1": ("Physics", 11, 3), "CH_P2": ("Physics", 12, 1), "CH_C1": ("Chemistry", 11, 2),
              "CH_B1": ("Biology", 12, 4), "CH_M1": ("Mathematics", 11, 2)}
    i = 0
    for cid, (subj, cls, n) in counts.items():
        for _ in range(n):
            conn.execute("INSERT INTO ki_concept VALUES(?,?,?,?, 'certified')", (f"KC_{i}", cid, subj, cls))
            i += 1
    conn.commit()
    return conn


class Validators(unittest.TestCase):
    def test_validate_distribution(self):
        ED.validate_distribution({"a": 0.5, "b": 0.5})
        for bad in ({"a": 0.5, "b": 0.4}, {"a": -0.1, "b": 1.1}, {}):
            with self.assertRaises(ED.ExamDnaError):
                ED.validate_distribution(bad)

    def test_exam_scope(self):
        ED.validate_exam_scope("NEET", "Biology")
        ED.validate_exam_scope("JEE_MAIN", "Mathematics")
        with self.assertRaises(ED.ExamDnaError):
            ED.validate_exam_scope("JEE_MAIN", "Biology")   # JEE assesses no Biology
        with self.assertRaises(ED.ExamDnaError):
            ED.validate_exam_scope("NOT_AN_EXAM", "Physics")

    def test_archetype_distribution_from_profiles(self):
        for exam in ED.EXAMS:
            d = ED.archetype_distribution(exam)
            self.assertAlmostEqual(sum(d.values()), 1.0, places=9)
            self.assertTrue(all(v > 0 for v in d.values()))


class Controls(unittest.TestCase):
    def test_distribution_controls(self):
        r = EC.check_distribution_controls()
        self.assertTrue(r["all_rejected"] and r["good_passes"])

    def test_scope_controls(self):
        r = EC.check_scope_controls({"CH_REAL"}, "CH_REAL")
        self.assertTrue(r["all_rejected"] and r["good_passes"])


class BuildOnTinyIndex(unittest.TestCase):
    def test_build_materializes_valid_normalized_dna(self):
        idx, out = _tiny_index(), ED.open_examdna(":memory:")
        try:
            m = ED.build(idx, out)
            self.assertGreater(m["weights"], 0)
            self.assertGreater(m["distributions"], 0)
            for exam in ED.EXAMS:
                self.assertAlmostEqual(sum(ED.subject_weights(out, exam).values()), 1.0, places=6)
                for dim in ("difficulty", "depth", "archetype"):
                    self.assertAlmostEqual(sum(ED.distribution(out, exam, dim).values()), 1.0, places=6)
                for subj in ED.EXAM_SUBJECTS[exam]:
                    cw = ED.chapter_weight_map(out, exam, subj)
                    self.assertTrue(cw)
                    self.assertAlmostEqual(sum(cw.values()), 1.0, places=6)
            # evidence-proportional: Physics CH_P1 (3 concepts) vs CH_P2 (1) -> 0.75 / 0.25
            cw = ED.chapter_weight_map(out, "JEE_MAIN", "Physics")
            self.assertAlmostEqual(cw["CH_P1"], 0.75, places=6)
            self.assertAlmostEqual(cw["CH_P2"], 0.25, places=6)
        finally:
            idx.close()
            out.close()

    def test_provenance_is_honest(self):
        idx, out = _tiny_index(), ED.open_examdna(":memory:")
        try:
            ED.build(idx, out)
            # nothing in v1 is labelled 'certified' — measurement is reserved for the mining phase
            n_cert = (out.execute("SELECT COUNT(*) FROM exam_weight WHERE status='certified'").fetchone()[0]
                      + out.execute("SELECT COUNT(*) FROM exam_distribution WHERE status='certified'").fetchone()[0])
            self.assertEqual(n_cert, 0)
            # difficulty/depth are curated_prior and openly say "NOT measured"
            pc = {r[0] for r in out.execute(
                "SELECT DISTINCT provenance_class FROM exam_distribution WHERE dimension IN ('difficulty','depth')")}
            self.assertEqual(pc, {"curated_prior"})
            for r in out.execute("SELECT basis FROM exam_distribution WHERE provenance_class='curated_prior'"):
                self.assertIn("NOT measured", r[0])
            # subject weightage is published; chapter weightage is evidence_proportional
            self.assertEqual({r[0] for r in out.execute(
                "SELECT DISTINCT provenance_class FROM exam_weight WHERE scope_type='subject'")}, {"published"})
            self.assertEqual({r[0] for r in out.execute(
                "SELECT DISTINCT provenance_class FROM exam_weight WHERE scope_type='chapter'")},
                {"evidence_proportional"})
        finally:
            idx.close()
            out.close()


@unittest.skipUnless(_IDX.exists(), "frozen knowledge_index.db not present (gitignored / local only)")
class ControlsOnFrozenIndex(unittest.TestCase):
    def test_check_all_holds_on_real_index(self):
        idx = ED.open_frozen_index()
        try:
            self.assertTrue(EC.check_all(idx)["all_ok"])
        finally:
            idx.close()


if __name__ == "__main__":
    unittest.main()
