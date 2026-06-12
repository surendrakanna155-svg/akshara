import importlib.util
import sys
import unittest
from pathlib import Path

_SCRIPTS = Path(__file__).resolve().parents[2] / "scripts"
sys.path.insert(0, str(_SCRIPTS))

from demo_school_lib import (  # noqa: E402
    PROBE_STUDENT_ID,
    is_valid_uuid,
    parent_experience_report_path,
    parent_experience_summary_path,
    resolve_probe_student_id,
)


class ValidationProbeStudentTest(unittest.TestCase):
    def test_rejects_placeholder_student_id(self) -> None:
        self.assertFalse(is_valid_uuid("student_1"))
        self.assertFalse(is_valid_uuid("teacher_1"))
        self.assertFalse(is_valid_uuid("parent_1"))

    def test_accepts_staging_probe_uuid(self) -> None:
        self.assertTrue(is_valid_uuid(PROBE_STUDENT_ID))

    def test_parent_experience_paths_use_uuid(self) -> None:
        sid = PROBE_STUDENT_ID
        self.assertIn(sid, parent_experience_summary_path(sid))
        self.assertIn(sid, parent_experience_report_path(sid))
        self.assertNotIn("student_1", parent_experience_summary_path(sid))

    def test_resolve_falls_back_to_default_uuid_without_tokens(self) -> None:
        self.assertEqual(resolve_probe_student_id(), PROBE_STUDENT_ID)


if __name__ == "__main__":
    unittest.main()
