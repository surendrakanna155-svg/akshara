"""QP engine Q2 — blueprint definition, validation, and scope-aware feasibility."""
import unittest

from kie import store
from kie.qpgen import blueprint, presets, scope
from kie.qpgen.models import (Blueprint, BlueprintCell, Difficulty, PaperRequest,
                              QuestionType, Subject)
from kie.intake.store_ext import now_iso


def _seed(conn, code, title, subject, qtypes=(), definition="", is_law=False):
    conn.execute(
        "INSERT INTO source_documents(doc_id,corpus,rel_path,category,exam,sha256,integrity_ok,encrypted,"
        "is_duplicate,verify_status,certify_status,certify_reason,created_at) "
        "VALUES (?,?,?,?,?,?,1,0,0,'verified','certified','ok',?)",
        (code + "_d", "foundation", "NEET/x.pdf", "NEET", "NEET", code + "s", now_iso()))
    conn.execute(
        "INSERT INTO concepts(concept_code,title,definition,subject_domain,status,evidence,created_at) "
        "VALUES (?,?,?,?, 'active', ?, ?)",
        (code, title, definition, subject, '{"doc":"%s"}' % (code + "_d"), now_iso()))
    if is_law:
        conn.execute("INSERT INTO formulas(formula_id,concept_code,kind,expression) VALUES (?,?,?,?)",
                     (code + "_f", code, "law", title))
    for i, qt in enumerate(qtypes):
        conn.execute(
            "INSERT INTO question_patterns(pattern_id,concept_code,question_type,bloom,difficulty,frequency,years,evidence)"
            " VALUES (?,?,?,?,?,?,?,?)", (f"{code}_p{i}", code, qt, "understand", "medium", 3, "[2023]", "{}"))


class TestBlueprint(unittest.TestCase):
    def setUp(self):
        self.conn = store.open_store(":memory:")
        _seed(self.conn, "PHY_A", "Newton's Second Law", Subject.PHYSICS, qtypes=("mcq", "short_answer"))
        _seed(self.conn, "PHY_B", "Work Energy Theorem", Subject.PHYSICS, qtypes=("mcq",))
        _seed(self.conn, "CHE_A", "Mole Concept", Subject.CHEMISTRY, is_law=True, qtypes=("mcq", "numerical"))
        self.conn.commit()

    def tearDown(self):
        self.conn.close()

    def test_presets_load_and_validate(self):
        for name in ("objective_45", "descriptive_40", "mixed_50"):
            bp = presets.get_blueprint(name)
            self.assertEqual(blueprint.validate_blueprint(bp), [])
            self.assertGreater(bp.total_marks, 0)
            self.assertGreater(bp.total_questions, 0)

    def test_default_blueprint_by_profile(self):
        self.assertEqual(blueprint.default_blueprint_name("NEET"), "objective_45")
        self.assertEqual(blueprint.default_blueprint_name("FOUNDATION"), "mixed_50")

    def test_validate_catches_bad_cells(self):
        bad = Blueprint("bad", cells=[
            BlueprintCell("A", "not_a_type", marks_each=1, count=1),
            BlueprintCell("A", QuestionType.MCQ, marks_each=0, count=0),
            BlueprintCell("A", QuestionType.MCQ, marks_each=1, count=1, difficulty="impossible"),
        ])
        errs = blueprint.validate_blueprint(bad)
        self.assertTrue(any("unknown question_type" in e for e in errs))
        self.assertTrue(any("count must be > 0" in e for e in errs))
        self.assertTrue(any("marks_each must be > 0" in e for e in errs))
        self.assertTrue(any("unknown difficulty" in e for e in errs))

    def test_type_availability_descriptive_vs_objective(self):
        sc = scope.resolve_scope(self.conn, PaperRequest(exam="NEET"))
        avail = blueprint.type_availability(self.conn, sc)
        # 3 in-scope concepts → each yields a descriptive question
        self.assertEqual(avail[QuestionType.SHORT_ANSWER], 3)
        self.assertEqual(avail[QuestionType.LONG_ANSWER], 3)
        # objective grounded in real patterns: mcq on PHY_A, PHY_B, CHE_A = 3; numerical only CHE_A = 1
        self.assertEqual(avail[QuestionType.MCQ], 3)
        self.assertEqual(avail[QuestionType.NUMERICAL], 1)
        self.assertEqual(avail[QuestionType.MATCH], 0)

    def test_feasibility_flags_shortfall(self):
        sc = scope.resolve_scope(self.conn, PaperRequest(exam="NEET"))
        avail = blueprint.type_availability(self.conn, sc)
        bp = Blueprint("t", cells=[
            BlueprintCell("A", QuestionType.NUMERICAL, marks_each=4, count=5),   # only 1 available
            BlueprintCell("A", QuestionType.SHORT_ANSWER, marks_each=2, count=2)  # 3 available → ok
        ])
        warns = blueprint.feasibility(bp, avail)
        self.assertEqual(len(warns), 1)
        self.assertIn("numerical", warns[0])
        self.assertIn("short by 4", warns[0])


if __name__ == "__main__":
    unittest.main()
