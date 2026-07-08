"""Tests for the continuous acquisition crawler (curriculum/scripts/crawler/).

Canonical requirement: docs/curriculum-intelligence/planning/CRAWLER_SPEC.md.
Deterministic, network-free fixtures only — proves frontier dedup + resume,
sitemap parsing, manifest columns, and the verify gate (Downloaded != Verified).

Run:  python3 -m unittest discover -s curriculum/scripts/tests -v
"""

from __future__ import annotations

import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]  # curriculum/
for _sub in ("crawler", "common", "verification"):
    sys.path.insert(0, str(ROOT / "scripts" / _sub))

import crawl  # noqa: E402
import discovery  # noqa: E402
import manifest  # noqa: E402
import verify  # noqa: E402
from frontier import Frontier, normalize_url  # noqa: E402
from workspace import make_sample_pdf  # noqa: E402

CONFIGS_SRC = ROOT / "configs"

SITEMAP_INDEX_XML = b"""<?xml version="1.0" encoding="UTF-8"?>
<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <sitemap><loc>https://example.gov.in/wp-sitemap-1.xml</loc></sitemap>
  <sitemap><loc>https://example.gov.in/wp-sitemap-2.xml</loc></sitemap>
</sitemapindex>
"""

URLSET_XML = b"""<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://example.gov.in/downloads/Class6_Mathematics_Syllabus.pdf</loc></url>
  <url><loc>https://example.gov.in/curriculum/textbooks.html</loc></url>
  <url><loc>https://example.gov.in/downloads/Class6_Mathematics_Syllabus.pdf</loc></url>
</urlset>
"""

MALFORMED_XML = b"<urlset><url><loc>https://example.gov.in/a.pdf</loc><url></urlset"


class FrontierTestCase(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="ci_crawler_test_"))
        self.state_path = self.tmp / "crawler_state.json"

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_normalize_url_collapses_trivial_variants(self):
        a = normalize_url("HTTPS://Example.gov.in:443/a/b/?y=2&x=1#frag")
        b = normalize_url("https://example.gov.in/a/b?x=1&y=2")
        self.assertEqual(a, b)

    def test_add_dedupes_by_normalized_url(self):
        fr = Frontier(self.state_path)
        self.assertTrue(fr.add("https://example.gov.in/page?a=1&b=2"))
        self.assertFalse(fr.add("https://example.gov.in/page?b=2&a=1"))  # same after normalize
        self.assertFalse(fr.add("https://EXAMPLE.gov.in/page/?a=1&b=2"))  # case + trailing slash
        self.assertEqual(len(fr.queued), 1)

    def test_add_skips_already_visited(self):
        fr = Frontier(self.state_path)
        fr.add("https://example.gov.in/page")
        fr.mark_visited("https://example.gov.in/page", status="CRAWLED")
        self.assertFalse(fr.add("https://example.gov.in/page"))
        self.assertEqual(len(fr.queued), 0)
        self.assertEqual(len(fr.visited), 1)

    def test_sha256_dedup_registry(self):
        fr = Frontier(self.state_path)
        sha = "a" * 64
        self.assertFalse(fr.has_hash(sha))
        fr.record_hash(sha, resource_id="AKS-CBSE-06-MATH-SYLL-2026-000001")
        self.assertTrue(fr.has_hash(sha))

    def test_save_and_load_round_trip_resumes_state(self):
        fr = Frontier(self.state_path)
        fr.add("https://example.gov.in/one")
        fr.add("https://example.gov.in/two")
        fr.mark_visited("https://example.gov.in/two", status="CRAWLED")
        fr.record_hash("b" * 64, resource_id="X")
        fr.next_seq("CBSE-06-MATH-syllabus")
        fr.save()

        resumed = Frontier.load(self.state_path)
        self.assertEqual(resumed.stats(), {"queued": 1, "visited": 1, "known_hashes": 1})
        self.assertTrue(resumed.has_hash("b" * 64))
        # a resumed frontier must not re-add already-visited/queued URLs
        self.assertFalse(resumed.add("https://example.gov.in/one"))
        self.assertFalse(resumed.add("https://example.gov.in/two"))
        # sequence counters persist too (no restart-to-1 collision)
        self.assertEqual(resumed.next_seq("CBSE-06-MATH-syllabus"), 2)

    def test_pop_is_fifo_and_empties_cleanly(self):
        fr = Frontier(self.state_path)
        fr.add("https://example.gov.in/one")
        fr.add("https://example.gov.in/two")
        first = fr.pop()
        self.assertEqual(first["url"], "https://example.gov.in/one")
        second = fr.pop()
        self.assertEqual(second["url"], "https://example.gov.in/two")
        self.assertIsNone(fr.pop())


