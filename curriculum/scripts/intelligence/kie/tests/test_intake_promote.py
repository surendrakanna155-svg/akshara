"""Intake Center I4 — additive promotion staging→production + versioning + derived refresh.

Proves the immutability contract: promotion only ADDS the new doc's content and never
mutates baseline rows; shared concept_codes keep the baseline row verbatim; the two derived
projections are refreshed over the combined corpus.
"""
import shutil
import tempfile
import unittest
from pathlib import Path

from kie import config, store
from kie.intake import detect, pipeline, promote
from kie.intake.models import Disposition
from kie.intake.store_ext import apply_intake_schema, now_iso


def _rich_pdf(path: Path) -> Path:
    import fitz
    doc = fitz.open()
    p = doc.new_page()
    p.insert_text((72, 90), "Laws Of Motion", fontsize=20)
    p.insert_text((72, 130), "Force is defined as the product of mass and acceleration.", fontsize=11)
    p.insert_text((72, 150), "Newton's Second Law relates force mass and acceleration.", fontsize=11)
    p.insert_text((72, 170), "Energy is defined as the capacity to do work in physics.", fontsize=11)
    p.insert_text((72, 200), "Which of the following is correct (A) mass (B) weight (C) force (D) energy", fontsize=11)
    path.parent.mkdir(parents=True, exist_ok=True)
    doc.save(str(path))
    doc.close()
    return path


