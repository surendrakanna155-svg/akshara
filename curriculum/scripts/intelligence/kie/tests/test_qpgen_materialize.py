"""QP engine Q5 — deterministic materialization + gated AI seam."""
import unittest

from kie import store
from kie.qpgen import materialize
from kie.qpgen.materialize import AiFillGatedError
from kie.qpgen.models import (PaperRequest, QuestionSlot, QuestionType, RenderMode, SlotStatus)
from kie.intake.store_ext import now_iso


def _slot(number, qtype, code="PHY_A", title="Newton's Second Law", subject="Physics", mode=None):
    mode = mode or (RenderMode.DETERMINISTIC if qtype in (QuestionType.SHORT_ANSWER, QuestionType.LONG_ANSWER)
                    else RenderMode.SPEC_ONLY)
    return QuestionSlot(number=number, section="A", concept_code=code, concept_title=title, subject=subject,
                        question_type=qtype, marks=3, bloom="understand", difficulty="medium",
                        render_mode=mode, status=SlotStatus.SPEC)


class TestMaterialize(unittest.TestCase):
    def setUp(self):
        self.conn = store.open_store(":memory:")
        self.conn.execute(
            "INSERT INTO concepts(concept_code,title,definition,subject_domain,status,evidence,created_at) "
            "VALUES ('PHY_A','Newton''s Second Law','force equals mass times acceleration','Physics','active','{}',?)",
            (now_iso(),))
        self.conn.execute(
            "INSERT INTO concepts(concept_code,title,definition,subject_domain,status,evidence,created_at) "
            "VALUES ('BIO_A','Photosynthesis','','Biology','active','{}',?)", (now_iso(),))
        self.conn.commit()

    def tearDown(self):
        self.conn.close()

    def test_descriptive_rendered_with_real_stem_and_answer(self):
        slots = [_slot(1, QuestionType.SHORT_ANSWER), _slot(2, QuestionType.LONG_ANSWER)]
        out = materialize.materialize(slots, self.conn, PaperRequest(exam="NEET"))
        self.assertEqual(out["filled"], 2)
        for s in slots:
            self.assertEqual(s.status, SlotStatus.FILLED)
            self.assertTrue(s.stem and "Newton's Second Law" in s.stem)
            self.assertIn("force equals mass", s.answer)   # certified definition used as model answer

    def test_missing_definition_uses_rubric_not_fabrication(self):
        slots = [_slot(1, QuestionType.SHORT_ANSWER, code="BIO_A", title="Photosynthesis", subject="Biology")]
        materialize.materialize(slots, self.conn, PaperRequest(exam="NEET"))
        self.assertIn("Photosynthesis", slots[0].stem)
        self.assertIn("Marking guideline", slots[0].answer)   # honest rubric, no invented facts

    def test_objective_becomes_spec_by_default(self):
        slots = [_slot(1, QuestionType.MCQ), _slot(2, QuestionType.NUMERICAL)]
        out = materialize.materialize(slots, self.conn, PaperRequest(exam="NEET"))
        self.assertEqual(out["filled"], 0)
        self.assertEqual(out["spec_only"], 2)
        for s in slots:
            self.assertEqual(s.status, SlotStatus.SPEC)
            self.assertIn("SPEC", s.stem)
            self.assertIn("author_requirements", s.provenance)

    def test_ai_fill_is_gated(self):
        slots = [_slot(1, QuestionType.MCQ)]
        # allow_ai_fill but not authorized → raises (deterministic default never calls AI)
        with self.assertRaises(AiFillGatedError):
            materialize.materialize(slots, self.conn, PaperRequest(exam="NEET", allow_ai_fill=True))

    def test_default_never_calls_ai(self):
        slots = [_slot(1, QuestionType.MCQ)]
        out = materialize.materialize(slots, self.conn, PaperRequest(exam="NEET"))
        self.assertFalse(out["ai"]["attempted"])

    def test_title_normalization_in_stems(self):
        self.assertEqual(materialize.display_title("PROTEINS"), "Proteins")
        self.assertEqual(materialize.display_title("DNA Replication"), "DNA Replication")  # acronym kept
        self.assertEqual(materialize.embed_title("The momentum of an object"), "the momentum of an object")

    def test_deterministic_stems_reproducible(self):
        a = [_slot(1, QuestionType.SHORT_ANSWER)]
        b = [_slot(1, QuestionType.SHORT_ANSWER)]
        materialize.materialize(a, self.conn, PaperRequest(exam="NEET", seed=3))
        materialize.materialize(b, self.conn, PaperRequest(exam="NEET", seed=3))
        self.assertEqual(a[0].stem, b[0].stem)


if __name__ == "__main__":
    unittest.main()
