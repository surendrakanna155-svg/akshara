"""Intake Center I2 — verify (reused engine) + duplicate + version/lineage detection."""
import shutil
import tempfile
import unittest
from pathlib import Path

from kie import store
from kie.intake import detect
from kie.intake.models import Disposition
from kie.intake.store_ext import apply_intake_schema, now_iso


def _pdf(path: Path, text: str) -> Path:
    import fitz
    doc = fitz.open()
    # a few pages so it clears min_pages / readiness thresholds
    for _ in range(2):
        doc.new_page().insert_text((72, 72), text)
    path.parent.mkdir(parents=True, exist_ok=True)
    doc.save(str(path))
    doc.close()
    return path


def _insert_doc(conn, doc_id, sha, rel_path="NEET/physics_2024.pdf", category="NEET", year=2024):
    conn.execute(
        "INSERT INTO source_documents(doc_id,corpus,rel_path,category,year,sha256,integrity_ok,"
        "encrypted,is_duplicate,verify_status,certify_status,certify_reason,created_at) "
        "VALUES (?,?,?,?,?,?,1,0,0,'verified','certified','ok',?)",
        (doc_id, "intake", rel_path, category, year, sha, now_iso()))


class TestLineage(unittest.TestCase):
    def test_strips_year_and_session(self):
        a = detect.lineage_key("NEET", "Physics_2024_ShiftA.pdf")
        b = detect.lineage_key("NEET", "Physics_2025_Shift-B.pdf")
        self.assertEqual(a, b)
        self.assertTrue(a.startswith("neet/"))

    def test_explicit_override(self):
        self.assertEqual(detect.lineage_key("X", "y.pdf", explicit="Custom/Key"), "custom/key")

    def test_year_extraction(self):
        self.assertEqual(detect.year_from("jee_main_2023_set2.pdf"), 2023)
        self.assertIsNone(detect.year_from("notes.pdf"))


class TestVerify(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_good_pdf_verifies_and_certifies(self):
        p = _pdf(self.tmp / "good.pdf", "photosynthesis chlorophyll light reaction")
        v = detect.verify_file(p)
        self.assertTrue(v["integrity_ok"])
        self.assertEqual(len(v["sha256"]), 64)
        self.assertEqual(v["kind"], "pdf")

    def test_corrupt_file_quarantined(self):
        bad = self.tmp / "bad.pdf"
        bad.write_bytes(b"not a real pdf at all")
        v = detect.verify_file(bad)
        self.assertFalse(v["integrity_ok"])


class TestClassify(unittest.TestCase):
    def setUp(self):
        self.conn = store.open_store(":memory:")
        apply_intake_schema(self.conn)

    def tearDown(self):
        self.conn.close()

    def _verdict(self, sha, integrity_ok=True, encrypted=False, reason=None):
        return {"sha256": sha, "integrity_ok": integrity_ok, "encrypted": encrypted,
                "corruption_reason": reason, "is_duplicate": False, "duplicate_of": None}

    def test_new_document(self):
        d = detect.classify_source(self.conn, self._verdict("a" * 64), "NEET", "phys_2024.pdf")
        self.assertEqual(d["disposition"], Disposition.NEW)
        self.assertEqual(d["version_no"], 1)

    def test_exact_duplicate(self):
        sha = "b" * 64
        _insert_doc(self.conn, detect.doc_id_for(sha), sha)
        self.conn.commit()
        d = detect.classify_source(self.conn, self._verdict(sha), "NEET", "phys_2024.pdf")
        self.assertEqual(d["disposition"], Disposition.EXACT_DUPLICATE)
        self.assertEqual(d["existing_doc_id"], detect.doc_id_for(sha))

    def test_new_version_via_lineage_head(self):
        old_sha = "c" * 64
        lk = detect.lineage_key("NEET", "phys_2024.pdf")
        self.conn.execute(
            "INSERT INTO document_versions(version_id,lineage_key,doc_id,version_no,sha256,year,created_at)"
            " VALUES (?,?,?,?,?,?,?)", (f"{lk}@v1", lk, detect.doc_id_for(old_sha), 1, old_sha, 2024, now_iso()))
        self.conn.commit()
        d = detect.classify_source(self.conn, self._verdict("d" * 64), "NEET", "phys_2025.pdf")
        self.assertEqual(d["disposition"], Disposition.NEW_VERSION)
        self.assertEqual(d["version_of"], detect.doc_id_for(old_sha))
        self.assertEqual(d["version_no"], 2)

    def test_quarantined_never_stageable(self):
        d = detect.classify_source(self.conn, self._verdict("e" * 64, integrity_ok=False, reason="PDF_TRUNCATED"),
                                   "NEET", "phys.pdf")
        self.assertEqual(d["disposition"], Disposition.QUARANTINED)
        self.assertNotIn(d["disposition"], Disposition.STAGEABLE)

    def test_backfill_baseline_lineage_chains_by_year(self):
        # two NEET physics papers of different years → same lineage, chained old→new
        _insert_doc(self.conn, "doc2024aaaaaaaa", "1" * 64, "NEET/physics_2024.pdf", "NEET", 2024)
        _insert_doc(self.conn, "doc2025bbbbbbbb", "2" * 64, "NEET/physics_2025.pdf", "NEET", 2025)
        self.conn.commit()
        added = detect.register_baseline_lineage(self.conn)
        self.assertEqual(added, 2)
        rows = self.conn.execute(
            "SELECT doc_id, version_no, superseded_by FROM document_versions ORDER BY version_no").fetchall()
        self.assertEqual(rows[0]["version_no"], 1)
        self.assertEqual(rows[0]["superseded_by"], "doc2025bbbbbbbb")  # 2024 superseded by 2025
        self.assertIsNone(rows[1]["superseded_by"])                    # 2025 is the head
        # idempotent
        self.assertEqual(detect.register_baseline_lineage(self.conn), 0)


if __name__ == "__main__":
    unittest.main()
