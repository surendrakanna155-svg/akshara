"""Phase-2 parser tests. Uses PyMuPDF-authored PDFs (guaranteed extractable text)
+ Tesseract OCR round-trip + a zip archive."""
import hashlib
import json
import shutil
import tempfile
import unittest
import zipfile
from pathlib import Path

import fitz  # PyMuPDF

from kie import config, ledger, phase2_parse, store


def _text_pdf_bytes(text="Newton second law states F equals m times a", pages=2) -> bytes:
    doc = fitz.open()
    for _ in range(pages):
        page = doc.new_page()
        page.insert_text((72, 72), text, fontsize=14)
    data = doc.tobytes()
    doc.close()
    return data


class TestExtract(unittest.TestCase):
    def test_text_and_blocks(self):
        doc = fitz.open(stream=_text_pdf_bytes(pages=2), filetype="pdf")
        pages = phase2_parse.extract_text_pages(doc)
        doc.close()
        self.assertEqual(len(pages), 2)
        self.assertIn("Newton", pages[0]["text"])
        self.assertTrue(pages[0]["blocks"])
        self.assertIn("Newton", pages[0]["blocks"][0]["text"])
        self.assertIn("size", pages[0]["blocks"][0])

    def test_ocr_reads_rendered_text(self):
        doc = fitz.open()
        page = doc.new_page()
        page.insert_text((72, 200), "PHYSICS", fontsize=48)
        pages, conf = phase2_parse.ocr_pages(doc)
        doc.close()
        joined = " ".join(p["text"] for p in pages).upper()
        self.assertIn("PHYSIC", joined)  # tolerant of a trailing-char OCR slip
        self.assertGreater(conf, 0)


class TestRun(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        # redirect KIE outputs into the temp dir
        self._orig = (config.KIE_HOME, config.PARSED_DIR, config.REPORTS_DIR)
        config.KIE_HOME = self.tmp / "kie"
        config.PARSED_DIR = config.KIE_HOME / "parsed"
        config.REPORTS_DIR = config.KIE_HOME / "reports"
        self.conn = store.open_store(":memory:")

    def tearDown(self):
        config.KIE_HOME, config.PARSED_DIR, config.REPORTS_DIR = self._orig
        self.conn.close()
        shutil.rmtree(self.tmp, ignore_errors=True)

    def _add_doc(self, rel, data, kind="pdf", strategy="text_extract", certify="certified"):
        p = self.tmp / "resources" / "foundation" / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(data)
        sha = hashlib.sha256(data).hexdigest()
        did = sha[:16]
        self.conn.execute(
            """INSERT INTO source_documents
                 (doc_id,corpus,rel_path,category,kind,sha256,integrity_ok,encrypted,
                  parser_class,parser_strategy,is_duplicate,verify_status,certify_status,certify_reason,created_at)
               VALUES (?,?,?,?,?,?,1,0,?,?,0,'verified',?,'ok','now')""",
            (did, "foundation", rel, "JEE_Main", kind, sha, "born_digital_text", strategy, certify),
        )
        self.conn.commit()
        return did

    def test_parses_certified_text_pdf(self):
        did = self._add_doc("JEE_Main/2016/paper.pdf",
                            _text_pdf_bytes("Kinematics displacement velocity acceleration", pages=3))
        s = phase2_parse.run(self.conn, workspace=self.tmp)
        self.assertEqual(s["parsed"], 1)
        self.assertEqual(s["failed"], 0)
        row = self.conn.execute("SELECT * FROM parsed_documents WHERE doc_id=?", (did,)).fetchone()
        self.assertEqual(row["method"], "pymupdf")
        self.assertEqual(row["pages"], 3)
        self.assertGreater(row["char_count"], 0)
        parsed = json.loads((config.PARSED_DIR / f"{did}.json").read_text())
        self.assertIn("Kinematics", parsed["pages"][0]["text"])
        self.assertEqual(ledger.get(self.conn, did, "parse")[0], "done")

    def test_idempotent_skip(self):
        self._add_doc("JEE_Main/2016/p.pdf", _text_pdf_bytes())
        phase2_parse.run(self.conn, workspace=self.tmp)
        s2 = phase2_parse.run(self.conn, workspace=self.tmp)
        self.assertEqual(s2["parsed"], 0)
        self.assertEqual(s2["skipped"], 1)

    def test_only_certified_parsed(self):
        self._add_doc("JEE_Main/ok.pdf", _text_pdf_bytes())
        self._add_doc("JEE_Main/bad.pdf", _text_pdf_bytes(text="x"), certify="quarantined")
        s = phase2_parse.run(self.conn, workspace=self.tmp)
        self.assertEqual(s["parsed"], 1)          # only the certified one
        self.assertEqual(s["considered"], 1)

    def test_failure_isolation(self):
        did = self._add_doc("JEE_Main/missing.pdf", _text_pdf_bytes())
        (self.tmp / "resources" / "foundation" / "JEE_Main" / "missing.pdf").unlink()
        s = phase2_parse.run(self.conn, workspace=self.tmp)
        self.assertEqual(s["failed"], 1)
        self.assertEqual(s["parsed"], 0)
        self.assertEqual(ledger.get(self.conn, did, "parse")[0], "failed")

    def test_archive_aggregates_members(self):
        # a zip containing a text PDF (NCERT-style)
        pdf_bytes = _text_pdf_bytes("Chapter Real Numbers Euclid division lemma", pages=1)
        buf = self.tmp / "resources" / "foundation" / "NCERT" / "book.zip"
        buf.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(buf, "w") as z:
            z.writestr("book/chapter1.pdf", pdf_bytes)
        data = buf.read_bytes()
        sha = hashlib.sha256(data).hexdigest()
        did = sha[:16]
        self.conn.execute(
            """INSERT INTO source_documents
                 (doc_id,corpus,rel_path,category,kind,sha256,integrity_ok,encrypted,
                  parser_class,parser_strategy,is_duplicate,verify_status,certify_status,certify_reason,created_at)
               VALUES (?,?,?,?,?,?,1,0,'archive','unpack',0,'verified','certified','ok','now')""",
            (did, "foundation", "NCERT/book.zip", "NCERT", "archive", sha),
        )
        self.conn.commit()
        s = phase2_parse.run(self.conn, workspace=self.tmp)
        self.assertEqual(s["parsed"], 1)
        parsed = json.loads((config.PARSED_DIR / f"{did}.json").read_text())
        self.assertTrue(parsed["method"].startswith("archive"))
        self.assertIn("Euclid", " ".join(p["text"] for p in parsed["pages"]))
        self.assertEqual(parsed["pages"][0]["member"], "book/chapter1.pdf")


if __name__ == "__main__":
    unittest.main()
