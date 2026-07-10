"""QP engine Q7 — end-to-end engine facade + assembly + render."""
import json
import unittest

from kie import store
from kie.qpgen.engine import QpGenError, QuestionPaperEngine
from kie.qpgen.models import PaperRequest, QuestionType, SlotStatus, Subject
from kie.qpgen.scope import ScopeError, ScopeEmptyError
from kie.intake.store_ext import now_iso


def _seed(conn, code, title, subject, patterns=(("mcq", "apply", "medium", 4), ("short_answer", "understand", "medium", 3))):
    conn.execute(
        "INSERT INTO source_documents(doc_id,corpus,rel_path,category,exam,sha256,integrity_ok,encrypted,"
        "is_duplicate,verify_status,certify_status,certify_reason,created_at) "
        "VALUES (?,?,?,?,?,?,1,0,0,'verified','certified','ok',?)",
        (code + "_d", "foundation", "NEET/x.pdf", "NEET", "NEET", code + "s", now_iso()))
    conn.execute(
        "INSERT INTO concepts(concept_code,title,definition,subject_domain,status,evidence,created_at) "
        "VALUES (?,?,?,?, 'active', ?, ?)",
        (code, title, f"definition of {title}", subject, '{"doc":"%s"}' % (code + "_d"), now_iso()))
    for i, (qt, bloom, diff, freq) in enumerate(patterns):
        conn.execute(
            "INSERT INTO question_patterns(pattern_id,concept_code,question_type,bloom,difficulty,frequency,years,evidence)"
            " VALUES (?,?,?,?,?,?,?,?)", (f"{code}_p{i}", code, qt, bloom, diff, freq, "[2023]", "{}"))


def _populated_conn():
    conn = store.open_store(":memory:")
    phys = ["Newton's Second Law", "Work Energy Theorem", "Electromagnetic Induction",
            "Thermodynamics", "Simple Harmonic Motion", "Gravitation"]
    chem = ["Mole Concept", "Chemical Bonding", "Thermochemistry", "Electrochemistry"]
    bio = ["Photosynthesis", "Cell Division", "Human Digestion", "Genetics"]
    for i, t in enumerate(phys):
        _seed(conn, f"PHY_{i}", t, Subject.PHYSICS)
    for i, t in enumerate(chem):
        _seed(conn, f"CHE_{i}", t, Subject.CHEMISTRY)
    for i, t in enumerate(bio):
        _seed(conn, f"BIO_{i}", t, Subject.BIOLOGY)
    conn.commit()
    return conn


class TestEngine(unittest.TestCase):
    def setUp(self):
        self.conn = _populated_conn()
        self.eng = QuestionPaperEngine(conn=self.conn)

    def tearDown(self):
        self.conn.close()

    def test_generate_descriptive_paper_end_to_end(self):
        req = PaperRequest(exam="NEET", blueprint_preset="descriptive_40", seed=1, title="NEET Bio-Phys Test")
        paper = self.eng.generate(req)
        self.assertGreater(paper.total_questions, 0)
        self.assertGreater(paper.total_marks, 0)
        # descriptive blueprint → all deterministic + FILLED, none out-of-syllabus
        self.assertEqual(paper.spec_only, 0)
        self.assertTrue(all(s.status == SlotStatus.FILLED for s in paper.slots))
        self.assertTrue(all(s.concept_code in {c for c in _scope_codes(self.conn)} for s in paper.slots))
        self.assertTrue(paper.provenance["validation"]["boundary_ok"])
        # every filled stem references its concept
        for s in paper.slots:
            self.assertIn(s.concept_title.lower(), s.stem.lower())

    def test_objective_paper_has_specs_not_ai(self):
        req = PaperRequest(exam="NEET", blueprint_preset="objective_45", seed=1)
        paper = self.eng.generate(req)
        self.assertGreater(paper.spec_only, 0)          # objective items are specs by default
        self.assertFalse(paper.provenance["materialization"]["ai"]["attempted"])

    def test_reproducible_for_same_seed(self):
        req = PaperRequest(exam="NEET", blueprint_preset="descriptive_40", seed=42)
        p1 = self.eng.generate(req)
        p2 = self.eng.generate(req)
        self.assertEqual([s.concept_code for s in p1.slots], [s.concept_code for s in p2.slots])
        self.assertEqual([s.stem for s in p1.slots], [s.stem for s in p2.slots])

    def test_render_json_and_markdown(self):
        paper = self.eng.generate(PaperRequest(exam="NEET", blueprint_preset="descriptive_40"))
        j = self.eng.render_json(paper)
        self.assertEqual(j["exam_profile"], "NEET")
        self.assertEqual(len(j["questions"]), paper.total_questions)
        md = self.eng.render_markdown(paper)
        self.assertIn("# ", md)
        self.assertIn("Answer Key", md)
        self.assertIn("Section", md)

    def test_unsupported_scope_raises(self):
        with self.assertRaises(ScopeError):
            self.eng.generate(PaperRequest(exam="CBSE_Class_3"))

    def test_empty_scope_raises(self):
        with self.assertRaises(ScopeEmptyError):
            self.eng.generate(PaperRequest(exam="NEET", chapters=("no such chapter here",)))


def _scope_codes(conn):
    from kie.qpgen import scope
    return scope.resolve_scope(conn, PaperRequest(exam="NEET")).concept_codes


if __name__ == "__main__":
    unittest.main()
