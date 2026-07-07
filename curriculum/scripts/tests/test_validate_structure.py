"""Tests for the directory-standard + storage-invariant validator.

Passes on a correctly scaffolded tree; fails (exit-worthy) on deliberately-broken
trees. Run:  python3 -m unittest discover -s curriculum/scripts/tests -v
"""

from __future__ import annotations

import shutil
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]  # curriculum/
for _sub in ("common", "utilities", "discovery", "download",
             "organization", "metadata", "reports", "maintenance", "verification"):
    sys.path.insert(0, str(ROOT / "scripts" / _sub))

import dry_run  # noqa: E402  (provides _prepare = full scaffolded empty workspace)
import validate_structure  # noqa: E402


class ValidateStructureTestCase(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="ci_struct_test_"))
        self.ws = dry_run._prepare(self.tmp)  # scaffold + bootstrap + seed indexes/logs/reports

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_passes_on_scaffolded_tree(self):
        self.assertEqual(validate_structure.validate(self.ws), [])

    def test_fails_when_required_top_level_folder_removed(self):
        shutil.rmtree(self.tmp / "indexes")
        problems = validate_structure.validate(self.ws)
        self.assertTrue(any(p.startswith("MISSING_TOP_LEVEL_DIR: indexes") for p in problems), problems)

    def test_fails_when_required_subdir_removed(self):
        shutil.rmtree(self.tmp / "downloads" / "duplicates")
        problems = validate_structure.validate(self.ws)
        self.assertTrue(any("MISSING_SUBDIR: downloads/duplicates" in p for p in problems), problems)

    def test_fails_when_required_index_missing(self):
        (self.tmp / "indexes" / "master_index.json").unlink()
        problems = validate_structure.validate(self.ws)
        self.assertTrue(any("MISSING_INDEX: master_index.json" in p for p in problems), problems)

    def test_fails_when_required_report_missing(self):
        (self.tmp / "reports" / "RESOURCE_MAP.md").unlink()
        problems = validate_structure.validate(self.ws)
        self.assertTrue(any("MISSING_REPORT: RESOURCE_MAP.md" in p for p in problems), problems)

    def test_fails_when_pm_file_missing(self):
        (self.tmp / "TODO.md").unlink()
        problems = validate_structure.validate(self.ws)
        self.assertTrue(any("MISSING_PM_FILE: TODO.md" in p for p in problems), problems)


if __name__ == "__main__":
    unittest.main(verbosity=2)
