"""Test for the end-to-end synthetic dry-run cycle (CI-A0 acceptance).

One self-made tiny PDF must traverse download→verify→organize→metadata→index and
land VERIFIED, with the repository correctly remaining NOT certified (coverage ~0%).
Run:  python3 -m unittest discover -s curriculum/scripts/tests -v
"""

from __future__ import annotations

import shutil
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]  # curriculum/
for _sub in ("common", "maintenance"):
    sys.path.insert(0, str(ROOT / "scripts" / _sub))

import dry_run  # noqa: E402


class DryRunCycleTestCase(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="ci_dryrun_test_"))

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_one_synthetic_file_through_full_cycle_without_certifying(self):
        res = dry_run.run(self.tmp)

        # download → verify (V1-V11) → organize (move into resources/)
        self.assertEqual(res["verified"], 1, res["download_stats"])
        self.assertTrue(Path(res["repository_file"]).is_file())
        self.assertIn("resources", res["repository_file"])

        # metadata + index
        self.assertTrue((self.tmp / res["metadata_file"]).is_file())
        self.assertEqual(res["master_entries"], 1)
        self.assertEqual(res["index_counts"]["resources"], 1)
        self.assertTrue(res["checksum"])

        # organization + structure validation both clean
        self.assertTrue(res["organize_ok"])
        self.assertTrue(res["structure_ok"], res["structure_problems"])

        # structural audit passes but D-5 certification MUST withhold (coverage ~0%)
        self.assertTrue(res["audit_passed"])
        self.assertFalse(res["certified"], "a single dry-run file must never certify")
        self.assertEqual(res["certify_rc"], 1)
        self.assertLess(res["coverage_pct"], 1.0)
        self.assertTrue(any("Priority-A coverage" in r for r in res["certification_reasons"]))


if __name__ == "__main__":
    unittest.main(verbosity=2)
