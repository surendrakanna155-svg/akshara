"""Phase-3 metadata tests: subject inference + heading→section detection."""
import json
import shutil
import tempfile
import unittest
from pathlib import Path

from kie import config, ledger, phase3_metadata, store


def _body(n, size=10.0):
    return [{"text": f"body sentence number {i} with plenty of ordinary words", "size": size, "bold": False}
            for i in range(n)]


PAGES = [{
    "page": 1,
    "blocks": [
        {"text": "Real Numbers", "size": 18.0, "bold": True},
        {"text": "Euclid's Division Lemma", "size": 14.0, "bold": True},
        *_body(4),
        {"text": "3.2 The Fundamental Theorem", "size": 14.0, "bold": True},
        *_body(4),
    ],
}]


class TestSubject(unittest.TestCase):
    def test_physics(self):
        subject, scores = phase3_metadata.infer_subject(
            "The force and acceleration relate through Newton's second law; momentum and energy are conserved."
        )
        self.assertEqual(subject, "Physics")
        self.assertGreater(scores["Physics"], scores["Biology"])

    def test_chemistry(self):
        subject, _ = phase3_metadata.infer_subject(
            "One mole of the compound reacts; the acid donates a proton and the atom forms a covalent bond."
        )
        self.assertEqual(subject, "Chemistry")

    def test_none_when_no_signal(self):
        subject, _ = phase3_metadata.infer_subject("the quick brown fox jumped over lazy dogs")
        self.assertIsNone(subject)


class TestSections(unittest.TestCase):
    def test_levels_and_breadcrumbs(self):
        secs = phase3_metadata.detect_sections(PAGES)
        titles = [s["title"] for s in secs]
        self.assertEqual(titles, ["Real Numbers", "Euclid's Division Lemma", "3.2 The Fundamental Theorem"])
        self.assertEqual([s["level"] for s in secs], [1, 2, 2])
        self.assertEqual(secs[1]["path"], "Real Numbers > Euclid's Division Lemma")
        self.assertEqual(secs[2]["path"], "Real Numbers > 3.2 The Fundamental Theorem")

    def test_no_headings_when_uniform(self):
        flat = [{"page": 1, "blocks": _body(6)}]
        self.assertEqual(phase3_metadata.detect_sections(flat), [])

    def test_deterministic(self):
        self.assertEqual(phase3_metadata.detect_sections(PAGES), phase3_metadata.detect_sections(PAGES))


class TestCatalogMetadata(unittest.TestCase):
    """Deterministic document-level JEE/NEET facets from the source path."""

    def test_doctype(self):
        self.assertEqual(phase3_metadata.classify_doctype(
            "NEET/2018/NEET_2018_mirror_C_answer-key-2018.pdf", "pdf"), "answer_key")
        self.assertEqual(phase3_metadata.classify_doctype(
            "AIIMS/2007/AIIMS_2007_mirror_A_solved-paper-solution.pdf", "pdf"), "solution")
        self.assertEqual(phase3_metadata.classify_doctype(
            "JEE_Main/2016/JEE_Main_2016_Question-Paper-H2.pdf", "pdf"), "previous_paper")
        self.assertEqual(phase3_metadata.classify_doctype("NCERT/Class_06/book.zip", "archive"), "textbook")

    def test_source_authority_provider(self):
        self.assertEqual(phase3_metadata.classify_source("JEE_Main/JEE_Main_2025_official_NTA_1.pdf"),
                         ("official", "NTA"))
        self.assertEqual(phase3_metadata.classify_source("NEET/NEET_2018_mirror_Careers360_key.pdf"),
                         ("mirror", "Careers360"))
        self.assertEqual(phase3_metadata.classify_source("x/random.pdf"), ("unknown", None))

    def test_language_class_session_stream(self):
        self.assertEqual(phase3_metadata.detect_language("NEET_2018_answer-key-Marathi.pdf"), "Marathi")
        self.assertEqual(phase3_metadata.detect_language("NEET_2018_key.pdf"), "English")
        self.assertEqual(phase3_metadata.classify_class_level("NCERT/Class_07/x.zip"), "Class 7")
        self.assertIsNotNone(phase3_metadata.detect_session("NEET-key-Set-CC.pdf"))
        self.assertEqual(phase3_metadata.stream_for("NEET", "NEET/x.pdf"), "Medical")
        self.assertEqual(phase3_metadata.stream_for("JEE_Main", "JEE_Main/x.pdf"), "Engineering")
        self.assertEqual(phase3_metadata.stream_for("Practice_Resources", "Practice_Resources/NEET/x.pdf"), "Medical")


