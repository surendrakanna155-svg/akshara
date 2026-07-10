"""Intake Center I5 — IntakeCenter end-to-end: import → review queue → approve/reject →
production; plus exact-duplicate short-circuit, watch folder, and batch lifecycle."""
import shutil
import tempfile
import unittest
from pathlib import Path

from kie import config, store
from kie.intake.center import IntakeCenter
from kie.intake.models import BatchStatus, Disposition, ReviewStatus, SourceKind
from kie.intake.store_ext import apply_intake_schema


def _rich_pdf(path: Path, extra: str = "") -> Path:
    import fitz
    doc = fitz.open()
    p = doc.new_page()
    p.insert_text((72, 90), "Laws Of Motion", fontsize=20)
    p.insert_text((72, 130), "Force is defined as the product of mass and acceleration.", fontsize=11)
    p.insert_text((72, 150), "Newton's Second Law relates force mass and acceleration.", fontsize=11)
    p.insert_text((72, 170), f"Energy is defined as the capacity to do work. {extra}", fontsize=11)
    p.insert_text((72, 200), "Which of the following is correct (A) mass (B) weight (C) force (D) energy", fontsize=11)
    path.parent.mkdir(parents=True, exist_ok=True)
    doc.save(str(path))
    doc.close()
    return path


class TestIntakeCenter(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self._orig = (config.KIE_HOME, config.PARSED_DIR, config.REPORTS_DIR)
        config.KIE_HOME = self.tmp / "kie"
        config.PARSED_DIR = config.KIE_HOME / "parsed"
        config.REPORTS_DIR = config.KIE_HOME / "reports"
        config.ensure_dirs()
        self.center = IntakeCenter(
            prod_db_path=self.tmp / "prod.db",
            intake_ws=self.tmp / "ws",
            staging_dir=self.tmp / "staging",
        )

    def tearDown(self):
        config.KIE_HOME, config.PARSED_DIR, config.REPORTS_DIR = self._orig
        shutil.rmtree(self.tmp, ignore_errors=True)

    def _prod(self):
        conn = store.open_store(str(self.tmp / "prod.db"))
        apply_intake_schema(conn)
        return conn

    def test_import_creates_reviewable_items(self):
        pdf = _rich_pdf(self.tmp / "src" / "physics_2024.pdf")
        summary = self.center.import_paths([pdf], source_kind=SourceKind.SINGLE, batch_id="B1")
        self.assertEqual(summary["total"], 1)
        self.assertEqual(summary["staged"], 1)
        self.assertEqual(summary["pending_review"], 1)
        q = self.center.list_queue(status=ReviewStatus.PENDING)
        self.assertEqual(len(q), 1)
        self.assertEqual(q[0].disposition, Disposition.NEW)
        self.assertGreater(q[0].stats.get("concepts", 0), 0)

    def test_approve_promotes_into_production(self):
        pdf = _rich_pdf(self.tmp / "src" / "physics_2024.pdf")
        self.center.import_paths([pdf], batch_id="B1")
        item = self.center.list_queue(batch_id="B1")[0]
        out = self.center.approve(item.item_id, reviewer="teacher", refresh=True)
        self.assertEqual(out["review_status"], ReviewStatus.APPROVED)
        conn = self._prod()
        try:
            self.assertTrue(conn.execute("SELECT 1 FROM source_documents WHERE doc_id=?", (item.doc_id,)).fetchone())
            self.assertGreater(conn.execute("SELECT COUNT(*) n FROM chunks WHERE doc_id=?", (item.doc_id,)).fetchone()["n"], 0)
            self.assertTrue(conn.execute("SELECT 1 FROM document_versions WHERE doc_id=?", (item.doc_id,)).fetchone())
            # batch auto-closed (only item is terminal)
            self.assertEqual(conn.execute("SELECT status FROM intake_batches WHERE batch_id='B1'").fetchone()["status"],
                             BatchStatus.CLOSED)
        finally:
            conn.close()

    def test_reexport_same_file_is_exact_duplicate(self):
        pdf = _rich_pdf(self.tmp / "src" / "physics_2024.pdf")
        self.center.import_paths([pdf], batch_id="B1")
        item = self.center.list_queue(batch_id="B1")[0]
        self.center.approve(item.item_id, refresh=False)
        again = self.center.import_paths([pdf], batch_id="B2")   # identical content, now in prod
        self.assertEqual(again["duplicates"], 1)
        self.assertEqual(again["staged"], 0)
        dup = self.center.list_queue(batch_id="B2")[0]
        self.assertEqual(dup.disposition, Disposition.EXACT_DUPLICATE)
        self.assertEqual(dup.review_status, ReviewStatus.SKIPPED)

    def test_reject_does_not_promote(self):
        pdf = _rich_pdf(self.tmp / "src" / "chem_2024.pdf")
        self.center.import_paths([pdf], batch_id="B1")
        item = self.center.list_queue(batch_id="B1")[0]
        self.center.reject(item.item_id, reviewer="teacher", notes="off-syllabus")
        conn = self._prod()
        try:
            self.assertIsNone(conn.execute("SELECT 1 FROM source_documents WHERE doc_id=?", (item.doc_id,)).fetchone())
        finally:
            conn.close()
        self.assertEqual(self.center.get_item(item.item_id).review_status, ReviewStatus.REJECTED)

    def test_cannot_approve_rejected_item(self):
        pdf = _rich_pdf(self.tmp / "src" / "bio_2024.pdf")
        self.center.import_paths([pdf], batch_id="B1")
        item = self.center.list_queue(batch_id="B1")[0]
        self.center.reject(item.item_id)
        with self.assertRaises(ValueError):
            self.center.approve(item.item_id)

    def test_no_resource_bypasses_the_pipeline(self):
        # two distinct files → two items; every input is recorded as an intake item
        a = _rich_pdf(self.tmp / "src" / "a_2024.pdf", extra="alpha unique alpha")
        b = _rich_pdf(self.tmp / "src" / "b_2024.pdf", extra="beta unique beta")
        summary = self.center.import_paths([a, b], batch_id="B1")
        self.assertEqual(summary["total"], 2)
        self.assertEqual(len(self.center.list_queue(batch_id="B1")), 2)

    def test_watch_folder_ingests_new_then_quiet(self):
        folder = self.tmp / "watched"
        _rich_pdf(folder / "phys_2024.pdf")
        res1 = self.center.poll_watch_folder(folder, category="NEET")
        self.assertEqual(res1["new_or_changed"], 1)
        self.assertIsNotNone(res1["batch_id"])
        self.assertEqual(len(self.center.list_queue(batch_id=res1["batch_id"])), 1)
        res2 = self.center.poll_watch_folder(folder, category="NEET")   # nothing changed
        self.assertEqual(res2["new_or_changed"], 0)


if __name__ == "__main__":
    unittest.main()
