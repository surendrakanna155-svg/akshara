"""Unit tests for the Download Verification & Recovery Engine.

Synthetic fixtures only — no network, no real downloads. Each test builds an
isolated temp workspace so tests never touch the real curriculum repository.
Run:  python3 -m unittest discover -s curriculum/scripts/verification/tests -v
"""

from __future__ import annotations

import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from verification_engine import (  # noqa: E402
    DUPLICATE,
    FAILED,
    VERIFIED,
    Reason,
    VerificationEngine,
)

CONFIGS_SRC = Path(__file__).resolve().parents[3] / "configs"


def make_minimal_pdf(pages: int = 1, pad_to: int = 0, truncate_tail: bool = False) -> bytes:
    """Hand-assembled valid PDF with correct xref offsets."""
    kids = " ".join(f"{3 + i} 0 R" for i in range(pages))
    objects = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        f"<< /Type /Pages /Kids [{kids}] /Count {pages} >>".encode(),
    ]
    for _ in range(pages):
        objects.append(b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>")

    out = bytearray(b"%PDF-1.4\n")
    offsets = []
    for i, body in enumerate(objects, start=1):
        offsets.append(len(out))
        out += f"{i} 0 obj\n".encode() + body + b"\nendobj\n"
    if pad_to and len(out) < pad_to:  # pad inside a comment stream to reach size floors
        out += b"%" + b"P" * (pad_to - len(out) - 2) + b"\n"
    xref_pos = len(out)
    out += f"xref\n0 {len(objects) + 1}\n".encode()
    out += b"0000000000 65535 f \n"
    for off in offsets:
        out += f"{off:010d} 00000 n \n".encode()
    out += (f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\n"
            f"startxref\n{xref_pos}\n%%EOF\n").encode()
    data = bytes(out)
    if truncate_tail:  # simulate a partial download: cut xref/trailer/%%EOF away
        data = data[:xref_pos - 10]
    return data


class EngineTestCase(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="ci_verify_test_"))
        shutil.copytree(CONFIGS_SRC, self.tmp / "configs")
        # relax size floor so tiny synthetic PDFs exercise the real checks
        rules_path = self.tmp / "configs" / "verification_rules.json"
        rules = json.loads(rules_path.read_text())
        rules["min_size_bytes"]["pdf"] = 512
        rules["min_size_bytes"]["default"] = 64
        rules_path.write_text(json.dumps(rules))
        self.engine = VerificationEngine(self.tmp)
        self.incoming = self.tmp / "downloads" / "incoming"
        self.incoming.mkdir(parents=True)

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def expected(self, filename: str, rid: str = "AKS-CBSE-08-SCI-TEXT-2026-000001") -> dict:
        return {
            "resource_id": rid,
            "expected_filename": filename,
            "document_type": "Textbook",
            "board": "CBSE",
            "class_label": "Class_08",
            "subject": "Science",
            "language": "English",
            "medium": "English",
            "source_url": "https://ncert.example/textbook.pdf",
            "download_timestamp": "2026-07-07T00:00:00Z",
            "destination": "curriculum/cbse/Class_08/Science/Textbooks",
            "alternative_sources": ["https://alt.example/textbook.pdf"],
        }

    def drop(self, filename: str, data: bytes) -> Path:
        p = self.incoming / filename
        p.write_bytes(data)
        return p

    # ------------------------------------------------------------ happy path

    def test_valid_pdf_passes_all_checks_and_moves_to_repository(self):
        f = self.drop("CBSE_Class08_Science_Textbook_2026_English.pdf", make_minimal_pdf(pages=3, pad_to=600))
        exp = self.expected(f.name)
        res = self.engine.verify_resource(exp, f)
        self.assertEqual(res.status, VERIFIED, res.detail)
        self.assertTrue(all(c.passed for c in res.checks), [c for c in res.checks if not c.passed])
        final = Path(res.final_path)
        self.assertTrue(final.is_file())
        self.assertIn("resources", final.parts)
        self.assertFalse(f.exists())  # moved, not copied
        # metadata + indexes written
        meta = self.tmp / "metadata" / "resources" / f"{f.name}.metadata.json"
        self.assertTrue(meta.is_file())
        master = json.loads((self.tmp / "indexes" / "master_index.json").read_text())
        self.assertEqual(master[exp["resource_id"]]["verification_status"], "VERIFIED")
        completed = json.loads((self.tmp / "COMPLETED_DOWNLOADS.json").read_text())
        self.assertEqual(completed[0]["checksum_sha256"], res.sha256)

    # --------------------------------------------------------------- failures

    def test_empty_file_fails(self):
        f = self.drop("CBSE_Class08_Science_Textbook_2026_English.pdf", b"")
        res = self.engine.verify_resource(self.expected(f.name), f)
        self.assertEqual(res.status, FAILED)
        self.assertEqual(res.reason_code, Reason.EMPTY_FILE)

    def test_tiny_file_rejected_as_too_small(self):
        f = self.drop("CBSE_Class08_Science_Textbook_2026_English.pdf", b"%PDF-1.4\n%%EOF\n")
        res = self.engine.verify_resource(self.expected(f.name), f)
        self.assertEqual(res.reason_code, Reason.TOO_SMALL)

    def test_html_error_page_masquerading_as_pdf_rejected(self):
        html = b"<!DOCTYPE html><html><body><h1>404 Not Found</h1></body></html>" + b" " * 600
        f = self.drop("CBSE_Class08_Science_Textbook_2026_English.pdf", html)
        res = self.engine.verify_resource(self.expected(f.name), f)
        self.assertEqual(res.status, FAILED)
        self.assertEqual(res.reason_code, Reason.CONTENT_TYPE_MISMATCH)

    def test_truncated_pdf_detected_as_partial_download(self):
        f = self.drop("CBSE_Class08_Science_Textbook_2026_English.pdf",
                      make_minimal_pdf(pages=2, pad_to=900, truncate_tail=True))
        res = self.engine.verify_resource(self.expected(f.name), f)
        self.assertEqual(res.status, FAILED)
        self.assertEqual(res.reason_code, Reason.PDF_TRUNCATED)

    def test_zero_page_pdf_rejected(self):
        # valid structure but no /Page objects: catalog + empty pages tree
        raw = bytearray(b"%PDF-1.4\n")
        objs = [b"<< /Type /Catalog /Pages 2 0 R >>", b"<< /Type /Pages /Kids [] /Count 0 >>"]
        offs = []
        for i, body in enumerate(objs, 1):
            offs.append(len(raw))
            raw += f"{i} 0 obj\n".encode() + body + b"\nendobj\n"
        raw += b"%" + b"P" * 600 + b"\n"
        xref = len(raw)
        raw += f"xref\n0 {len(objs)+1}\n".encode() + b"0000000000 65535 f \n"
        for o in offs:
            raw += f"{o:010d} 00000 n \n".encode()
        raw += f"trailer\n<< /Size {len(objs)+1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n".encode()
        f = self.drop("CBSE_Class08_Science_Textbook_2026_English.pdf", bytes(raw))
        res = self.engine.verify_resource(self.expected(f.name), f)
        self.assertEqual(res.reason_code, Reason.PDF_NO_PAGES)

    def test_name_mismatch_fails(self):
        f = self.drop("random_download(1).pdf", make_minimal_pdf(pad_to=600))
        res = self.engine.verify_resource(self.expected("CBSE_Class08_Science_Textbook_2026_English.pdf"), f)
        self.assertEqual(res.reason_code, Reason.NAME_MISMATCH)

    # ----------------------------------------------------- recovery mechanics

    def test_failure_recorded_in_failed_downloads_with_retry_metadata(self):
        f = self.drop("CBSE_Class08_Science_Textbook_2026_English.pdf", b"")
        exp = self.expected(f.name)
        self.engine.verify_resource(exp, f)
        failed = json.loads((self.tmp / "FAILED_DOWNLOADS.json").read_text())
        self.assertEqual(len(failed), 1)
        e = failed[0]
        self.assertEqual(e["failure_reason"], Reason.EMPTY_FILE)
        self.assertEqual(e["retry_count"], 1)
        self.assertEqual(e["status"], "RETRY_PENDING")
        self.assertIn("next_retry", e)
        # bad artifact preserved for forensics
        preserved = list((self.tmp / "downloads" / "failed").glob("*"))
        self.assertEqual(len(preserved), 1)

    def test_recovery_ladder_retry_then_alternative_then_missing(self):
        exp = self.expected("CBSE_Class08_Science_Textbook_2026_English.pdf")
        rid = exp["resource_id"]
        # two failures on primary source (max_retries_per_source = 2)
        for _ in range(2):
            f = self.drop(exp["expected_filename"], b"")
            self.engine.verify_resource(exp, f)
        action = self.engine.next_recovery_action(rid)
        self.assertEqual(action["action"], "TRY_ALTERNATIVE")
        self.assertEqual(action["url"], exp["alternative_sources"][0])
        # two failures on the alternative
        for _ in range(2):
            f = self.drop(exp["expected_filename"], b"")
            self.engine.verify_resource(exp, f)
        action = self.engine.next_recovery_action(rid)
        self.assertEqual(action["action"], "RECORD_MISSING")
        self.engine.record_missing(exp, ["ncert.example", "alt.example"], "all sources exhausted")
        md = (self.tmp / "MISSING_RESOURCES.md").read_text()
        self.assertIn(rid, md)
        self.assertIn("all sources exhausted", md)

    def test_recovery_success_clears_failure_entry(self):
        exp = self.expected("CBSE_Class08_Science_Textbook_2026_English.pdf")
        f = self.drop(exp["expected_filename"], b"")
        self.engine.verify_resource(exp, f)  # fail once
        f = self.drop(exp["expected_filename"], make_minimal_pdf(pages=2, pad_to=700))
        res = self.engine.verify_resource(exp, f)  # retry succeeds
        self.assertEqual(res.status, VERIFIED)
        failed = json.loads((self.tmp / "FAILED_DOWNLOADS.json").read_text())
        self.assertEqual(failed, [])

    def test_duplicate_content_diverted_not_reindexed(self):
        pdf = make_minimal_pdf(pages=1, pad_to=650)
        f1 = self.drop("CBSE_Class08_Science_Textbook_2026_English.pdf", pdf)
        r1 = self.engine.verify_resource(self.expected(f1.name), f1)
        self.assertEqual(r1.status, VERIFIED)
        exp2 = self.expected("CBSE_Class08_Science_Textbook_2026_English_v2.pdf",
                             rid="AKS-CBSE-08-SCI-TEXT-2026-000002")
        f2 = self.drop(exp2["expected_filename"], pdf)
        r2 = self.engine.verify_resource(exp2, f2)
        self.assertEqual(r2.status, DUPLICATE)
        dmap = json.loads((self.tmp / "indexes" / "duplicate_map.json").read_text())
        self.assertEqual(len(dmap), 1)
        dups = list((self.tmp / "downloads" / "duplicates").glob("*"))
        self.assertEqual(len(dups), 1)

    # ---------------------------------------------------------------- report

    def test_report_contains_all_required_counters(self):
        exp_ok = self.expected("CBSE_Class08_Science_Textbook_2026_English.pdf")
        exp_bad = self.expected("CBSE_Class08_Maths_Textbook_2026_English.pdf",
                                rid="AKS-CBSE-08-MATH-TEXT-2026-000001")
        (self.tmp / "DOWNLOAD_QUEUE.json").write_text(json.dumps([exp_ok, exp_bad]))
        self.engine.verify_resource(exp_ok, self.drop(exp_ok["expected_filename"], make_minimal_pdf(pad_to=700)))
        self.engine.verify_resource(exp_bad, self.drop(exp_bad["expected_filename"], b""))
        report = self.engine.generate_report().read_text()
        for needle in ["Total Expected Files | 2", "Successfully Verified | 1",
                       "Empty / Too-Small Files | 1", "Overall Download Health Score",
                       "Corrupted Files", "Duplicate Files", "Retried Downloads",
                       "Alternative Sources Used", "Remaining Missing Resources"]:
            self.assertIn(needle, report)

    # ----------------------------------------------------------------- audit

    def test_repository_audit_pass_and_fail_paths(self):
        import repository_audit

        exp = self.expected("CBSE_Class08_Science_Textbook_2026_English.pdf")
        (self.tmp / "DOWNLOAD_QUEUE.json").write_text(json.dumps([exp]))
        f = self.drop(exp["expected_filename"], make_minimal_pdf(pages=2, pad_to=700))
        self.assertEqual(self.engine.verify_resource(exp, f).status, VERIFIED)

        self.assertEqual(repository_audit.audit(self.tmp), 0)
        status = json.loads((self.tmp / "PROJECT_STATUS.json").read_text())
        self.assertEqual(status["repository_status"], repository_audit.READY)

        # corrupt the stored file → audit must fail and revoke readiness
        master = json.loads((self.tmp / "indexes" / "master_index.json").read_text())
        stored = self.tmp / master[exp["resource_id"]]["repository_path"]
        stored.write_bytes(b"corrupted")
        self.assertEqual(repository_audit.audit(self.tmp), 1)
        status = json.loads((self.tmp / "PROJECT_STATUS.json").read_text())
        self.assertEqual(status["repository_status"], "NOT_READY")
        self.assertIn("A4", (self.tmp / "reports" / "REPOSITORY_AUDIT_REPORT.md").read_text())


if __name__ == "__main__":
    unittest.main(verbosity=2)
