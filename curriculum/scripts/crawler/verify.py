#!/usr/bin/env python3
"""Crawler -> certified VerificationEngine adapter.

Canonical requirement: docs/curriculum-intelligence/planning/CRAWLER_SPEC.md
(§Per-resource pipeline, §Verification gate) — "reuse the existing
verification_engine V1-V11 per file (import it; do NOT duplicate)".

This module does exactly two things:

  1. ``classify()`` — best-effort board/class/subject/category classification
     of a discovered URL (+ link text), using the same taxonomy
     (boards/classes/subjects/categories) the rest of the acquisition
     pipeline already uses (configs/*.json), so crawled resources land in the
     same repository tree as catalogue-driven downloads.
  2. ``build_expected()`` / ``verify_file()`` — build the ``expected`` record
     ``VerificationEngine.verify_resource()`` requires, then hand the
     downloaded file straight to it. V1-V11 (%PDF magic, non-empty, min-size,
     pypdf-parseable, sha256, dedup, move-into-repository) is never
     reimplemented here — only invoked.

Precise config-alignment of the classification heuristic is a later
refinement, not a correctness gate: the engine only requires its
``metadata_required_fields`` be non-empty (verification_rules.json), so an
"Unclassified" class or "General" subject still verifies correctly; it is
just less useful for coverage reporting until classification improves.
"""

from __future__ import annotations

import re
import sys
from datetime import datetime, timezone
from pathlib import Path

_SCRIPTS = Path(__file__).resolve().parents[1]  # curriculum/scripts
for _sub in ("common", "verification"):
    _p = str(_SCRIPTS / _sub)
    if _p not in sys.path:
        sys.path.insert(0, _p)

from workspace import Workspace, utcnow  # noqa: E402
from verification_engine import (  # noqa: E402,F401
    DUPLICATE,
    FAILED,
    VERIFIED,
    Reason,
    VerificationEngine,
    VerificationResult,
)

# category slug -> human document_type label (mirrors
# configs/download_rules.json:document_type_to_category, inverted for the
# categories this crawler actually assigns).
CATEGORY_TYPE_LABEL = {
    "syllabus": "Syllabus",
    "textbook": "Textbook",
    "teacher_guide": "Teacher Guide",
    "learning_outcomes": "Learning Outcomes",
    "academic_standards": "Academic Standards",
    "blueprint": "Blueprint",
    "question_bank": "Question Bank",
    "sample_paper": "Sample Paper",
    "previous_paper": "Previous Paper",
    "worksheet": "Worksheet",
    "activity_book": "Activity Book",
    "lab_manual": "Lab Manual",
    "reference": "Reference Material",
    "circular": "Circular",
    "notification": "Notification",
    "supplementary": "Supplementary Resource",
}

# Ordered: first (keyword, category) match wins — specific before generic.
_CATEGORY_KEYWORDS: list[tuple[str, str]] = [
    ("marking scheme", "sample_paper"), ("marking-scheme", "sample_paper"),
    ("sample paper", "sample_paper"), ("sample-paper", "sample_paper"), ("model paper", "sample_paper"),
    ("previous paper", "previous_paper"), ("previous-paper", "previous_paper"), ("past paper", "previous_paper"),
    ("question bank", "question_bank"), ("question-bank", "question_bank"),
    ("teacher guide", "teacher_guide"), ("teacher-guide", "teacher_guide"), ("teacher handbook", "teacher_guide"),
    ("lab manual", "lab_manual"), ("practical manual", "lab_manual"),
    ("activity book", "activity_book"),
    ("blueprint", "blueprint"), ("assessment framework", "blueprint"),
    ("learning outcome", "learning_outcomes"),
    ("academic standard", "academic_standards"),
    ("worksheet", "worksheet"),
    ("syllabus", "syllabus"), ("curriculum", "syllabus"),
    ("circular", "circular"),
    ("notification", "notification"),
    ("textbook", "textbook"), ("text-book", "textbook"), ("text_book", "textbook"),
]

