"""R5-2 [C14] — concept-namespace convergence onto the KC_ spine: governed-fact topic + factory legacy code
resolution (honest-null on unresolved/ambiguous), OCR-junk retirement, derived (no source-store mutation).
"""
from __future__ import annotations

import json
import os
import sqlite3
import tempfile
import unittest

from kie import config
from kie.qie import store as QIE_STORE
from kie.qie.graph import namespace as NS
from kie.qie.graph import store as GST


def _synth_index(tmp):
    path = os.path.join(tmp, "knowledge_index.db")
    c = sqlite3.connect(path)
    c.execute("CREATE TABLE ki_concept (concept_id TEXT PRIMARY KEY, subject TEXT, canonical_name TEXT, "
              "aliases TEXT, prerequisites TEXT, status TEXT)")
    c.execute("CREATE TABLE ki_meta (key TEXT, value TEXT)")
    c.execute("INSERT INTO ki_meta VALUES ('certified_knowledge_fingerprint_v1.5','feedface99')")
    c.executemany("INSERT INTO ki_concept VALUES (?,?,?,?,?,?)", [
        ("KC_WE", "Physics", "Work Energy And Power", "[]", "[]", "certified"),
        ("KC_IMM", "Biology", "Human Health And Diseases", "[]", "[]", "certified"),
        ("KC_URI", "Biology", "Uricotelism", "[]", "[]", "certified"),
    ])
    c.commit()
    c.close()
    return path


def _synth_qie(tmp):
    path = os.path.join(tmp, "qie.db")
    c = QIE_STORE.open_store(path)

    def gf(fid, subject, chapter, topic):
        c.execute("INSERT INTO governed_fact (fact_id, subject, concept_candidate, lane, fact_text, "
                  "answer_text, provenance, verification, status, topic, created_at) "
                  "VALUES (?,?,?,?,?,?,?,?,?,?,?)",
                  (fid, subject, chapter, "CLASSIFICATION_TAXONOMIC", "q", "a", "{}", "{}", "verified",
                   topic, "2026-07-21"))
    gf("GF_TOPIC", "Biology", "Biology :: Human Health And Diseases", "Uricotelism")  # topic -> KC_URI
    gf("GF_CHAP", "Physics", "Physics :: Work Energy And Power", None)                # chapter -> KC_WE
    gf("GF_NONE", "Biology", "Biology :: Nonexistent Chapter", "Nonexistent Topic")   # unresolved
    c.commit()
    c.close()
    return path


def _synth_corpus(tmp):
    path = os.path.join(tmp, "factory_corpus.db")
    c = sqlite3.connect(path)
    c.execute("CREATE TABLE generation_spec (spec_id TEXT, concept_code TEXT, subject TEXT)")
    c.executemany("INSERT INTO generation_spec VALUES (?,?,?)", [
        ("s1", "PHY_WORK_ENERGY_AND_POWER", "Physics"),      # legacy -> KC_WE
        ("s2", "PHY_QUESTIONS_ANSWERS", "Physics"),          # OCR-junk -> retired
        ("s3", "MAT_ANSWERSANSWERS", "Mathematics"),         # OCR-junk -> retired
        ("s4", "BIO_TOTALLY_UNKNOWN_THING", "Biology"),      # unresolved
        ("s5", "KC_WE", "Physics"),                          # already a REAL KC_ id
        ("s6", "KC_BOGUS_DOESNOTEXIST", "Physics"),          # a KC_ code that is NOT a certified concept
    ])
    c.commit()
    c.close()
    return path


