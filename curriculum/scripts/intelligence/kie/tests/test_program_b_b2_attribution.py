"""Program B · B2 — subject attribution (OD-4: subject from the document, before concept) + subject-scoped
concept resolution (the D3 mislabel fix).

Hermetic tests (always run) are the adversarial controls: a real section header is detected; a multi-subject
cover line and an incidental subject mention are NOT headers; subject inherits in document order; honest-null
before the first header. Concept resolution is subject-scoped + strict: a "Motion" name under a Physics section
resolves to the Physics concept (never Biology), a name only in another subject is honest-null (no cross-subject),
no-subject and within-subject ambiguity are honest-null. Live tests self-skip when the gitignored DBs are absent.
"""
from __future__ import annotations

import hashlib
import json
import os
import sqlite3
import tempfile
import unittest

from kie import config
from kie.qie.pyq import concept_attr as CA
from kie.qie.pyq import source_class as SC
from kie.qie.pyq import subject_seg as SS

_KIE_DB = config.DB_PATH
_IDX_DB = config.KIE_HOME / "knowledge_index.db"


def _synth_index(tmp):
    """Minimal frozen-index shape: Physics 'Motion'/'Power', Biology 'Cell', two Physics 'Force' (ambiguous)."""
    path = os.path.join(tmp, "knowledge_index.db")
    c = sqlite3.connect(path)
    c.execute("CREATE TABLE ki_concept (concept_id TEXT PRIMARY KEY, subject TEXT, canonical_name TEXT, "
              "aliases TEXT, status TEXT)")
    c.execute("CREATE TABLE ki_meta (key TEXT, value TEXT)")
    c.execute("INSERT INTO ki_meta VALUES ('certified_knowledge_fingerprint_v1.5','abcdef012345')")
    c.executemany("INSERT INTO ki_concept VALUES (?,?,?,?,?)", [
        ("KC_PHYMOT", "Physics", "Motion", "[]", "certified"),
        ("KC_PHYPOW", "Physics", "Power", "[]", "certified"),
        ("KC_BIOCELL", "Biology", "Cell", "[]", "certified"),
        ("KC_F1", "Physics", "Force", "[]", "certified"),
        ("KC_F2", "Physics", "Force", '["Force Vector"]', "certified"),   # ambiguous: two Physics "Force"
        ("KC_DRAFT", "Physics", "Draft", "[]", "proposed"),               # non-certified: ignored
    ])
    c.commit()
    c.close()
    return path


class TestSubjectHeaderDetection(unittest.TestCase):
    def test_section_path_header(self):
        self.assertEqual(SS.detect_header_subject("PART I : PHYSICS", "Q.1 A block ..."), ("Physics", "section_path"))
        self.assertEqual(SS.detect_header_subject("PART II : CHEMISTRY > Answer", "18.")[0], "Chemistry")

    def test_in_text_header(self):
        self.assertEqual(SS.detect_header_subject("", "Physics : Section-A (Q. No. 1 to 35)"),
                         ("Physics", "text_header"))
        self.assertEqual(SS.detect_header_subject("", "SECTION-A BOTANY")[0], "Biology")

    def test_cover_line_is_not_a_header(self):
        # a multi-subject cover line must not set a subject
        self.assertEqual(SS.detect_header_subject("", "NEET 2016 (Physics, Chemistry and Biology) Code AA"),
                         (None, None))

    def test_incidental_mention_is_not_a_header(self):
        # a subject word inside a stem with NO part/section cue is not a header
        self.assertEqual(SS.detect_header_subject("", "A physics student drops a ball from a height h."),
                         (None, None))

    def test_prose_with_cue_word_is_not_a_header(self):
        # the cue must be a real PART/SECTION token, not a substring or a preposition phrase
        for prose in ("This part of physics deals with rotational motion",
                      "A particle in physics moves along x", "The department of physics announced",
                      "Apart from mathematics, students study logic"):
            self.assertEqual(SS.detect_header_subject("", prose), (None, None), prose)

    def test_letter_and_numeral_section_labels(self):
        self.assertEqual(SS.detect_header_subject("", "SECTION-A BOTANY")[0], "Biology")
        self.assertEqual(SS.detect_header_subject("", "PART – 1 PHYSICS")[0], "Physics")


