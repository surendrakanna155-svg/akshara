"""Tests for the Part-02 PM-file bootstrap (utilities/pm_bootstrap.py).

Synthetic, isolated temp workspaces only. Run:
  python3 -m unittest discover -s curriculum/scripts/tests -v
"""

from __future__ import annotations

import shutil
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]  # curriculum/
for _sub in ("common", "utilities", "metadata", "reports"):
    sys.path.insert(0, str(ROOT / "scripts" / _sub))

from workspace import Workspace, load_json, write_json  # noqa: E402
import scaffold_workspace  # noqa: E402
import pm_bootstrap  # noqa: E402

CONFIGS = ROOT / "configs"

PM_KEYS = ("todo", "progress", "session_log", "checkpoints",
           "download_queue", "failed_downloads", "completed_downloads", "project_status")


class PmBootstrapTestCase(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="ci_pm_test_"))
        shutil.copytree(CONFIGS, self.tmp / "configs")
        scaffold_workspace.build(self.tmp)
        self.ws = Workspace(self.tmp)

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_all_eight_pm_files_present_with_part02_fields(self):
        pm_bootstrap.bootstrap(self.ws)
        for key in PM_KEYS:
            self.assertTrue(self.ws.pm(key).is_file(), f"missing PM file: {key}")

        todo = self.ws.pm("todo").read_text()
        for section in ("## Pending", "## In Progress", "## Completed", "## Blocked", "## Skipped"):
            self.assertIn(section, todo)

        progress = self.ws.pm("progress").read_text()
        for field in ("Current stage", "Current board", "Current class", "Current subject",
                      "Files downloaded", "Files verified", "Files failed", "Retry queue",
                      "Estimated remaining work", "Overall completion"):
            self.assertIn(field, progress)

        self.assertIn("Session start", self.ws.pm("session_log").read_text())
        self.assertIn("Checkpoint 000", self.ws.pm("checkpoints").read_text())

        self.assertEqual(load_json(self.ws.pm("download_queue")), [])
        self.assertEqual(load_json(self.ws.pm("failed_downloads")), [])
        self.assertEqual(load_json(self.ws.pm("completed_downloads")), [])

        status = load_json(self.ws.pm("project_status"))
        for field in ("current_stage", "overall_progress_pct", "board_progress",
                      "downloads", "failures", "warnings", "last_updated",
                      "repository_certified", "repository_status"):
            self.assertIn(field, status)

    def test_idempotent_preserves_cert_fields_and_live_queue(self):
        pm_bootstrap.bootstrap(self.ws)
        # simulate a live certification + a populated queue, then re-bootstrap
        status = load_json(self.ws.pm("project_status"))
        status["repository_certified"] = True
        status["repository_status"] = "REPOSITORY_READY_FOR_KNOWLEDGE_BASE_GENERATION"
        write_json(self.ws.pm("project_status"), status)
        write_json(self.ws.pm("download_queue"), [{"resource_id": "AKS-X"}])

        pm_bootstrap.bootstrap(self.ws)  # must not clobber cert fields or live data

        status2 = load_json(self.ws.pm("project_status"))
        self.assertTrue(status2["repository_certified"])
        self.assertEqual(status2["repository_status"], "REPOSITORY_READY_FOR_KNOWLEDGE_BASE_GENERATION")
        self.assertEqual(load_json(self.ws.pm("download_queue")), [{"resource_id": "AKS-X"}])


if __name__ == "__main__":
    unittest.main(verbosity=2)
