"""Tier-2 model-verification lane — caching, candidate selection, fact aggregation (no model call)."""
import unittest

from kie.qie import store as qstore, tier2_verify as T2, mine


class TestTier2Cache(unittest.TestCase):
    def setUp(self):
        self.q = qstore.open_store(":memory:")

    def test_verdict_cache_and_aggregation(self):
        T2.record_verdict(self.q, "h1", "fkA", "Biology", "agree", "opus", "", "t")
        T2.record_verdict(self.q, "h2", "fkB", "Biology", "agree", "opus", "", "t")
        T2.record_verdict(self.q, "h3", "fkB", "Biology", "disagree", "opus", "", "t")  # fkB has a disagree
        T2.record_verdict(self.q, "h4", "fkC", "Biology", "unverifiable", "opus", "", "t")
        vf = T2.tier2_verified_facts(self.q)
        self.assertIn("fkA", vf)          # agree, no disagree
        self.assertNotIn("fkB", vf)       # has a disagree -> not verified (strict)
        self.assertNotIn("fkC", vf)       # only unverifiable
        stats = T2.agreement_stats(self.q, "Biology")
        self.assertEqual((stats["agree"], stats["disagree"], stats["unverifiable"]), (2, 1, 1))

    def test_cached_hashes(self):
        T2.record_verdict(self.q, "h1", "fk", "Biology", "agree", "m", "", "t")
        self.assertEqual(T2.cached_hashes(self.q), {"h1"})


class TestCandidateSelection(unittest.TestCase):
    def test_only_distinct_nonnumeric_resolved_biology(self):
        by_title = {"photosynthesis": "BIO_PHOTOSYNTHESIS", "nephron": "BIO_NEPHRON"}
        items = [
            {"subject": "Biology", "stem": "Why does photosynthesis stop in the dark?",
             "options": {"a": "no light", "b": "x"}, "answer_text": "no light", "doc_id": "d1"},
            {"subject": "Biology", "stem": "Why does photosynthesis stop in the dark?",   # duplicate fact
             "options": {"a": "no light", "b": "x"}, "answer_text": "no light", "doc_id": "d2"},
            {"subject": "Biology", "stem": "Compute 2+2 in nephron count?",               # numeric -> skip
             "options": {"a": "4"}, "answer_text": "4", "doc_id": "d3"},
            {"subject": "Physics", "stem": "Why does current flow?", "options": {"a": "emf"},
             "answer_text": "emf", "doc_id": "d4"},                                        # wrong subject
        ]
        cands = T2.collect_candidates(items, by_title, verified_facts=set(), subject="Biology")
        self.assertEqual(len(cands), 1)   # only the distinct resolved non-numeric Biology fact
        c = list(cands.values())[0]
        self.assertEqual(c["concept"], "BIO_PHOTOSYNTHESIS")

    def test_already_kvs_verified_excluded(self):
        by_title = {"photosynthesis": "BIO_PHOTOSYNTHESIS"}
        item = {"subject": "Biology", "stem": "Why does photosynthesis stop in the dark?",
                "options": {"a": "no light"}, "answer_text": "no light", "doc_id": "d1"}
        fk = mine.fact_key("BIO_PHOTOSYNTHESIS", "no light")
        cands = T2.collect_candidates([item], by_title, verified_facts={fk}, subject="Biology")
        self.assertEqual(len(cands), 0)   # already KVS-verified -> not a Tier-2 candidate


if __name__ == "__main__":
    unittest.main()
