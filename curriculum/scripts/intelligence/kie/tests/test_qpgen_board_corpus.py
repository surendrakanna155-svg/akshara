"""P1-4 honest board support (2026-07-11 QP Content Readiness remediation).

Regression-locks the fail-closed guard: a Class-X *board* paper (CBSE/AP/Telangana) is refused
because the certified corpus holds only JEE/NEET Class 11-12 knowledge — never generated from
out-of-grade content. A Class-XII board scope is in-band and remains supported.
"""
import unittest

from kie import store
from kie.qpgen import engine as engine_mod
from kie.qpgen.engine import QuestionPaperEngine
from kie.qpgen.models import PaperRequest, Subject
from kie.qpgen.scope import ScopeError
from kie.intake.store_ext import now_iso


def _seed(conn, code, title, subject):
    conn.execute(
        "INSERT INTO source_documents(doc_id,corpus,rel_path,category,exam,sha256,integrity_ok,"
        "encrypted,is_duplicate,verify_status,certify_status,certify_reason,created_at) "
        "VALUES (?,?,?,?,?,?,1,0,0,'verified','certified','ok',?)",
        (code + "_d", "foundation", "NEET/x.pdf", "NEET", "NEET", code + "s", now_iso()))
    conn.execute(
        "INSERT INTO concepts(concept_code,title,definition,subject_domain,status,evidence,created_at) "
        "VALUES (?,?,?,?, 'active', ?, ?)",
        (code, title, f"definition of {title}", subject, '{"doc":"%s"}' % (code + "_d"), now_iso()))
    for j, (qt, diff) in enumerate((("mcq", "medium"), ("short_answer", "medium"))):
        conn.execute(
            "INSERT INTO question_patterns(pattern_id,concept_code,question_type,bloom,difficulty,"
            "frequency,years,evidence) VALUES (?,?,?,?,?,?,?,?)",
            (f"{code}_p{j}", code, qt, "understand", diff, 5 - j, "[2023]", "{}"))


class BoardCorpusTest(unittest.TestCase):
    def setUp(self):
        self.conn = store.open_store(":memory:")
        for subj, pref in ((Subject.PHYSICS, "PHY"), (Subject.CHEMISTRY, "CHE"),
                           (Subject.BIOLOGY, "BIO"), (Subject.MATHEMATICS, "MAT")):
            for i in range(40):
                _seed(self.conn, f"{pref}_{i}", f"{subj} Concept {i}", subj)
        self.conn.commit()
        self.eng = QuestionPaperEngine(conn=self.conn)

    def tearDown(self):
        self.conn.close()

    def test_class_x_board_blueprints_fail_closed(self):
        for bp in ("cbse_x_science", "ts_scert_x_science", "ap_scert_x_science"):
            with self.assertRaises(ScopeError) as ctx:
                self.eng.generate(PaperRequest(exam="FOUNDATION", blueprint_preset=bp, seed=1))
            self.assertIn("Class-X board", str(ctx.exception))
            self.assertIn("Class 11-12", str(ctx.exception))

    def test_class_xii_board_still_supported(self):
        # Class XII physics is in the 11-12 band → must NOT be refused
        paper = self.eng.generate(PaperRequest(exam="FOUNDATION", blueprint_preset="cbse_xii_physics",
                                               subjects=("Physics",), seed=1))
        self.assertTrue(paper.total_questions > 0)

    def test_guard_set_contains_only_class_x_boards(self):
        self.assertEqual(engine_mod._CLASS_X_BOARD_NO_CORPUS,
                         frozenset({"cbse_x_science", "ts_scert_x_science", "ap_scert_x_science"}))


if __name__ == "__main__":
    unittest.main()
