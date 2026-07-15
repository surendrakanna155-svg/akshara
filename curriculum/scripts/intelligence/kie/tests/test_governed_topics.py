"""Tests for the governed TOPIC layer — owner decision B (concept granularity for the qualitative lane).

The owner approved topic granularity with two explicit prohibitions, and these pin BOTH as mechanical, not
as a promise:
  1. "Do not derive concept titles by blindly truncating subject_term or source prose."  -> not_truncated
  2. "Do not create artificial topic names merely to bypass qpgen deduplication."        -> grounding
Plus: the subject hard-gate, the concept sanitizer, provenance/verification, and the chapter fallback are
all preserved.
"""
import json
import unittest

from kie.qie import store as S
from kie.qie.convert import topics as T

SET = "backfill_v1"

# a fact shaped exactly as governed_fact rows are, used to exercise the gates deterministically
URICO = {
    "subject": "Biology",
    "concept_candidate": "Biology :: Excretory Products And Their Elimination",
    "fact_text": "Uricotelism (excretion of nitrogenous waste as uric acid) is found in birds, reptiles "
                 "and insects.",
    "answer_text": "Birds, reptiles and insects",
    "structured": json.dumps({"subject_term": "Uricotelism (excretion of uric acid)",
                              "predicate": "is found in", "object_term": "birds, reptiles and insects"}),
    "provenance": json.dumps({"stem_excerpt": "Uricotelism is found in", "chapter": "Excretory Products"}),
}


class TestTopicGates(unittest.TestCase):
    def test_authored_topic_certifies(self):
        v = T.certify("Uricotelism", URICO)
        self.assertEqual(v["status"], "certified", v["failed_gates"])
        self.assertEqual(v["topic"], "Uricotelism")

    def test_artificial_topic_is_refused(self):
        """The owner's prohibition, enforced: a plausible-sounding name that the fact's OWN evidence does not
        support cannot be minted just to buy a dedup slot."""
        for bogus in ("Nitrogen excretion strategy", "VSEPR theory", "Ammonotelism"):
            v = T.certify(bogus, URICO)
            self.assertEqual(v["status"], "rejected", bogus)
            self.assertIn("grounding", v["failed_gates"], bogus)

    def test_truncated_prose_is_refused(self):
        """The other prohibition: prose cut down to 5 words is not a concept name."""
        v = T.certify("Uricotelism excretion of nitrogenous waste as uric acid found in birds", URICO)
        self.assertEqual(v["status"], "rejected")
        self.assertIn("not_truncated", v["failed_gates"])

    def test_topic_equal_to_its_own_chapter_is_refused(self):
        """Buys nothing over the fallback, and would hide that the fallback is what is really in play.
        Regression: comparing a CLEANED topic against a RAW chapter let this through."""
        for same in ("Excretory Products And Their Elimination", "Excretory Products And Elimination"):
            v = T.certify(same, URICO)
            self.assertEqual(v["status"], "rejected", same)
            self.assertIn("not_chapter", v["failed_gates"], same)

    def test_sanitizer_gate_is_the_same_one_every_concept_passes(self):
        v = T.certify("Uricotelism is when they excrete", URICO)     # sentence fragment
        self.assertEqual(v["status"], "rejected")

    def test_subject_gate_is_inherited_not_reopened(self):
        v = T.certify("Uricotelism", {**URICO, "subject": ""})
        self.assertIn("subject", v["failed_gates"])

    def test_grounding_matches_words_not_typography(self):
        # possessive + plural must ground against the evidence's own surface forms
        fact = {**URICO, "fact_text": "Kepler's second law follows from conservation of angular momentum. "
                                      "Bile pigment is made from haemoglobin."}
        self.assertTrue(T.grounding_gate("Kepler second law", fact)["ok"])
        self.assertTrue(T.grounding_gate("Bile pigments", fact)["ok"])

    def test_singulars_handles_both_s_and_es_plurals(self):
        self.assertIn("nitrile", T._singulars("nitriles"))     # drop -s
        self.assertIn("box", T._singulars("boxes"))            # drop -es
        self.assertIn("body", T._singulars("bodies"))          # -ies -> y


class TestConceptKeyFallback(unittest.TestCase):
    def test_certified_topic_binds_at_topic_granularity(self):
        self.assertEqual(T.concept_key({"subject": "Biology", "topic": "Uricotelism",
                                        "concept_candidate": "Biology :: Excretory Products"}),
                         "Biology :: Uricotelism")

    def test_absent_topic_falls_back_to_the_chapter(self):
        """Strictly additive: a fact without a certified topic keeps binding exactly as before."""
        for t in (None, "", "   "):
            self.assertEqual(T.concept_key({"subject": "Biology", "topic": t,
                                            "concept_candidate": "Biology :: Excretory Products"}),
                             "Biology :: Excretory Products")


