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
import math
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


# importance tiers: within a tier the SEED decides order, so different seeds pick different
# (equally-important) concepts → cross-paper variety WITHOUT sacrificing importance ordering.
IMPORTANCE_TIERS = 4


def _seed_hash(concept_code: str, seed: int) -> int:
    return int(hashlib.sha256(f"{concept_code}|{seed}".encode()).hexdigest()[:12], 16)


def _tier_map(cands: List[Candidate], n: int = IMPORTANCE_TIERS) -> Dict[str, int]:
    """Bucket candidates of one type into n equal-size importance tiers by frequency RANK
    (tier 0 = top quantile of exam-importance). Rank-based (not ratio-to-max) so a power-law
    frequency distribution still spreads concepts across tiers — giving the seed real room to
    vary selection within a tier while keeping quality (tier 0 stays the most important)."""
    ordered = sorted(cands, key=lambda c: (-c.frequency, c.concept_code))
    size = max(1, math.ceil(len(ordered) / n))
    return {c.key: min(n - 1, i // size) for i, c in enumerate(ordered)}


def _priority(cand: Candidate, seed: int, subject_usage: Dict[str, int], tier: int):
    """Lower = picked first: balance subjects → importance tier → SEEDED order (variety) →
    frequency within tier → stable id. The seed now drives selection, not just final ties."""
    return (
        subject_usage.get(cand.subject, 0),   # per-paper subject balance
        tier,                                  # importance tier (quality preserved)
        _seed_hash(cand.concept_code, seed),   # SEED drives which concepts of a tier are chosen
        -cand.frequency,                       # within tier+seed, prefer higher frequency
        cand.concept_code,                     # final stable tie-break (reproducible)
    )


def select(blueprint: Blueprint, pool: List[Candidate], request: PaperRequest,
           scope: SyllabusScope) -> SelectionResult:
    exclude = set(request.exclude_concepts or ())
    by_type: Dict[str, List[Candidate]] = {}
    for c in pool:
        if c.concept_code in exclude:          # cross-paper non-overlap (Set A/B / series)
            continue
        by_type.setdefault(c.question_type, []).append(c)
    tier_of: Dict[str, int] = {}
    for cands in by_type.values():
        tier_of.update(_tier_map(cands))

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
            best = min(bucket, key=lambda c: _priority(c, request.seed, subject_usage, tier_of[c.key]))
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
