"""KVS v0 seed — filters junk endpoints, honest evidence counting. Temp DBs only."""
import sqlite3
import unittest

from kie.qie import store as qstore, kvs_seed


def _fake_kie():
    conn = sqlite3.connect(":memory:")
    conn.execute("CREATE TABLE concepts(concept_code TEXT PRIMARY KEY, title TEXT, subject_domain TEXT, status TEXT, reference_facts TEXT)")
    conn.execute("CREATE TABLE concept_edges(from_concept TEXT, relationship_type TEXT, to_concept TEXT, strength REAL, notes TEXT, evidence TEXT)")
    conn.executemany("INSERT INTO concepts VALUES (?,?,?,?,?)", [
        ("BIO_MITOCHONDRION", "Mitochondrion", "Biology", "active", None),
        ("BIO_ORGANELLE", "Organelle", "Biology", "active", None),
        ("PHY_BERNOULLI", "Bernoulli's principle", "Physics", "active", '[{"expression":"Bernoulli principle","kind":"principle"}]'),
        ("BIO_JUNK", "Keep the curiosity alive", "Biology", "rejected", None),  # quarantined
    ])
    conn.executemany("INSERT INTO concept_edges VALUES (?,?,?,?,?,?)", [
        ("BIO_MITOCHONDRION", "parent_child", "BIO_ORGANELLE", 1.0, None, "doc1"),  # both active -> seed
        ("BIO_MITOCHONDRION", "related", "BIO_JUNK", 1.0, None, "doc2"),            # junk endpoint -> skip
    ])
    conn.commit()
    return conn


class TestKvsSeed(unittest.TestCase):
    def setUp(self):
        self.kie = _fake_kie()
        self.qie = qstore.open_store(":memory:")

    def test_edges_skip_junk_endpoint(self):
        res = kvs_seed.seed_assertions_from_edges(self.kie, self.qie, "t")
        self.assertEqual(res["assertions_seeded"], 1)          # only the both-active edge
        self.assertEqual(res["edges_skipped_junk_endpoint"], 1)

    def test_taxonomy_from_parent_child(self):
        res = kvs_seed.seed_taxonomy_from_parent_child(self.kie, self.qie, "t")
        self.assertEqual(res["taxonomy_rows_seeded"], 1)
        row = self.qie.execute("SELECT class_name, member FROM kvs_taxonomy").fetchone()
        self.assertEqual((row[0], row[1]), ("Organelle", "Mitochondrion"))  # child is-a member of parent

    def test_reference_facts_seed_weak_assertions(self):
        res = kvs_seed.seed_reference_facts(self.kie, self.qie, "t")
        self.assertEqual(res["reference_fact_assertions"], 1)
        row = self.qie.execute("SELECT predicate, object_term, evidence_count FROM kvs_assertion WHERE concept_code='PHY_BERNOULLI'").fetchone()
        self.assertEqual(row[0], "has_principle")
        self.assertEqual(row[2], 1)   # single-source -> not yet promotable

    def test_seed_all_reports_promotable_honestly(self):
        res = kvs_seed.seed_all(self.kie, self.qie, "t")
        self.assertIn("kvs_assertions_total", res)
        self.assertIn("kvs_assertions_promotable_ge2_evidence", res)
        # all our fixtures are single-source, so promotable count is 0 (honest thinness)
        self.assertEqual(res["kvs_assertions_promotable_ge2_evidence"], 0)


if __name__ == "__main__":
    unittest.main()
