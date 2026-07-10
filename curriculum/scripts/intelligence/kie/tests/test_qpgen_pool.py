"""QP engine Q3 — candidate pool from Question Intelligence + Concept Graph."""
import unittest

from kie import store
from kie.qpgen import pool, scope
from kie.qpgen.models import PaperRequest, QuestionType, RenderMode, Subject
from kie.intake.store_ext import now_iso


def _seed(conn, code, title, subject, patterns=(), is_law=False):
    conn.execute(
        "INSERT INTO source_documents(doc_id,corpus,rel_path,category,exam,sha256,integrity_ok,encrypted,"
        "is_duplicate,verify_status,certify_status,certify_reason,created_at) "
        "VALUES (?,?,?,?,?,?,1,0,0,'verified','certified','ok',?)",
        (code + "_d", "foundation", "NEET/x.pdf", "NEET", "NEET", code + "s", now_iso()))
    conn.execute(
        "INSERT INTO concepts(concept_code,title,definition,subject_domain,status,evidence,created_at) "
        "VALUES (?,?,?,?, 'active', ?, ?)", (code, title, "", subject, '{"doc":"%s"}' % (code + "_d"), now_iso()))
    if is_law:
        conn.execute("INSERT INTO formulas(formula_id,concept_code,kind,expression) VALUES (?,?,?,?)",
                     (code + "_f", code, "law", title))
    for i, (qt, bloom, diff, freq) in enumerate(patterns):
        conn.execute(
            "INSERT INTO question_patterns(pattern_id,concept_code,question_type,bloom,difficulty,frequency,years,evidence)"
            " VALUES (?,?,?,?,?,?,?,?)", (f"{code}_p{i}", code, qt, bloom, diff, freq, "[2022, 2023]", "{}"))


class TestPool(unittest.TestCase):
    def setUp(self):
        self.conn = store.open_store(":memory:")
        _seed(self.conn, "PHY_A", "Newton's Second Law", Subject.PHYSICS,
              patterns=[("mcq", "apply", "hard", 5), ("mcq", "remember", "easy", 2), ("numerical", "apply", "hard", 4)])
        _seed(self.conn, "CHE_A", "Mole Concept", Subject.CHEMISTRY, is_law=True,
              patterns=[("mcq", "understand", "medium", 3)])
        self.conn.execute("INSERT INTO concept_edges(from_concept,to_concept,relationship_type,strength) "
                          "VALUES ('PHY_A','CHE_A','related',1.0)")
        self.conn.commit()
        self.scope = scope.resolve_scope(self.conn, PaperRequest(exam="NEET"))

    def tearDown(self):
        self.conn.close()

    def test_pool_has_objective_and_descriptive(self):
        p = pool.build_pool(self.conn, self.scope)
        st = pool.pool_stats(p)
        # objective: PHY_A mcq, PHY_A numerical, CHE_A mcq = 3; descriptive: 2 concepts × 2 = 4
        self.assertEqual(st["by_type"][QuestionType.MCQ], 2)
        self.assertEqual(st["by_type"][QuestionType.NUMERICAL], 1)
        self.assertEqual(st["by_type"][QuestionType.SHORT_ANSWER], 2)
        self.assertEqual(st["by_type"][QuestionType.LONG_ANSWER], 2)

    def test_objective_collapses_to_best_pattern(self):
        p = pool.build_pool(self.conn, self.scope)
        mcqs = [c for c in p if c.concept_code == "PHY_A" and c.question_type == QuestionType.MCQ]
        self.assertEqual(len(mcqs), 1)                       # collapsed to one per (concept,type)
        self.assertEqual(mcqs[0].difficulty, "hard")         # the freq=5 pattern won, not freq=2 easy
        self.assertEqual(mcqs[0].frequency, 5)
        self.assertEqual(sorted(mcqs[0].years), [2022, 2023])

    def test_render_modes_and_graph_degree(self):
        p = pool.build_pool(self.conn, self.scope)
        for c in p:
            if c.question_type in (QuestionType.SHORT_ANSWER, QuestionType.LONG_ANSWER):
                self.assertEqual(c.render_mode, RenderMode.DETERMINISTIC)
            else:
                self.assertEqual(c.render_mode, RenderMode.SPEC_ONLY)
        # graph degree attached (PHY_A—CHE_A related edge → both degree 1)
        self.assertTrue(all(c.graph_degree >= 1 for c in p))

    def test_keys_unique_per_concept_type(self):
        p = pool.build_pool(self.conn, self.scope)
        keys = [c.key for c in p]
        self.assertEqual(len(keys), len(set(keys)))


if __name__ == "__main__":
    unittest.main()