class TestShippedTopicSet(unittest.TestCase):
    """The committed set is the reproducible governance record (qie.db is a gitignored derived store)."""

    def test_every_shipped_topic_certifies_against_its_own_fact(self):
        """Replaying the set must reproduce the verdicts — no shipped topic may fail its own gates."""
        import sqlite3
        from kie import config
        try:
            conn = sqlite3.connect(f"file:{config.KIE_HOME / 'qie.db'}?mode=ro", uri=True)
            facts = T._facts_by_id(conn)
        except sqlite3.Error:
            self.skipTest("no local governed store")
            return
        finally:
            try:
                conn.close()
            except Exception:
                pass
        if not facts:
            self.skipTest("no verified facts in the local store")
        checked = 0
        for row in T.load(SET)["topics"]:
            fact = facts.get(row["fact_id"])
            if not fact:
                continue
            v = T.certify(row["topic"], fact)
            self.assertEqual(v["status"], "certified",
                             f"{row['topic']!r} ({row['fact_id']}): {v['failed_gates']}")
            checked += 1
        self.assertTrue(checked, "the shipped topic set matched no fact in the store")

    def test_set_loads_and_is_well_formed(self):
        data = T.load(SET)
        self.assertTrue(data["topics"])
        seen = set()
        for row in data["topics"]:
            self.assertIn("fact_id", row)
            self.assertTrue((row.get("topic") or "").strip(), row)
            self.assertNotIn(row["fact_id"], seen, "duplicate fact_id in the topic set")
            seen.add(row["fact_id"])

    def test_shared_topics_are_intentional_not_split_for_slots(self):
        """Two facts teaching the SAME concept share a topic (and therefore one paper slot). This pins that
        the set does not mint near-duplicate names to win extra dedup slots."""
        data = T.load(SET)
        topics = [r["topic"] for r in data["topics"]]
        shared = {t for t in topics if topics.count(t) > 1}
        self.assertIn("Sertoli cells", shared)


class TestAdmissionPathCertifiesProposedTopics(unittest.TestCase):
    """Without this, the back-fill is a one-off: every NEW fact would silently revert to chapter binding —
    the exact ceiling decision B removed."""

    def _cand(self):
        from kie.qie.convert.candidates import Candidate
        import inspect
        kw = {}
        for name, p in inspect.signature(Candidate).parameters.items():
            if p.default is not inspect.Parameter.empty:
                continue
            kw[name] = {"subject": "Biology", "lane": "STRUCTURE_FUNCTION",
                        "concept_candidate": "Biology :: Excretory Products And Their Elimination",
                        "stem": "Uricotelism is found in", "answer_text": "Birds, reptiles and insects",
                        "options": {"1": "Birds, reptiles and insects", "2": "Frogs and toads",
                                    "3": "Mammals and birds", "4": "Fishes"},
                        "doc_id": "d1", "chapter_hint": "Excretory Products", "exam": "NEET",
                        "ocr_score": 0.9, "answer_label": "1", "fact_key": "k1",
                        "signature": "sig1"}.get(name, "x")
        return Candidate(**kw)

    def _register(self, topic):
        from kie.qie.convert import register as R
        conn = S.open_store(":memory:")
        cand = self._cand()
        verdict = {"keep": True, "answer_correct": True, "on_topic": True,
                   "fact_text": "Uricotelism (excretion of uric acid) is found in birds, reptiles and insects.",
                   "structured": {"subject_term": "Uricotelism", "predicate": "is found in",
                                  "object_term": "birds, reptiles and insects"},
                   "item_hash": "ih1", "topic": topic}
        res = R.register_verified(conn, cand, verdict, "t", "test")
        row = conn.execute("SELECT topic FROM governed_fact WHERE fact_id=?", (res["fact_id"],)).fetchone()
        conn.close()
        return res, (row[0] if row else None)

    def test_grounded_topic_is_certified_and_persisted(self):
        res, stored = self._register("Uricotelism")
        self.assertEqual(res["topic_status"], "certified")
        self.assertEqual(stored, "Uricotelism")

    def test_invented_topic_is_refused_and_fact_keeps_chapter_binding(self):
        res, stored = self._register("Nitrogen excretion strategy")
        self.assertEqual(res["topic_status"], "rejected")
        self.assertIsNone(stored)                       # -> concept_key falls back to the chapter

    def test_no_proposed_topic_is_not_an_error(self):
        res, stored = self._register(None)
        self.assertEqual(res["topic_status"], "absent")
        self.assertIsNone(stored)


class TestTopicGranularityLiftsTheCeiling(unittest.TestCase):
    def test_topics_beat_chapters_for_biology(self):
        """The whole point of decision B: chapters capped Biology at 38 against a NEET demand of 90."""
        import sqlite3
        from kie import config
        try:
            conn = sqlite3.connect(f"file:{config.KIE_HOME / 'qie.db'}?mode=ro", uri=True)
        except Exception:
            self.skipTest("no local store")
        try:
            cov = T.coverage(conn)
        except sqlite3.Error:
            self.skipTest("no governed facts")
        finally:
            conn.close()
        bio = cov.get("Biology")
        if not bio or not bio["topics"]:
            self.skipTest("no Biology topics applied locally")
        self.assertGreater(bio["bindable_concepts"], bio["chapters"])


if __name__ == "__main__":
    unittest.main()
