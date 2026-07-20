"""Adversarial controls for the Exam DNA certifier — run BEFORE any Exam DNA is trusted.

Same governance mechanic as plan_controls / factory.controls: construct deliberately-BROKEN Exam DNA and
assert every gate refuses it; also assert the real curated set passes. A certifier that cannot fail a
known-bad distribution is not evidence, and any planning built on it would be theatre.
"""
from __future__ import annotations

import sqlite3
from typing import List, Tuple

from kie.qie.knowledge import examdna as ED


class ExamDnaControlBreach(Exception):
    """A structurally-invalid or dishonestly-scoped Exam DNA record survived the certifier."""


def _distribution_controls() -> List[Tuple[str, dict]]:
    """(name, a distribution that MUST be rejected by validate_distribution)"""
    return [
        ("sums_below_one", {"easy": 0.2, "moderate": 0.3, "hard": 0.2}),   # 0.7
        ("sums_above_one", {"easy": 0.5, "moderate": 0.5, "hard": 0.5}),   # 1.5
        ("negative_probability", {"easy": -0.1, "moderate": 0.6, "hard": 0.5}),
        ("empty", {}),
    ]


def check_distribution_controls() -> dict:
    for name, d in _distribution_controls():
        try:
            ED.validate_distribution(d)
        except ED.ExamDnaError:
            continue  # correctly rejected
        raise ExamDnaControlBreach(f"distribution control {name!r} SURVIVED: {d!r} was accepted as valid")
    # a genuine distribution must PASS
    ED.validate_distribution({"easy": 0.30, "moderate": 0.55, "hard": 0.15})
    return {"distribution_controls": len(_distribution_controls()), "all_rejected": True, "good_passes": True}


def check_scope_controls(valid_chapter_ids: set, real_chapter_id: str) -> dict:
    """Structural scope gates: unknown exam, wrong-exam subject, and an absent chapter must all be refused."""
    controls = [
        ("unknown_exam", lambda: ED.validate_exam_scope("JEE_MADE_UP", "Physics")),
        ("wrong_exam_subject", lambda: ED.validate_exam_scope("JEE_MAIN", "Biology")),  # JEE has no Biology
        ("absent_chapter", lambda: ED.validate_chapter_ref(valid_chapter_ids, "CH_NOT_REAL_999")),
    ]
    for name, fn in controls:
        try:
            fn()
        except ED.ExamDnaError:
            continue  # correctly rejected
        raise ExamDnaControlBreach(f"scope control {name!r} SURVIVED the certifier")
    # the legitimate scopes must PASS
    ED.validate_exam_scope("NEET", "Biology")
    ED.validate_exam_scope("JEE_MAIN", "Mathematics")
    if real_chapter_id:
        ED.validate_chapter_ref(valid_chapter_ids, real_chapter_id)
    return {"scope_controls": len(controls), "all_rejected": True, "good_passes": True}


def check_all(index_conn: sqlite3.Connection) -> dict:
    """Run every Exam DNA control against the real frozen index. Raises ExamDnaControlBreach on any hole."""
    d = check_distribution_controls()
    valid = ED.valid_chapter_ids(index_conn, "Physics")
    a_real = next(iter(valid)) if valid else ""
    s = check_scope_controls(valid, a_real)
    return {"distribution": d, "scope": s, "all_ok": True}