class TestSegmentDoc(unittest.TestCase):
    def test_inherit_and_honest_null(self):
        chunks = [
            (0, "", "Cover page: roll number and instructions"),          # before any header → honest-null
            (1, "", "Physics : Section A"),                               # text header → Physics
            (2, "", "Q.1 A block of mass M ..."),                         # inherit Physics
            (3, "PART II : CHEMISTRY", "Q.31 The pH of ..."),             # section_path header → Chemistry
            (4, "", "Q.32 The rate of reaction ..."),                     # inherit Chemistry
        ]
        seg = {o: (s, m) for o, s, m, h in SS.segment_doc(chunks)}
        self.assertEqual(seg[0], (None, "honest_null"))
        self.assertEqual(seg[1][0], "Physics")
        self.assertEqual(seg[2], ("Physics", "inherited_from_header"))
        self.assertEqual(seg[3][0], "Chemistry")
        self.assertEqual(seg[4], ("Chemistry", "inherited_from_header"))

    def test_boundary_chunk_is_honest_null_not_mislabelled(self):
        # a chunk with a PRIOR-subject question then a MID-CHUNK header must not be stamped the later subject
        chunks = [
            (0, "", "Physics : Section A"),
            (1, "", "Q.5 optics: refractive index n=1.5 total internal reflection " * 8 + "PART-II CHEMISTRY SECTION"),
            (2, "", "Q.31 the pH of a buffer solution"),
        ]
        seg = {o: (s, m) for o, s, m, h in SS.segment_doc(chunks)}
        self.assertEqual(seg[1], (None, "mixed_boundary"), "a straddling chunk must be honest-null, not Chemistry")
        self.assertEqual(seg[2], ("Chemistry", "inherited_from_header"), "current subject must still advance")

    def test_two_header_chunk_is_honest_null(self):
        seg = SS.segment_doc([(0, "", "SECTION MATHEMATICS ...many Qs... SECTION PHYSICS ...")])
        self.assertEqual((seg[0][1], seg[0][2]), (None, "mixed_boundary"))

    def test_deep_same_subject_header_is_continuation_not_boundary(self):
        # a deep header REPEATING the current subject (a per-question tag / sub-section) is not a boundary
        chunks = [
            (0, "", "Physics : Section A"),                                  # header → Physics
            (1, "", "Q.2 " + "x " * 40 + "Topic Name : Physics - Section"),  # deep, SAME subject → continuation
            (2, "", "Q.3 " + "y " * 40 + "PART II CHEMISTRY"),               # deep, DIFFERENT subject → boundary
        ]
        seg = {o: (s, m) for o, s, m, h in SS.segment_doc(chunks)}
        self.assertEqual(seg[1], ("Physics", "continuation"), "same-subject deep header must stay attributed")
        self.assertEqual(seg[2], (None, "mixed_boundary"), "different-subject deep header is a real boundary")


