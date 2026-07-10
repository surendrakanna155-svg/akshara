"""Intake Center I6 — batch + queue reports render from the control tables."""
import shutil
import tempfile
import unittest
from pathlib import Path

from kie import config
from kie.intake import report
from kie.intake.center import IntakeCenter


def _rich_pdf(path: Path) -> Path:
    import fitz
    doc = fitz.open()
    p = doc.new_page()
    p.insert_text((72, 90), "Laws Of Motion", fontsize=20)
    p.insert_text((72, 130), "Force is defined as the product of mass and acceleration.", fontsize=11)
    p.insert_text((72, 200), "Which is correct (A) mass (B) weight (C) force (D) energy", fontsize=11)
    path.parent.mkdir(parents=True, exist_ok=True)
    doc.save(str(path))
    doc.close()
    return path


class TestReports(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self._orig = (config.KIE_HOME, config.PARSED_DIR, config.REPORTS_DIR)
        self.center = IntakeCenter(prod_db_path=self.tmp / "prod.db", intake_ws=self.tmp / "ws",
                                   staging_dir=self.tmp / "staging")

    def tearDown(self):
        config.KIE_HOME, config.PARSED_DIR, config.REPORTS_DIR = self._orig
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_batch_and_queue_reports(self):
        pdf = _rich_pdf(self.tmp / "src" / "physics_2024.pdf")
        self.center.import_paths([pdf], batch_id="B1")
        conn = self.center.open()
        try:
            br = report.batch_report(conn, "B1")
            self.assertIn("Batch `B1`", br)
            self.assertIn("physics_2024.pdf", br)
            qr = report.queue_report(conn)
            self.assertIn("Queue Status", qr)
            self.assertIn("Total items seen", qr)
        finally:
            conn.close()

    def test_missing_batch(self):
        conn = self.center.open()
        try:
            self.assertIn("Not found", report.batch_report(conn, "NOPE"))
        finally:
            conn.close()


if __name__ == "__main__":
    unittest.main()
