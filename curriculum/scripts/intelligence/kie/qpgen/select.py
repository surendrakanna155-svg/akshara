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
from typing import Dict, List, Optional

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

# Composite importance signal (Phase 4). Exam frequency stays PRIMARY; PYQ recency, concept-graph
# centrality (already computed in the pool, previously unused in ranking) and evidence authority
# (named-law / definition / multi-pattern breadth) are additive modifiers. Deterministic:
# recency is measured against the corpus's own latest year, never the wall clock.
# Modifier weights are deliberately SMALL so exam frequency stays clearly primary: each modifier
# differentiates similar-frequency concepts and breaks ties, but a real frequency gap still wins.
_RECENCY_WINDOW = 12      # a PYQ this many years older than the corpus's latest counts for ~0
_GRAPH_CAP = 10           # cap a hub concept's centrality contribution so it can't dominate
_W_RECENCY, _W_GRAPH, _W_AUTHORITY = 1.0, 0.25, 0.3


def _seed_hash(concept_code: str, seed: int) -> int:
    return int(hashlib.sha256(f"{concept_code}|{seed}".encode()).hexdigest()[:12], 16)


def _recency(years: List[int], ref_year) -> float:
    """Weighted count of appearances, recent PYQs weighing more (linear decay over the window).
    0 when there is no year evidence (e.g. descriptive candidates) or no reference year."""
    if not years or ref_year is None:
        return 0.0
    return sum(max(0.0, 1.0 - (ref_year - y) / _RECENCY_WINDOW) for y in years)


def importance_score(cand: Candidate, ref_year) -> float:
    """Deterministic composite importance: frequency (primary) + recency + graph centrality +
    evidence authority. Higher = more important. Used for tiering and the within-tier tie-break."""
    freq = cand.frequency or 0
    centrality = min(cand.graph_degree or 0, _GRAPH_CAP)
    authority = max(0, (cand.evidence or 0) - freq)     # law/def/breadth beyond raw frequency
    return (freq + _W_RECENCY * _recency(cand.years, ref_year)
            + _W_GRAPH * centrality + _W_AUTHORITY * authority)


def _ref_year(pool: List[Candidate]):
    """The corpus's latest PYQ year (data-driven, so recency stays deterministic + wall-clock-free)."""
    years = [y for c in pool for y in (c.years or ())]
    return max(years) if years else None