_SUBJECT_KEYWORDS: list[tuple[str, str, str]] = [
    ("mathematics", "Mathematics", "MATH"), ("maths", "Mathematics", "MATH"),
    ("social science", "Social Science", "SST"), ("social studies", "Social Science", "SST"),
    ("computer science", "Computer Science", "CS"),
    ("science", "Science", "SCI"),
    ("physics", "Physics", "PHY"), ("chemistry", "Chemistry", "CHEM"), ("biology", "Biology", "BIO"),
    ("history", "History", "HIST"), ("geography", "Geography", "GEO"), ("civics", "Civics", "CIV"),
    ("english", "English", "ENG"),
]

_CLASS_RE = re.compile(r"class[\s_-]?0*([6-9]|10)(?!\d)", re.IGNORECASE)

BOARD_CODES = {"cbse": "CBSE", "ap": "APSCERT", "telangana": "TSSCERT", "icse": "CISCE"}
BOARD_FOLDERS = {"cbse": "cbse", "ap": "ap", "telangana": "telangana", "icse": "icse"}


def _match_keyword(haystack: str, table):
    low = haystack.lower()
    for entry in table:
        if entry[0] in low:
            return entry
    return None


def classify(url: str, board_key: str, link_text: str = "") -> dict:
    """Best-effort board/class/subject/category classification from the URL
    (+ optional anchor text) alone — no page content is required."""
    haystack = f"{url} {link_text}"
    cat_match = _match_keyword(haystack, _CATEGORY_KEYWORDS)
    category = cat_match[1] if cat_match else "supplementary"

    subj_match = _match_keyword(haystack, _SUBJECT_KEYWORDS)
    subject_display, subject_code = (subj_match[1], subj_match[2]) if subj_match else ("General", "GEN")

    m = _CLASS_RE.search(haystack)
    class_num = m.group(1) if m else None
    class_label = f"Class_{int(class_num):02d}" if class_num else "Unclassified"
    class_code = f"{int(class_num):02d}" if class_num else "XX"

    return {
        "board_key": board_key,
        "board": BOARD_CODES.get(board_key, (board_key or "unknown").upper()),
        "board_folder": BOARD_FOLDERS.get(board_key, board_key or "unknown"),
        "class_label": class_label,
        "class_code": class_code,
        "subject": subject_display,
        "subject_code": subject_code,
        "category": category,
        "document_type": CATEGORY_TYPE_LABEL.get(category, "Supplementary Resource"),
    }


def build_expected(ws: Workspace, classification: dict, url: str, ext: str, seq: int,
                    year: str | None = None, language: str = "English") -> dict:
    """Build the ``expected`` record ``VerificationEngine.verify_resource()``
    requires (resource_id, expected_filename, destination, metadata fields)."""
    year = year or str(datetime.now(timezone.utc).year)
    c = classification
    rid = ws.resource_id(c["board"], c["class_code"], c["subject_code"], c["category"], year, seq)

    dl_rules = ws.config("download_rules")
    category_folder = dl_rules["category_to_subject_folder"].get(c["category"], "Reference")
    resource_type_label = CATEGORY_TYPE_LABEL.get(c["category"], "Supplementary Resource")
    subject_folder_name = c["subject"].replace(" ", "_")

    filename = ws.repo_filename(c["board"], c["class_label"], subject_folder_name,
                                 resource_type_label, year, "v1", language, ext)
    destination = str(Path("curriculum") / c["board_folder"] / c["class_label"] /
                       subject_folder_name / category_folder)

    return {
        "resource_id": rid,
        "expected_filename": filename,
        "document_type": c["document_type"],
        "board": c["board"],
        "class_label": c["class_label"],
        "subject": c["subject"],
        "language": language,
        "medium": language,
        "source_url": url,
        "download_timestamp": utcnow(),
        "destination": destination,
        "alternative_sources": [],
    }


def verify_file(engine: VerificationEngine, expected: dict, file_path: Path) -> VerificationResult:
    """Route a downloaded file through the certified engine (V1-V11). This is
    the ONLY call site that decides VERIFIED/FAILED/DUPLICATE — never
    re-implement %PDF/size/sha256/dedup checks here."""
    return engine.verify_resource(expected, Path(file_path))
