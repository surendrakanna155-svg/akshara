#!/usr/bin/env python3
"""Unit tests for backfill year normalization (no DB required)."""
from __future__ import annotations

import re
import unittest


def normalize_academic_year_label(label: str) -> str:
    text = label.strip().replace("–", "-").replace("—", "-")
    return re.sub(r"\s+", "", text)


class BackfillNormalizationTest(unittest.TestCase):
    def test_normalize_academic_year_label(self) -> None:
        self.assertEqual(normalize_academic_year_label("2026–27"), "2026-27")
        self.assertEqual(normalize_academic_year_label("2026—27"), "2026-27")
        self.assertEqual(normalize_academic_year_label(" 2026 - 27 "), "2026-27")
        self.assertEqual(normalize_academic_year_label(""), "")


if __name__ == "__main__":
    unittest.main()
