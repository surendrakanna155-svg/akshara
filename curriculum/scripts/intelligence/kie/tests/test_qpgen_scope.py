"""QP engine Q1 — concept sanitizer + syllabus scope resolver (strict boundaries)."""
import unittest

from kie import store
from kie.qpgen import presets, sanitize, scope
from kie.qpgen.models import PaperRequest, Subject
from kie.qpgen.scope import ScopeEmptyError, ScopeError
from kie.intake.store_ext import now_iso


def _seed_concept(conn, code, title, subject, doc_exam="NEET", definition="", freq=0, is_law=False,
                  class_label=None):
    conn.execute(
        "INSERT INTO source_documents(doc_id,corpus,rel_path,category,exam,class_label,sha256,integrity_ok,encrypted,"
        "is_duplicate,verify_status,certify_status,certify_reason,created_at) "
        "VALUES (?,?,?,?,?,?,?,1,0,0,'verified','certified','ok',?)",
        (code + "_d", "foundation", f"{doc_exam}/x.pdf", doc_exam, doc_exam, class_label, code + "sha", now_iso()))
    conn.execute(
        "INSERT INTO concepts(concept_code,title,definition,subject_domain,status,evidence,created_at) "
        "VALUES (?,?,?,?, 'active', ?, ?)",
        (code, title, definition, subject, '{"doc":"%s"}' % (code + "_d"), now_iso()))
    if freq:
        conn.execute(
            "INSERT INTO question_patterns(pattern_id,concept_code,question_type,bloom,difficulty,frequency,years,evidence)"
            " VALUES (?,?,?,?,?,?,?,?)", (code + "_p", code, "mcq", "understand", "medium", freq, "[2023]", "{}"))
    if is_law:
        conn.execute("INSERT INTO formulas(formula_id,concept_code,kind,expression) VALUES (?,?,?,?)",
                     (code + "_f", code, "law", title))


class TestSanitizer(unittest.TestCase):
    def test_accepts_real_concepts(self):
        for t in ("Newton's Second Law", "Photosynthesis", "Electromagnetic Induction",
                  "Bernoulli's principle", "Kinematics", "Thermodynamics"):
            self.assertTrue(sanitize.is_clean_concept(t), t)

    def test_rejects_ocr_garbage(self):
        for t in ("GAJAHA", "HAGAJA", "AJHGAA", "doJmZo", "wBOTANY", "AGAJHA"):
            self.assertFalse(sanitize.is_clean_concept(t), t)

    def test_rejects_boilerplate(self):
        for t in ("SUMMARY", "Preface", "Chapter", "Activity 10.1: Let us explore",
                  "Pause and Ponder", "A step further", "Threads of Curiosity", "Exercise", "3.2 What Is a Cell"):
            self.assertFalse(sanitize.is_clean_concept(t), t)

    def test_rejects_empty_and_symbols(self):
        for t in ("", "  ", "12.3", "***", "a"):
            self.assertFalse(sanitize.is_clean_concept(t), repr(t))


class TestScope(unittest.TestCase):
    def setUp(self):
        self.conn = store.open_store(":memory:")
        # clean, evidence-backed concepts across subjects
        _seed_concept(self.conn, "PHY_NEWTON2", "Newton's Second Law", Subject.PHYSICS, "NEET", freq=5)
        _seed_concept(self.conn, "BIO_PHOTO", "Photosynthesis", Subject.BIOLOGY, "NEET", definition="process ...")
        _seed_concept(self.conn, "MAT_CALC", "Differential Calculus", Subject.MATHEMATICS, "JEE_Main", freq=3)
        _seed_concept(self.conn, "CHE_MOLE", "Mole Concept", Subject.CHEMISTRY, "NEET", is_law=True)
        # noise + no-evidence concepts that MUST be excluded
        _seed_concept(self.conn, "NOISE_1", "GAJAHA", Subject.PHYSICS, "NEET", freq=9)      # garbage title
        _seed_concept(self.conn, "NOISE_2", "Kinematics", Subject.PHYSICS, "NEET", freq=0)  # clean but no evidence
        self.conn.commit()

    def tearDown(self):
        self.conn.close()

    def test_neet_scope_excludes_math_noise_and_unbacked(self):
        sc = scope.resolve_scope(self.conn, PaperRequest(exam="NEET"))
        self.assertEqual(sc.exam_profile, "NEET")
        codes = set(sc.concept_codes)
        self.assertIn("PHY_NEWTON2", codes)
        self.assertIn("BIO_PHOTO", codes)
        self.assertIn("CHE_MOLE", codes)
        self.assertNotIn("MAT_CALC", codes)     # Mathematics not in NEET profile
        self.assertNotIn("NOISE_1", codes)      # garbage title rejected
        self.assertNotIn("NOISE_2", codes)      # clean but no evidence

    def test_subject_filter_within_profile(self):
        sc = scope.resolve_scope(self.conn, PaperRequest(exam="NEET", subjects=(Subject.BIOLOGY,)))
        self.assertEqual(set(sc.concept_codes), {"BIO_PHOTO"})

    def test_subject_outside_profile_rejected(self):
        with self.assertRaises(ScopeError):
            scope.resolve_scope(self.conn, PaperRequest(exam="NEET", subjects=(Subject.MATHEMATICS,)))

    def test_unknown_exam_rejected(self):
        with self.assertRaises(ScopeError):
            scope.resolve_scope(self.conn, PaperRequest(exam="ICSE_Class_5_EVS"))

    def test_empty_scope_refused_not_fabricated(self):
        with self.assertRaises(ScopeEmptyError):
            scope.resolve_scope(self.conn, PaperRequest(exam="NEET", subjects=(Subject.PHYSICS,),
                                                        chapters=("nonexistent chapter xyz",)))

    def test_board_alias_resolves(self):
        self.assertEqual(presets.resolve_exam_profile(None, "neet", None), "NEET")
        self.assertEqual(presets.resolve_exam_profile("jee advanced", None, None), "JEE_ADVANCED")
        self.assertIsNone(presets.resolve_exam_profile(None, "CBSE", None))