class SitemapParseTestCase(unittest.TestCase):
    def test_sitemap_index_returns_sub_sitemaps(self):
        parsed = discovery.parse_sitemap(SITEMAP_INDEX_XML)
        self.assertEqual(len(parsed["sitemaps"]), 2)
        self.assertIn("https://example.gov.in/wp-sitemap-1.xml", parsed["sitemaps"])
        self.assertEqual(parsed["urls"], [])

    def test_urlset_returns_urls_and_dedup_is_left_to_frontier(self):
        parsed = discovery.parse_sitemap(URLSET_XML)
        # the sitemap itself may repeat a <loc>; parse_sitemap is a pure parser,
        # Frontier.add() is what actually dedupes when these are enqueued.
        self.assertEqual(len(parsed["urls"]), 3)
        self.assertTrue(any(u.endswith(".pdf") for u in parsed["urls"]))

    def test_malformed_xml_falls_back_to_regex_scan(self):
        parsed = discovery.parse_sitemap(MALFORMED_XML)
        self.assertIn("https://example.gov.in/a.pdf", parsed["urls"])

    def test_is_resource_url_and_section_detection(self):
        self.assertTrue(discovery.is_resource_url("https://x.gov.in/a/b/Syllabus.PDF"))
        self.assertFalse(discovery.is_resource_url("https://x.gov.in/a/b/page.html"))
        self.assertTrue(discovery.looks_like_section("https://x.gov.in/downloads/syllabus"))
        self.assertFalse(discovery.looks_like_section("https://x.gov.in/about/contact"))

    def test_extract_links_resolves_relative_and_skips_junk(self):
        html = (b'<html><body>'
                b'<a href="/downloads/file.pdf">PDF</a>'
                b'<a href="https://other.example/x">other</a>'
                b'<a href="mailto:x@y.com">mail</a>'
                b'<a href="#top">anchor</a>'
                b'</body></html>')
        links = discovery.extract_links(html, "https://example.gov.in/section/")
        self.assertIn("https://example.gov.in/downloads/file.pdf", links)
        self.assertIn("https://other.example/x", links)
        self.assertEqual(len(links), 2)

    def test_board_for_domain_and_search_hook_seam(self):
        self.assertEqual(discovery.board_for_domain("ncert.nic.in"), "cbse")
        self.assertEqual(discovery.board_for_domain("cisce.org"), "icse")
        self.assertIsNone(discovery.board_for_domain("unknown.example"))

        self.addCleanup(discovery.set_search_hook, None)
        discovery.set_search_hook(lambda domain, topic: [f"https://{domain}/found.pdf",
                                                          "https://off-domain.example/nope.pdf"])
        found = discovery.search_discover("cisce.org", "syllabus")
        self.assertEqual(found, ["https://cisce.org/found.pdf"])