class TestConceptResolution(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.idx = CA.build_subject_index(_synth_index(cls.tmp.name))

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_mislabel_fix_resolves_within_document_subject(self):
        # the D3 fix: "Motion" (old code BIO_MOTION) under a Physics section → the PHYSICS concept, never Biology
        self.assertEqual(CA.resolve(self.idx, "Physics", "Motion"), ("KC_PHYMOT", "subject_scoped"))

    def test_strict_no_cross_subject(self):
        # "Cell" exists only in Biology; a Physics section must NOT borrow it → honest-null
        self.assertEqual(CA.resolve(self.idx, "Physics", "Cell"), (None, "unresolved"))

    def test_no_subject_is_honest_null(self):
        self.assertEqual(CA.resolve(self.idx, None, "Motion"), (None, "no_subject"))

    def test_within_subject_ambiguity_is_honest_null(self):
        self.assertEqual(CA.resolve(self.idx, "Physics", "Force"), (None, "ambiguous"))

    def test_versioned_to_frozen_fingerprint(self):
        self.assertIn("abcdef012345", self.idx[1])


def _md5(p):
    return hashlib.md5(p.read_bytes()).hexdigest()


@unittest.skipUnless(_KIE_DB.exists() and _IDX_DB.exists(), "kie.db / knowledge_index.db not present (gitignored)")
class TestLiveB2(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.pyq = os.path.join(cls.tmp.name, "pyq_corpus.db")
        SC.build(pyq_db_path=cls.pyq)                       # B1 prerequisite
        cls.before = (_md5(_KIE_DB), _md5(_IDX_DB))
        cls.summary = SS.build(pyq_db_path=cls.pyq)
        cls.after = (_md5(_KIE_DB), _md5(_IDX_DB))

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_freeze_byte_identical(self):
        self.assertEqual(self.before, self.after, "B2 must not mutate the frozen kie.db / index")

    def test_subject_coverage_reported_honestly(self):
        s = self.summary["stats"]
        # coverage is partial by construction (only papers with a detectable subject header) — assert it is
        # REPORTED (not inflated) and that all four canonical subjects appear.
        self.assertIn("subject_doc_coverage", s)
        self.assertLess(s["subject_doc_coverage"], 1.0, "coverage must be honest, not claimed complete")
        for subj in ("Physics", "Chemistry", "Mathematics", "Biology"):
            self.assertIn(subj, s["chunks_by_subject"])

    def test_no_subject_is_a_valid_honest_null_state(self):
        c = sqlite3.connect(f"file:{self.pyq}?mode=ro", uri=True)
        try:
            n_null = c.execute("SELECT COUNT(*) FROM pyq_chunk_subject WHERE subject IS NULL").fetchone()[0]
            # a NULL subject must be one of the two honest-null states (no header seen, or a straddling boundary)
            n_meth = c.execute("SELECT COUNT(*) FROM pyq_chunk_subject WHERE subject IS NULL "
                               "AND subject_method NOT IN ('honest_null','mixed_boundary')").fetchone()[0]
            n_bad = c.execute("SELECT COUNT(*) FROM pyq_chunk_subject WHERE subject IS NOT NULL "
                              "AND subject_method IN ('honest_null','mixed_boundary')").fetchone()[0]
        finally:
            c.close()
        self.assertGreater(n_null, 0, "honest-null must be a real, populated state")
        self.assertEqual(n_meth, 0, "every NULL subject must be an honest-null state")
        self.assertEqual(n_bad, 0, "an honest-null method must never carry a subject")

    def test_boundary_chunks_are_null_not_mislabelled(self):
        # regression for the adversarial-verifier P0: straddling chunks are honest-null, never a single subject
        c = sqlite3.connect(f"file:{self.pyq}?mode=ro", uri=True)
        try:
            n = c.execute("SELECT COUNT(*) FROM pyq_chunk_subject WHERE subject_method='mixed_boundary' "
                          "AND subject IS NOT NULL").fetchone()[0]
        finally:
            c.close()
        self.assertEqual(n, 0, "a mixed_boundary chunk must never be stamped a subject")

    def test_determinism(self):
        with tempfile.TemporaryDirectory() as t:
            p = os.path.join(t, "p.db")
            SC.build(pyq_db_path=p)
            s2 = SS.build(pyq_db_path=p)
        self.assertEqual(self.summary["stats"], s2["stats"])

    def test_mislabel_evidence_is_real_and_independent(self):
        r = CA.mislabel_report()
        # D3 is real on BOTH honest measures: the broad prefix≠index rate AND the clean cross-subject swaps
        # (the report separates them so the "Science"-granularity bucket never inflates the clean-swap claim).
        self.assertGreater(r["prefix_disagrees_with_index"], 50)
        self.assertGreater(r["clean_cross_subject_swaps"], 0,
                           "there must be genuine prefix↔canonical-subject swaps (e.g. physics topic under BIO_)")
        self.assertGreaterEqual(r["disagreement_rate"], r["clean_swap_rate"],
                                "the broad rate must be reported alongside (>=) the clean-swap rate")


if __name__ == "__main__":
    unittest.main(verbosity=2)
