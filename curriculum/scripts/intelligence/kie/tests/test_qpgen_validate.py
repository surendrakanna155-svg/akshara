"""QP engine Q6 — validation gate (adversarial: no out-of-syllabus / wrong-grade escapes)."""
import unittest

from kie import store
from kie.qpgen import scope, validate
from kie.qpgen.models import (Blueprint, BlueprintCell, PaperRequest, QuestionSlot,
                              QuestionType, RenderMode, Subject, SlotStatus)
from kie.intake.store_ext import now_iso


def _seed(conn, code, title, subject):
    conn.execute(
        "INSERT INTO source_documents(doc_id,corpus,rel_path,category,exam,sha256,integrity_ok,encrypted,"
        "is_duplicate,verify_status,certify_status,certify_reason,created_at) "
        "VALUES (?,?,?,?,?,?,1,0,0,'verified','certified','ok',?)",
        (code + "_d", "foundation", "NEET/x.pdf", "NEET", "NEET", code + "s", now_iso()))
    conn.execute(
        "INSERT INTO concepts(concept_code,title,definition,subject_domain,status,evidence,created_at) "
        "VALUES (?,?,?,?, 'active', ?, ?)", (code, title, "", subject, '{"doc":"%s"}' % (code + "_d"), now_iso()))
    conn.execute(
        "INSERT INTO question_patterns(pattern_id,concept_code,question_type,bloom,difficulty,frequency,years,evidence)"
        " VALUES (?,?,?,?,?,?,?,?)", (code + "_p", code, "mcq", "understand", "medium", 3, "[2023]", "{}"))


def _slot(n, code, title, subject, qtype=QuestionType.SHORT_ANSWER, status=SlotStatus.FILLED, stem=None, exam="NEET"):
    return QuestionSlot(number=n, section="A", concept_code=code, concept_title=title, subject=subject,
                        question_type=qtype, marks=2, bloom="understand", difficulty="medium",
                        render_mode=RenderMode.DETERMINISTIC, status=status,
                        stem=stem if stem is not None else f"Explain {title}.", provenance={"exam": exam})


class TestValidate(unittest.TestCase):
    def setUp(self):
        self.conn = store.open_store(":memory:")
        _seed(self.conn, "PHY_A", "Newton's Second Law", Subject.PHYSICS)
        _seed(self.conn, "BIO_A", "Photosynthesis", Subject.BIOLOGY)
        self.conn.commit()
        self.scope = scope.resolve_scope(self.conn, PaperRequest(exam="NEET"))
        self.bp = Blueprint("t", cells=[BlueprintCell("A", QuestionType.SHORT_ANSWER, 2, 2)])

    def tearDown(self):
        self.conn.close()

    def test_all_valid_passes(self):
        slots = [_slot(1, "PHY_A", "Newton's Second Law", Subject.PHYSICS),
                 _slot(2, "BIO_A", "Photosynthesis", Subject.BIOLOGY)]
        rep = validate.validate_paper(slots, self.bp, self.scope)
        self.assertTrue(rep.ok)
        self.assertEqual(rep.rejected_slots, 0)
        self.assertTrue(rep.boundary_ok)

    def test_rejects_out_of_syllabus_concept(self):
        slots = [_slot(1, "MAT_XX", "Integration", Subject.PHYSICS)]  # concept not in scope
        rep = validate.validate_paper(slots, self.bp, self.scope)
        self.assertFalse(rep.ok)
        self.assertEqual(slots[0].status, SlotStatus.REJECTED)
        self.assertTrue(any("OUT_OF_SYLLABUS" in v for v in rep.violations))
        self.assertFalse(rep.boundary_ok)

    def test_rejects_wrong_subject(self):
        # Mathematics is not in the NEET scope subjects
        slots = [_slot(1, "PHY_A", "Newton's Second Law", Subject.MATHEMATICS)]
        rep = validate.validate_paper(slots, self.bp, self.scope)
        self.assertTrue(any("WRONG_SUBJECT" in v for v in rep.violations))
        self.assertEqual(slots[0].status, SlotStatus.REJECTED)

    def test_rejects_garbage_concept_title(self):
        slots = [_slot(1, "PHY_A", "GAJAHA", Subject.PHYSICS)]
        rep = validate.validate_paper(slots, self.bp, self.scope)
        self.assertTrue(any("UNCLEAN_CONCEPT" in v for v in rep.violations))

    def test_rejects_ungrounded_filled_stem(self):
        # filled stem that doesn't mention the concept → rejected
        slots = [_slot(1, "PHY_A", "Newton's Second Law", Subject.PHYSICS, stem="Explain something unrelated.")]
        rep = validate.validate_paper(slots, self.bp, self.scope)
        self.assertTrue(any("UNGROUNDED_STEM" in v for v in rep.violations))

    def test_rejects_duplicate_concept_type(self):
        slots = [_slot(1, "PHY_A", "Newton's Second Law", Subject.PHYSICS),
                 _slot(2, "PHY_A", "Newton's Second Law", Subject.PHYSICS)]
        rep = validate.validate_paper(slots, self.bp, self.scope)
        self.assertEqual(rep.rejected_slots, 1)
        self.assertTrue(any("DUPLICATE" in v for v in rep.violations))

    def test_exam_profile_mismatch_rejected(self):
        slots = [_slot(1, "PHY_A", "Newton's Second Law", Subject.PHYSICS, exam="JEE_ADVANCED")]
        rep = validate.validate_paper(slots, self.bp, self.scope)
        self.assertTrue(any("EXAM_MISMATCH" in v for v in rep.violations))

    def test_conformance_reports_shortfall_softly(self):
        slots = [_slot(1, "PHY_A", "Newton's Second Law", Subject.PHYSICS)]  # only 1, blueprint wants 2
        rep = validate.validate_paper(slots, self.bp, self.scope)
        self.assertTrue(rep.ok)  # not rejected — soft
        self.assertTrue(any("wants 2" in c for c in rep.conformance))


if __name__ == "__main__":
    unittest.main()
