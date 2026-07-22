"""Program B · B3 — question re-mining with a deterministic provenance chain (OD-2).

Hermetic tests (always run) lock the anti-phantom guarantees: markers reject variables/decimals/OMR noise and
catch the two-space form; the per-item question-structure gate rejects instructions, notices, syllabus/experiment
lists, OCR garble, and non-English papers; spans are capped (no tail-swallow); the same question repeated in a
doc collapses; every emitted item carries a full provenance chain. Live tests self-skip when the gitignored DBs
are absent and assert the guarantees on the real corpus.
"""
from __future__ import annotations

import hashlib
import os
import sqlite3
import tempfile
import unittest

from kie import config
from kie.qie.pyq import mining as MI
from kie.qie.pyq import source_class as SC
from kie.qie.pyq import subject_seg as SS

_KIE_DB = config.DB_PATH

# realistic English exam questions (enough English words + structure to pass the is_question gate)
_Q = {
    1: ("1. A block of mass M slides down a frictionless inclined plane of angle theta. The acceleration of the "
        "block is which of the following ? (1) g sin theta (2) g cos theta (3) g tan theta (4) zero"),
    2: ("2. A charged particle enters a uniform magnetic field. The path of the particle in the field is which "
        "of these shapes ? (1) circle (2) straight line (3) parabola (4) helix"),
    3: ("3. Assertion : the sky appears blue during the day. Reason : blue light is scattered more than red "
        "light by the atmosphere because scattering is inversely proportional to wavelength."),
    4: ("4. Match List I with List II and select the correct answer using the codes given below the lists for "
        "the physical quantities and their units."),
    5: ("5. A particle moves so that the nearest integer value of its displacement in metres is what number "
        "when the time is two seconds and the speed is uniform ?"),
}


class TestMarkers(unittest.TestCase):
    def test_two_space_form_caught_and_qn_requires_dot(self):
        nums = [n for _, n in MI._markers("1.  At time t the block moves. Q.2 A ball rolls. Q3 is a variable.")]
        self.assertIn(1, nums)       # "1.␣␣At" (two spaces) — the born-digital form
        self.assertIn(2, nums)       # "Q.2" (dot required)
        self.assertNotIn(3, nums)    # "Q3" (no dot) is a physics variable, not a marker

    def test_omr_noise_decimals_variables_zero_rejected(self):
        nums = [n for _, n in MI._markers("11 12 13 14 and value 3.5 m and H2O and fixed at x=0.The field")]
        self.assertEqual(nums, [], "bare OMR numbers, decimals, mid-word digits, and 0. are never markers")


class TestQuestionGate(unittest.TestCase):
    def test_real_mcq_and_numerical_and_assertion_and_match_pass(self):
        self.assertEqual(MI._is_question(_Q[1])[0], True)
        self.assertEqual(MI._is_question(_Q[3])[0], True)
        self.assertEqual(MI._is_question(_Q[4])[0], True)
        self.assertEqual(MI._is_question(_Q[5])[0], True)

    def test_instruction_block_rejected(self):
        instr = ("1. The Answer Sheet is inside this Test Booklet. When you are directed to open the Test "
                 "Booklet, take out the Answer Sheet and fill in the particulars carefully with blue ball pen.")
        ok, why = MI._is_question(instr)
        self.assertFalse(ok)

    def test_notice_and_list_rejected(self):
        self.assertFalse(MI._is_question("1. The National Testing Agency is committed to transparent conduct.")[0])
        self.assertFalse(MI._is_question("1. Vernier calipers 2. Screw gauge 3. Simple pendulum")[0])

    def test_ocr_garble_and_non_english_rejected(self):
        self.assertFalse(MI._is_question("Q3 Ub UR dem AR UH Ud Hl SS HI IRA VI Hd Gd (1) x (2) y (3) z (4) w")[0])

    def test_no_structure_rejected(self):
        self.assertFalse(MI._is_question("Define electromagnetic induction in your own words for the class.")[0])

    def test_section_header_with_trailing_options_rejected(self):
        # the round-2 P0: a SECTION header whose 3000-char span reaches the NEXT question's options must NOT pass
        span = ("PART I : PHYSICS SECTION 1 (Maximum Marks: 18) This section contains four questions. "
                + "x " * 200 + "A block slides down a plane which is correct (1) a (2) b (3) c (4) d")
        self.assertFalse(MI._is_question(span)[0], "a section header must not become a question via bleed-in options")

    def test_instruction_with_trailing_options_rejected(self):
        span = ("Use of white fluid for correction is not permissible on the Answer Sheet provided to the "
                "candidate. (1) alpha (2) beta (3) gamma (4) delta")
        ok, why = MI._is_question(span)
        self.assertFalse(ok)
        self.assertEqual(why, "section_or_instruction_header")

    def test_answer_key_line_and_option_fragment_rejected(self):
        # round-3 residual: an answer-key line has the answer letter as its FIRST paren → tiny stem → rejected
        self.assertFalse(MI._is_question("Q.26: (A), (C) and (D) Ans for the above")[0])
        self.assertFalse(MI._is_question("5: (A) (B) (C) (D)")[0])

    def test_formula_heavy_chemistry_question_kept(self):
        # the round-2 P1-c: real English chem questions (low mean-token-length) must NOT be dropped as garble
        span = ("The correct order of the wavelength of maxima of the absorption band for these is which of "
                "the following ? (1) I II III (2) II I III (3) III II I (4) I III II")
        self.assertTrue(MI._is_question(span)[0])


