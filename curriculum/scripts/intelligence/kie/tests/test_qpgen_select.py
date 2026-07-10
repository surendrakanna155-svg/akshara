"""QP engine Q4 — deterministic blueprint-filling selection."""
import unittest

from kie import store
from kie.qpgen import pool, scope, select
from kie.qpgen.models import Blueprint, BlueprintCell, Difficulty, PaperRequest, QuestionType, Subject
from kie.intake.store_ext import now_iso


def _seed(conn, code, title, subject, patterns=()):
    conn.execute(
        "INSERT INTO source_documents(doc_id,corpus,rel_path,category,exam,sha256,integrity_ok,encrypted,"
        "is_duplicate,verify_status,certify_status,certify_reason,created_at) "
        "VALUES (?,?,?,?,?,?,1,0,0,'verified','certified','ok',?)",
        (code + "_d", "foundation", "NEET/x.pdf", "NEET", "NEET", code + "s", now_iso()))
    conn.execute(
        "INSERT INTO concepts(concept_code,title,definition,subject_domain,status,evidence,created_at) "
        "VALUES (?,?,?,?, 'active', ?, ?)", (code, title, "", subject, '{"doc":"%s"}' % (code + "_d"), now_iso()))
    for i, (qt, bloom, diff, freq) in enumerate(patterns):
        conn.execute(
            "INSERT INTO question_patterns(pattern_id,concept_code,question_type,bloom,difficulty,frequency,years,evidence)"
            " VALUES (?,?,?,?,?,?,?,?)", (f"{code}_p{i}", code, qt, bloom, diff, freq, "[2023]", "{}"))


class TestSelect(unittest.TestCase):
    def setUp(self):
        self.conn = store.open_store(":memory:")
        # 6 physics + 4 bio concepts, all with mcq patterns of varying frequency
        for i in range(6):
            _seed(self.conn, f"PHY_{i}", f"Physics Concept {i}", Subject.PHYSICS,
                  patterns=[("mcq", "apply", "medium" if i % 2 else "hard", 10 - i)])
        for i in range(4):
            _seed(self.conn, f"BIO_{i}", f"Biology Concept {i}", Subject.BIOLOGY,
                  patterns=[("mcq", "understand", "medium", 5 - i)])
        self.conn.commit()
        self.scope = scope.resolve_scope(self.conn, PaperRequest(exam="NEET"))
        self.pool = pool.build_pool(self.conn, self.scope)

    def tearDown(self):
        self.conn.close()

    def test_fills_cells_with_no_duplicate_concepts(self):
        bp = Blueprint("t", cells=[BlueprintCell("A", QuestionType.MCQ, 4, 6)])
        r = select.select(bp, self.pool, PaperRequest(exam="NEET"), self.scope)
        self.assertEqual(len(r.slots), 6)
        self.assertEqual(len({s.concept_code for s in r.slots}), 6)   # all distinct concepts
        self.assertEqual([s.number for s in r.slots], [1, 2, 3, 4, 5, 6])

    def test_subject_balancing(self):
        bp = Blueprint("t", cells=[BlueprintCell("A", QuestionType.MCQ, 4, 8)])
        r = select.select(bp, self.pool, PaperRequest(exam="NEET"), self.scope)
        subs = [s.subject for s in r.slots]
        # with balancing, both subjects represented (not all 8 from physics)
        self.assertIn(Subject.PHYSICS, subs)
        self.assertIn(Subject.BIOLOGY, subs)
        self.assertGreaterEqual(subs.count(Subject.BIOLOGY), 3)

    def test_deterministic_for_same_seed(self):
        bp = Blueprint("t", cells=[BlueprintCell("A", QuestionType.MCQ, 4, 5)])
        r1 = select.select(bp, self.pool, PaperRequest(exam="NEET", seed=7), self.scope)
        r2 = select.select(bp, self.pool, PaperRequest(exam="NEET", seed=7), self.scope)
        self.assertEqual([s.concept_code for s in r1.slots], [s.concept_code for s in r2.slots])

    def test_difficulty_preference_then_relax(self):
        # request 5 HARD mcqs but only 3 physics-hard exist → relax, note recorded, still filled
        bp = Blueprint("t", cells=[BlueprintCell("A", QuestionType.MCQ, 4, 5, difficulty=Difficulty.HARD)])
        r = select.select(bp, self.pool, PaperRequest(exam="NEET"), self.scope)
        self.assertEqual(len(r.slots), 5)
        self.assertTrue(any("relaxed difficulty" in n for n in r.notes))

    def test_shortfall_reported_not_padded(self):
        bp = Blueprint("t", cells=[BlueprintCell("A", QuestionType.MCQ, 4, 50)])  # only 10 concepts
        r = select.select(bp, self.pool, PaperRequest(exam="NEET"), self.scope)
        self.assertEqual(len(r.slots), 10)
        self.assertTrue(any("short" in s for s in r.shortfalls))
        self.assertEqual(len({s.concept_code for s in r.slots}), 10)


if __name__ == "__main__":
    unittest.main()