class TestPromotion(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.ws = self.tmp / "ws"
        self._orig = (config.KIE_HOME, config.PARSED_DIR, config.REPORTS_DIR)
        config.KIE_HOME = self.tmp / "kie"
        config.PARSED_DIR = config.KIE_HOME / "parsed"
        config.REPORTS_DIR = config.KIE_HOME / "reports"
        config.ensure_dirs()
        # production store (in-memory is fine; the staging file is ATTACHed to it)
        self.prod = store.open_store(":memory:")
        apply_intake_schema(self.prod)

    def tearDown(self):
        config.KIE_HOME, config.PARSED_DIR, config.REPORTS_DIR = self._orig
        self.prod.close()
        shutil.rmtree(self.tmp, ignore_errors=True)

    def _build_staging(self, pdf: Path, category="NEET"):
        """Stage a PDF into a fresh staging FILE db; return (staging_path, doc_id, detection)."""
        verdict = detect.verify_file(pdf)
        doc_id = detect.doc_id_for(verdict["sha256"])
        detection = detect.classify_source(self.prod, verdict, category, pdf.name)
        rel = pipeline.stage_resource(pdf, doc_id, pdf.name, self.ws)
        spath = self.tmp / f"staging_{doc_id}.db"
        sconn = store.open_store(str(spath))
        pipeline.ingest_to_staging(sconn, verdict, rel, category)
        pipeline.run_phases(sconn, self.ws)
        sconn.close()
        return spath, doc_id, detection

    def _seed_baseline(self):
        """A tiny immutable baseline: 1 doc, 1 chunk, 1 concept — with sentinel values."""
        self.prod.execute(
            "INSERT INTO source_documents(doc_id,corpus,rel_path,category,sha256,integrity_ok,encrypted,"
            "is_duplicate,verify_status,certify_status,certify_reason,created_at) "
            "VALUES ('baseline00000000','foundation','NCERT/base.pdf','NCERT',?,1,0,0,'verified','certified','ok',?)",
            ("f" * 64, now_iso()))
        self.prod.execute(
            "INSERT INTO chunks(chunk_id,doc_id,ordinal,block_type,text) "
            "VALUES ('baseline00000000#0','baseline00000000',0,'paragraph','baseline chunk text')")
        self.prod.execute("INSERT INTO chunks_fts(text, chunk_id) VALUES ('baseline chunk text','baseline00000000#0')")
        self.prod.commit()

    def test_additive_promotion_preserves_baseline(self):
        self._seed_baseline()
        pdf = _rich_pdf(self.tmp / "src" / "physics_2024.pdf")
        spath, doc_id, detection = self._build_staging(pdf)
        self.assertEqual(detection["disposition"], Disposition.NEW)

        # pick a staged concept and pre-seed it into the baseline with a sentinel definition
        sconn = store.open_store(str(spath))
        shared_code = sconn.execute(
            "SELECT concept_code FROM concepts WHERE json_extract(evidence,'$.doc')=? ORDER BY concept_code LIMIT 1",
            (doc_id,)).fetchone()["concept_code"]
        sconn.close()
        self.prod.execute(
            "INSERT INTO concepts(concept_code,title,definition,status,evidence,created_at) "
            "VALUES (?,?,?,'active',?,?)",
            (shared_code, "Preexisting", "BASELINE_PRESERVED", '{"doc":"baseline00000000"}', now_iso()))
        self.prod.commit()
        base_docs = self.prod.execute("SELECT COUNT(*) n FROM source_documents").fetchone()["n"]
        base_concepts = self.prod.execute("SELECT COUNT(*) n FROM concepts").fetchone()["n"]

        promote.promote_document(self.prod, spath, doc_id, detection, item_id="B#1")

        # new doc + its chunks added; baseline doc + chunk untouched
        self.assertEqual(self.prod.execute("SELECT COUNT(*) n FROM source_documents").fetchone()["n"], base_docs + 1)
        self.assertTrue(self.prod.execute("SELECT 1 FROM source_documents WHERE doc_id=?", (doc_id,)).fetchone())
        self.assertEqual(
            self.prod.execute("SELECT text FROM chunks WHERE chunk_id='baseline00000000#0'").fetchone()["text"],
            "baseline chunk text")
        self.assertGreater(self.prod.execute("SELECT COUNT(*) n FROM chunks WHERE doc_id=?", (doc_id,)).fetchone()["n"], 0)

        # shared concept_code kept the BASELINE row verbatim (never overwritten); new codes added
        self.assertEqual(
            self.prod.execute("SELECT definition FROM concepts WHERE concept_code=?", (shared_code,)).fetchone()["definition"],
            "BASELINE_PRESERVED")
        self.assertGreater(self.prod.execute("SELECT COUNT(*) n FROM concepts").fetchone()["n"], base_concepts)

        # FTS stays in lockstep with chunks
        nc = self.prod.execute("SELECT COUNT(*) n FROM chunks").fetchone()["n"]
        nf = self.prod.execute("SELECT COUNT(*) n FROM chunks_fts").fetchone()["n"]
        self.assertEqual(nc, nf)

        # version recorded as v1
        v = self.prod.execute("SELECT version_no FROM document_versions WHERE doc_id=?", (doc_id,)).fetchone()
        self.assertEqual(v["version_no"], 1)

    def test_promotion_is_idempotent(self):
        pdf = _rich_pdf(self.tmp / "src" / "chem_2024.pdf")
        spath, doc_id, detection = self._build_staging(pdf)
        promote.promote_document(self.prod, spath, doc_id, detection, item_id="B#1")
        c1 = self.prod.execute("SELECT COUNT(*) n FROM chunks").fetchone()["n"]
        v1 = self.prod.execute("SELECT COUNT(*) n FROM document_versions").fetchone()["n"]
        promote.promote_document(self.prod, spath, doc_id, detection, item_id="B#1")  # again
        self.assertEqual(self.prod.execute("SELECT COUNT(*) n FROM chunks").fetchone()["n"], c1)
        self.assertEqual(self.prod.execute("SELECT COUNT(*) n FROM chunks_fts").fetchone()["n"], c1)
        self.assertEqual(self.prod.execute("SELECT COUNT(*) n FROM document_versions").fetchone()["n"], v1)

    def test_derived_refresh_after_promotion(self):
        pdf = _rich_pdf(self.tmp / "src" / "bio_2024.pdf")
        spath, doc_id, detection = self._build_staging(pdf)
        promote.promote_document(self.prod, spath, doc_id, detection, item_id="B#1")
        out = promote.refresh_derived(self.prod)
        self.assertIn("graph", out)
        self.assertGreaterEqual(self.prod.execute("SELECT COUNT(*) n FROM question_patterns").fetchone()["n"], 1)

    def test_new_version_supersedes_prior_head(self):
        # register a prior head for a lineage
        lk = detect.lineage_key("NEET", "physics_2024.pdf")
        self.prod.execute(
            "INSERT INTO document_versions(version_id,lineage_key,doc_id,version_no,sha256,year,created_at) "
            "VALUES (?,?,?,?,?,?,?)", (f"{lk}@v1", lk, "priorhead0000000", 1, "a" * 64, 2024, now_iso()))
        self.prod.commit()
        pdf = _rich_pdf(self.tmp / "src" / "physics_2025.pdf")   # same lineage, newer content
        spath, doc_id, detection = self._build_staging(pdf)
        self.assertEqual(detection["disposition"], Disposition.NEW_VERSION)
        self.assertEqual(detection["version_no"], 2)
        promote.promote_document(self.prod, spath, doc_id, detection, item_id="B#1")
        # both versions present; old head superseded by new; new head open
        old = self.prod.execute("SELECT superseded_by FROM document_versions WHERE doc_id='priorhead0000000'").fetchone()
        new = self.prod.execute("SELECT superseded_by, version_no FROM document_versions WHERE doc_id=?", (doc_id,)).fetchone()
        self.assertEqual(old["superseded_by"], doc_id)
        self.assertIsNone(new["superseded_by"])
        self.assertEqual(new["version_no"], 2)


if __name__ == "__main__":
    unittest.main()
