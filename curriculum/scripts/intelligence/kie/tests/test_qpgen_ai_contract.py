"""QP engine R8 — validated, cached AI-fill contract (with a FAKE provider; no real API).

Proves: AI runs only when authorized + provider wired; output is CACHED by spec-hash (minimal
calls); AI questions pass the SAME validation gate as everything else, and invalid AI output is
rejected — never shipped. The deterministic template layer is preferred first."""
import os
import unittest

from kie import store
from kie.qpgen import materialize, scope, validate
from kie.qpgen.materialize import AiFillGatedError, AiProviderNotWired
from kie.qpgen.models import (Blueprint, BlueprintCell, PaperRequest, QuestionSlot,
                              QuestionType, RenderMode, SlotStatus, Subject)
from kie.intake.store_ext import now_iso


def _slot(n, code, title, subject, qtype=QuestionType.MCQ):
    return QuestionSlot(number=n, section="A", concept_code=code, concept_title=title, subject=subject,
                        question_type=qtype, marks=4, bloom="apply", difficulty="medium",
                        render_mode=RenderMode.SPEC_ONLY, status=SlotStatus.SPEC,
                        provenance={"exam": "NEET"})


class _CountingProvider:
    """A fake governed provider that returns a canned original question and counts calls."""
    def __init__(self):
        self.calls = 0

    def author(self, spec):
        self.calls += 1
        # a well-formed MCQ: exactly four distinct options with the answer among them
        # (what a governed provider must return to pass the objective-validation gate).
        return {"stem": f"Which statement about {spec['concept_title']} is correct?",
                "answer": "Statement I only",
                "options": ["Statement I only", "Statement II only",
                            "Both I and II", "Neither I nor II"],
                "solution": "Statement I only is correct."}


class _RogueProvider:
    """A provider that returns out-of-syllabus junk — the gate must reject it."""
    def author(self, spec):
        return {"stem": "Compute the tax liability under section 80C.", "answer": "x"}


class TestAiContract(unittest.TestCase):
    def setUp(self):
        self._prev = os.environ.get("KIE_AI_AUTHORIZED")
        self.conn = store.open_store(":memory:")

    def tearDown(self):
        if self._prev is None:
            os.environ.pop("KIE_AI_AUTHORIZED", None)
        else:
            os.environ["KIE_AI_AUTHORIZED"] = self._prev
        self.conn.close()

    def test_gated_without_authorization(self):
        os.environ.pop("KIE_AI_AUTHORIZED", None)
        with self.assertRaises(AiFillGatedError):
            materialize.ai_fill([_slot(1, "BIO_A", "Photosynthesis", Subject.BIOLOGY)],
                                provider=_CountingProvider())

    def test_authorized_but_no_provider_raises(self):
        os.environ["KIE_AI_AUTHORIZED"] = "1"
        with self.assertRaises(AiProviderNotWired):
            materialize.ai_fill([_slot(1, "BIO_A", "Photosynthesis", Subject.BIOLOGY)], provider=None)

    def test_ai_output_is_cached_by_spec_hash(self):
        os.environ["KIE_AI_AUTHORIZED"] = "1"
        prov = _CountingProvider()
        cache = {}
        slots = [_slot(1, "BIO_A", "Photosynthesis", Subject.BIOLOGY)]
        materialize.ai_fill(slots, provider=prov, cache=cache)
        # a second identical spec reuses the cache → no extra provider call (minimize AI calls)
        slots2 = [_slot(2, "BIO_A", "Photosynthesis", Subject.BIOLOGY)]
        out = materialize.ai_fill(slots2, provider=prov, cache=cache)
        self.assertEqual(prov.calls, 1)                 # cached, not re-called
        self.assertEqual(out["cache_hits"], 1)
        self.assertEqual(slots2[0].status, SlotStatus.FILLED)
        self.assertEqual(slots2[0].provenance["source"], "ai")

    def test_ai_output_passes_same_validation_gate(self):
        # seed an in-scope concept so scope contains BIO_A
        self.conn.execute(
            "INSERT INTO source_documents(doc_id,corpus,rel_path,category,exam,sha256,integrity_ok,encrypted,"
            "is_duplicate,verify_status,certify_status,certify_reason,created_at) "
            "VALUES ('BIO_A_d','foundation','NEET/x.pdf','NEET','NEET','s',1,0,0,'verified','certified','ok',?)",
            (now_iso(),))
        self.conn.execute(
            "INSERT INTO concepts(concept_code,title,definition,subject_domain,status,evidence,created_at) "
            "VALUES ('BIO_A','Photosynthesis','','Biology','active','{\"doc\":\"BIO_A_d\"}',?)", (now_iso(),))
        self.conn.execute(
            "INSERT INTO question_patterns(pattern_id,concept_code,question_type,bloom,difficulty,frequency,years,evidence)"
            " VALUES ('p','BIO_A','mcq','apply','medium',3,'[2023]','{}')")
        self.conn.commit()
        sc = scope.resolve_scope(self.conn, PaperRequest(exam="NEET", subjects=("Biology",)))
        bp = Blueprint("t", cells=[BlueprintCell("A", QuestionType.MCQ, 4, 1)])

        os.environ["KIE_AI_AUTHORIZED"] = "1"
        # good AI question → validates and ships
        good = [_slot(1, "BIO_A", "Photosynthesis", Subject.BIOLOGY)]
        materialize.ai_fill(good, provider=_CountingProvider(), cache={})
        rep = validate.validate_paper(good, bp, sc)
        self.assertTrue(rep.ok)
        self.assertEqual(good[0].status, SlotStatus.FILLED)

        # rogue out-of-syllabus AI question on an OUT-OF-SCOPE concept → gate rejects it
        rogue = [_slot(1, "FIN_XX", "Income Tax", "Commerce")]
        materialize.ai_fill(rogue, provider=_RogueProvider(), cache={})
        rep2 = validate.validate_paper(rogue, bp, sc)
        self.assertFalse(rep2.ok)
        self.assertEqual(rogue[0].status, SlotStatus.REJECTED)   # never shipped


if __name__ == "__main__":
    unittest.main()
