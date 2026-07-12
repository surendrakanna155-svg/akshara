"""Concept-canon apply/rollback — reversible, respects review-only rows. Uses temp DBs only."""
import sqlite3
import unittest

from kie.qie import store as qstore, concept_canon as cc


def _fake_kie():
    """A tiny in-memory kie.db-shaped store with a concepts table."""
    conn = sqlite3.connect(":memory:")
    conn.execute("CREATE TABLE concepts(concept_code TEXT PRIMARY KEY, title TEXT, subject_domain TEXT, status TEXT)")
    conn.executemany("INSERT INTO concepts VALUES (?,?,?,?)", [
        ("BIO_CHOOSE_THE_COR", "Choose the correct", "Biology", "active"),   # non_concept fragment -> reject
        ("MAT_ANSWERSANSWERS", "Answersanswersanswersanswers", "Mathematics", "active"),  # ocr_junk (>=20) -> reject
        ("CHE_OHMS_LAW", "Ohms law", "Physics", "active"),                   # prefix/domain -> REVIEW (untouched)
        ("PHY_OHM_S_LAW", "Ohm's law", "Physics", "active"),                 # clean -> untouched
    ])
    conn.commit()
    return conn


class TestCanonApply(unittest.TestCase):
    def setUp(self):
        self.kie = _fake_kie()
        self.qie = qstore.open_store(":memory:")
        cands = cc.find_candidates(self.kie)
        cc.write_candidates(self.qie, cands, "t0")

    def test_review_rows_present_and_not_rejected_status(self):
        row = self.qie.execute("SELECT proposed_status FROM concept_canon_ledger WHERE concept_code='CHE_OHMS_LAW'").fetchone()
        self.assertEqual(row[0], "review")

    def test_apply_quarantines_only_rejects(self):
        res = cc.apply_quarantine(self.kie, self.qie, "t1")
        self.assertEqual(res["quarantined"], 2)          # the two junk concepts
        self.assertGreaterEqual(res["review_untouched"], 1)
        # junk concepts now rejected
        for code in ("BIO_CHOOSE_THE_COR", "MAT_ANSWERSANSWERS"):
            s = self.kie.execute("SELECT status FROM concepts WHERE concept_code=?", (code,)).fetchone()[0]
            self.assertEqual(s, "rejected")
        # review + clean concepts still ACTIVE (not auto-changed)
        for code in ("CHE_OHMS_LAW", "PHY_OHM_S_LAW"):
            s = self.kie.execute("SELECT status FROM concepts WHERE concept_code=?", (code,)).fetchone()[0]
            self.assertEqual(s, "active")

    def test_rollback_restores_prior_status(self):
        cc.apply_quarantine(self.kie, self.qie, "t1")
        n = cc.rollback(self.kie, self.qie)
        self.assertEqual(n, 2)
        for code in ("BIO_CHOOSE_THE_COR", "MAT_ANSWERSANSWERS"):
            s = self.kie.execute("SELECT status FROM concepts WHERE concept_code=?", (code,)).fetchone()[0]
            self.assertEqual(s, "active")   # fully reversible

    def test_apply_is_idempotent(self):
        cc.apply_quarantine(self.kie, self.qie, "t1")
        res2 = cc.apply_quarantine(self.kie, self.qie, "t2")   # nothing left with applied=0
        self.assertEqual(res2["quarantined"], 0)


if __name__ == "__main__":
    unittest.main()
