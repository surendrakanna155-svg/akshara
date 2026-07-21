"""Persist QuestionBlueprints by EVOLVING factory_corpus.db's generation_spec in place (Owner Decision 3).

The blueprint IS a generation_spec row: the existing factory pipeline (validate_run, certify) keeps reading
the columns it always did (lane, subject, class_level, archetype, ...); the planning layer adds the rich
QuestionBlueprint columns via idempotent ALTERs. One corpus, one lifecycle — no second spec shape.
"""
from __future__ import annotations

import json
import sqlite3
from typing import Dict, List, Optional

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


def _concept_ids_all(bp: dict) -> list:
    """#database-5 (R3-4): the composition-member concept IDS (not display titles). concept_code already
    stores the primary concept_id, so concept_codes_all must be its ID sibling — a stable key a downstream
    reader can join on, never a display string. The primary id plus any compose-partner ids the planner
    attached (deduped, order-stable). Never fabricates an id: only ids the blueprint actually carries."""
    ids = [bp["concept_id"]]
    for partner in bp.get("compose_with", []) or []:
        if partner and partner not in ids:
            ids.append(partner)
    return ids


def _row(bp: dict) -> Dict[str, object]:
    ev = bp.get("planner_evidence", {})
    return {
        "spec_id": bp["spec_id"], "run_id": bp["run_id"],
        "lane": bp["lane"], "board": None, "exam_profile": bp["exam"], "exam": bp["exam"],
        "class_level": bp["class_level"], "subject": bp["subject"],
        "chapter_id": bp["chapter_id"], "chapter_title": bp.get("chapter_title"),
        "concept_code": bp["concept_id"], "concept_title": bp["concept_name"],
        "concept_codes_all": json.dumps(_concept_ids_all(bp)),
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
    # R3-2 ([C12]): STOP RE-PARENTING spec provenance. spec_id = sha(blueprint_fingerprint|occurrence) is
    # content-derived and run-INDEPENDENT, so the planner re-issues the SAME spec_id across runs. The old
    # `INSERT OR REPLACE` overwrote the prior row — silently re-parenting an earlier run's spec (its run_id +
    # created_at provenance) to the new run and corrupting historical run reports. A conflicting spec_id means
    # the IDENTICAL blueprint already exists, so `ON CONFLICT DO NOTHING` keeps the original row untouched —
    # provenance preserved, no re-parent. (Run-scoped spec ids / consumption-ledger semantics are a deferred
    # design choice owned by the run-planner lane; see the R3-2 residual note.)
    conn.executemany(
        f"INSERT INTO generation_spec ({','.join(cols)}) VALUES ({','.join('?' * len(cols))}) "
        f"ON CONFLICT(spec_id) DO NOTHING",
        [tuple(r[c] for c in cols) for r in rows])
    conn.commit()
    return len(rows)


def load_blueprints(conn: sqlite3.Connection, run_id: str) -> List[dict]:
    return [dict(r) for r in conn.execute(
        "SELECT * FROM generation_spec WHERE run_id=? ORDER BY spec_id", (run_id,))]


# ── #database-5 one-shot backfill: rewrite existing generation_spec.concept_codes_all TITLES -> IDS ──────
def _resolve_title_to_id(row: sqlite3.Row, member: str, index_conn: Optional[sqlite3.Connection]) -> Optional[str]:
    """Resolve one concept_codes_all member to a concept_id, DETERMINISTICALLY, without fabricating:
      1. it already equals this row's concept_code (the id-of-record)  -> keep it (already an id / self);
      2. it equals this row's concept_title                            -> use concept_code (the primary id);
      3. it resolves uniquely by canonical_name in the frozen index    -> use that concept_id;
      otherwise -> None (unresolvable; the caller keeps the original member and logs — honest null)."""
    code = row["concept_code"]
    if member == code:
        return member
    if member == row["concept_title"] and code:
        return code
    if index_conn is not None:
        hits = [r[0] for r in index_conn.execute(
            "SELECT concept_id FROM ki_concept WHERE canonical_name=?", (member,))]
        if len(hits) == 1:
            return hits[0]
    return None


def backfill_concept_codes_all(conn: sqlite3.Connection,
                               index_conn: Optional[sqlite3.Connection] = None) -> Dict[str, object]:
    """One-shot, deterministic, idempotent backfill for the #database-5 defect (the pre-fix writer stored
    concept TITLES in concept_codes_all instead of ids). Rewrites each generation_spec row's member list to
    concept_ids where resolvable (see `_resolve_title_to_id`); leaves any unresolvable member AS-IS and
    records it under `unresolved` — it NEVER fabricates an id. Rows already fully id-valued are untouched.

    Pass `index_conn` (a read-only knowledge_index.db) to also resolve composition-partner TITLES by
    canonical_name; without it, only the concept_code shortcut applies (sufficient for the single-concept
    rows the pre-fix writer produced). Returns a summary; commits only if it changed anything."""
    rewritten = unchanged = 0
    unresolved: List[dict] = []
    updates: List[tuple] = []
    for row in conn.execute("SELECT spec_id, concept_code, concept_title, concept_codes_all "
                            "FROM generation_spec"):
        raw = row["concept_codes_all"]
        if not raw:
            unchanged += 1
            continue
        try:
            members = json.loads(raw)
        except (ValueError, TypeError):
            unresolved.append({"spec_id": row["spec_id"], "reason": "concept_codes_all not valid JSON",
                               "value": raw})
            unchanged += 1
            continue
        if not isinstance(members, list):
            unresolved.append({"spec_id": row["spec_id"], "reason": "concept_codes_all not a JSON list",
                               "value": raw})
            unchanged += 1
            continue
        new_members, changed_any = [], False
        for m in members:
            rid = _resolve_title_to_id(row, m, index_conn)
            if rid is None:
                new_members.append(m)  # honest: leave the original, do NOT fabricate an id
                unresolved.append({"spec_id": row["spec_id"], "member": m})
            else:
                new_members.append(rid)
                changed_any = changed_any or (rid != m)
        if changed_any:
            updates.append((json.dumps(new_members), row["spec_id"]))
            rewritten += 1
        else:
            unchanged += 1
    if updates:
        conn.executemany("UPDATE generation_spec SET concept_codes_all=? WHERE spec_id=?", updates)
        conn.commit()
    return {"rewritten": rewritten, "unchanged": unchanged,
            "unresolved_count": len(unresolved), "unresolved": unresolved}
