"""QP engine Q1 — concept sanitizer + syllabus scope resolver (strict boundaries)."""
import unittest

from kie import store
from kie.qpgen import presets, sanitize, scope
from kie.qpgen.models import PaperRequest, Subject
from kie.qpgen.scope import ScopeEmptyError, ScopeError
from kie.intake.store_ext import now_iso


def _seed_concept(conn, code, title, subject, doc_exam="NEET", definition="", freq=0, is_law=False):
    conn.execute(
        "INSERT INTO source_documents(doc_id,corpus,rel_path,category,exam,sha256,integrity_ok,encrypted,"
        "is_duplicate,verify_status,certify_status,certify_reason,created_at) "
        "VALUES (?,?,?,?,?,?,1,0,0,'verified','certified','ok',?)",
        (code + "_d", "foundation", f"{doc_exam}/x.pdf", doc_exam, doc_exam, code + "sha", now_iso()))
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


if __name__ == "__main__":
    unittest.main()
