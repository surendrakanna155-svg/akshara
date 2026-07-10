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


class TestPreservation(unittest.TestCase):
    """Phase-2 preserves coords / images / table bboxes / equations / chapters / OCR words."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_page_coordinates_and_keys(self):
        doc = fitz.open(stream=_text_pdf_bytes(pages=1), filetype="pdf")
        pages = phase2_parse.extract_text_pages(doc)
        doc.close()
        self.assertGreater(pages[0]["width"], 0)
        self.assertGreater(pages[0]["height"], 0)
        for k in ("images", "equations", "tables"):
            self.assertIn(k, pages[0])

    def test_equation_heuristic(self):
        self.assertTrue(phase2_parse._is_math_span("ABDF+CMMI10", "x"))       # math font
        self.assertTrue(phase2_parse._is_math_span("Helvetica", "∫ f dx = ∑ y"))  # symbols
        self.assertFalse(phase2_parse._is_math_span("Helvetica", "plain words"))

    def test_image_references(self):
        doc = fitz.open()
        page = doc.new_page(width=300, height=300)
        pix = fitz.Pixmap(fitz.csRGB, fitz.IRect(0, 0, 40, 40))
        pix.clear_with(128)
        page.insert_image(fitz.Rect(50, 50, 150, 150), pixmap=pix)
        pages = phase2_parse.extract_text_pages(doc)
        doc.close()
        self.assertTrue(pages[0]["images"])
        self.assertIsNotNone(pages[0]["images"][0]["xref"])
        self.assertEqual(len(pages[0]["images"][0]["bbox"]), 4)

    def test_table_boundaries(self):
        doc = fitz.open()
        page = doc.new_page(width=320, height=220)
        xs, ys = [40, 110, 180, 250], [40, 80, 120, 160]
        for x in xs:
            page.draw_line((x, ys[0]), (x, ys[-1]))
        for y in ys:
            page.draw_line((xs[0], y), (xs[-1], y))
        k = 0
        for r in range(3):
            for c in range(3):
                page.insert_text((xs[c] + 15, ys[r] + 22), str(k))
                k += 1
        pages = phase2_parse.extract_text_pages(doc)
        doc.close()
        self.assertTrue(pages[0]["_grid"])                       # ruled grid detected
        tbls = [t for p in pages for t in p["tables"]]
        self.assertTrue(tbls)
        self.assertEqual(len(tbls[0]["bbox"]), 4)                # table boundary preserved
        self.assertIn(tbls[0]["source"], ("pymupdf", "pdfplumber"))

    def test_decorative_page_not_treated_as_grid(self):
        # a graphics-heavy page (>1500 vector items) must NOT trigger the pdfplumber fallback
        doc = fitz.open()
        page = doc.new_page(width=612, height=792)
        for i in range(1700):
            y = 40 + (i % 700)
            page.draw_line((0, y), (400, y))
        self.assertFalse(phase2_parse._page_has_grid(page))
        doc.close()

    def test_chapter_boundaries_from_toc(self):
        doc = fitz.open()
        for _ in range(2):
            doc.new_page().insert_text((72, 72), "chapter body text content here")
        doc.set_toc([[1, "Chapter 1 Kinematics", 1], [1, "Chapter 2 Dynamics", 2]])
        p = self.tmp / "toc.pdf"
        doc.save(str(p))
        doc.close()
        res = phase2_parse.parse_pdf_file(p, "text_extract")
        titles = [c["title"] for c in res["chapter_boundaries"]]
        self.assertIn("Chapter 1 Kinematics", titles)
        self.assertEqual(res["chapter_count"], 2)
        self.assertTrue(all(c["source"] == "toc" for c in res["chapter_boundaries"]))

    @unittest.skipUnless(shutil.which("tesseract"), "tesseract required")
    def test_ocr_word_coordinates(self):
        doc = fitz.open()
        doc.new_page().insert_text((72, 200), "PHYSICS", fontsize=48)
        pages, conf = phase2_parse.ocr_pages(doc)
        doc.close()
        self.assertTrue(pages[0]["words"])
        self.assertEqual(len(pages[0]["words"][0]["bbox"]), 4)
        self.assertIn("PHYSIC", " ".join(w["text"] for w in pages[0]["words"]).upper())


def _image_only_pdf(path, tmp, text="PHYSICS ENTRANCE EXAM"):
    """A PDF whose page is a rendered image with NO text layer (simulates a scan)."""
    src = fitz.open()
    src.new_page(width=612, height=792).insert_text((60, 300), text, fontsize=42)
    pix = src[0].get_pixmap(dpi=150)
    png = tmp / "render.png"
    pix.save(str(png))
    src.close()
    out = fitz.open()
    out.new_page(width=612, height=792).insert_image(fitz.Rect(0, 0, 612, 792), filename=str(png))
    out.save(str(path))
    out.close()
    return path


def _mixed_pdf(path, tmp):
    """Page 1 = real embedded text; page 2 = image-only (scanned)."""
    out = fitz.open()
    out.new_page(width=612, height=792).insert_text(
        (72, 200), "This page has real selectable embedded text for direct extraction of physics",
        fontsize=13)
    src = fitz.open()
    src.new_page(width=612, height=792).insert_text((60, 300), "SCANNED CHEMISTRY PAGE", fontsize=42)
    pix = src[0].get_pixmap(dpi=150)
    png = tmp / "mix.png"
    pix.save(str(png))
    src.close()
    out.new_page(width=612, height=792).insert_image(fitz.Rect(0, 0, 612, 792), filename=str(png))
    out.save(str(path))
    out.close()
    return path


class TestDetectionFirst(unittest.TestCase):
    """Detection-first: OCR only image pages; text pages use direct PyMuPDF extraction."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_embedded_text_skips_ocr_even_when_strategy_is_ocr(self):
        p = self.tmp / "t.pdf"
        p.write_bytes(_text_pdf_bytes("Kinematics velocity acceleration momentum energy", pages=2))
        res = phase2_parse.parse_pdf_file(p, "ocr")   # Phase-1 said scan; text is really there
        self.assertEqual(res["method"], "pymupdf")
        self.assertEqual(res["ocr_pages"], 0)
        self.assertFalse(res["ocr_used"])

    @unittest.skipUnless(shutil.which("tesseract"), "tesseract required")
    def test_image_only_full_ocr(self):
        p = _image_only_pdf(self.tmp / "scan.pdf", self.tmp)
        res = phase2_parse.parse_pdf_file(p, "text_extract")
        self.assertEqual(res["method"], "tesseract")
        self.assertEqual(res["ocr_pages"], res["page_count"])
        self.assertTrue(res["ocr_used"])
        self.assertIn("PHYSIC", " ".join(pg["text"] for pg in res["pages"]).upper())

    @unittest.skipUnless(shutil.which("tesseract"), "tesseract required")
    def test_mixed_partial_ocr(self):
        p = _mixed_pdf(self.tmp / "mixed.pdf", self.tmp)
        res = phase2_parse.parse_pdf_file(p, "text_extract")
        self.assertEqual(res["page_count"], 2)
        self.assertEqual(res["method"], "mixed")
        self.assertEqual(res["ocr_pages"], 1)
        self.assertIn("selectable", res["pages"][0]["text"].lower())   # page1 direct
        self.assertFalse(res["pages"][0].get("ocr"))
        self.assertTrue(res["pages"][1].get("ocr"))                    # page2 OCR'd


if __name__ == "__main__":
    unittest.main()