class TestDedupAndTruncate(unittest.TestCase):
    def test_exact_copy_shares_fingerprint(self):
        # exact-content fingerprint: a byte-identical copy collapses; a whitespace-only reflow still matches.
        self.assertTrue(MI._stem_fp(_Q[1]) and MI._stem_fp(_Q[1]) == MI._stem_fp("  " + _Q[1] + "  "))

    def test_distinct_questions_never_false_merge(self):
        # the round-2 P1-b: two DIFFERENT questions must NEVER share a fingerprint (no generic-stem false-merge)
        self.assertNotEqual(MI._stem_fp(_Q[1]), MI._stem_fp(_Q[2]))
        q_a = "Identify the correct statement. RNA polymerase moves along the DNA template strand."
        q_b = "Identify the correct statement. Capping and methylation occur during RNA processing."
        self.assertNotEqual(MI._stem_fp(q_a), MI._stem_fp(q_b), "generic-stem questions must stay distinct")

    def test_solutions_section_truncated(self):
        body = "x " * 500 + " HINTS AND SOLUTIONS " + "y " * 500
        self.assertLess(len(MI._truncate_at_solutions(body)), len(body))


class TestExtractDocSynthetic(unittest.TestCase):
    def _kie(self, texts):
        c = sqlite3.connect(":memory:")
        self.addCleanup(c.close)
        c.row_factory = sqlite3.Row
        c.execute("CREATE TABLE chunks (doc_id TEXT, ordinal INT, text TEXT, sha256 TEXT)")
        c.executemany("INSERT INTO chunks VALUES (?,?,?,?)",
                      [("D", i, t, f"s{i}") for i, t in enumerate(texts)])
        return c

    def test_full_provenance_chain_and_types(self):
        kie = self._kie(["Physics : Section A", _Q[1] + " " + _Q[2], _Q[3] + " " + _Q[4] + " " + _Q[5]])
        subj_map = {("D", 0): "Physics", ("D", 1): "Physics", ("D", 2): "Physics"}
        rows = MI.extract_doc(kie, "D", "NEET", 2016, subj_map, ({}, "v"))
        self.assertEqual(sorted(r["question_number"] for r in rows), [1, 2, 3, 4, 5])
        for r in rows:
            self.assertEqual((r["exam"], r["year"], r["subject"]), ("NEET", 2016, "Physics"))
            self.assertTrue(r["chunk_ids"] != "[]" and r["chunk_sha256"] != "[]")
            self.assertLessEqual(r["span_len"], MI._MAX_SPAN)
        byq = {r["question_number"]: r["question_type"] for r in rows}
        self.assertEqual(byq[1], "mcq")
        self.assertEqual(byq[3], "assertion_reason")
        self.assertEqual(byq[4], "match")
        self.assertEqual(byq[5], "numerical")

    def test_non_english_doc_yields_nothing(self):
        kie = self._kie([_Q[1] + " " + _Q[2] + " " + _Q[3] + " " + _Q[4] + " " + _Q[5]])
        rows = MI.extract_doc(kie, "D", "NEET", 2016, {}, ({}, "v"),
                              rel_path="NEET/2016/NEET_2016_Hindi.pdf")
        self.assertEqual(rows, [], "a regional-language paper is skipped (duplicate of the English version)")

    def test_content_addressed_id_deterministic_and_positional(self):
        self.assertEqual(MI._content_addressed_id("D", 1, 10, "span"), MI._content_addressed_id("D", 1, 10, "span"))
        self.assertNotEqual(MI._content_addressed_id("D", 1, 10, "span"),
                            MI._content_addressed_id("D", 1, 20, "span"))

    def test_non_paper_yields_no_items(self):
        kie = self._kie(["1. The Answer Sheet is inside the Test Booklet. 2. Darken the bubble with a pen. "
                         "3. Do not open the booklet. 4. Rough work on the last page. 5. Sign the attendance."])
        self.assertEqual(MI.extract_doc(kie, "E", "NEET", None, {}, ({}, "v")), [],
                         "an instructions-only doc yields NO questions (honest-null, not phantom)")