class TestRun(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self._orig = (config.KIE_HOME, config.PARSED_DIR, config.REPORTS_DIR)
        config.KIE_HOME = self.tmp / "kie"
        config.PARSED_DIR = config.KIE_HOME / "parsed"
        config.REPORTS_DIR = config.KIE_HOME / "reports"
        config.ensure_dirs()
        self.conn = store.open_store(":memory:")
        self.did = "abc123def4560000"
        self.conn.execute(
            """INSERT INTO source_documents
                 (doc_id,corpus,rel_path,category,sha256,integrity_ok,encrypted,parser_class,parser_strategy,
                  is_duplicate,verify_status,certify_status,certify_reason,created_at)
               VALUES (?,?,?,?,?,1,0,'born_digital_text','text_extract',0,'verified','certified','ok','now')""",
            (self.did, "foundation", "NCERT/rn.pdf", "NCERT", "s" * 64),
        )
        self.conn.execute(
            "INSERT INTO parsed_documents(doc_id,method,pages,char_count,table_count,ocr_used,output_ref,created_at) "
            "VALUES (?,?,?,?,?,0,?,'now')",
            (self.did, "pymupdf", 1, 500, 0, f"parsed/{self.did}.json"),
        )
        self.conn.commit()
        physics_pages = [{"page": 1, "blocks": PAGES[0]["blocks"], "text":
                          "force acceleration momentum energy Newton velocity"}]
        (config.PARSED_DIR / f"{self.did}.json").write_text(json.dumps({"pages": physics_pages}))

    def tearDown(self):
        config.KIE_HOME, config.PARSED_DIR, config.REPORTS_DIR = self._orig
        self.conn.close()
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_run_populates_sections_and_subject(self):
        s = phase3_metadata.run(self.conn)
        self.assertEqual(s["processed"], 1)
        self.assertEqual(s["sections"], 3)
        self.assertEqual(s["subjects"].get("Physics"), 1)
        rows = self.conn.execute("SELECT COUNT(*) n FROM document_sections WHERE doc_id=?", (self.did,)).fetchone()["n"]
        self.assertEqual(rows, 3)
        subj = self.conn.execute("SELECT subject FROM source_documents WHERE doc_id=?", (self.did,)).fetchone()["subject"]
        self.assertEqual(subj, "Physics")
        self.assertEqual(ledger.get(self.conn, self.did, "metadata")[0], "done")

    def test_run_persists_catalog_metadata(self):
        phase3_metadata.run(self.conn)
        r = self.conn.execute("SELECT doc_type, language FROM source_documents WHERE doc_id=?",
                              (self.did,)).fetchone()
        self.assertEqual(r["language"], "English")
        self.assertIsNotNone(r["doc_type"])
        dm = self.conn.execute("SELECT * FROM document_metadata WHERE doc_id=?", (self.did,)).fetchone()
        self.assertIsNotNone(dm)
        self.assertEqual(dm["stream"], "Foundation")            # NCERT → Foundation
        self.assertIsNotNone(dm["title"])
        self.assertGreaterEqual(dm["confidence"], 0.0)

    def test_idempotent(self):
        phase3_metadata.run(self.conn)
        s2 = phase3_metadata.run(self.conn)
        self.assertEqual(s2["processed"], 0)
        self.assertEqual(s2["skipped"], 1)


if __name__ == "__main__":
    unittest.main()
