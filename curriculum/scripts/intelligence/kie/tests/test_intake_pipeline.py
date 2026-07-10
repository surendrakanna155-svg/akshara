"""Intake Center I3 — staging pipeline reuses phases 2-7 on an isolated staging store."""
import shutil
import tempfile
import unittest
from pathlib import Path

from kie import config, store
from kie.intake import detect, pipeline
from kie.intake.models import ReviewStatus


def _rich_pdf(path: Path) -> Path:
    """A born-digital PDF with a heading, a definition, a named law, and an MCQ so the
    deterministic concept + question extractors all yield output."""
    import fitz
    doc = fitz.open()
    page = doc.new_page()
    page.insert_text((72, 90), "Laws Of Motion", fontsize=20)
    page.insert_text((72, 130), "Force is defined as the product of mass and acceleration.", fontsize=11)
    page.insert_text((72, 150), "Newton's Second Law relates force mass and acceleration.", fontsize=11)
    page.insert_text((72, 170), "Momentum is defined as the product of mass and velocity.", fontsize=11)
    page.insert_text((72, 200), "Which of the following is correct (A) mass (B) weight (C) force (D) energy", fontsize=11)
    page2 = doc.new_page()
    page2.insert_text((72, 90), "Work And Energy", fontsize=20)
    page2.insert_text((72, 130), "Energy is defined as the capacity to do work in physics.", fontsize=11)
    path.parent.mkdir(parents=True, exist_ok=True)
    doc.save(str(path))
    doc.close()
    return path


def _blank_pdf(path: Path) -> Path:
    import fitz
    doc = fitz.open()
    doc.new_page()  # no text
    path.parent.mkdir(parents=True, exist_ok=True)
    doc.save(str(path))
    doc.close()
    return path


class TestStagingPipeline(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.ws = self.tmp / "ws"                       # intake workspace (files land here)
        self._orig = (config.KIE_HOME, config.PARSED_DIR, config.REPORTS_DIR)
        config.KIE_HOME = self.tmp / "kie"
        config.PARSED_DIR = config.KIE_HOME / "parsed"
        config.REPORTS_DIR = config.KIE_HOME / "reports"
        config.ensure_dirs()

    def tearDown(self):
        config.KIE_HOME, config.PARSED_DIR, config.REPORTS_DIR = self._orig
        shutil.rmtree(self.tmp, ignore_errors=True)

    def _stage(self, origin: Path, category="NEET"):
        verdict = detect.verify_file(origin)
        doc_id = detect.doc_id_for(verdict["sha256"])
        rel = pipeline.stage_resource(origin, doc_id, origin.name, self.ws)
        conn = store.open_store(":memory:")
        pipeline.ingest_to_staging(conn, verdict, rel, category)
        summaries = pipeline.run_phases(conn, self.ws)
        return conn, doc_id, rel, summaries

    def test_end_to_end_extracts_knowledge(self):
        origin = _rich_pdf(self.tmp / "src" / "physics_2024.pdf")
        conn, doc_id, rel, summaries = self._stage(origin)

        # file copied into the content-addressed managed tree
        self.assertTrue((self.ws / "resources/intake" / rel).exists())
        # staging contains ONLY this batch's document (baseline never seen)
        self.assertEqual(conn.execute("SELECT COUNT(*) n FROM source_documents").fetchone()["n"], 1)

        stats = pipeline.staged_stats(conn, doc_id)
        self.assertGreater(stats.chunks, 0)
        self.assertGreater(stats.concepts, 0)          # definitions + section titles + law
        self.assertGreaterEqual(stats.patterns, 1)     # the MCQ became a question pattern

        # clean born-digital extraction → no flags → PENDING (ready for human review)
        flags = pipeline.staged_flags(conn, doc_id)
        self.assertEqual(flags, [])
        self.assertEqual(pipeline.review_status_for(flags), ReviewStatus.PENDING)
        self.assertTrue(pipeline.sample_concepts(conn, doc_id))
        conn.close()

    def test_reuses_frozen_phase_functions(self):
        # graph + questions actually ran in staging (edges/patterns exist globally)
        origin = _rich_pdf(self.tmp / "src" / "chem.pdf")
        conn, doc_id, rel, summaries = self._stage(origin)
        self.assertIn("graph", summaries)
        self.assertIn("questions", summaries)
        self.assertGreaterEqual(conn.execute("SELECT COUNT(*) n FROM question_patterns").fetchone()["n"], 1)
        conn.close()

    def test_empty_document_flagged_for_review(self):
        origin = _blank_pdf(self.tmp / "src" / "blank.pdf")
        conn, doc_id, rel, summaries = self._stage(origin)
        flags = pipeline.staged_flags(conn, doc_id)
        # no text → no chunks and/or no concepts → routed to NEEDS_REVIEW
        self.assertTrue(flags)
        self.assertEqual(pipeline.review_status_for(flags), ReviewStatus.NEEDS_REVIEW)
        conn.close()

    def test_restage_is_idempotent_copy(self):
        origin = _rich_pdf(self.tmp / "src" / "bio.pdf")
        verdict = detect.verify_file(origin)
        doc_id = detect.doc_id_for(verdict["sha256"])
        rel1 = pipeline.stage_resource(origin, doc_id, origin.name, self.ws)
        rel2 = pipeline.stage_resource(origin, doc_id, origin.name, self.ws)  # no error, same rel
        self.assertEqual(rel1, rel2)


if __name__ == "__main__":
    unittest.main()