@unittest.skipUnless(_KIE_DB.exists(), "kie.db not present (gitignored, local only)")
class TestLiveB3(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.pyq = os.path.join(cls.tmp.name, "pyq_corpus.db")
        cls.b = hashlib.md5(_KIE_DB.read_bytes()).hexdigest()
        SC.build(pyq_db_path=cls.pyq)
        SS.build(pyq_db_path=cls.pyq)
        cls.summary = MI.build(pyq_db_path=cls.pyq)
        cls.a = hashlib.md5(_KIE_DB.read_bytes()).hexdigest()

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def _q(self, sql):
        c = sqlite3.connect(f"file:{self.pyq}?mode=ro", uri=True)
        try:
            return c.execute(sql).fetchall()
        finally:
            c.close()

    def test_freeze_byte_identical(self):
        self.assertEqual(self.b, self.a)

    def test_full_provenance_chain(self):
        bad = self._q("SELECT COUNT(*) FROM pyq_item WHERE exam IS NULL OR chunk_ids='[]' OR chunk_ids IS NULL "
                      "OR chunk_sha256='[]'")[0][0]
        self.assertEqual(bad, 0)

    def test_item_traces_to_eligible_doc(self):
        orphan = self._q("SELECT COUNT(*) FROM pyq_item i WHERE NOT EXISTS "
                         "(SELECT 1 FROM pyq_source_class s WHERE s.doc_id=i.doc_id AND s.eligible_for_dna=1)")[0][0]
        self.assertEqual(orphan, 0)

    def test_span_cap_enforced(self):
        # the tail-swallow defect: no item may exceed the span cap
        self.assertEqual(self._q(f"SELECT COUNT(*) FROM pyq_item WHERE span_len > {MI._MAX_SPAN}")[0][0], 0)

    def test_known_non_paper_and_garble_docs_yield_nothing(self):
        # the adversarial-verifier P0 repros: NTA notice, experiment list, Hindi garble → 0 items
        n = self._q("SELECT COUNT(*) FROM pyq_item WHERE doc_id IN "
                    "('c98caaaef450571f','7cad9da2a1206544','8b5167727ed2c648')")[0][0]
        self.assertEqual(n, 0, "instruction/notice/garble docs must not produce questions")

    def test_reports_instances_and_distinct(self):
        s = self.summary["stats"]
        self.assertGreater(s["items"], 1000)
        self.assertIn("exact_distinct_instances", s)
        self.assertLessEqual(s["exact_distinct_instances"], s["items"])

    def test_determinism(self):
        with tempfile.TemporaryDirectory() as t:
            p = os.path.join(t, "p.db")
            SC.build(pyq_db_path=p)
            SS.build(pyq_db_path=p)
            s2 = MI.build(pyq_db_path=p)
        self.assertEqual(self.summary["stats"], s2["stats"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
