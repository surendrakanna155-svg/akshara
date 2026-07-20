"""QDI <-> curriculum scope-linking + blueprint attachment (the DETERMINISTIC parts of Phase 4).

Certified QDI design patterns enrich a QuestionBlueprint with expected_solving_path + misconceptions +
pattern_id — but ONLY `status='certified'` patterns, and attachment is deterministic (a fixed pick by
pattern_id). When no certified pattern matches, the blueprint keeps HONEST NULLS — no fabricated design DNA.

Scope-linking maps a pattern to the exam profile + earliest class its machinery is legal at (populates the
`qdi_scope_link` seam). Certification of the patterns themselves is model-audited (Phase 4 mining, owner-gated);
everything here is deterministic and testable now.
"""
from __future__ import annotations

from typing import Dict, List, Optional

VALID_EXAM_PROFILES = ("SCHOOL", "JEE_MAIN", "JEE_ADVANCED", "NEET")
_EXAM_TO_PROFILE = {"JEE_Main": "JEE_MAIN", "JEE_Advanced": "JEE_ADVANCED", "NEET": "NEET", "AIIMS": "NEET"}


def scope_link_for(pattern: dict, min_class: int = 11) -> dict:
    """Deterministic scope link for a competitive-exam design pattern (classes 11-12)."""
    exam = pattern.get("exam", "")
    return {"pattern_id": pattern.get("pattern_id"), "subject": pattern.get("subject"),
            "min_class": min_class, "exam_profile": _EXAM_TO_PROFILE.get(exam, "SCHOOL"),
            "basis": f"{exam or 'unknown'} design pattern; machinery legal from class {min_class}"}


def validate_scope_link(link: dict) -> Optional[str]:
    if link.get("exam_profile") not in VALID_EXAM_PROFILES:
        return f"invalid exam_profile {link.get('exam_profile')!r}"
    mc = link.get("min_class")
    if not isinstance(mc, int) or not (1 <= mc <= 12):
        return f"invalid min_class {mc!r}"
    if not link.get("pattern_id"):
        return "scope link has no pattern_id"
    return None


def index_by_key(patterns: List[dict]) -> Dict[tuple, List[dict]]:
    """(subject, archetype, difficulty_band) -> [patterns], each sorted by pattern_id for a deterministic pick."""
    idx: Dict[tuple, List[dict]] = {}
    for p in patterns:
        idx.setdefault((p.get("subject"), p.get("archetype"), p.get("difficulty_band")), []).append(p)
    for key in idx:
        idx[key].sort(key=lambda p: p.get("pattern_id") or "")
    return idx


def attach_pattern(bp: dict, idx: Dict[tuple, List[dict]]) -> dict:
    """Attach a certified pattern's design DNA to a blueprint if one matches (subject, archetype, difficulty).
    Deterministic pick (first by pattern_id). No match -> honest nulls preserved."""
    cands = idx.get((bp.get("subject"), bp.get("archetype"), bp.get("difficulty")))
    if not cands:
        return bp
    p = cands[0]
    bp["pattern_id"] = p.get("pattern_id")
    bp["expected_solving_path"] = p.get("solution_structure")
    bp["misconceptions_to_evaluate"] = p.get("misconceptions") or []
    bp["planner_evidence"] = {**bp.get("planner_evidence", {}), "design_pattern": p.get("pattern_id")}
    return bp
