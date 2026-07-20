"""Root-cause-fix regression tests — source selection + section-subject resolution for COMBINED exam papers.

Locks the fix for the proven defect (JEE-Physics requests resolving to NEET-Biology content):
  * exam_sources matches the EXAM IDENTITY (category/exam), with NO Previous_Papers path-bypass leak;
  * resolve_chunk_subjects propagates in-paper section-subject markers to each chunk (subject is a SECTION
    property of combined papers, not a whole-document tag);
  * candidate_chunks(subject=...) keeps only the resolved subject's chunks and drops boilerplate/mojibake.
Self-contained (synthetic in-memory kie.db shaped like the real defect).
"""
from __future__ import annotations

import sqlite3
import unittest

from kie.qie.knowledge import qdi as QDI

_PHYS = ("Section - A (Physics) 1. A capacitor of capacitance C is connected across an ac source of voltage "
         "V = V0 sin(wt). Find the displacement current between the plates at the given instant. "
         "(1) 2 A (2) 4 A (3) 6 A (4) 8 A  Ans (2)")
_PHYS2 = ("2. A block of mass 3 kg is pushed by a constant net force of 12 N on a smooth frictionless "
          "horizontal surface; determine the magnitude of its acceleration and the total distance covered "
          "in 2 seconds starting from rest under this force. (1) 4 (2) 8 (3) 6 (4) 12  Ans (1)")
_CHEM = ("Section - B (Chemistry) 15. Arrange the following methyl halides in the correct order of their "
         "boiling points and reactivity toward nucleophilic substitution reactions in solution. "
         "(A) F > Cl (B) I > Br  Ans (A)")
_BIO = ("Section (Botany) 45. Which of the following is NOT an objective of the biofortification of crop "
        "plants for improved human nutrition and micronutrient content in staple foods? "
        "(1) protein quantity (2) vitamin content  Ans (1)")
_BOILER = ("Read carefully the following instructions before you begin. Do not open the test booklet until "
           "you are asked to do so. Rough work must be done only in the space provided. Attempt all questions "
           "in the answer sheet as per the OMR instructions given on the cover page of this booklet today.")


def _mkkie():
    k = sqlite3.connect(":memory:")
    k.row_factory = sqlite3.Row
    k.executescript(
        "CREATE TABLE source_documents (doc_id TEXT PRIMARY KEY, rel_path TEXT, category TEXT, exam TEXT, "
        "subject TEXT, year INT);"
        "CREATE TABLE chunks (chunk_id TEXT PRIMARY KEY, doc_id TEXT, ordinal INT, text TEXT);")
    # a NEET combined paper MIS-TAGGED subject='Physics' (the exact real defect shape), + a JEE_Main paper
    k.execute("INSERT INTO source_documents VALUES ('D_neet','NEET/Previous_Papers/2021/x','NEET','NEET','Physics',2021)")
    k.execute("INSERT INTO source_documents VALUES ('D_jee','JEE_Main/Previous_Papers/2020/y','JEE_Main','JEE_Main',NULL,2020)")
    for cid, o, t in [("c1", 1, _PHYS), ("c2", 2, _PHYS2), ("c3", 3, _CHEM), ("c4", 4, _BIO), ("c5", 5, _BOILER)]:
        k.execute("INSERT INTO chunks VALUES (?,?,?,?)", (cid, "D_neet", o, t))
    k.execute("INSERT INTO chunks VALUES ('j1','D_jee',1,?)",
              ("Section (Physics) 1. A projectile is launched; find its range and time of flight for the "
               "given speed and angle over level ground. (1) 20 m (2) 40 m  Ans (2)",))
    k.commit()
    return k


class ExamIsolation(unittest.TestCase):
    def test_exam_identity_match_no_path_bypass(self):
        k = _mkkie()
        try:
            # a NEET Previous_Papers doc must NOT be returned for a JEE_Main request (the OR-bypass bug)
            self.assertEqual({s["doc_id"] for s in QDI.exam_sources(k, exams=("JEE_Main",))}, {"D_jee"})
            self.assertEqual({s["doc_id"] for s in QDI.exam_sources(k, exams=("NEET",))}, {"D_neet"})
        finally:
            k.close()


class SectionSubjectResolution(unittest.TestCase):
    def test_resolve_propagates_section_markers(self):
        k = _mkkie()
        try:
            res = QDI.resolve_chunk_subjects(k, "D_neet")
            self.assertEqual(res["c1"], "Physics")
            self.assertEqual(res["c2"], "Physics")      # inherits the most-recent marker
            self.assertEqual(res["c3"], "Chemistry")
            self.assertEqual(res["c4"], "Biology")       # Botany -> Biology
        finally:
            k.close()

    def test_candidate_chunks_filters_by_resolved_subject_and_drops_boilerplate(self):
        k = _mkkie()
        try:
            self.assertEqual({r["chunk_id"] for r in QDI.candidate_chunks(k, ["D_neet"], subject="Physics")},
                             {"c1", "c2"})   # physics only — NO biology leak
            self.assertEqual({r["chunk_id"] for r in QDI.candidate_chunks(k, ["D_neet"], subject="Chemistry")},
                             {"c3"})
            self.assertEqual({r["chunk_id"] for r in QDI.candidate_chunks(k, ["D_neet"], subject="Biology")},
                             {"c4"})
            # boilerplate is dropped regardless of subject
            self.assertNotIn("c5", {r["chunk_id"] for r in QDI.candidate_chunks(k, ["D_neet"])})
        finally:
            k.close()

    def test_usable_chunk_rejects_boilerplate_and_mojibake(self):
        self.assertFalse(QDI._usable_chunk(_BOILER))
        self.assertTrue(QDI._usable_chunk(_PHYS))
        self.assertFalse(QDI._usable_chunk("ÁŸêŸ ◊¥ ∑§ÊÒŸ »§‚‹Ê¥ ∑§ ’ÊÿÊ»§ÊÁ≈¸UÁ»§∑§‡ÊŸ " * 8))  # mojibake


if __name__ == "__main__":
    unittest.main()
