"""QP engine — production-readiness hardening (independent validation, 2026-07-10).

Locks two fixes found during the final independent production-readiness validation:
  * a truncated/fragmentary certified definition is NOT shown as an authoritative model answer
    (falls back to the honest teacher marking guideline);
  * a gated-AI OBJECTIVE item whose stem does not reference its (in-scope) concept is rejected
    by the SAME validation gate as descriptive items — closing an off-topic-content gap.
"""
import os
import unittest

from kie import store
from kie.qpgen import materialize, validate, scope
from kie.qpgen.materialize import usable_definition
from kie.qpgen.models import (Blueprint, BlueprintCell, PaperRequest, QuestionSlot,
                              QuestionType, RenderMode, SlotStatus, Subject)
from kie.intake.store_ext import now_iso


class TestDefinitionQualityFloor(unittest.TestCase):
    def test_usable_definition_rejects_fragments_keeps_real(self):
        for frag in ("the amount of", "below :", "the energy", "autonomous elements,",
                     "the energy required to", "the ratio of re", "below:"):
            self.assertFalse(usable_definition(frag), frag)
        for good in ("the force per unit area", "force equals mass times acceleration",
                     "Photosynthesis is the process by which plants make food"):
            self.assertTrue(usable_definition(good), good)

    def test_fragment_definition_falls_back_to_marking_guideline(self):
        conn = store.open_store(":memory:")
        conn.execute(
            "INSERT INTO concepts(concept_code,title,definition,subject_domain,status,evidence,created_at) "
            "VALUES ('BIO_F','Primary production','the amount of','Biology','active','{}',?)", (now_iso(),))
        conn.commit()
        slot = QuestionSlot(number=1, section="A", concept_code="BIO_F", concept_title="Primary production",
                            subject="Biology", question_type=QuestionType.SHORT_ANSWER, marks=2,
                            bloom="understand", difficulty="medium", render_mode=RenderMode.DETERMINISTIC,
                            status=SlotStatus.SPEC)
        materialize.materialize([slot], conn, PaperRequest(exam="NEET"))
        self.assertIn("Marking guideline", slot.answer)         # fragment NOT shown as the answer
        self.assertNotEqual(slot.answer.strip(), "the amount of")
        conn.close()


class _RogueInScope:
    """Returns off-topic content for an IN-SCOPE concept slot — must be caught by grounding."""
    def author(self, spec):
        return {"stem": "Compute the income-tax liability under section 80C.",
                "answer": "x", "options": ["1", "2", "3", "4"], "solution": "n/a"}


class TestAiObjectiveGrounding(unittest.TestCase):
    def setUp(self):
        self._prev = os.environ.get("KIE_AI_AUTHORIZED")
        self.conn = store.open_store(":memory:")
        self.conn.execute(
            "INSERT INTO source_documents(doc_id,corpus,rel_path,category,exam,sha256,integrity_ok,encrypted,"
            "is_duplicate,verify_status,certify_status,certify_reason,created_at) "
            "VALUES ('d','foundation','NEET/x.pdf','NEET','NEET','s',1,0,0,'verified','certified','ok',?)",
            (now_iso(),))
        self.conn.execute(
            "INSERT INTO concepts(concept_code,title,definition,subject_domain,status,evidence,created_at) "
            "VALUES ('PHY_A','Electric Field','','Physics','active','{\"doc\":\"d\"}',?)", (now_iso(),))
        self.conn.execute(
            "INSERT INTO question_patterns(pattern_id,concept_code,question_type,bloom,difficulty,frequency,years,evidence)"
            " VALUES ('p','PHY_A','mcq','apply','medium',3,'[2023]','{}')")
        self.conn.commit()

    def tearDown(self):
        if self._prev is None:
            os.environ.pop("KIE_AI_AUTHORIZED", None)
        else:
            os.environ["KIE_AI_AUTHORIZED"] = self._prev
        self.conn.close()

    def test_offtopic_ai_objective_on_in_scope_concept_is_rejected(self):
        os.environ["KIE_AI_AUTHORIZED"] = "1"
        sc = scope.resolve_scope(self.conn, PaperRequest(exam="NEET", subjects=("Physics",)))
        bp = Blueprint("t", cells=[BlueprintCell("A", QuestionType.MCQ, 4, 1)])
        slot = QuestionSlot(number=1, section="A", concept_code="PHY_A", concept_title="Electric Field",
                            subject=Subject.PHYSICS, question_type=QuestionType.MCQ, marks=4,
                            bloom="apply", difficulty="medium", render_mode=RenderMode.SPEC_ONLY,
                            status=SlotStatus.SPEC, provenance={"exam": "NEET"})
        materialize.ai_fill([slot], provider=_RogueInScope(), cache={})
        # in-scope concept + correct subject, but stem is off-topic → grounding rejects it
        rep = validate.validate_paper([slot], bp, sc)
        self.assertFalse(rep.ok)
        self.assertEqual(slot.status, SlotStatus.REJECTED)
        self.assertTrue(any("UNGROUNDED_STEM" in x for x in slot.validation))


if __name__ == "__main__":
    unittest.main()