class TestGradeIsolation(unittest.TestCase):
    """P0-1 — absolute grade isolation: no Class 6-10 content in a Class 11-12 profile."""

    def setUp(self):
        self.conn = store.open_store(":memory:")
        # NCERT textbook concepts across grades (class-labelled)
        _seed_concept(self.conn, "BIO_C7", "Nutrition in Plants", Subject.BIOLOGY, "NCERT", freq=4, class_label="Class 7")
        _seed_concept(self.conn, "BIO_C9", "Tissues", Subject.BIOLOGY, "NCERT", freq=4, class_label="Class 9")
        _seed_concept(self.conn, "BIO_C11", "Cell Structure", Subject.BIOLOGY, "NCERT", freq=4, class_label="Class 11")
        _seed_concept(self.conn, "BIO_C12", "Human Reproduction", Subject.BIOLOGY, "NCERT", freq=4, class_label="Class 12")
        # competitive-exam concept (no class_label) → grade 11-12 by nature
        _seed_concept(self.conn, "PHY_NEET", "Rotational Motion", Subject.PHYSICS, "NEET", freq=6)
        # unresolvable grade (class label present but unparseable) → excluded
        _seed_concept(self.conn, "BIO_BAD", "Some Topic", Subject.BIOLOGY, "NCERT", freq=4, class_label="Foundation")
        self.conn.commit()

    def tearDown(self):
        self.conn.close()

    def test_neet_excludes_class_6_to_10(self):
        sc = scope.resolve_scope(self.conn, PaperRequest(exam="NEET"))
        codes = set(sc.concept_codes)
        self.assertNotIn("BIO_C7", codes)     # Class 7 excluded
        self.assertNotIn("BIO_C9", codes)     # Class 9 excluded
        self.assertIn("BIO_C11", codes)       # Class 11 kept
        self.assertIn("BIO_C12", codes)       # Class 12 kept
        self.assertIn("PHY_NEET", codes)      # competitive (grade 11-12) kept
        self.assertNotIn("BIO_BAD", codes)    # unresolvable grade excluded (never assumed in-band)

    def test_foundation_includes_all_grades(self):
        sc = scope.resolve_scope(self.conn, PaperRequest(exam="FOUNDATION"))
        codes = set(sc.concept_codes)
        self.assertIn("BIO_C7", codes)        # FOUNDATION grade band 6-12 keeps Class 7
        self.assertIn("BIO_C11", codes)
        self.assertIn("PHY_NEET", codes)

    def test_doc_grade_helper(self):
        self.assertEqual(scope.doc_grade("Class 8", "NCERT"), 8)
        self.assertEqual(scope.doc_grade(None, "NEET"), 11)     # competitive → in-band 11
        self.assertIsNone(scope.doc_grade("Foundation", "NCERT"))  # unparseable
        self.assertIsNone(scope.doc_grade(None, None))          # unknown

    def test_grade_isolation_reported_in_stats(self):
        sc = scope.resolve_scope(self.conn, PaperRequest(exam="NEET"))
        self.assertEqual(sc.stats["grade_band"], [11, 12])
        self.assertNotIn(7, sc.stats["by_grade"])
        self.assertNotIn(9, sc.stats["by_grade"])


if __name__ == "__main__":
    unittest.main()
