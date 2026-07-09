"""Phase-1 verification + D-5 certification tests."""
import json
import tempfile
import unittest
from pathlib import Path

from kie import ledger, phase1_verify, store


def _entry(sha, path, category="JEE_Main", integrity_ok=True, corruption_reason=None,
           encrypted=False, is_duplicate=False, duplicate_of=None,
           parser_class="born_digital_text", parser_strategy="text_extract",
           kind="pdf", pages=10, bytes_=1234):
    return {
        "path": path, "category": category, "kind": kind, "bytes": bytes_,
        "sha256": sha, "integrity_ok": integrity_ok, "corruption_reason": corruption_reason,
        "parser_class": parser_class, "parser_strategy": parser_strategy, "pages": pages,
        "encrypted": encrypted, "is_duplicate": is_duplicate, "duplicate_of": duplicate_of,
    }


MANIFEST = {
    "phase": "1_repository_verification",
    "entries": [
        _entry("a" * 64, "JEE_Main/Previous_Papers/2016/paper1.pdf"),
        _entry("b" * 64, "NEET/Previous_Papers/2019/neet2019.pdf", category="NEET", parser_class="scanned_image", parser_strategy="ocr"),
        _entry("c" * 64, "AIIMS/broken.pdf", category="AIIMS", integrity_ok=False, corruption_reason="eof_marker_missing"),
        _entry("d" * 64, "JEE_Advanced/locked.pdf", category="JEE_Advanced", encrypted=True),
        # a redundant copy of the first paper — SAME content hash, so it collapses onto it.
        _entry("a" * 64, "JEE_Main/Previous_Papers/2016/paper1_copy.pdf", is_duplicate=True, duplicate_of="a" * 64),
    ],
}


class TestClassify(unittest.TestCase):
    def test_certified(self):
        self.assertEqual(phase1_verify.classify(_entry("a" * 64, "x.pdf"))[:2], ("verified", "certified"))

    def test_corrupt_quarantined(self):
        e = _entry("a" * 64, "x.pdf", integrity_ok=False, corruption_reason="bad")
        self.assertEqual(phase1_verify.classify(e)[:2], ("corrupt", "quarantined"))

    def test_encrypted_quarantined(self):
        self.assertEqual(phase1_verify.classify(_entry("a" * 64, "x.pdf", encrypted=True))[:2], ("encrypted", "quarantined"))

    def test_duplicate_of_certified_stays_certified(self):
        e = _entry("a" * 64, "x.pdf", is_duplicate=True, duplicate_of="b" * 64)
        vs, cs, reason = phase1_verify.classify(e)
        self.assertEqual((vs, cs), ("verified", "certified"))
        self.assertIn("b" * 64, reason)

    def test_doc_id_deterministic(self):
        self.assertEqual(phase1_verify.doc_id_for("f" * 64), "f" * 16)

    def test_year_from_path(self):
        self.assertEqual(phase1_verify._year_from_path("JEE_Main/Previous_Papers/2016/paper1.pdf"), 2016)
        self.assertIsNone(phase1_verify._year_from_path("NCERT/Textbooks/algebra.pdf"))


class TestRun(unittest.TestCase):
    def setUp(self):
        self.conn = store.open_store(":memory:")
        self.tmp = tempfile.mkdtemp()
        self.mpath = Path(self.tmp) / "manifest.json"
        self.mpath.write_text(json.dumps(MANIFEST))

    def tearDown(self):
        self.conn.close()

    def test_run_counts_and_gate(self):
        s = phase1_verify.run(self.conn, manifest_path=self.mpath, corpus="foundation")
        self.assertEqual(s["entries"], 5)
        self.assertEqual(s["duplicate_entries"], 1)     # the paper1_copy entry
        self.assertEqual(s["unique_documents"], 4)      # a(=copy), b, c, d
        self.assertEqual(s["certified"], 2)             # a, b
        self.assertEqual(s["quarantined"], 2)           # c (corrupt), d (encrypted)
        self.assertTrue(s["repository_certified"])

    def test_certified_docs_only_certified(self):
        phase1_verify.run(self.conn, manifest_path=self.mpath)
        docs = phase1_verify.certified_docs(self.conn)
        self.assertEqual(len(docs), 2)
        self.assertTrue(all(d["certify_status"] == "certified" for d in docs))
        self.assertTrue(all(d["corpus"] == "foundation" for d in docs))

    def test_verify_ledger_recorded(self):
        phase1_verify.run(self.conn, manifest_path=self.mpath)
        # 4 distinct doc_ids (the duplicate copy collapses onto its canonical).
        self.assertEqual(ledger.counts(self.conn, "verify").get("done"), 4)
        self.assertFalse(ledger.needs_run(self.conn, "a" * 16, "verify", "a" * 64))
        self.assertTrue(ledger.needs_run(self.conn, "a" * 16, "verify", "changed"))

    def test_run_is_idempotent(self):
        s1 = phase1_verify.run(self.conn, manifest_path=self.mpath)
        rows1 = self.conn.execute("SELECT COUNT(*) AS n FROM source_documents").fetchone()["n"]
        s2 = phase1_verify.run(self.conn, manifest_path=self.mpath)
        rows2 = self.conn.execute("SELECT COUNT(*) AS n FROM source_documents").fetchone()["n"]
        self.assertEqual(rows1, rows2)                      # upsert, no duplication
        self.assertEqual(s1["certified"], s2["certified"])

    def test_determinism_excluding_timestamps(self):
        phase1_verify.run(self.conn, manifest_path=self.mpath)
        cols = ("doc_id,corpus,rel_path,category,year,sha256,verify_status,"
                "certify_status,certify_reason,parser_class,parser_strategy")
        snap1 = self.conn.execute(f"SELECT {cols} FROM source_documents ORDER BY doc_id").fetchall()

        conn2 = store.open_store(":memory:")
        phase1_verify.run(conn2, manifest_path=self.mpath)
        snap2 = conn2.execute(f"SELECT {cols} FROM source_documents ORDER BY doc_id").fetchall()
        conn2.close()
        self.assertEqual([tuple(r) for r in snap1], [tuple(r) for r in snap2])

    def test_render_report(self):
        s = phase1_verify.run(self.conn, manifest_path=self.mpath)
        report = phase1_verify.render_report(self.conn, s)
        self.assertIn("KIE Phase 1", report)
        self.assertIn("Repository certified (D-5): **True**", report)


if __name__ == "__main__":
    unittest.main()
