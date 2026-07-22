"""Program B · B1 — corpus role classification.

Hermetic unit tests (always run) on the PURE classify()/taxonomy: fail-closed folder trust (defect D5),
path/content conflict → honest-null, practice/mock never DNA-eligible, provenance recovery from the full path.
Plus the adversarial controls. Plus live-corpus + freeze-safety tests that self-skip when the gitignored DBs
are absent (the run_kie_suite canonical guard fails loudly if they skip on the canonical machine).
"""
from __future__ import annotations

import hashlib
import json
import os
import sqlite3
import tempfile
import unittest

from kie import config
from kie.qie.pyq import controls as CT
from kie.qie.pyq import source_class as SC
from kie.qie.pyq import taxonomy as TX

_KIE_DB = config.DB_PATH
_IDX_DB = config.KIE_HOME / "knowledge_index.db"


def _row(**kw) -> dict:
    base = {"doc_id": "d", "rel_path": "", "category": None, "subject": None, "doc_type": None, "year": None}
    base.update(kw)
    return base


def _md5(path) -> str:
    return hashlib.md5(path.read_bytes()).hexdigest()


class TestTaxonomy(unittest.TestCase):
    def test_jee_requires_qualifier(self):
        self.assertEqual(TX.canonical_exam("JEE_Advanced"), "JEE_ADVANCED")
        self.assertEqual(TX.canonical_exam("jeeadv_ac_in_archive"), "JEE_ADVANCED")
        self.assertEqual(TX.canonical_exam("JEE Main"), "JEE_MAIN")
        self.assertIsNone(TX.canonical_exam("JEE"), "a bare unqualified JEE is ambiguous → honest-null")

    def test_dump_folder_is_never_an_exam(self):
        self.assertIsNone(TX.canonical_exam("Cursor_Downloads"))
        self.assertIsNone(TX.canonical_exam("Practice_Resources"))
        self.assertIsNone(TX.canonical_exam(""))

    def test_neet_and_lineage_tokens(self):
        self.assertEqual(TX.canonical_exam("NEET"), "NEET")
        self.assertEqual(TX.canonical_exam("AIPMT"), "AIPMT")
        self.assertEqual(TX.EXAM_FAMILY["AIPMT"], "NEET")   # lineage recorded, never collapsed on exam_resolved

    def test_subject_normalization(self):
        self.assertEqual(TX.canonical_subject("Maths"), "Mathematics")
        self.assertEqual(TX.canonical_subject("Botany"), "Biology")
        self.assertIsNone(TX.canonical_subject("General Knowledge"))

    def test_year_ambiguous_is_honest_null(self):
        self.assertEqual(TX.parse_year("JEE_Advanced_2010_Paper1"), 2010)
        self.assertIsNone(TX.parse_year("mix_2010_and_2011"), "two years in one blob → honest-null")
        self.assertIsNone(TX.parse_year("no_year_here"))


class TestClassifyFailClosed(unittest.TestCase):
    def test_dump_folder_never_assigns_exam(self):
        r = SC.classify(_row(rel_path="Cursor_Downloads/paper.pdf", category="Cursor_Downloads",
                             doc_type="previous_paper"), "")
        self.assertIsNone(r["exam_resolved"], "the D5 defect: a top dump folder must never become an exam")
        self.assertEqual(r["eligible_for_dna"], 0)

    def test_path_content_conflict_holds(self):
        r = SC.classify(_row(rel_path="Cursor_Downloads/a/JEE_Advanced/Previous_Papers/2010/JEE_Advanced_2010.pdf",
                             doc_type="previous_paper"),
                        "National Eligibility cum Entrance Test NEET booklet")
        self.assertIsNone(r["exam_resolved"])
        self.assertEqual(r["exam_method"], "ambiguous")

    def test_official_provenance_recovered_from_full_path(self):
        r = SC.classify(_row(rel_path="Cursor_Downloads/jeeadv_ac_in_archive/JEE_Advanced/Previous_Papers/2010/"
                                      "JEE_Advanced_2010_Paper1.pdf", category="Cursor_Downloads",
                             doc_type="previous_paper"), "")
        self.assertEqual(r["exam_resolved"], "JEE_ADVANCED")
        self.assertEqual(r["source_authority"], "official")
        self.assertEqual(r["year_resolved"], 2010)
        self.assertEqual(r["eligible_for_dna"], 1)

    def test_practice_and_mock_never_eligible(self):
        dpp = SC.classify(_row(rel_path="Cursor_Downloads/studentbro_neet_dpps/NEET/Bio/dpp.pdf", doc_type="dpp"), "")
        self.assertEqual(dpp["source_role"], "practice_dpp")
        self.assertEqual(dpp["eligible_for_dna"], 0)
        mock = SC.classify(_row(rel_path="Cursor_Downloads/allen_jee_main_mock/JEE_Main/m.pdf",
                                doc_type="mock_test"), "")
        self.assertEqual(mock["source_role"], "mock")
        self.assertEqual(mock["eligible_for_dna"], 0)

    def test_genuine_pyq_full_paper_defers_subject(self):
        r = SC.classify(_row(rel_path="NEET/Previous_Papers/2016/NEET_2016.pdf", category="NEET",
                             doc_type="previous_paper", year=2016), "")
        self.assertEqual(r["source_role"], "genuine_pyq")
        self.assertIsNone(r["subject_hint"], "a full exam paper is multi-subject → subject resolved per-question")
        self.assertEqual(r["subject_method"], "multi_subject_defer")


