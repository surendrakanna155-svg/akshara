"""Program B · B6 — Exam DNA v2 consumer contract (integration).

The contract: every cell a consumer reads carries its `provenance_class`; an insufficient_evidence cell has no
probability (honest-null); and any "exam-representative" claim is FAIL-CLOSED on v2 — allowed only where the
dimension is genuinely `pyq_measured`. Live tests self-skip when the gitignored DBs are absent.
"""
from __future__ import annotations

import os
import sqlite3
import tempfile
import unittest

from kie import config
from kie.qie.pyq import dna_access as DA
from kie.qie.pyq import dna_v2 as D2
from kie.qie.pyq import difficulty as DF
from kie.qie.pyq import marking as MK
from kie.qie.pyq import mining as MI
from kie.qie.pyq import source_class as SC
from kie.qie.pyq import subject_seg as SS

_KIE_DB = config.DB_PATH


@unittest.skipUnless(_KIE_DB.exists(), "kie.db not present (gitignored, local only)")
class TestExamDnaContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.pyq = os.path.join(cls.tmp.name, "pyq_corpus.db")
        for step in (SC.build, SS.build, MI.build, DF.build, MK.build, D2.build):
            step(pyq_db_path=cls.pyq)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_every_cell_surfaces_provenance(self):
        for exam in ("NEET", "JEE_MAIN", "JEE_ADVANCED"):
            for cell in DA.exam_dna(exam, pyq_db_path=self.pyq):
                self.assertIn(cell["provenance_class"],
                              {"pyq_measured", "structural_proxy", "published", "insufficient_evidence"})
                if cell["provenance_class"] == "insufficient_evidence":
                    self.assertIsNone(cell["probability"], "insufficient_evidence must be honest-null")

    def test_no_exam_is_representative_on_this_corpus(self):
        # the honest truth: no exam has ≥30 INDEPENDENT sittings, so EVERY exam-representative claim is refused
        # fail-closed (the gate never lets an under-evidenced claim through).
        for exam in ("NEET", "JEE_MAIN", "JEE_ADVANCED"):
            self.assertFalse(DA.is_exam_representative(exam, "question_type", pyq_db_path=self.pyq))
            with self.assertRaises(DA.ExamDnaV2InsufficientEvidence):
                DA.assert_exam_representative(exam, "question_type", pyq_db_path=self.pyq)

    def test_published_and_structural_are_not_exam_representative(self):
        # subject_weight is published (mandated, not a per-corpus measurement) — never backs a representative claim
        self.assertFalse(DA.is_exam_representative("NEET", "subject_weight", pyq_db_path=self.pyq))
        self.assertFalse(DA.is_exam_representative("NEET", "structural_difficulty", pyq_db_path=self.pyq))

    def test_coverage_map(self):
        cov = DA.coverage(pyq_db_path=self.pyq)
        self.assertEqual(cov["NEET"]["question_type"], "insufficient_evidence")
        self.assertEqual(cov["JEE_MAIN"]["question_type"], "insufficient_evidence")
        self.assertEqual(cov["NEET"]["subject_weight"], "published")


if __name__ == "__main__":
    unittest.main(verbosity=2)