class TestNamespaceConvergence(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = self.tmp.name
        self.idx, self.qie, self.corpus = _synth_index(t), _synth_qie(t), _synth_corpus(t)
        self.graph = os.path.join(t, "graph_edges.db")
        self.summary = NS.build(graph_path=self.graph, index_path=self.idx, qie_path=self.qie,
                                corpus_path=self.corpus)

    def tearDown(self):
        self.tmp.cleanup()

    def _row(self, ont, sid):
        conn = GST.open_store(self.graph, writable=False)
        try:
            return conn.execute("SELECT resolved_kc, method, retired FROM concept_namespace "
                                "WHERE src_ontology=? AND src_id=?", (ont, sid)).fetchone()
        finally:
            conn.close()

    def test_topic_resolves_to_kc_labeled_truthfully(self):
        r = self._row("governed_fact_topic", "GF_TOPIC")
        self.assertEqual(r["resolved_kc"], "KC_URI")
        self.assertEqual(r["method"], "topic_name")           # a genuine fine-grained topic hit

    def test_chapter_fallback_is_labeled_distinctly(self):
        # verifier Finding 1: a chapter-fallback resolution must NOT be mislabeled 'topic_name'
        r = self._row("governed_fact_topic", "GF_CHAP")
        self.assertEqual(r["resolved_kc"], "KC_WE")
        self.assertEqual(r["method"], "chapter_fallback")

    def test_topic_unresolved_is_honest_null(self):
        r = self._row("governed_fact_topic", "GF_NONE")
        self.assertIsNone(r["resolved_kc"])
        self.assertEqual(r["method"], "unresolved")

    def test_legacy_code_resolves_via_name_tail(self):
        self.assertEqual(self._row("factory_legacy_code", "PHY_WORK_ENERGY_AND_POWER")["resolved_kc"], "KC_WE")

    def test_ocr_junk_is_retired_never_resolved(self):
        for code in ("PHY_QUESTIONS_ANSWERS", "MAT_ANSWERSANSWERS"):
            r = self._row("factory_legacy_code", code)
            self.assertIsNone(r["resolved_kc"], f"{code} must never resolve to a concept")
            self.assertEqual(r["method"], "ocr_junk_retired")
            self.assertEqual(r["retired"], 1)

    def test_unknown_legacy_code_honest_null(self):
        r = self._row("factory_legacy_code", "BIO_TOTALLY_UNKNOWN_THING")
        self.assertIsNone(r["resolved_kc"])
        self.assertEqual(r["method"], "unresolved")
        self.assertEqual(r["retired"], 0)

    def test_already_kc_passthrough_only_when_certified(self):
        r = self._row("factory_legacy_code", "KC_WE")
        self.assertEqual(r["resolved_kc"], "KC_WE")
        self.assertEqual(r["method"], "already_kc")

    def test_bogus_kc_code_is_honest_null(self):
        # verifier Finding 4: a KC_-prefixed code that is not a real certified concept must not pass through
        r = self._row("factory_legacy_code", "KC_BOGUS_DOESNOTEXIST")
        self.assertIsNone(r["resolved_kc"])
        self.assertEqual(r["method"], "unknown_kc")

    def test_summary_partition(self):
        gf = self.summary["by_ontology"]["governed_fact_topic"]
        self.assertEqual(gf["total"], 3)
        self.assertEqual(gf["resolved"], 2)                 # GF_TOPIC + GF_CHAP
        self.assertEqual(gf["honest_null"], 1)              # GF_NONE
        lc = self.summary["by_ontology"]["factory_legacy_code"]
        self.assertEqual(lc["retired"], 2)                  # the two junk codes
        self.assertEqual(lc["total"], lc["resolved"] + lc["retired"] + lc["honest_null"])

    def test_resolve_to_kc_query(self):
        self.assertEqual(NS.resolve_to_kc("governed_fact_topic", "GF_TOPIC", self.graph), "KC_URI")
        self.assertIsNone(NS.resolve_to_kc("factory_legacy_code", "PHY_QUESTIONS_ANSWERS", self.graph))

    def test_source_stores_never_written(self):
        for p in (self.idx, self.qie, self.corpus):
            ro = sqlite3.connect(f"file:{p}?mode=ro", uri=True)
            with self.assertRaises(sqlite3.OperationalError):
                ro.execute("CREATE TABLE _w (x)")
            ro.close()

    def test_deterministic_rebuild(self):
        s2 = NS.build(graph_path=self.graph, index_path=self.idx, qie_path=self.qie, corpus_path=self.corpus)
        self.assertEqual(self.summary["by_ontology"], s2["by_ontology"])


class TestOcrJunkDetector(unittest.TestCase):
    def test_junk_codes(self):
        for c in ("PHY_QUESTIONS_ANSWERS", "PHY_ANSWERS_FOR_THE_ABOVE_QUESTIONS", "BIO_ANSWERANSWER",
                  "MAT_ANSWERSANSWERS", "MAT_SOLUTIONS_SOLUTIONS", "PHY_ANSWER_KEY"):
            self.assertTrue(NS._is_ocr_junk(c), c)

    def test_real_codes_not_junk(self):
        for c in ("PHY_WORK_ENERGY", "BIO_IMMUNITY", "REL_OHMS_LAW", "CALC_DEFINITE_INTEGRAL", "MAT_MATRICES"):
            self.assertFalse(NS._is_ocr_junk(c), c)

    def test_over_retire_regression_the_theory(self):
        # verifier Finding 2: a legit concept whose name contains "The Theory/Theorem…" must NOT be retired
        for c in ("BIO_THE_THEORY_OF_EVOLUTION", "PHY_THE_THEORY_OF_RELATIVITY", "MAT_THE_THEOREM",
                  "CHE_THE_THERMOCHEMISTRY", "BIO_THE_LIVING_WORLD"):
            self.assertFalse(NS._is_ocr_junk(c), f"{c} is a real concept and must never be retired")


_LIVE = all((config.KIE_HOME / n).exists() for n in ("knowledge_index.db", "qie.db", "factory_corpus.db"))


@unittest.skipUnless(_LIVE, "live estate not present")
class TestLiveConvergence(unittest.TestCase):
    def test_live_convergence_is_honest(self):
        summ = NS.build()
        rep = NS.convergence_report()
        self.assertGreaterEqual(rep["retired_total"], 3)    # the known OCR-junk codes retired
        gf = summ["by_ontology"]["governed_fact_topic"]
        self.assertEqual(gf["total"], 128)
        self.assertLess(gf["resolution_rate"], 1.0)         # not inflated (topics are fine-grained)
        self.assertEqual(gf["total"], gf["resolved"] + gf["retired"] + gf["honest_null"])


if __name__ == "__main__":
    unittest.main()
