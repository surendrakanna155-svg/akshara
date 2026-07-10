"""Deterministic selection — fill each blueprint cell from the candidate pool.

Rules (all deterministic + reproducible for a given seed):
  * type match: a cell is filled only by candidates of its question_type.
  * coverage: each concept is used at most ONCE in the whole paper (max spread).
  * difficulty: cell.difficulty is a PREFERENCE — matching candidates first, then relaxed
    (a note is recorded); syllabus stays hard, difficulty stays soft.
  * priority: exam-important first (pattern frequency), then graph centrality, with dynamic
    subject balancing so a multi-subject paper does not collapse onto one subject.
  * shortfall: if the pool cannot fill a cell after de-dup, the cell is filled partially and
    the shortfall is reported — never padded with out-of-scope or duplicate content.
"""
from __future__ import annotations

import hashlib
from dataclasses import dataclass, field
from typing import Dict, List

from kie.qpgen.models import Blueprint, PaperRequest, QuestionSlot, SlotStatus
from kie.qpgen.pool import Candidate
from kie.qpgen.scope import SyllabusScope


@dataclass
class SelectionResult:
    slots: List[QuestionSlot] = field(default_factory=list)
    shortfalls: List[str] = field(default_factory=list)
    notes: List[str] = field(default_factory=list)
    used_concepts: set = field(default_factory=set)


def _seed_hash(concept_code: str, seed: int) -> int:
    return int(hashlib.sha256(f"{concept_code}|{seed}".encode()).hexdigest()[:12], 16)


def _priority(cand: Candidate, seed: int, subject_usage: Dict[str, int]):
    """Lower = picked first. Balance subjects, then exam-importance, then centrality, then
    a stable seeded tie-break (reproducible variety across seeds)."""
    return (
        subject_usage.get(cand.subject, 0),   # prefer under-represented subject
        -cand.frequency,                       # exam-important first
        -cand.graph_degree,                    # well-connected concepts first
        _seed_hash(cand.concept_code, seed),   # deterministic variety
        cand.concept_code,                     # final stable tie-break
    )


def select(blueprint: Blueprint, pool: List[Candidate], request: PaperRequest,
           scope: SyllabusScope) -> SelectionResult:
    by_type: Dict[str, List[Candidate]] = {}
    for c in pool:
        by_type.setdefault(c.question_type, []).append(c)

    res = SelectionResult()
    subject_usage: Dict[str, int] = {}
    number = 0

    for ci, cell in enumerate(blueprint.cells):
        available = [c for c in by_type.get(cell.question_type, []) if c.concept_code not in res.used_concepts]
        picked = 0
        relaxed = 0
        for _ in range(cell.count):
            # matching difficulty first, then relax
            remaining = [c for c in available if c.concept_code not in res.used_concepts]
            if not remaining:
                break
            pref = [c for c in remaining if not cell.difficulty or c.difficulty == cell.difficulty]
            bucket = pref if pref else remaining
            if not pref and cell.difficulty:
                relaxed += 1
            best = min(bucket, key=lambda c: _priority(c, request.seed, subject_usage))
            number += 1
            picked += 1
            res.used_concepts.add(best.concept_code)
            subject_usage[best.subject] = subject_usage.get(best.subject, 0) + 1
            res.slots.append(QuestionSlot(
                number=number, section=cell.section, concept_code=best.concept_code,
                concept_title=best.concept_title, subject=best.subject, question_type=best.question_type,
                marks=cell.marks_each, bloom=cell.bloom or best.bloom,
                difficulty=cell.difficulty or best.difficulty, render_mode=best.render_mode,
                status=SlotStatus.SPEC,
                provenance={"frequency": best.frequency, "years": best.years, "source": best.source,
                            "pattern_id": best.pattern_id, "exam": scope.exam_profile,
                            "graph_degree": best.graph_degree}))
        if picked < cell.count:
            res.shortfalls.append(
                f"cell[{ci}] {cell.section}/{cell.question_type} x{cell.count}: filled {picked} "
                f"(short {cell.count - picked} — pool exhausted after concept de-dup)")
        if relaxed:
            res.notes.append(
                f"cell[{ci}] {cell.section}/{cell.question_type}: relaxed difficulty on {relaxed} "
                f"(requested {cell.difficulty})")
    return res
