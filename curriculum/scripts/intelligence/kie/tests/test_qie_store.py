"""QIE store — isolated qie.db schema migrates and holds DNA / Item Models / canon ledger.
Uses an in-memory DB; never touches kie.db."""
import unittest

from kie.qie import store, concept_canon


class TestQieStore(unittest.TestCase):
    def setUp(self):
        self.conn = store.open_store(":memory:")

    def tearDown(self):
        self.conn.close()

    def test_schema_version_set(self):
        v = self.conn.execute("SELECT value FROM qie_meta WHERE key='schema_version'").fetchone()
        self.assertEqual(v[0], store.SCHEMA_VERSION)

    def test_core_tables_exist(self):
        names = {r[0] for r in self.conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        for t in ("question_dna", "item_model", "distractor_dna", "kvs_assertion",
                  "kvs_taxonomy", "kvs_sequence", "kvs_structure_function", "kvs_comparison",
                  "generated_item", "concept_canon_ledger"):
            self.assertIn(t, names)

    def test_item_model_yield_columns(self):
        # the retained yield gate reads n_dna >= 5 and n_resources >= 2 off the model row
        cols = {r[1] for r in self.conn.execute("PRAGMA table_info(item_model)")}
        self.assertIn("n_dna", cols)
        self.assertIn("n_resources", cols)
        self.assertIn("concept_scope", cols)   # EXACT concept-code binding, not keyword substr
        self.assertIn("version", cols)

    def test_insert_dna_and_model(self):
        with store.txn(self.conn) as c:
            c.execute("INSERT INTO question_dna(dna_id,lane,subject,concept_code,created_at) "
                      "VALUES ('d1','NUMERIC_RELATIONAL','Physics','PHY_OHM','t')")
            c.execute("INSERT INTO item_model(item_model_id,lane,concept_scope,n_dna,n_resources,created_at) "
                      "VALUES ('m1','NUMERIC_RELATIONAL','[\"PHY_OHM\"]',6,3,'t')")
        row = self.conn.execute("SELECT n_dna,n_resources,certification_status FROM item_model WHERE item_model_id='m1'").fetchone()
        self.assertEqual((row[0], row[1], row[2]), (6, 3, "draft"))

    def test_canon_candidate_ledger_defaults_unapplied(self):
        cands = [concept_canon.Candidate("BIO_CHOOSE_THE_COR", "Choose the correct", "Biology",
                                         "non_concept", "fragment")]
        n = concept_canon.write_candidates(self.conn, cands, "t")
        self.assertEqual(n, 1)
        row = self.conn.execute("SELECT applied, reason FROM concept_canon_ledger WHERE concept_code='BIO_CHOOSE_THE_COR'").fetchone()
        self.assertEqual((row[0], row[1]), (0, "non_concept"))  # applied=0 => analysis-only, kie.db untouched


class TestOcrJunkHeuristic(unittest.TestCase):
    def test_structural_junk_flagged(self):
        # what the STRUCTURAL heuristic genuinely catches: too-short, merged-long-token, consonant runs
        self.assertTrue(concept_canon._is_ocr_junk("x"))
        self.assertTrue(concept_canon._is_ocr_junk("thermodynamicsandheat"))  # merged >=14
        self.assertTrue(concept_canon._is_ocr_junk("bcdfghjk law"))           # consonant run
        self.assertFalse(concept_canon._is_ocr_junk("Ohm's law"))
        self.assertFalse(concept_canon._is_ocr_junk("Photosynthesis"))

    def test_non_concept_fragment_flagged_via_find(self):
        # the yield-gate culprit class (question/section fragments) is caught by the phrase list in
        # find_candidates; vocabulary-shaped junk (e.g. "Aelangelang") is NOT caught structurally and
        # is documented as needing the evidence-based pass (Phase A2).
        low = "choose the correct"
        self.assertTrue(any(p in low for p in concept_canon._NON_CONCEPT))


if __name__ == "__main__":
    unittest.main()
