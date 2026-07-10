"""Exam-profile + blueprint presets — deterministic, grounded in the certified corpus.

Exam profiles map the certified `source_documents.exam` values to the subjects the KIE
actually holds. Board/class aliases resolve onto these profiles; a scope with no certified
data is refused upstream (never fabricated).
"""
from __future__ import annotations

from typing import Dict, Optional

from kie.qpgen.models import Blueprint, BlueprintCell, Difficulty, QuestionType, Subject

# ── exam profiles (subjects + which source_documents.exam rows count as in-profile) ──
EXAM_PROFILES: Dict[str, dict] = {
    "NEET": {
        "subjects": (Subject.PHYSICS, Subject.CHEMISTRY, Subject.BIOLOGY),
        "grade_band": (11, 12),
        "source_exams": ("NEET", "AIPMT", "AIIMS", "NTA_Sample", "Practice_Resources", "NCERT"),
    },
    "AIIMS": {
        "subjects": (Subject.PHYSICS, Subject.CHEMISTRY, Subject.BIOLOGY),
        "grade_band": (11, 12),
        "source_exams": ("AIIMS", "NEET", "AIPMT", "Practice_Resources", "NCERT"),
    },
    "JEE_MAIN": {
        "subjects": (Subject.PHYSICS, Subject.CHEMISTRY, Subject.MATHEMATICS),
        "grade_band": (11, 12),
        "source_exams": ("JEE_Main", "NTA_Sample", "Practice_Resources", "NCERT"),
    },
    "JEE_ADVANCED": {
        "subjects": (Subject.PHYSICS, Subject.CHEMISTRY, Subject.MATHEMATICS),
        "grade_band": (11, 12),
        "source_exams": ("JEE_Advanced", "JEE_Main", "Practice_Resources", "NCERT"),
    },
    "FOUNDATION": {   # the whole certified corpus
        "subjects": Subject.ALL,
        "grade_band": (6, 12),
        "source_exams": ("NEET", "AIPMT", "AIIMS", "NTA_Sample", "JEE_Main",
                         "JEE_Advanced", "Practice_Resources", "NCERT"),
    },
}

# Competitive-exam sources carry NO class_label in the corpus but ARE grade 11-12 by nature
# (previous-year papers / practice). NCERT textbooks are the only class-labelled source.
COMPETITIVE_EXAMS = frozenset({
    "NEET", "AIIMS", "AIPMT", "NTA_Sample", "JEE_Main", "JEE_Advanced", "Practice_Resources",
})
COMPETITIVE_GRADES = (11, 12)

# board/class aliases → exam profile. Only mappings with certified data are allowed.
BOARD_ALIASES = {
    "neet": "NEET", "aiims": "AIIMS", "jee": "JEE_MAIN", "jee main": "JEE_MAIN",
    "jee_main": "JEE_MAIN", "jee advanced": "JEE_ADVANCED", "jee_advanced": "JEE_ADVANCED",
    "foundation": "FOUNDATION", "ncert": "FOUNDATION",
}


def resolve_exam_profile(exam: Optional[str], board: Optional[str], class_label: Optional[str]) -> Optional[str]:
    """Return a known EXAM_PROFILES key, or None if the request maps to no certified scope."""
    if exam:
        key = exam.strip().upper().replace(" ", "_")
        if key in EXAM_PROFILES:
            return key
        alias = BOARD_ALIASES.get(exam.strip().lower())
        if alias:
            return alias
    if board:
        alias = BOARD_ALIASES.get(board.strip().lower())
        if alias:
            return alias
    return None


# ── blueprint presets ───────────────────────────────────────────────────────────────
def _neet_style() -> Blueprint:
    # 45-mark objective section (single-subject slice), NEET/JEE MCQ-first
    return Blueprint(
        name="objective_45",
        cells=[
            BlueprintCell("A", QuestionType.MCQ, marks_each=4, count=10, difficulty=Difficulty.MEDIUM),
            BlueprintCell("A", QuestionType.MCQ, marks_each=4, count=5, difficulty=Difficulty.HARD),
        ],
        instructions=["All questions are compulsory.", "Each correct answer carries 4 marks."],
    )


def _cbse_style_descriptive() -> Blueprint:
    # a subjective-style paper the deterministic renderer can fully materialize
    return Blueprint(
        name="descriptive_40",
        cells=[
            BlueprintCell("A", QuestionType.SHORT_ANSWER, marks_each=2, count=5, difficulty=Difficulty.MEDIUM),
            BlueprintCell("B", QuestionType.SHORT_ANSWER, marks_each=3, count=5, difficulty=Difficulty.HARD),
            BlueprintCell("C", QuestionType.LONG_ANSWER, marks_each=5, count=3, difficulty=Difficulty.HARD),
        ],
        instructions=["All questions are compulsory.", "Answer briefly and to the point."],
    )


def _mixed_practice() -> Blueprint:
    return Blueprint(
        name="mixed_50",
        cells=[
            BlueprintCell("A", QuestionType.MCQ, marks_each=1, count=10),
            BlueprintCell("B", QuestionType.SHORT_ANSWER, marks_each=2, count=8),
            BlueprintCell("C", QuestionType.ASSERTION_REASON, marks_each=2, count=4),
            BlueprintCell("D", QuestionType.LONG_ANSWER, marks_each=4, count=4),
        ],
        instructions=["All questions are compulsory."],
    )


BLUEPRINT_PRESETS = {
    "objective_45": _neet_style,
    "descriptive_40": _cbse_style_descriptive,
    "mixed_50": _mixed_practice,
}


def get_blueprint(name: str) -> Blueprint:
    if name not in BLUEPRINT_PRESETS:
        raise KeyError(f"unknown blueprint preset: {name} (have {sorted(BLUEPRINT_PRESETS)})")
    return BLUEPRINT_PRESETS[name]()