class ManifestTestCase(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="ci_crawler_manifest_test_"))
        self.path = self.tmp / "crawler_manifest.json"

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_upsert_has_all_spec_columns_plus_provenance(self):
        records = {}
        manifest.upsert(records, "AKS-CBSE-06-MATH-SYLL-2026-000001", board="CBSE",
                        class_label="Class_06", subject="Mathematics",
                        url="https://ncert.nic.in/syllabus.pdf", status="VERIFIED",
                        verification="VERIFIED", last_checked="2026-07-08T00:00:00Z",
                        retry_count=0, sha256="c" * 64, bytes_=12345,
                        local_path="resources/curriculum/cbse/x.pdf",
                        discovered_via="https://ncert.nic.in/sitemap.xml", evidence="")
        rec = records["AKS-CBSE-06-MATH-SYLL-2026-000001"]
        for col in manifest.COLUMNS:
            self.assertIn(col, rec, f"missing spec column {col}")
        for extra in ("sha256", "bytes", "local_path", "discovered_via", "evidence"):
            self.assertIn(extra, rec)

    def test_update_preserves_provenance_when_not_repeated(self):
        records = {}
        manifest.upsert(records, "R1", board="CBSE", class_label="Class_06", subject="Mathematics",
                        url="https://x/y.pdf", status="VERIFIED", verification="VERIFIED",
                        last_checked="t1", sha256="d" * 64, bytes_=99, local_path="p")
        manifest.upsert(records, "R1", board="CBSE", class_label="Class_06", subject="Mathematics",
                        url="https://x/y.pdf", status="VERIFIED", verification="VERIFIED",
                        last_checked="t2")
        self.assertEqual(records["R1"]["sha256"], "d" * 64)
        self.assertEqual(records["R1"]["local_path"], "p")
        self.assertEqual(records["R1"]["Last-checked"], "t2")

    def test_save_and_load_round_trip(self):
        records = {}
        manifest.upsert(records, "R1", board="CBSE", class_label="Class_06", subject="Mathematics",
                        url="https://x/y.pdf", status="VERIFIED", verification="VERIFIED",
                        last_checked="t1")
        manifest.save(self.path, records)
        loaded = manifest.load(self.path)
        self.assertEqual(loaded, records)

    def test_summary_reports_downloaded_and_verified_separately(self):
        records = {}
        # one verified, one downloaded-but-failed-verification, one hard-failed, one missing
        manifest.upsert(records, "R1", board="CBSE", class_label="Class_06", subject="Mathematics",
                        url="u1", status="VERIFIED", verification="VERIFIED", last_checked="t")
        manifest.upsert(records, "R4", board="CBSE", class_label="Class_09", subject="English",
                        url="u4", status="DOWNLOADED", verification="FAILED", last_checked="t")
        manifest.upsert(records, "R2", board="CBSE", class_label="Class_07", subject="Science",
                        url="u2", status="FAILED", verification="FAILED", last_checked="t")
        manifest.upsert(records, "R3", board="APSCERT", class_label="Class_08", subject="English",
                        url="u3", status="NOT_PUBLICLY_AVAILABLE", verification="NOT_VERIFIED",
                        last_checked="t", retry_count=2)
        s = manifest.summary(records)
        self.assertEqual(s["total_discovered"], 4)
        self.assertEqual(s["verified"], 1)
        self.assertEqual(s["failed"], 1)
        self.assertEqual(s["not_publicly_available"], 1)
        self.assertEqual(s["downloaded"], 2)     # R1 (VERIFIED) + R4 (DOWNLOADED, failed verification)
        self.assertNotEqual(s["downloaded"], s["verified"])  # Downloaded != Verified
        self.assertEqual(s["verified_by_board"], {"CBSE": 1})


