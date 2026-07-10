"""Blueprint engine — define, validate, and feasibility-check the target paper structure.

A blueprint is the deterministic contract for the paper: sections and cells (question_type,
marks, count, optional bloom/difficulty). Feasibility is measured against the resolved scope
so a request that cannot be honestly filled is reported up-front (never silently padded).
"""
from __future__ import annotations

from typing import Dict, List

from kie.qpgen import presets
from kie.qpgen.models import (Blueprint, Bloom, Difficulty, PaperRequest, QuestionType)
from kie.qpgen.scope import SyllabusScope

# descriptive items can be rendered from any in-scope concept; objective items must be
# grounded in a real Question-Intelligence pattern of that type.
DESCRIPTIVE_TYPES = frozenset({QuestionType.SHORT_ANSWER, QuestionType.LONG_ANSWER})
OBJECTIVE_TYPES = frozenset({QuestionType.MCQ, QuestionType.NUMERICAL,
                            QuestionType.ASSERTION_REASON, QuestionType.MATCH})


class BlueprintError(ValueError):
    pass


def default_blueprint_name(exam_profile: str) -> str:
    if exam_profile in ("NEET", "AIIMS", "JEE_MAIN", "JEE_ADVANCED"):
        return "objective_45"
    return "mixed_50"


def resolve_blueprint(request: PaperRequest, exam_profile: str) -> Blueprint:
    name = request.blueprint_preset or default_blueprint_name(exam_profile)
    return presets.get_blueprint(name)


def validate_blueprint(bp: Blueprint) -> List[str]:
    """Structural errors (empty ⇒ valid)."""
    errs: List[str] = []
    if not bp.cells:
        errs.append("blueprint has no cells")
    for i, c in enumerate(bp.cells):
        tag = f"cell[{i}] ({c.section}/{c.question_type})"
        if c.question_type not in QuestionType.ALL:
            errs.append(f"{tag}: unknown question_type {c.question_type!r}")
        if c.count <= 0:
            errs.append(f"{tag}: count must be > 0")
        if c.marks_each <= 0:
            errs.append(f"{tag}: marks_each must be > 0")
        if c.difficulty and c.difficulty not in Difficulty.ALL:
            errs.append(f"{tag}: unknown difficulty {c.difficulty!r}")
        if c.bloom and c.bloom not in Bloom.ALL:
            errs.append(f"{tag}: unknown bloom {c.bloom!r}")
    return errs


def type_availability(conn, scope: SyllabusScope) -> Dict[str, int]:
    """How many questions of each type the scope can honestly supply.

    Descriptive types → # in-scope concepts (each yields a descriptive question).
    Objective types  → # in-scope concepts that appear as that pattern type in real PYQs.
    """
    avail: Dict[str, int] = {t: len(scope.concepts) for t in DESCRIPTIVE_TYPES}
    codes = list(scope.concept_codes)
    if not codes:
        return {t: 0 for t in QuestionType.ALL}
    placeholders = ",".join("?" * len(codes))
    rows = conn.execute(
        f"SELECT question_type, COUNT(DISTINCT concept_code) n FROM question_patterns "
        f"WHERE concept_code IN ({placeholders}) GROUP BY question_type", codes
    ).fetchall()
    by_type = {r["question_type"]: r["n"] for r in rows}
    for t in OBJECTIVE_TYPES:
        avail[t] = by_type.get(t, 0)
    return avail


def feasibility(bp: Blueprint, availability: Dict[str, int]) -> List[str]:
    """Warnings for cells the scope cannot fully supply (aggregated per type)."""
    warnings: List[str] = []
    need: Dict[str, int] = {}
    for c in bp.cells:
        need[c.question_type] = need.get(c.question_type, 0) + c.count
    for qtype, required in sorted(need.items()):
        have = availability.get(qtype, 0)
        if have < required:
            warnings.append(
                f"type '{qtype}': blueprint needs {required} but scope supplies {have} "
                f"(short by {required - have})")
    return warnings
