"""QP engine — Phase 5 objective-question validation.

Locks the structural gate for FILLED objective items (MCQ / assertion-reason / numerical /
match): exactly four DISTINCT options, a marked answer that is present among them EXACTLY once,
no blank/malformed options, a concrete answer for numerical/match. The SAME gate applies to
deterministic template output and gated-AI output — nothing malformed ever reaches the paper.
"""
import unittest

from kie import store
from kie.qpgen import scope, validate, templates
from kie.qpgen.engine import QuestionPaperEngine
from kie.qpgen.models import (Blueprint, BlueprintCell, PaperRequest, QuestionSlot,
                              QuestionType, RenderMode, SlotStatus, Subject)
from kie.intake.store_ext import now_iso


def _mcq(options, answer, status=SlotStatus.FILLED, source="template"):
    return QuestionSlot(number=1, section="A", concept_code="C", concept_title="Ohm's law",
                        subject=Subject.PHYSICS, question_type=QuestionType.MCQ, marks=4,
                        bloom="apply", difficulty="medium", render_mode=RenderMode.DETERMINISTIC,
                        status=status, stem="A resistor of 5 Ω carries 2 A. Find the voltage.",
                        options=options, answer=answer, provenance={"source": source})


class _Scope:
    """Minimal scope stub: everything is in-scope + right subject (isolate objective checks)."""
    subjects = [Subject.PHYSICS]
    exam_profile = "NEET"

    def in_scope(self, code):
        return True


class TestObjectiveViolations(unittest.TestCase):
    SC = _Scope()

    def _violations(self, slot):
        return validate.validate_slot(slot, self.SC)

    def test_wellformed_mcq_passes(self):
        self.assertEqual(self._violations(_mcq(["10 V", "7 V", "12 V", "3 V"], "10 V")), [])

    def test_wrong_option_count_rejected(self):
        for opts in (["10 V", "7 V", "12 V"], ["10 V", "7 V", "12 V", "3 V", "1 V"], None):
            v = self._violations(_mcq(opts, "10 V"))
            self.assertTrue(any("BAD_OPTION_COUNT" in x for x in v), opts)

    def test_duplicate_options_rejected(self):
        v = self._violations(_mcq(["10 V", "10 V", "7 V", "12 V"], "10 V"))
        self.assertTrue(any("DUPLICATE_OPTIONS" in x for x in v))

    def test_blank_option_rejected(self):
        v = self._violations(_mcq(["10 V", "", "7 V", "12 V"], "10 V"))
        self.assertTrue(any("MALFORMED_OPTION" in x for x in v))

    def test_answer_not_in_options_rejected(self):
        v = self._violations(_mcq(["7 V", "12 V", "3 V", "1 V"], "10 V"))
        self.assertTrue(any("ANSWER_NOT_IN_OPTIONS" in x for x in v))

    def test_no_answer_rejected(self):
        v = self._violations(_mcq(["10 V", "7 V", "12 V", "3 V"], ""))
        self.assertTrue(any("NO_ANSWER" in x for x in v))

    def test_numerical_needs_answer(self):
        slot = _mcq(None, "")
        slot.question_type = QuestionType.NUMERICAL
        self.assertTrue(any("NO_ANSWER" in x for x in self._violations(slot)))

    def test_spec_objective_is_not_option_checked(self):
        # a SPEC objective item has no options yet (authoring placeholder) → not option-validated
        self.assertEqual(self._violations(_mcq(None, None, status=SlotStatus.SPEC)), [])


class TestRealTemplatesPassTheGate(unittest.TestCase):
    def test_every_template_mcq_passes_objective_validation(self):
        sc = _Scope()
        for tmpl in templates.REGISTRY:
            if QuestionType.MCQ not in tmpl.types:
                continue
            for seed in range(10):
                out = templates.instantiate(tmpl, "C_" + tmpl.template_id, seed, QuestionType.MCQ)
                slot = _mcq(out["options"], out["answer"])
                self.assertEqual(validate.validate_slot(slot, sc), [], (tmpl.template_id, out))


class TestSameGateForAi(unittest.TestCase):
    """A gated-AI MCQ is validated by the SAME objective gate; malformed AI output is rejected."""
    def test_malformed_ai_mcq_is_rejected(self):
        sc = _Scope()
        ai_bad = _mcq(["A", "B", "C"], "A", source="ai")     # only 3 options from an AI provider
        self.assertTrue(any("BAD_OPTION_COUNT" in x for x in validate.validate_slot(ai_bad, sc)))
        ai_bad2 = _mcq(["A", "B", "C", "D"], "Z", source="ai")  # answer not among options
        self.assertTrue(any("ANSWER_NOT_IN_OPTIONS" in x for x in validate.validate_slot(ai_bad2, sc)))

    def test_wellformed_ai_mcq_passes(self):
        sc = _Scope()
        ai_ok = _mcq(["A", "B", "C", "D"], "B", source="ai")
        # (grounding for ai source requires the stem to mention the concept; use a stub scope +
        # a stem that names the concept)
        ai_ok.stem = "Which of the following about Ohm's law is correct?"
        self.assertEqual(validate.validate_slot(ai_ok, sc), [])


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
    for qt in ("mcq", "numerical"):
        conn.execute(
            "INSERT INTO question_patterns(pattern_id,concept_code,question_type,bloom,difficulty,"
            "frequency,years,evidence) VALUES (?,?,?,?,?,?,?,?)",
            (f"{code}_{qt}", code, qt, "apply", "medium", 4, "[2023]", "{}"))


class TestEndToEndNoMalformedObjectiveShips(unittest.TestCase):
    def test_generated_paper_has_no_malformed_objective(self):
        conn = store.open_store(":memory:")
        # concepts that DO bind templates → real FILLED objective items in the paper
        for i, t in enumerate(("Ohm's law", "Newton's Second Law", "Mole Concept",
                               "Kinetic Energy", "Pythagoras Theorem")):
            _seed(conn, f"C_{i}", t, Subject.PHYSICS if i < 4 else Subject.CHEMISTRY)
        conn.commit()
        eng = QuestionPaperEngine(conn=conn)
        for seed in range(6):
            paper = eng.generate(PaperRequest(exam="FOUNDATION", blueprint_preset="mixed_50", seed=seed))
            for s in paper.slots:
                if s.status == SlotStatus.FILLED and s.question_type == QuestionType.MCQ:
                    self.assertEqual(validate._objective_violations(s), [], (seed, s.stem))
        conn.close()


if __name__ == "__main__":
    unittest.main()
