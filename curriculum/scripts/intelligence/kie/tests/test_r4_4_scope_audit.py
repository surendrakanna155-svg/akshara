"""R4-4 — deferred audit passes [BS-3][BS-5][BS-6]: build-process audit honesty, downstream read-contracts
(fail-closed), and the reconciled-inventory guard against single-lane whole-system claims.
"""
from __future__ import annotations

import os
import sqlite3
import tempfile
import unittest

from kie import config
from kie.qie import scope_audit as SA


def _synth_index(tmp, *, with_run: bool):
    path = os.path.join(tmp, "knowledge_index.db")
    c = sqlite3.connect(path)
    c.execute("CREATE TABLE ki_meta (key TEXT PRIMARY KEY, value TEXT)")
    c.executemany("INSERT INTO ki_meta VALUES (?,?)",
                  [("frozen_version", "v1.5"), ("certified_knowledge_fingerprint_v1.5", "abc123"),
                   ("v14_final_audit", "pass")])
    c.execute("CREATE TABLE ki_concept (concept_id TEXT, audit_verdict TEXT)")
    c.execute("INSERT INTO ki_concept VALUES ('KC_1','accept')")
    c.execute("CREATE TABLE ki_progress (id INTEGER)")
    c.execute("INSERT INTO ki_progress VALUES (1)")
    c.execute("CREATE TABLE ki_run (run_id TEXT)")
    if with_run:
        c.execute("INSERT INTO ki_run VALUES ('build-1')")
    c.commit()
    c.close()
    return path


class TestBuildProcessAudit(unittest.TestCase):
    def test_gap_reported_when_ki_run_empty(self):
        with tempfile.TemporaryDirectory() as tmp:
            a = SA.build_process_audit(_synth_index(tmp, with_run=False))
            self.assertTrue(a["available"])
            self.assertTrue(a["output_audit_present"])       # per-concept audit_verdict exists
            self.assertFalse(a["process_audit_present"])     # ki_run empty -> no build trail
            self.assertIsNotNone(a["gap"])
            self.assertIn("ki_run", a["gap"])
            self.assertTrue(a["forward_requirement"])
            self.assertTrue(a["freeze_safe"])

    def test_no_gap_when_run_trail_present(self):
        with tempfile.TemporaryDirectory() as tmp:
            a = SA.build_process_audit(_synth_index(tmp, with_run=True))
            self.assertTrue(a["process_audit_present"])
            self.assertIsNone(a["gap"])

    def test_absent_index_is_honest(self):
        a = SA.build_process_audit(os.path.join(tempfile.gettempdir(), "nope_kx.db"))
        self.assertFalse(a["available"])

    def test_freeze_safe_never_writes(self):
        # opened mode=ro: a write attempt must fail (the frozen index is never our hatch)
        with tempfile.TemporaryDirectory() as tmp:
            p = _synth_index(tmp, with_run=False)
            SA.build_process_audit(p)
            ro = sqlite3.connect(f"file:{p}?mode=ro", uri=True)
            with self.assertRaises(sqlite3.OperationalError):
                ro.execute("INSERT INTO ki_run VALUES ('x')")
            ro.close()


class TestDownstreamContracts(unittest.TestCase):
    def test_every_surface_reader_is_sanctioned(self):
        for surface, spec in SA.DOWNSTREAM_SURFACES.items():
            for reader in spec["readers"]:
                self.assertIn(reader, SA.SANCTIONED_READERS, f"{surface} declares un-sanctioned {reader}")

    def test_sanctioned_read_passes(self):
        SA.assert_surface_read("analytics", "manifest")      # analytics reads the reconciled manifest

    def test_unknown_surface_refused(self):
        with self.assertRaises(SA.SurfaceContractViolation):
            SA.assert_surface_read("nonexistent_surface", "manifest")

    def test_raw_store_reader_refused(self):
        # a raw store is NEVER a sanctioned reader (the qie.db second-surface mistake, RI-6)
        with self.assertRaises(SA.SurfaceContractViolation):
            SA.assert_surface_read("ai_tutor", "raw_qie_db")

    def test_reader_not_in_surface_spec_refused(self):
        # analytics may read ONLY the manifest, not the product bank
        self.assertNotIn("product_bank", SA.DOWNSTREAM_SURFACES["analytics"]["readers"])
        with self.assertRaises(SA.SurfaceContractViolation):
            SA.assert_surface_read("analytics", "product_bank")


class TestReconciledInventoryGuard(unittest.TestCase):
    def test_refuses_whole_system_claim_without_manifest(self):
        with self.assertRaises(SA.SurfaceContractViolation):
            SA.reconciled_inventory_guard(os.path.join(tempfile.gettempdir(), "no_manifest.db"))


_LIVE = (config.KIE_HOME / "unified_inventory.db").exists()


@unittest.skipUnless(_LIVE, "live manifest not present")
class TestLiveReconciledInventory(unittest.TestCase):
    def test_manifest_spans_all_three_source_lanes(self):
        g = SA.reconciled_inventory_guard()
        self.assertTrue(g["reconciled"])
        # the blind spot BS-6 named: a whole-system claim must span every source store, incl. qie.db
        self.assertIn("qie.db", g["source_stores"])
        self.assertIn("qpl_question_bank.db", g["source_stores"])
        self.assertIn("factory_corpus.db", g["source_stores"])


@unittest.skipUnless((config.KIE_HOME / "knowledge_index.db").exists(), "frozen index not present")
class TestLiveBuildAudit(unittest.TestCase):
    def test_live_names_the_ki_run_gap_honestly(self):
        a = SA.build_process_audit()
        self.assertTrue(a["available"])
        self.assertEqual(a["provenance_counts"]["ki_run"], 0)   # the BS-5 gap, reported not hidden
        self.assertFalse(a["process_audit_present"])
        self.assertTrue(a["output_audit_present"])


if __name__ == "__main__":
    unittest.main()
