"""Phase-1 store tests.

Run (from repo root):
  PYTHONPATH=curriculum/scripts/intelligence \
  curriculum/.venv/bin/python3 -m unittest discover -s curriculum/scripts/intelligence/kie/tests -v
"""
import unittest

from kie import store


class TestStore(unittest.TestCase):
    def setUp(self):
        self.conn = store.open_store(":memory:")

    def tearDown(self):
        self.conn.close()

    def _tables(self):
        rows = self.conn.execute(
            "SELECT name FROM sqlite_master WHERE type IN ('table','view')"
        ).fetchall()
        return {r["name"] for r in rows}

    def test_schema_creates_all_core_tables(self):
        tables = self._tables()
        for t in (
            "schema_meta", "source_documents", "stage_ledger", "parsed_documents",
            "chunks", "chunks_fts", "concepts", "concept_edges", "concept_board_mappings",
            "formulas", "question_patterns", "question_families", "question_templates",
            "distractors", "generated_items",
        ):
            self.assertIn(t, tables, f"missing table {t}")

    def test_schema_version_recorded(self):
        self.assertEqual(store.schema_version(self.conn), store.SCHEMA_VERSION)

    def test_migrate_is_idempotent(self):
        store.migrate(self.conn)  # second run must not error / duplicate
        store.migrate(self.conn)
        n = self.conn.execute("SELECT COUNT(*) AS n FROM schema_meta WHERE key='schema_version'").fetchone()["n"]
        self.assertEqual(n, 1)

    def test_fts5_available(self):
        self.conn.execute("INSERT INTO chunks_fts(text, chunk_id) VALUES ('newton second law of motion', 'c1')")
        hit = self.conn.execute("SELECT chunk_id FROM chunks_fts WHERE chunks_fts MATCH 'newton'").fetchone()
        self.assertEqual(hit["chunk_id"], "c1")

    def test_txn_rolls_back_on_error(self):
        with self.assertRaises(ValueError):
            with store.txn(self.conn):
                self.conn.execute(
                    "INSERT INTO schema_meta(key, value) VALUES ('x', '1')"
                )
                raise ValueError("boom")
        self.assertIsNone(
            self.conn.execute("SELECT value FROM schema_meta WHERE key='x'").fetchone()
        )

    def test_concept_edge_selfloop_rejected(self):
        self.conn.execute(
            "INSERT INTO concepts(concept_code,title,created_at) VALUES ('C1','t','now')"
        )
        with self.assertRaises(Exception):
            self.conn.execute(
                "INSERT INTO concept_edges(from_concept,to_concept) VALUES ('C1','C1')"
            )


if __name__ == "__main__":
    unittest.main()
