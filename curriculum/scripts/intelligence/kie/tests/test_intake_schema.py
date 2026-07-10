"""Intake Center I0 — control schema applies additively without touching core tables."""
import unittest

from kie import store
from kie.intake import store_ext


class TestIntakeSchema(unittest.TestCase):
    def setUp(self):
        self.conn = store.open_store(":memory:")

    def tearDown(self):
        self.conn.close()

    def test_apply_creates_all_control_tables(self):
        self.assertFalse(store_ext.has_intake_schema(self.conn))
        store_ext.apply_intake_schema(self.conn)
        self.assertTrue(store_ext.has_intake_schema(self.conn))

    def test_apply_is_idempotent(self):
        store_ext.apply_intake_schema(self.conn)
        store_ext.apply_intake_schema(self.conn)  # must not raise
        self.assertTrue(store_ext.has_intake_schema(self.conn))

    def test_core_content_tables_untouched(self):
        # Applying intake schema must not drop/alter the frozen Phase 1-7 tables.
        store_ext.apply_intake_schema(self.conn)
        core = {
            r[0]
            for r in self.conn.execute(
                "SELECT name FROM sqlite_master WHERE type='table'"
            ).fetchall()
        }
        for t in ("source_documents", "chunks", "concepts", "concept_edges",
                  "question_patterns", "stage_ledger", "chunks_fts"):
            self.assertIn(t, core)

    def test_version_lineage_unique_per_version(self):
        store_ext.apply_intake_schema(self.conn)
        self.conn.execute(
            "INSERT INTO document_versions(version_id, lineage_key, doc_id, version_no, sha256, created_at)"
            " VALUES ('k@v1','k','d1',1,'s1','now')")
        with self.assertRaises(Exception):
            self.conn.execute(
                "INSERT INTO document_versions(version_id, lineage_key, doc_id, version_no, sha256, created_at)"
                " VALUES ('k@v1b','k','d2',1,'s2','now')")  # duplicate (lineage_key, version_no)


if __name__ == "__main__":
    unittest.main()