class TestAdversarialControls(unittest.TestCase):
    def test_all_controls_pass(self):
        summary = CT.check_controls()
        self.assertEqual(summary["controls_passed"], 15)


@unittest.skipUnless(_KIE_DB.exists(), "kie.db not present (gitignored, local only)")
class TestLiveCorpus(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.pyq = os.path.join(cls.tmp.name, "pyq_corpus.db")
        cls.md5_before = (_md5(_KIE_DB), _md5(_IDX_DB) if _IDX_DB.exists() else None)
        cls.summary = SC.build(pyq_db_path=cls.pyq)
        cls.md5_after = (_md5(_KIE_DB), _md5(_IDX_DB) if _IDX_DB.exists() else None)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def _q(self, sql, args=()):
        c = sqlite3.connect(f"file:{self.pyq}?mode=ro", uri=True)
        try:
            return c.execute(sql, args).fetchall()
        finally:
            c.close()

    def test_frozen_substrate_byte_identical(self):
        self.assertEqual(self.md5_before, self.md5_after,
                         "B1 must never mutate the frozen kie.db / knowledge_index.db")

    def test_d5_regression_no_exam_from_folder_alone(self):
        n = self._q("SELECT COUNT(*) FROM pyq_source_class WHERE exam_resolved IS NOT NULL "
                    "AND json_extract(signals,'$.path_exams')='[]' "
                    "AND json_extract(signals,'$.category_token_exam') IS NULL "
                    "AND json_extract(signals,'$.content_exams')='[]'")[0][0]
        self.assertEqual(n, 0, "no document may receive an exam with zero path/category/content exam signal")

    def test_no_practice_leaks_into_genuine_pyq(self):
        n = self._q("SELECT COUNT(*) FROM pyq_source_class WHERE source_role='genuine_pyq' "
                    "AND (rel_path LIKE '%dpp%' OR rel_path LIKE '%_mock%' OR rel_path LIKE '%chapterwise%')")[0][0]
        self.assertEqual(n, 0)

    def test_no_pure_solution_or_answer_key_is_eligible(self):
        # regression for the adversarial-verifier P0: a pure answer key / solution PDF must never feed exam DNA
        n = self._q("SELECT COUNT(*) FROM pyq_source_class WHERE eligible_for_dna=1 "
                    "AND json_extract(signals,'$.solution_key_path')=1")[0][0]
        self.assertEqual(n, 0, "a solution/answer-key document must never be DNA-eligible")

    def test_eligible_requires_content_chunks(self):
        n = self._q("SELECT COUNT(*) FROM pyq_source_class WHERE eligible_for_dna=1 "
                    "AND json_extract(signals,'$.has_content_chunks')=0")[0][0]
        self.assertEqual(n, 0, "a doc with no minable content chunks can never be DNA-eligible")

    def test_paper_with_solutions_kept_eligible(self):
        # the keeper direction: papers that CARRY answers/solutions still have real questions
        n = self._q("SELECT COUNT(*) FROM pyq_source_class WHERE eligible_for_dna=1 "
                    "AND (rel_path LIKE '%qs_ans%' OR rel_path LIKE '%with_Sol%')")[0][0]
        self.assertGreaterEqual(n, 5, "question+answer papers (real questions) must remain eligible")

    def test_eligibility_requires_genuine_pyq_and_exam(self):
        bad = self._q("SELECT COUNT(*) FROM pyq_source_class WHERE eligible_for_dna=1 "
                      "AND (source_role<>'genuine_pyq' OR exam_resolved IS NULL)")[0][0]
        self.assertEqual(bad, 0, "eligible_for_dna must imply genuine_pyq AND a resolved exam")

    def test_all_three_planned_exams_have_eligible_pyq(self):
        rows = self._q("SELECT exam_resolved, COUNT(*) FROM pyq_source_class WHERE eligible_for_dna=1 "
                       "GROUP BY exam_resolved")
        by = {e: n for e, n in rows}
        for exam in ("NEET", "JEE_MAIN", "JEE_ADVANCED"):
            self.assertGreaterEqual(by.get(exam, 0), 30,
                                    f"{exam} should clear the OD-5 N>=30 floor at the exam level")

    def test_determinism(self):
        with tempfile.TemporaryDirectory() as t:
            s2 = SC.build(pyq_db_path=os.path.join(t, "p.db"))
        self.assertEqual(self.summary["stats"], s2["stats"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
