"""KVS v1 build — semantic-answer / resolved-concept filters that prevent over-corroboration."""
import sqlite3
import unittest

from kie.qie import mine, store as qstore, kvs_build


class TestFilters(unittest.TestCase):
    def test_semantic_answer_rejects_option_labels(self):
        for bad in ("a-ii, b-i, c-iv, d-iii", "a, b, c only", "both a and b", "all of the above",
                    "a", "iii", "1 and 3", "none of these"):
            self.assertFalse(mine.is_semantic_answer(bad), bad)
        for good in ("mitochondrion", "proximal convoluted tubule", "increases with temperature"):
            self.assertTrue(mine.is_semantic_answer(good), good)

    def test_resolved_concept_rejects_coarse_bucket(self):
        self.assertTrue(mine.is_resolved_concept("BIO_NEPHRON"))
        self.assertFalse(mine.is_resolved_concept("Biology:cell"))


def _corpus_with_repeated_fact():
    conn = sqlite3.connect(":memory:")
    conn.execute("CREATE TABLE concepts(concept_code TEXT, title TEXT, subject_domain TEXT, status TEXT)")
    conn.execute("INSERT INTO concepts VALUES ('BIO_NEPHRON','nephron','Biology','active')")
    conn.execute("CREATE TABLE chunks(chunk_id TEXT, doc_id TEXT, text TEXT)")
    stem = ("1. In a nephron, which structure reabsorbs glucose?\n"
            "(1) Proximal convoluted tubule (2) Glomerulus (3) Loop of Henle (4) Collecting duct\nAnswer (1)\n")
    # same fact in 3 distinct docs -> promotable; plus an option-label fact that must NOT promote
    conn.executemany("INSERT INTO chunks VALUES (?,?,?)", [
        ("c1", "docA", stem), ("c2", "docB", stem), ("c3", "docC", stem),
        ("c4", "docA", "2. Match: which set is correct?\n(1) a-i (2) a-ii, b-i (3) a, b only (4) none\nAnswer (2)\n"),
        ("c5", "docB", "3. Match: which set is correct?\n(1) a-i (2) a-ii, b-i (3) a, b only (4) none\nAnswer (2)\n"),
    ])
    conn.commit()
    return conn


class TestKvsBuild(unittest.TestCase):
    def test_only_semantic_resolved_facts_promote(self):
        kie = _corpus_with_repeated_fact()
        q = qstore.open_store(":memory:")
        res = kvs_build.build_from_corpus(kie, q, "t")
        # the glucose/nephron fact (3 docs, semantic, resolved concept) promotes; the option-label one does not
        self.assertEqual(res["promotable_ge2docs"], 1)
        vf = kvs_build.promotable_fact_keys(q)
        self.assertEqual(len(vf), 1)


if __name__ == "__main__":
    unittest.main()
