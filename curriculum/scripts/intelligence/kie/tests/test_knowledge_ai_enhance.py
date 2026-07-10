"""Knowledge Layer Phase 5 — optional AI-enhanced generation (curate.ai_enhance / ai_provider / ai_cache).

Locks the Phase-5 contract end to end through the knowledge-layer runner:
  * ZERO AI unless opt-in AND KIE_AI_AUTHORIZED=1 AND a provider — otherwise byte-identical to
    the deterministic engine (AI is optional, never mandatory);
  * AI output flows through the engine's SAME validation gate (ungrounded/out-of-syllabus junk
    is rejected, never shipped);
  * the provider is called at most once per distinct spec, and a persistent cache carries that
    across runs (minimal API calls);
  * the NullProvider default makes the whole path a no-op.
"""
import os
import unittest

from kie import store
from kie.curate import ai_cache, ai_enhance
from kie.curate.ai_provider import GovernedAiProvider, NullProvider
from kie.qpgen.engine import QuestionPaperEngine
from kie.qpgen.models import PaperRequest
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
        " VALUES (?,?,?,?,?,?,?,?)", (code + "_p", code, "mcq", "apply", "medium", 5, "[2023]", "{}"))


def _bio_kie():
    conn = store.open_store(":memory:")
    topics = ["Photosynthesis", "Human Digestion", "Cell Structure", "Blood Circulation",
              "Genetic Inheritance", "Nervous Coordination", "Plant Transpiration",
              "Ecosystem Dynamics", "Enzyme Action", "Reproductive System", "Excretion in Humans",
              "Photorespiration"]
    for i, t in enumerate(topics):
        _seed(conn, f"BIO_{i}", t, "Biology")
    conn.commit()
    return conn


class _CountingProvider:
    """Governed provider that authors a grounded, well-formed MCQ and counts calls."""
    def __init__(self):
        self.calls = 0

    def author(self, spec):
        self.calls += 1
        return {"stem": f"Which of the following statements about {spec['concept_title']} is correct?",
                "answer": "Statement I only",
                "options": ["Statement I only", "Statement II only", "Both I and II", "Neither I nor II"],
                "solution": "Statement I only is correct."}


def _req(**kw):
    return PaperRequest(exam="NEET", subjects=("Biology",), blueprint_preset="objective_45", **kw)


class AiGatingTest(unittest.TestCase):
    def setUp(self):
        self._prev = os.environ.pop("KIE_AI_AUTHORIZED", None)
        self.conn = _bio_kie()

    def tearDown(self):
        if self._prev is not None:
            os.environ["KIE_AI_AUTHORIZED"] = self._prev
        else:
            os.environ.pop("KIE_AI_AUTHORIZED", None)
        self.conn.close()

    def _render(self, paper):
        return QuestionPaperEngine(conn=self.conn).render_json(paper)

    def test_no_provider_is_noop_identical_to_engine(self):
        paper = ai_enhance.generate(_req(seed=1), conn=self.conn)
        eng = QuestionPaperEngine(conn=self.conn).generate(_req(seed=1))
        # identical paper content (the only added field is the 'ai' provenance marker)
        a, b = self._render(paper), self._render(eng)
        self.assertEqual(a["questions"], b["questions"])
        self.assertEqual((paper.total_questions, paper.total_marks, paper.filled, paper.spec_only),
                         (eng.total_questions, eng.total_marks, eng.filled, eng.spec_only))
        self.assertFalse(paper.provenance["ai"]["enabled"])

    def test_optin_without_authorization_makes_zero_ai_calls(self):
        prov = _CountingProvider()
        paper = ai_enhance.generate(_req(seed=1, allow_ai_fill=True), conn=self.conn, provider=prov)
        self.assertEqual(prov.calls, 0)                      # not authorized → no AI
        self.assertFalse(paper.provenance["ai"]["enabled"])

    def test_authorized_optin_with_provider_fills_specs(self):
        os.environ["KIE_AI_AUTHORIZED"] = "1"
        prov = _CountingProvider()
        paper = ai_enhance.generate(_req(seed=1, allow_ai_fill=True), conn=self.conn, provider=prov)
        self.assertTrue(paper.provenance["ai"]["enabled"])
        self.assertGreater(prov.calls, 0)                    # AI authored at least one spec
        self.assertGreater(paper.provenance["ai"]["detail"].get("filled", 0), 0)

    def test_null_provider_is_noop_even_when_authorized(self):
        os.environ["KIE_AI_AUTHORIZED"] = "1"
        paper = ai_enhance.generate(_req(seed=1, allow_ai_fill=True), conn=self.conn, provider=NullProvider())
        # NullProvider declines all → nothing filled by AI
        self.assertEqual(paper.provenance["ai"]["detail"].get("filled", 0), 0)


class AiCacheTest(unittest.TestCase):
    def setUp(self):
        self._prev = os.environ.get("KIE_AI_AUTHORIZED")
        os.environ["KIE_AI_AUTHORIZED"] = "1"
        self.conn = _bio_kie()

    def tearDown(self):
        if self._prev is None:
            os.environ.pop("KIE_AI_AUTHORIZED", None)
        else:
            os.environ["KIE_AI_AUTHORIZED"] = self._prev
        self.conn.close()

    def test_persistent_cache_reused_across_runs(self):
        import tempfile
        from pathlib import Path
        with tempfile.TemporaryDirectory() as d:
            cache = ai_cache.PersistentSpecCache(Path(d) / "c.json")
            prov = _CountingProvider()
            ai_enhance.generate(_req(seed=1, allow_ai_fill=True), conn=self.conn, provider=prov, cache=cache)
            first_calls = prov.calls
            self.assertGreater(first_calls, 0)
            self.assertTrue((Path(d) / "c.json").exists())      # persisted
            # a fresh cache loaded from the SAME file, same specs → no new provider calls
            cache2 = ai_cache.PersistentSpecCache(Path(d) / "c.json")
            prov2 = _CountingProvider()
            ai_enhance.generate(_req(seed=1, allow_ai_fill=True), conn=self.conn, provider=prov2, cache=cache2)
            self.assertEqual(prov2.calls, 0)                    # fully served from persistent cache

    def test_rogue_ai_output_is_rejected_not_shipped(self):
        class _Rogue:
            def author(self, spec):
                return {"stem": "Compute the tax liability under section 80C.", "answer": "x"}
        paper = ai_enhance.generate(_req(seed=2, allow_ai_fill=True), conn=self.conn, provider=_Rogue())
        # ungrounded/out-of-syllabus stem must never appear in the shipped paper
        blob = QuestionPaperEngine(conn=self.conn).render_markdown(paper)
        self.assertNotIn("tax liability", blob.lower())


class GovernedProviderTest(unittest.TestCase):
    def test_grounding_gate_drops_ungrounded_stem(self):
        prov = GovernedAiProvider(lambda spec: {"stem": "An unrelated sentence.", "answer": "y"})
        self.assertIsNone(prov.author({"concept_title": "Photosynthesis"}))

    def test_grounded_stem_passes(self):
        prov = GovernedAiProvider(
            lambda spec: {"stem": f"Explain {spec['concept_title']} briefly.", "answer": "y"})
        out = prov.author({"concept_title": "Photosynthesis"})
        self.assertIsNotNone(out)
        self.assertIn("Photosynthesis", out["stem"])

    def test_null_provider_declines(self):
        self.assertIsNone(NullProvider().author({"concept_title": "X"}))


if __name__ == "__main__":
    unittest.main()
