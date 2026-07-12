"""Phase C slice 3 — corrected mining/grouping path: lane != archetype, profile preserved, group by
(subject, profile, concept, archetype), verification per-lane, profile-invalid cannot certify."""
import sqlite3
import unittest

from kie.qie import capability, store as qstore


def _kie():
    c = sqlite3.connect(":memory:")
    c.execute("CREATE TABLE concepts(concept_code TEXT, title TEXT, subject_domain TEXT, status TEXT)")
    c.execute("INSERT INTO concepts VALUES ('BIO_HUMAN_ENDOCRINE_SYSTEM','Human Endocrine System','Biology','active')")
    c.execute("CREATE TABLE source_documents(doc_id TEXT, exam TEXT)")
    c.execute("CREATE TABLE chunks(doc_id TEXT, text TEXT)")
    c.commit()
    return c


def _item(stem, ans, doc, source):
    return ({"stem": stem, "answer_text": ans, "options": {"1": ans, "2": "x"}, "subject": "Biology",
             "doc_id": doc, "source": source}, "NEET")


class TestCapability(unittest.TestCase):
    def setUp(self):
        self.k = _kie()
        self.q = qstore.open_store(":memory:")
        # resolver that resolves the endocrine entity, else None
        self.resolver = lambda stem, ans, subj: (
            "BIO_HUMAN_ENDOCRINE_SYSTEM" if any(w in (stem + " " + (ans or "")).lower()
            for w in ("glucagon", "insulin", "hormone", "adrenaline", "cortisol", "thyroxine")) else None)

    def test_schema_has_assessment_profile(self):
        cols = {r[1] for r in self.q.execute("PRAGMA table_info(question_dna)")}
        self.assertIn("assessment_profile", cols)
        self.assertIn("archetype", cols)

    def test_lane_and_archetype_independent_and_profile_preserved(self):
        # 5 distinct endocrine factual-recall questions from 3 docs, NEET profile (clean of causal markers)
        stream = [
            _item("Hypoglycemic hormone is", "Insulin", "d1", "NEET"),
            _item("The hormone secreted by adrenal medulla is", "adrenaline", "d2", "NEET"),
            _item("The anti-insulin hormone is", "cortisol", "d3", "NEET"),
            _item("The hormone increasing basal metabolic rate is", "thyroxine", "d1", "NEET"),
            _item("Blood glucose is raised by the hormone", "Glucagon", "d2", "NEET"),
        ]
        res = capability.mine_capability(self.k, self.q, "t", self.resolver, min_res=2, stream=stream)
        rows = list(self.q.execute("SELECT lane, archetype, assessment_profile FROM question_dna"))
        self.assertTrue(rows)
        for lane, archetype, profile in rows:
            self.assertNotEqual(lane, archetype)                 # axes are independent (not archetype=lane)
            self.assertEqual(archetype, "factual_single_best_answer")
            self.assertEqual(lane, "CONCEPTUAL_CAUSAL")          # its verification lane
            self.assertEqual(profile, "NEET")
        # grouped by (subject, profile, concept, archetype)
        m = [x for x in res["models"] if x["concept"] == "BIO_HUMAN_ENDOCRINE_SYSTEM"]
        self.assertTrue(m and m[0]["archetype"] == "factual_single_best_answer" and m[0]["profile"] == "NEET")

    def test_profile_invalid_archetype_cannot_certify(self):
        # same factual-recall evidence but under JEE_MAIN, where factual_single_best_answer is NOT valid
        stream = [(dict(it, subject="Biology"), "JEE_MAIN") for it, _ in [
            _item("Hypoglycemic hormone is", "Insulin", "d1", "x"),
            _item("The hormone secreted by adrenal medulla is", "adrenaline", "d2", "x"),
            _item("The anti-insulin hormone is", "cortisol", "d3", "x"),
            _item("The hormone increasing basal metabolic rate is", "thyroxine", "d1", "x"),
            _item("Blood glucose is raised by the hormone", "Glucagon", "d2", "x")]]
        res = capability.mine_capability(self.k, self.q, "t", self.resolver, min_res=2, stream=stream)
        endo = [m for m in res["models"] if m["concept"] == "BIO_HUMAN_ENDOCRINE_SYSTEM"]
        self.assertTrue(endo)
        self.assertFalse(endo[0]["profile_valid"])   # factual recall invalid for JEE_MAIN
        self.assertFalse(endo[0]["certifiable"])      # so it cannot certify

    def test_replication_is_not_genuine(self):
        # one question replicated across 6 docs: qualifies on n_dna but NOT genuine (1 distinct stem)
        stream = [_item("Glycogen is converted to glucose by", "Glucagon", f"d{i}", "NEET") for i in range(6)]
        res = capability.mine_capability(self.k, self.q, "t", self.resolver, min_res=2, stream=stream)
        endo = [m for m in res["models"] if m["concept"] == "BIO_HUMAN_ENDOCRINE_SYSTEM"]
        self.assertTrue(endo)
        self.assertEqual(endo[0]["distinct_stems"], 1)
        self.assertFalse(endo[0]["genuine"])          # replication != genuine support
        self.assertFalse(endo[0]["certifiable"])


if __name__ == "__main__":
    unittest.main()