def _tier_map(cands: List[Candidate], score_of: Dict[str, float], n: int = IMPORTANCE_TIERS) -> Dict[str, int]:
    """Bucket candidates of one type into n equal-size importance tiers by composite-score RANK
    (tier 0 = top quantile of importance). Rank-based (not ratio-to-max) so a power-law
    distribution still spreads concepts across tiers — giving the seed real room to vary
    selection within a tier while keeping quality (tier 0 stays the most important)."""
    ordered = sorted(cands, key=lambda c: (-score_of[c.key], c.concept_code))
    size = max(1, math.ceil(len(ordered) / n))
    return {c.key: min(n - 1, i // size) for i, c in enumerate(ordered)}


def _fill_rank(cand: Candidate, fillable: Dict[str, int]) -> int:
    """FILL-AWARENESS (2026-07-11 Content Density Phase 2). Lower = preferred. Ranks a candidate by
    the STRENGTH of the deterministic, grounded content available to materialize it AS-IS (AI OFF):
      0 solver-verified template · 1 grounded verified definition · 2 other validated capability ·
      3 unfillable (would ship as an authoring spec).
    fillable maps candidate.key → that rank; absent ⇒ unfillable (3). This lifts paper completeness
    without touching syllabus/grade/subject boundaries or the difficulty/bloom bucket (applied
    upstream), and it sits AFTER subject balance and does NOT reorder chapter/seed diversity among
    equally-fillable candidates, so coverage diversity and seed variety are preserved."""
    return fillable.get(cand.key, 3) if fillable else 0


def _priority(cand: Candidate, seed: int, subject_usage: Dict[str, int],
              chapter_usage: Dict[str, int], tier: int, score: float,
              fillable: Optional[Dict[str, int]] = None):
    """Lower = picked first: balance subjects → prefer FILLABLE content → balance chapters →
    importance tier → SEEDED order (variety) → composite importance → stable id. Subject coverage
    is balanced first; then we prefer concepts we can actually fill deterministically; chapter
    coverage and the seed still drive diversity/variety among equally-fillable candidates."""
    return (
        subject_usage.get(cand.subject, 0),    # per-paper subject balance (diversity first)
        _fill_rank(cand, fillable or {}),      # prefer template > definition > other > unfillable
        chapter_usage.get(cand.chapter, 0),    # per-paper chapter/topic balance (diversity)
        tier,                                  # importance tier (graph + recency + evidence + freq)
        _seed_hash(cand.concept_code, seed),   # SEED drives which concepts of a tier are chosen
        -round(score, 6),                      # within tier+seed, prefer higher composite importance
        cand.concept_code,                     # final stable tie-break (reproducible)
    )


def select(blueprint: Blueprint, pool: List[Candidate], request: PaperRequest,
           scope: SyllabusScope, fillable: Optional[Dict[str, int]] = None) -> SelectionResult:
    """`fillable` (optional): candidate.key → fill-strength rank (0 template, 1 definition,
    2 other, 3/absent unfillable), supplied by the engine which knows the materialization
    capabilities. When provided, selection PREFERS fillable concepts (after subject balance) so a
    paper ships complete deterministic content instead of authoring specs — without weakening
    syllabus/grade/subject isolation, chapter diversity, bloom/difficulty, or seed determinism."""
    exclude = set(request.exclude_concepts or ())
    ref_year = _ref_year(pool)
    score_of: Dict[str, float] = {c.key: importance_score(c, ref_year) for c in pool}
    by_type: Dict[str, List[Candidate]] = {}
    for c in pool:
        if c.concept_code in exclude:          # cross-paper non-overlap (Set A/B / series)
            continue
        by_type.setdefault(c.question_type, []).append(c)
    tier_of: Dict[str, int] = {}
    for cands in by_type.values():
        tier_of.update(_tier_map(cands, score_of))

    res = SelectionResult()
    subject_usage: Dict[str, int] = {}
    chapter_usage: Dict[str, int] = {}
    number = 0

    for ci, cell in enumerate(blueprint.cells):
        # a subject-bound cell (e.g. NEET "Physics · Section A") draws ONLY from that subject,
        # so per-subject exam sections stay coherent; unbound cells draw from all subjects.
        available = [c for c in by_type.get(cell.question_type, [])
                     if c.concept_code not in res.used_concepts
                     and (not cell.subject or c.subject == cell.subject)]
        picked = 0
        relaxed = {"difficulty": 0, "bloom": 0}
        for _ in range(cell.count):
            remaining = [c for c in available if c.concept_code not in res.used_concepts]
            if not remaining:
                break
            # SELECT for the requested difficulty AND bloom (graceful degradation, not stamping)
            bucket, relaxed_here = _preference_bucket(remaining, cell)
            for k in relaxed_here:
                relaxed[k] += 1
            best = min(bucket, key=lambda c: _priority(c, request.seed, subject_usage,
                                                       chapter_usage, tier_of[c.key], score_of[c.key],
                                                       fillable))
            number += 1
            picked += 1
            res.used_concepts.add(best.concept_code)
            subject_usage[best.subject] = subject_usage.get(best.subject, 0) + 1
            chapter_usage[best.chapter] = chapter_usage.get(best.chapter, 0) + 1
            # LABEL with the candidate's ACTUAL bloom/difficulty (honest), record the target too
            res.slots.append(QuestionSlot(
                number=number, section=cell.section, concept_code=best.concept_code,
                concept_title=best.concept_title, subject=best.subject, question_type=best.question_type,
                marks=cell.marks_each, bloom=best.bloom, difficulty=best.difficulty,
                render_mode=best.render_mode, status=SlotStatus.SPEC,
                provenance={"frequency": best.frequency, "years": best.years, "source": best.source,
                            "pattern_id": best.pattern_id, "exam": scope.exam_profile,
                            "graph_degree": best.graph_degree, "chapter": best.chapter,
                            "importance_score": round(score_of[best.key], 4),
                            "recency": round(_recency(best.years, ref_year), 4),
                            "requested_difficulty": cell.difficulty, "requested_bloom": cell.bloom,
                            "difficulty_met": (not cell.difficulty) or best.difficulty == cell.difficulty,
                            "bloom_met": (not cell.bloom) or best.bloom == cell.bloom}))
        if picked < cell.count:
            res.shortfalls.append(
                f"cell[{ci}] {cell.section}/{cell.question_type} x{cell.count}: filled {picked} "
                f"(short {cell.count - picked} — pool exhausted after concept de-dup)")
        for constraint, n in relaxed.items():
            if n:
                requested = getattr(cell, constraint)
                res.notes.append(
                    f"cell[{ci}] {cell.section}/{cell.question_type}: {constraint} relaxed on {n}/"
                    f"{cell.count} (requested {requested}; scope lacked enough matching candidates)")
    return res


def _preference_bucket(remaining: List[Candidate], cell):
    """Graceful degradation: prefer candidates matching BOTH difficulty and bloom; else match
    difficulty only (bloom relaxed); else bloom only (difficulty relaxed); else any (both
    relaxed). Returns (bucket, tuple_of_relaxed_constraints)."""
    def diff_ok(c):
        return (not cell.difficulty) or c.difficulty == cell.difficulty

    def bloom_ok(c):
        return (not cell.bloom) or c.bloom == cell.bloom

    both = [c for c in remaining if diff_ok(c) and bloom_ok(c)]
    if both:
        return both, ()
    if cell.difficulty:
        d = [c for c in remaining if diff_ok(c)]
        if d:
            return d, ("bloom",) if cell.bloom else ()
    if cell.bloom:
        b = [c for c in remaining if bloom_ok(c)]
        if b:
            return b, ("difficulty",) if cell.difficulty else ()
    return remaining, tuple(k for k in ("difficulty", "bloom") if getattr(cell, k))