class VerifyGateTestCase(unittest.TestCase):
    """Proves the crawler routes every file through the real V1-V11 engine
    (no re-implemented checks) and that Downloaded != Verified end to end."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="ci_crawler_verify_test_"))
        shutil.copytree(CONFIGS_SRC, self.tmp / "configs")
        rules_path = self.tmp / "configs" / "verification_rules.json"
        rules = json.loads(rules_path.read_text())
        rules["min_size_bytes"]["pdf"] = 512  # relax floor for tiny synthetic fixtures
        rules["min_size_bytes"]["default"] = 64
        rules_path.write_text(json.dumps(rules))

        sys.path.insert(0, str(ROOT / "scripts" / "verification"))
        from verification_engine import VerificationEngine
        from workspace import Workspace
        self.engine = VerificationEngine(self.tmp)
        self.ws = Workspace(self.tmp)
        self.incoming = self.tmp / "downloads" / "incoming"
        self.incoming.mkdir(parents=True)

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_classify_extracts_board_class_subject_category(self):
        c = verify.classify(
            "https://cbseacademic.nic.in/downloads/Class8_Science_Textbook.pdf", "cbse")
        self.assertEqual(c["board"], "CBSE")
        self.assertEqual(c["class_label"], "Class_08")
        self.assertEqual(c["subject"], "Science")
        self.assertEqual(c["category"], "textbook")

    def test_unclassifiable_url_still_gets_non_empty_fields(self):
        c = verify.classify("https://cisce.org/wp-content/uploads/2026/06/misc123.pdf", "icse")
        self.assertEqual(c["board"], "CISCE")
        self.assertTrue(c["class_label"])  # "Unclassified", never empty
        self.assertTrue(c["subject"])      # "General", never empty
        self.assertTrue(c["category"])     # falls back to "supplementary"

    def test_valid_pdf_downloaded_and_verified(self):
        classification = verify.classify(
            "https://ncert.nic.in/downloads/Class6_Mathematics_Syllabus.pdf", "cbse")
        expected = verify.build_expected(self.ws, classification,
                                         "https://ncert.nic.in/downloads/Class6_Mathematics_Syllabus.pdf",
                                         "pdf", seq=1, year="2026")
        f = self.incoming / expected["expected_filename"]
        f.write_bytes(make_sample_pdf(pages=2, pad_to=700))

        result = verify.verify_file(self.engine, expected, f)
        self.assertEqual(result.status, "VERIFIED", result.detail)
        self.assertTrue(Path(result.final_path).is_file())

    def test_downloaded_does_not_imply_verified(self):
        """The verify gate: a file can be DOWNLOADED (bytes landed on disk)
        without being VERIFIED (passing V1-V11) — spec explicitly requires
        the two be reported separately, only Verified counts %."""
        classification = verify.classify(
            "https://ncert.nic.in/downloads/Class7_Science_Textbook.pdf", "cbse")
        expected = verify.build_expected(self.ws, classification,
                                         "https://ncert.nic.in/downloads/Class7_Science_Textbook.pdf",
                                         "pdf", seq=2, year="2026")
        f = self.incoming / expected["expected_filename"]
        f.write_bytes(b"<html><body>404 Not Found</body></html>" + b" " * 600)  # "downloaded" junk

        records = {}
        result = verify.verify_file(self.engine, expected, f)
        self.assertEqual(result.status, "FAILED")
        manifest.upsert(records, expected["resource_id"], board=classification["board"],
                        class_label=classification["class_label"], subject=classification["subject"],
                        url=expected["source_url"], status="DOWNLOADED", verification=result.status,
                        last_checked="t", evidence=result.detail)
        s = manifest.summary(records)
        self.assertEqual(s["downloaded"], 1)
        self.assertEqual(s["verified"], 0)


class CrawlCliDryRunTestCase(unittest.TestCase):
    """Exercises crawl.run() end to end with network disabled — proves the
    CLI wiring (seed -> frontier -> manifest -> resume) never makes an HTTP
    call and that a second invocation is idempotent (resume)."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="ci_crawler_cli_test_"))
        shutil.copytree(CONFIGS_SRC, self.tmp / "configs")
        self.state_path = self.tmp / "acquisition" / "crawler_state.json"
        self.manifest_path = self.tmp / "acquisition" / "crawler_manifest.json"

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_dry_run_seeds_without_network_and_is_idempotent_on_resume(self):
        stats1 = crawl.run(board="cbse", resume=True, dry_run=True,
                           workspace_root=self.tmp, state_path=self.state_path,
                           manifest_path=self.manifest_path)
        self.assertFalse(stats1["network"])
        self.assertGreater(stats1["seeded"], 0)
        self.assertTrue(self.state_path.is_file())
        queued_after_first = stats1["frontier"]["queued"]

        # second run resumes: the same board seeds must NOT be re-added
        stats2 = crawl.run(board="cbse", resume=True, dry_run=True,
                           workspace_root=self.tmp, state_path=self.state_path,
                           manifest_path=self.manifest_path)
        self.assertEqual(stats2["seeded"], 0, "resumed run must not re-seed already-queued URLs")
        self.assertEqual(stats2["frontier"]["queued"], queued_after_first)

    def test_allow_network_false_overrides_missing_dry_run_flag(self):
        # even without --dry-run, allow_network defaults False -> still no HTTP
        stats = crawl.run(board="icse", resume=False, dry_run=False, allow_network=False,
                          workspace_root=self.tmp, state_path=self.state_path,
                          manifest_path=self.manifest_path)
        self.assertFalse(stats["network"])
        self.assertEqual(stats["pages_processed"], 0)

    def test_board_filter_only_seeds_requested_board(self):
        stats = crawl.run(board="icse", resume=False, dry_run=True,
                          workspace_root=self.tmp, state_path=self.state_path,
                          manifest_path=self.manifest_path)
        fr = Frontier.load(self.state_path)
        for rec in fr.queued.values():
            self.assertEqual(rec["board"], "icse")


if __name__ == "__main__":
    unittest.main(verbosity=2)
