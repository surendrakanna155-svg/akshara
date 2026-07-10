"""Candidate pool — reuses Question Intelligence + the Concept Graph to build the set of
possible questions for a scope, at one-candidate-per-(concept, question_type) grain.

Objective candidates are grounded in real PYQ patterns (carry type/bloom/difficulty/
frequency/years). Descriptive candidates are synthesized per concept (short/long answer),
inheriting the concept's dominant bloom/difficulty. Graph degree is attached so selection can
spread across the concept graph instead of clustering.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, List, Tuple

from kie.qpgen.blueprint import DESCRIPTIVE_TYPES
from kie.qpgen.models import Bloom, Difficulty, QuestionType, RenderMode
from kie.qpgen.scope import SyllabusScope

_DESCRIPTIVE = (QuestionType.SHORT_ANSWER, QuestionType.LONG_ANSWER)


@dataclass
class Candidate:
    key: str                 # stable dedup id: "<concept_code>|<question_type>"
    concept_code: str
    concept_title: str
    subject: str
    question_type: str
    bloom: str
    difficulty: str
    frequency: int
    years: List[int]
    render_mode: str
    source: str              # 'pattern' | 'concept'
    graph_degree: int = 0
    pattern_id: str = None
    evidence: int = 0        # scope evidence strength (for weighting)
    chapter: str = None      # canonical syllabus chapter (for coverage balancing)


def _graph_degrees(conn, codes: List[str]) -> Dict[str, int]:
    if not codes:
        return {}
    ph = ",".join("?" * len(codes))
    deg: Dict[str, int] = {c: 0 for c in codes}
    for col in ("from_concept", "to_concept"):
        for r in conn.execute(
            f"SELECT {col} c, COUNT(*) n FROM concept_edges WHERE {col} IN ({ph}) GROUP BY {col}", codes
        ).fetchall():
            deg[r["c"]] = deg.get(r["c"], 0) + r["n"]
    return deg


def _concept_profile(conn, codes: List[str]) -> Dict[str, Tuple[str, str]]:
    """Dominant (bloom, difficulty) per concept from its highest-frequency pattern."""
    if not codes:
        return {}
    ph = ",".join("?" * len(codes))
    prof: Dict[str, Tuple[str, str]] = {}
    for r in conn.execute(
        f"SELECT concept_code, bloom, difficulty, frequency FROM question_patterns "
        f"WHERE concept_code IN ({ph}) ORDER BY COALESCE(frequency,0) DESC", codes
    ).fetchall():
        prof.setdefault(r["concept_code"], (r["bloom"] or Bloom.UNDERSTAND,
                                            r["difficulty"] or Difficulty.MEDIUM))
    return prof


def _best_patterns(conn, codes: List[str]) -> Dict[Tuple[str, str], dict]:
    """Best (highest-frequency) pattern per (concept, question_type)."""
    if not codes:
        return {}
    ph = ",".join("?" * len(codes))
    best: Dict[Tuple[str, str], dict] = {}
    for r in conn.execute(
        f"SELECT pattern_id, concept_code, question_type, bloom, difficulty, "
        f"       COALESCE(frequency,0) f, years FROM question_patterns "
        f"WHERE concept_code IN ({ph}) ORDER BY COALESCE(frequency,0) DESC", codes
    ).fetchall():
        key = (r["concept_code"], r["question_type"])
        if key not in best:
            best[key] = dict(r)
    return best


def _years(raw) -> List[int]:
    import json
    try:
        return [int(y) for y in json.loads(raw or "[]")]
    except Exception:
        return []


def build_pool(conn, scope: SyllabusScope) -> List[Candidate]:
    codes = list(scope.concept_codes)
    degrees = _graph_degrees(conn, codes)
    profile = _concept_profile(conn, codes)
    best = _best_patterns(conn, codes)
    out: List[Candidate] = []

    # objective candidates — one per (concept, type), grounded in the best real pattern
    for (code, qtype), p in best.items():
        if qtype in DESCRIPTIVE_TYPES:
            continue  # descriptive handled below, uniformly per concept
        cref = scope.concepts[code]
        out.append(Candidate(
            key=f"{code}|{qtype}", concept_code=code, concept_title=cref.title, subject=cref.subject,
            question_type=qtype, bloom=p["bloom"] or Bloom.UNDERSTAND,
            difficulty=p["difficulty"] or Difficulty.MEDIUM, frequency=p["f"], years=_years(p["years"]),
            render_mode=RenderMode.SPEC_ONLY, source="pattern", graph_degree=degrees.get(code, 0),
            pattern_id=p["pattern_id"], evidence=cref.evidence, chapter=cref.chapter))

    # descriptive candidates — one short + one long per in-scope concept (deterministic)
    for code, cref in scope.concepts.items():
        dom_bloom, dom_diff = profile.get(code, (Bloom.UNDERSTAND, Difficulty.MEDIUM))
        for qtype in _DESCRIPTIVE:
            diff = dom_diff if qtype == QuestionType.SHORT_ANSWER else Difficulty.HARD
            bloom = dom_bloom if qtype == QuestionType.SHORT_ANSWER else Bloom.ANALYZE
            out.append(Candidate(
                key=f"{code}|{qtype}", concept_code=code, concept_title=cref.title, subject=cref.subject,
                question_type=qtype, bloom=bloom, difficulty=diff, frequency=cref.evidence, years=[],
                render_mode=RenderMode.DETERMINISTIC, source="concept",
                graph_degree=degrees.get(code, 0), evidence=cref.evidence, chapter=cref.chapter))
    return out


def pool_stats(pool: List[Candidate]) -> Dict:
    by_type: Dict[str, int] = {}
    by_mode: Dict[str, int] = {}
    for c in pool:
        by_type[c.question_type] = by_type.get(c.question_type, 0) + 1
        by_mode[c.render_mode] = by_mode.get(c.render_mode, 0) + 1
    return {"total": len(pool), "by_type": by_type, "by_render_mode": by_mode,
            "concepts": len({c.concept_code for c in pool})}
