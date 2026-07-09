"""Tests for the KIE Phase-1 Repository Verification engine.

Builds a synthetic corpus (born-digital / scanned / truncated / duplicate PDFs +
valid/broken archives) in a temp workspace and asserts the verdicts, duplicate
detection, corruption detection, manifest, and report.

Run under the data-lane venv so pypdf is available:
  curriculum/.venv/bin/python -m unittest curriculum.scripts.tests.test_repository_verifier
  curriculum/.venv/bin/python -m unittest discover -s curriculum/scripts/tests -v
"""

from __future__ import annotations

import io
import json
import shutil
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]  # curriculum/
sys.path.insert(0, str(ROOT / "scripts" / "intelligence"))
sys.path.insert(0, str(ROOT / "scripts" / "verification"))

import repository_verifier as rv  # noqa: E402

REAL_CONFIGS = ROOT / "configs"


def _make_pdf(content_stream: bytes) -> bytes:
    """Assemble a byte-correct minimal single-page PDF with a valid xref + startxref."""
    objs = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] "
        b"/Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>",
        b"<< /Length " + str(len(content_stream)).encode() + b" >>\nstream\n"
        + content_stream + b"\nendstream",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    ]
    out = b"%PDF-1.4\n"
    offsets = []
    for i, body in enumerate(objs, start=1):
        offsets.append(len(out))
        out += f"{i} 0 obj\n".encode() + body + b"\nendobj\n"
    xref_pos = len(out)
    n = len(objs) + 1
    out += b"xref\n0 " + str(n).encode() + b"\n0000000000 65535 f \n"
    for off in offsets:
        out += f"{off:010d} 00000 n \n".encode()
    out += b"trailer\n<< /Size " + str(n).encode() + b" /Root 1 0 R >>\n"
    out += b"startxref\n" + str(xref_pos).encode() + b"\n%%EOF"
    return out


# A >200-char text payload so a single sampled page classifies as born_digital.
_TEXT = ("Newtons second law states that force equals mass times acceleration. "
         "This born digital document has a real extractable text layer for parsing. "
         "Kinematics kinetics thermodynamics electromagnetism organic chemistry cells.")
TEXT_PDF = _make_pdf(b"BT /F1 12 Tf 72 700 Td (" + _TEXT.encode() + b") Tj ET")
SCANNED_PDF = _make_pdf(b"q 1 0 0 1 0 0 cm Q")   # graphics only, no text operators
TRUNCATED_PDF = TEXT_PDF[:120]                    # header present, no %%EOF / startxref


def _valid_zip() -> bytes:
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as zf:
        zf.writestr("inner.txt", "packaged resource content")
    return buf.getvalue()


class RepositoryVerifierTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="kie_p1_"))
        (self.tmp / "configs").mkdir(parents=True)
        for f in ("paths.json", "verification_rules.json"):
            shutil.copy(REAL_CONFIGS / f, self.tmp / "configs" / f)
        self.src = self.tmp / "resources" / "foundation"
        self.src.mkdir(parents=True)
        self.verifier = rv.RepositoryVerifier(self.tmp)

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def _write(self, rel: str, data: bytes) -> Path:
        p = self.src / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(data)
        return p

    # ---------------------------------------------------------------- readiness

    @unittest.skipUnless(rv.HAVE_PYPDF, "pypdf required for readiness classification")
    def test_born_digital_text(self):
        self._write("NEET/a.pdf", TEXT_PDF)
        v = self.verifier.verify_file(self.src / "NEET" / "a.pdf")
        self.assertTrue(v.integrity_ok)
        self.assertEqual(v.parser_class, "born_digital_text")
        self.assertEqual(v.parser_strategy, "text_extract")
        self.assertEqual(v.category, "NEET")
        self.assertGreater(v.text_chars_sampled, 200)

    @unittest.skipUnless(rv.HAVE_PYPDF, "pypdf required for readiness classification")
    def test_scanned_image(self):
        self._write("AIIMS/scan.pdf", SCANNED_PDF)
        v = self.verifier.verify_file(self.src / "AIIMS" / "scan.pdf")
        self.assertTrue(v.integrity_ok)          # structurally valid, just no text
        self.assertEqual(v.parser_class, "scanned_image")
        self.assertEqual(v.parser_strategy, "ocr")
        self.assertEqual(v.text_chars_sampled, 0)

    def test_corrupt_truncated(self):
        self._write("JEE_Main/bad.pdf", TRUNCATED_PDF)
        v = self.verifier.verify_file(self.src / "JEE_Main" / "bad.pdf")
        self.assertFalse(v.integrity_ok)
        self.assertEqual(v.parser_class, "corrupt")
        self.assertEqual(v.parser_strategy, "exclude")
        self.assertIsNotNone(v.corruption_reason)

    # --------------------------------------------------------------- archives

    def test_archive_valid(self):
        self._write("Practice_Resources/pack.zip", _valid_zip())
        v = self.verifier.verify_file(self.src / "Practice_Resources" / "pack.zip")
        self.assertTrue(v.integrity_ok)
        self.assertEqual(v.parser_class, "archive")
        self.assertEqual(v.parser_strategy, "unpack")

    def test_archive_corrupt(self):
        self._write("Practice_Resources/broken.zip", b"PK\x03\x04not-a-real-zip-body")
        v = self.verifier.verify_file(self.src / "Practice_Resources" / "broken.zip")
        self.assertFalse(v.integrity_ok)
        self.assertEqual(v.parser_class, "corrupt")

    # -------------------------------------------------------------- duplicates

    def test_exact_duplicate_detection(self):
        self._write("NEET/one.pdf", TEXT_PDF)
        self._write("NEET/two.pdf", TEXT_PDF)   # identical bytes
        self._write("JEE_Main/unique.pdf", SCANNED_PDF)
        manifest = self.verifier.run()
        self.assertEqual(len(manifest["duplicate_sets"]), 1)
        dset = manifest["duplicate_sets"][0]
        self.assertEqual(dset["kept"], "NEET/one.pdf")            # first by sorted path
        self.assertEqual(dset["duplicates"], ["NEET/two.pdf"])
        self.assertEqual(manifest["totals"]["duplicate_files"], 1)
        self.assertEqual(manifest["totals"]["unique_documents"], 2)

    def test_filename_collision_hint(self):
        self._write("NEET/paper.pdf", TEXT_PDF)
        self._write("JEE_Main/paper.pdf", SCANNED_PDF)  # same name, different content
        manifest = self.verifier.run()
        names = [c["filename"] for c in manifest["filename_collisions"]]
        self.assertIn("paper.pdf", names)

    # ------------------------------------------------------------ full run/IO

    def test_run_writes_manifest_report_status(self):
        self._write("NEET/a.pdf", TEXT_PDF)
        self._write("AIIMS/scan.pdf", SCANNED_PDF)
        self._write("JEE_Main/bad.pdf", TRUNCATED_PDF)
        self._write("Practice_Resources/pack.zip", _valid_zip())
        manifest = self.verifier.run()

        self.assertTrue(self.verifier.manifest_path.is_file())
        self.assertTrue(self.verifier.report_path.is_file())
        self.assertTrue(self.verifier.status_path.is_file())

        t = manifest["totals"]
        self.assertEqual(t["total_files"], 4)
        self.assertEqual(t["corrupt"], 1)
        self.assertEqual(t["needs_unpack"], 1)

        status = json.loads(self.verifier.status_path.read_text())
        self.assertIn("kie_phase1", status)
        self.assertEqual(status["kie_phase1"]["total_files"], 4)

        report = self.verifier.report_path.read_text()
        self.assertIn("Repository Verification Report", report)
        self.assertIn("JEE_Main/bad.pdf", report)

    def test_report_only_regenerates(self):
        self._write("NEET/a.pdf", TEXT_PDF)
        self.verifier.run()
        self.verifier.report_path.unlink()
        manifest = rv._load_json(self.verifier.manifest_path, None)
        self.assertIsNotNone(manifest)
        self.verifier.report_path.write_text(self.verifier._render_report(manifest), encoding="utf-8")
        self.assertTrue(self.verifier.report_path.is_file())

    def test_sample_indices(self):
        self.assertEqual(rv._sample_indices(1, 5), [0])
        self.assertEqual(rv._sample_indices(0, 5), [])
        idx = rv._sample_indices(100, 5)
        self.assertEqual(idx[0], 0)
        self.assertEqual(idx[-1], 99)
        self.assertLessEqual(len(idx), 5)


if __name__ == "__main__":
    unittest.main()
