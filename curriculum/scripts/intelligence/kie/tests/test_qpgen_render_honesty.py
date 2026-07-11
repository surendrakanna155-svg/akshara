"""Render-honesty contract (2026-07-11 QP Content Readiness remediation).

Regression-locks the documented assemble.py exception:
  * a FILLED MCQ renders its options (A)-(D) in the paper AND emits them in JSON;
  * a SPEC / authoring stub is NEVER printed as a student question — it is routed to a
    clearly-labelled "Items requiring authoring" worklist outside the student paper;
  * a filled-but-generic marking-guideline answer is treated as NOT print-ready (unfilled),
    so no placeholder key is presented as an answer;
  * the paper header states honest deterministic coverage;
  * a real descriptive key renders as a mark-weighted marking scheme;
  * an internal-choice section note surfaces for a section that has printable content.
"""
import unittest

from kie.qpgen import assemble
from kie.qpgen.models import (Blueprint, BlueprintCell, GeneratedPaper, PaperRequest, QuestionSlot,
                              QuestionType, RenderMode, SlotStatus)
from kie.qpgen.scope import SyllabusScope


def _slot(n, section, qtype, marks, *, status, stem, concept="Newton's second law",
          subject="Physics", options=None, answer=None, solution=None):
    return QuestionSlot(
        number=n, section=section, concept_code=f"C{n}", concept_title=concept, subject=subject,
        question_type=qtype, marks=marks, bloom="understand", difficulty="medium",
        render_mode=RenderMode.DETERMINISTIC if status == SlotStatus.FILLED else RenderMode.SPEC_ONLY,
        status=status, stem=stem, options=options, answer=answer, solution=solution,
        provenance={})


def _paper(slots, blueprint=None):
    bp = blueprint or Blueprint(name="t", cells=[])
    scope = SyllabusScope(exam_profile="NEET", subjects=["Physics"], concepts={}, chapters=[])
    return GeneratedPaper(
        request=PaperRequest(exam="NEET"), blueprint_name="t", title="Test Paper",
        subjects=["Physics"], exam_profile="NEET", slots=slots,
        total_marks=sum(s.marks for s in slots), total_questions=len(slots),
        filled=sum(1 for s in slots if s.status == SlotStatus.FILLED),
        provenance={"section_notes": {}})


class RenderHonestyTest(unittest.TestCase):
    def test_filled_mcq_renders_options(self):
        s = _slot(1, "Section A", QuestionType.MCQ, 4, status=SlotStatus.FILLED,
                  stem="A body of mass 5 kg accelerates at 2 m/s². Find the net force.",
                  options=["10 N", "7 N", "3 N", "2.5 N"], answer="10 N",
                  solution="F = m·a = 5×2 = 10 N.")
        md = assemble.render_markdown(_paper([s]))
        self.assertIn("(A) 10 N", md)
        self.assertIn("(B) 7 N", md)
        self.assertIn("Correct option: **10 N**", md)
        j = assemble.render_json(_paper([s]))
        self.assertEqual(j["questions"][0]["options"], ["10 N", "7 N", "3 N", "2.5 N"])
        self.assertTrue(j["questions"][0]["printable"])
        self.assertEqual(j["printable_questions"], 1)

    def test_spec_never_printed_as_question(self):
        s = _slot(1, "Section A", QuestionType.MCQ, 4, status=SlotStatus.SPEC,
                  stem="[SPEC · author via approved AI] mcq on 'Refraction' …", concept="Refraction")
        md = assemble.render_markdown(_paper([s]))
        self.assertNotIn("[SPEC", md)                             # not in the student body
        self.assertIn("requiring authoring", md)                 # routed to the worklist
        self.assertIn("0 of 1", md)                              # honest coverage
        self.assertFalse(assemble.render_json(_paper([s]))["questions"][0]["printable"])

    def test_generic_key_is_not_printable(self):
        s = _slot(1, "Section A", QuestionType.SHORT_ANSWER, 2, status=SlotStatus.FILLED,
                  stem="Define Refraction.", concept="Refraction",
                  answer="[Marking guideline — award full marks for a correct, in-syllabus "
                         "explanation of Refraction; teacher to confirm key points.]")
        md = assemble.render_markdown(_paper([s]))
        self.assertNotIn("Marking guideline", md)                # placeholder never shown as a key
        self.assertIn("requiring authoring", md)
        self.assertFalse(assemble.is_student_printable(s))

    def test_real_descriptive_key_is_mark_weighted(self):
        s = _slot(1, "Section A", QuestionType.LONG_ANSWER, 5, status=SlotStatus.FILLED,
                  stem="Explain power in detail.", concept="Power",
                  answer="the rate at which work is done")
        self.assertTrue(assemble.is_student_printable(s))
        md = assemble.render_markdown(_paper([s]))
        self.assertIn("[5 marks]", md)
        self.assertIn("Award marks for", md)
        self.assertIn("relevant example", md)                    # depth scales with marks (>=5)

    def test_ocr_artifact_stem_not_printable(self):
        s = _slot(1, "Section A", QuestionType.SHORT_ANSWER, 2, status=SlotStatus.FILLED,
                  stem="Define Ohmwas led to his law.", concept="Ohmwas led to his law",
                  answer="a real definition of the law here")
        # a clause/merged concept title fails the clean-concept gate → not printable
        self.assertFalse(assemble.is_student_printable(s))

    def test_section_note_surfaces_with_printable_content(self):
        bp = Blueprint(name="t", cells=[
            BlueprintCell("Section B", QuestionType.MCQ, marks_each=4, count=1, choose=2)])
        s = _slot(1, "Section B", QuestionType.MCQ, 4, status=SlotStatus.FILLED,
                  stem="A resistor of 5 Ω carries 2 A. Find the p.d.",
                  options=["10 V", "7 V", "3 V", "2.5 V"], answer="10 V")
        paper = _paper([s], blueprint=bp)
        # mimic assemble()'s note derivation
        paper.provenance["section_notes"] = {"Section B": ["(Attempt any 1 of 2.)"]}
        md = assemble.render_markdown(paper)
        self.assertIn("Attempt any", md)


if __name__ == "__main__":
    unittest.main()
