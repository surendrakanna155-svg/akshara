"""Phase-4 chunking + FTS tests."""
import json
import shutil
import tempfile
import unittest
from pathlib import Path

from kie import config, ledger, phase4_chunk, store


def _body(n, size=10.0, word="alpha"):
    return [{"text": " ".join([word] * 6), "size": size, "bold": False} for _ in range(n)]


class TestChunker(unittest.TestCase):
    def test_headings_bound_chunks_with_path(self):
        pages = [{"page": 1, "blocks": [
            {"text": "Mechanics", "size": 18.0, "bold": True},
            *_body(2, word="force"),
            {"text": "Thermodynamics", "size": 18.0, "bold": True},
            *_body(1, word="heat"),
        ]}]
        chunks = phase4_chunk.chunk_pages(pages, target_tokens=1000)
        self.assertEqual(len(chunks), 2)
        self.assertEqual(chunks[0]["section_path"], "Mechanics")
        self.assertIn("force", chunks[0]["text"])
        self.assertEqual(chunks[1]["section_path"], "Thermodynamics")
        self.assertIn("heat", chunks[1]["text"])

    def test_token_cap_splits(self):
        pages = [{"page": 1, "blocks": _body(20, word="x")}]  # 120 words, no headings
        chunks = phase4_chunk.chunk_pages(pages, target_tokens=30)
        self.assertGreater(len(chunks), 1)
        self.assertTrue(all(c["token_est"] <= 60 for c in chunks))

    def test_ocr_text_fallback(self):
        pages = [{"page": 1, "blocks": [], "text": "First paragraph here.\n\nSecond paragraph here."}]
        chunks = phase4_chunk.chunk_pages(pages, target_tokens=1000)
        self.assertEqual(len(chunks), 1)
        self.assertIn("First paragraph", chunks[0]["text"])
        self.assertIn("Second paragraph", chunks[0]["text"])

    def test_tables_are_atomic(self):
        chunks = phase4_chunk.chunk_pages([{"page": 1, "blocks": _body(1)}],
                                          tables=[{"page": 2, "rows": [["a", "b"], ["c", "d"]]}],
                                          target_tokens=1000)
        table = [c for c in chunks if c["block_type"] == "table"]
        self.assertEqual(len(table), 1)
        self.assertEqual(table[0]["text"], "a | b\nc | d")

    def test_deterministic(self):
        pages = [{"page": 1, "blocks": [{"text": "H", "size": 18.0}, *_body(3)]}]
        self.assertEqual(phase4_chunk.chunk_pages(pages), phase4_chunk.chunk_pages(pages))


class TestRun(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self._orig = (config.KIE_HOME, config.PARSED_DIR, config.REPORTS_DIR)
        config.KIE_HOME = self.tmp / "kie"
        config.PARSED_DIR = config.KIE_HOME / "parsed"
        config.REPORTS_DIR = config.KIE_HOME / "reports"
        config.ensure_dirs()
        self.conn = store.open_store(":memory:")
        self.did = "deadbeefcafe0001"
        self.conn.execute(
            """INSERT INTO source_documents
                 (doc_id,corpus,rel_path,category,sha256,integrity_ok,encrypted,parser_class,parser_strategy,
                  is_duplicate,verify_status,certify_status,certify_reason,created_at)
               VALUES (?,?,?,?,?,1,0,'born_digital_text','text_extract',0,'verified','certified','ok','now')""",
            (self.did, "foundation", "JEE/p.pdf", "JEE_Main", "z" * 64),
        )
        self.conn.execute(
            "INSERT INTO parsed_documents(doc_id,method,pages,char_count,table_count,ocr_used,output_ref,created_at) "
            "VALUES (?,?,?,?,?,0,?,'now')", (self.did, "pymupdf", 1, 100, 0, f"parsed/{self.did}.json"))
        self.conn.commit()
        pages = [{"page": 1, "blocks": [
            {"text": "Kinematics", "size": 18.0, "bold": True},
            {"text": "displacement velocity acceleration motion graphs", "size": 10.0},
        ]}]
        (config.PARSED_DIR / f"{self.did}.json").write_text(json.dumps({"pages": pages, "tables": []}))

    def tearDown(self):
        config.KIE_HOME, config.PARSED_DIR, config.REPORTS_DIR = self._orig
        self.conn.close()
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_run_and_fts_search(self):
        s = phase4_chunk.run(self.conn)
        self.assertEqual(s["processed"], 1)
        self.assertGreaterEqual(s["chunks"], 1)
        self.assertEqual(ledger.get(self.conn, self.did, "chunk")[0], "done")
        hits = phase4_chunk.search(self.conn, "acceleration")
        self.assertTrue(hits)
        self.assertEqual(hits[0]["doc_id"], self.did)
        self.assertIn("Kinematics", hits[0]["section_path"])

    def test_reprocess_replaces_not_duplicates(self):
        phase4_chunk.run(self.conn)
        n1 = self.conn.execute("SELECT COUNT(*) n FROM chunks").fetchone()["n"]
        phase4_chunk.run(self.conn, force=True)
        n2 = self.conn.execute("SELECT COUNT(*) n FROM chunks").fetchone()["n"]
        fts = self.conn.execute("SELECT COUNT(*) n FROM chunks_fts").fetchone()["n"]
        self.assertEqual(n1, n2)
        self.assertEqual(n2, fts)  # FTS stays in lockstep, no orphan rows

    def test_idempotent_skip(self):
        phase4_chunk.run(self.conn)
        s2 = phase4_chunk.run(self.conn)
        self.assertEqual(s2["processed"], 0)
        self.assertEqual(s2["skipped"], 1)


if __name__ == "__main__":
    unittest.main()
