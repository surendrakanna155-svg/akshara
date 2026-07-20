"""Persist QuestionBlueprints by EVOLVING factory_corpus.db's generation_spec in place (Owner Decision 3).

The blueprint IS a generation_spec row: the existing factory pipeline (validate_run, certify) keeps reading
the columns it always did (lane, subject, class_level, archetype, ...); the planning layer adds the rich
QuestionBlueprint columns via idempotent ALTERs. One corpus, one lifecycle — no second spec shape.
"""
from __future__ import annotations

import json
import sqlite3
from typing import Dict, List

from kie.qie.factory import corpus as CO  # noqa: F401  (re-exported convenience: same store)

# columns the QuestionBlueprint adds to generation_spec (idempotent migration)
BLUEPRINT_COLUMNS = [
    ("exam", "TEXT"), ("chapter_id", "TEXT"), ("chapter_title", "TEXT"), ("sub_concept", "TEXT"),
    ("prerequisites", "TEXT"), ("curriculum_boundary", "TEXT"), ("chapter_weight", "REAL"),
    ("concept_weight", "REAL"), ("reasoning_depth", "INTEGER"), ("difficulty_basis", "TEXT"),
    ("difficulty_drivers", "TEXT"), ("learning_objective", "TEXT"), ("expected_solving_path", "TEXT"),
    ("misconceptions", "TEXT"), ("pattern_id", "TEXT"), ("blueprint_fingerprint", "TEXT"),
    ("target_difficulty", "TEXT"), ("blueprint_model", "TEXT"),
]


def migrate(conn: sqlite3.Connection) -> None:
    existing = {r[1] for r in conn.execute("PRAGMA table_info(generation_spec)")}
    for name, typ in BLUEPRINT_COLUMNS:
        if name not in existing:
            conn.execute(f"ALTER TABLE generation_spec ADD COLUMN {name} {typ}")
    conn.commit()


def _row(bp: dict) -> Dict[str, object]:
    ev = bp.get("planner_evidence", {})
    return {
        "spec_id": bp["spec_id"], "run_id": bp["run_id"],
        "lane": bp["lane"], "board": None, "exam_profile": bp["exam"], "exam": bp["exam"],
        "class_level": bp["class_level"], "subject": bp["subject"],
        "chapter_id": bp["chapter_id"], "chapter_title": bp.get("chapter_title"),
        "concept_code": bp["concept_id"], "concept_title": bp["concept_name"],
        "concept_codes_all": json.dumps([bp["concept_name"]]),
        "sub_concept": bp.get("sub_concept"),
        "composition": bp["composition"], "archetype": bp["archetype"], "question_type": bp["question_type"],
        "intended_depth": bp["reasoning_depth"], "reasoning_depth": bp["reasoning_depth"],
        "intended_difficulty": bp["difficulty"], "target_difficulty": bp["target_difficulty"],
        "visual_required": int(bool(bp.get("visual_required", False))),
        "prerequisites": json.dumps(bp.get("prerequisites", [])),
        "curriculum_boundary": json.dumps(bp.get("curriculum_boundary", {})),
        "boundary": json.dumps({"forbidden_terms": bp.get("forbidden_terms", [])}),
        "chapter_weight": bp.get("chapter_weight"), "concept_weight": bp.get("concept_weight"),
        "difficulty_basis": bp.get("difficulty_basis"),
        "difficulty_drivers": json.dumps(bp.get("difficulty_drivers", {})),
        "learning_objective": bp.get("learning_objective"),
        "expected_solving_path": json.dumps(bp.get("expected_solving_path")),
        "misconceptions": json.dumps(bp.get("misconceptions_to_evaluate", [])),
        "pattern_id": bp.get("pattern_id"), "blueprint_fingerprint": bp["blueprint_fingerprint"],
        "blueprint_model": bp.get("blueprint_model"),
        "planner_evidence": json.dumps(ev),
        # deterministic marker (never a wall clock): a planned row is provenance-stamped, not time-stamped
        "created_at": f"planned:{ev.get('foundation_version', '?')}:{ev.get('examdna_version', '?')}",
    }


def save_blueprints(conn: sqlite3.Connection, blueprints: List[dict]) -> int:
    migrate(conn)
    rows = [_row(b) for b in blueprints]
    if not rows:
        return 0
    cols = list(rows[0].keys())
    conn.executemany(
        f"INSERT OR REPLACE INTO generation_spec ({','.join(cols)}) VALUES ({','.join('?' * len(cols))})",
        [tuple(r[c] for c in cols) for r in rows])
    conn.commit()
    return len(rows)


def load_blueprints(conn: sqlite3.Connection, run_id: str) -> List[dict]:
    return [dict(r) for r in conn.execute(
        "SELECT * FROM generation_spec WHERE run_id=? ORDER BY spec_id", (run_id,))]
