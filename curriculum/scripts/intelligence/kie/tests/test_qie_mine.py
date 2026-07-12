"""Phase-B miner — recovery, lane classification, numeric DNA + distractor transforms, clustering."""
import sqlite3
import unittest

from kie.qie import store as qstore, mine


class TestRecovery(unittest.TestCase):
    def test_split_and_recover(self):
        text = ("1. A resistor of 30 ohm carries 9 A. Find the voltage.\n(1) 270 (2) 39 (3) 21 (4) 3\nAnswer (1)\n")
        recs = mine.split_and_recover(text)
        self.assertEqual(len(recs), 1)
        self.assertEqual(len(recs[0]["options"]), 4)
        self.assertEqual(recs[0]["key"], 1)

    def test_lane_classification(self):
        self.assertEqual(mine.classify_nonnumeric_lane("Assertion (A): x. Reason (R): y."), "ASSERTION_RELATION")
        self.assertEqual(mine.classify_nonnumeric_lane("What is the function of the nephron?"), "STRUCTURE_FUNCTION")
        self.assertEqual(mine.classify_nonnumeric_lane("Which of the following is not a metal?"), "CLASSIFICATION_TAXONOMIC")
        self.assertEqual(mine.classify_nonnumeric_lane("random stem"), "CONCEPTUAL_GENERIC")

    def test_distractor_transforms(self):
        opts = {1: "270", 2: "540", 3: "135", 4: "-270"}
        tf = mine.distractor_transforms(270.0, opts, 1)
        kinds = {t["transform"] for t in tf}
        self.assertIn("x2", kinds)       # 540
        self.assertIn("half", kinds)     # 135
        self.assertIn("sign_flip", kinds)  # -270


def _fake_corpus():
    conn = sqlite3.connect(":memory:")
    conn.execute("CREATE TABLE concepts(concept_code TEXT, title TEXT, subject_domain TEXT, status TEXT)")
    conn.execute("INSERT INTO concepts VALUES ('PHY_OHM','Ohms law','Physics','active')")
    conn.execute("CREATE TABLE chunks(chunk_id TEXT, doc_id TEXT, text TEXT)")
    # 6 Ohm items across 3 docs -> should qualify one numeric Item Model (>=5 DNA, >=2 resources)
    items = []
    vals = [(30, 9, 270), (10, 5, 50), (20, 4, 80), (12, 6, 72), (7, 3, 21), (8, 2, 16)]
    for i, (r, cur, v) in enumerate(vals):
        doc = f"doc{i % 3}"
        items.append((f"c{i}", doc,
                      f"1. A resistor of {r} ohm carries a current of {cur} A. Find the voltage.\n"
                      f"(1) {v} (2) {r+cur} (3) {v*2} (4) {abs(r-cur)}\nAnswer (1)\n"))
    conn.executemany("INSERT INTO chunks VALUES (?,?,?)", items)
    conn.commit()
    return conn


class TestMineRun(unittest.TestCase):
    def test_numeric_clustering_and_yield(self):
        kie = _fake_corpus()
        qie = qstore.open_store(":memory:")
        res = mine.run(kie, qie, "t")
        phy = res["per_subject"]["Physics"]
        self.assertGreaterEqual(phy["numeric_verified"], 5)      # V=IR verified independently
        self.assertGreaterEqual(phy["qualified_item_models"], 1)  # the Ohm cluster qualifies
        # DNA + Item Model persisted
        self.assertGreaterEqual(qie.execute("SELECT COUNT(*) FROM question_dna").fetchone()[0], 5)
        self.assertGreaterEqual(qie.execute("SELECT COUNT(*) FROM item_model WHERE n_dna>=5 AND n_resources>=2").fetchone()[0], 1)


if __name__ == "__main__":
    unittest.main()
