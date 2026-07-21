"""R5-1 [C13] — resolve the frozen index's prerequisite NAME strings to KC_ concept_ids.

The frozen `ki_concept.prerequisites` are unkeyed name strings (index_schema.sql): ~30% resolve to nothing and
~95 are ambiguous multi-target, so adaptive traversal cannot key off them. This builds a DERIVED, versioned
edge table on TOP of the frozen index (opened mode=ro — no foundation mutation), reusing the certified crosswalk
(canonical_name + aliases). Discipline (audit §11): unresolved AND ambiguous names are kept as HONEST NULL —
never guessed. The resolution rate is reported, not inflated.
"""
from __future__ import annotations

import json
from typing import Dict, List, Optional, Set, Tuple

from kie.qie.graph import store as ST
from kie.qie.inventory import crosswalk as XW


def _build_multimaps(idx) -> Tuple[Dict[Tuple[str, str], Set[str]], Dict[str, Set[str]]]:
    """(subject,norm)->{concept_ids} and norm->{concept_ids} over certified concepts' canonical_name + aliases.

    A MULTIMAP (not the crosswalk's collapsed first-wins map) so genuine multi-target AMBIGUITY is surfaced,
    not silently resolved to whichever concept happened to be inserted first (the audit's 95 ambiguous names)."""
    by_subj: Dict[Tuple[str, str], Set[str]] = {}
    by_norm: Dict[str, Set[str]] = {}
    for r in idx.execute("SELECT concept_id, subject, canonical_name, aliases FROM ki_concept "
                         "WHERE status='certified'"):
        names = [r["canonical_name"]]
        try:
            names += json.loads(r["aliases"] or "[]")
        except (json.JSONDecodeError, TypeError):
            pass
        for nm in names:
            n = XW._norm(nm)
            if not n:
                continue
            by_subj.setdefault((r["subject"] or "", n), set()).add(r["concept_id"])
            by_norm.setdefault(n, set()).add(r["concept_id"])
    return by_subj, by_norm


def _resolve(by_subj, by_norm, subject: Optional[str], norm: str) -> Tuple[Optional[str], str, int]:
    """(resolved_concept_id, method, candidate_count). Honest-null (id=None) for unresolved OR ambiguous."""
    if not norm:
        return None, "unresolved", 0
    exact = by_subj.get((subject or "", norm), set())
    if len(exact) == 1:
        return next(iter(exact)), "subject_name", 1          # unique subject-scoped match
    if len(exact) > 1:
        return None, "ambiguous", len(exact)                 # multi-target IN-subject -> honest-null
    cross = by_norm.get(norm, set())
    if len(cross) == 1:
        return next(iter(cross)), "cross_subject_unique", 1  # a single cross-subject match is safe
    if len(cross) > 1:
        return None, "ambiguous", len(cross)                 # multi-target cross-subject -> honest-null
    return None, "unresolved", 0


def _prereq_names(raw) -> List[str]:
    try:
        vals = json.loads(raw or "[]")
    except (json.JSONDecodeError, TypeError):
        return []
    out: List[str] = []
    for v in vals if isinstance(vals, list) else []:
        nm = v if isinstance(v, str) else (v.get("name") if isinstance(v, dict) else None)
        if nm:
            out.append(nm)
    return out


def build(graph_path=None, index_path=XW.INDEX_DB_PATH) -> Dict[str, object]:
    """Reconcile every certified concept's prerequisite names into resolved KC_ edges. Idempotent (rebuilds
    fresh). Returns a resolution summary. READ-ONLY over the frozen index; writes only graph_edges.db."""
    xw_version = XW.build(index_path).version                # frozen-fingerprint-pinned version string
    idx = XW.open_index_ro(index_path)
    try:
        by_subj, by_norm = _build_multimaps(idx)
        edges: List[tuple] = []
        seen: set = set()
        for r in idx.execute("SELECT concept_id, subject, prerequisites FROM ki_concept WHERE status='certified'"):
            for name in _prereq_names(r["prerequisites"]):
                norm = XW._norm(name)
                if not norm:
                    continue
                key = (r["concept_id"], norm)
                if key in seen:
                    continue                                 # dedup a concept's repeated prereq
                seen.add(key)
                rid, method, cc = _resolve(by_subj, by_norm, r["subject"], norm)
                if rid == r["concept_id"]:
                    # a concept is never its own prerequisite — a name resolving to the declaring concept is a
                    # degenerate self-edge, kept honest-null (guards a future index revision; verifier P3-note-1).
                    rid, method = None, "self_loop"
                edges.append((r["concept_id"], r["subject"], name, norm, rid, method, cc))
    finally:
        idx.close()

    conn = ST.open_store(graph_path, writable=True)
    try:
        conn.execute("DELETE FROM prereq_edge")
        conn.executemany(
            "INSERT INTO prereq_edge (concept_id, subject, prereq_name, prereq_norm, resolved_concept_id, "
            "resolution_method, candidate_count) VALUES (?,?,?,?,?,?,?)", edges)
        stats = _tally(edges)
        meta = {"crosswalk_version": xw_version, "total_edges": str(len(edges)),
                "resolution_stats": json.dumps(stats)}
        for k, v in meta.items():
            conn.execute("INSERT INTO prereq_meta(key, value) VALUES (?,?) "
                         "ON CONFLICT(key) DO UPDATE SET value=excluded.value", (k, v))
        conn.commit()
    finally:
        conn.close()
    return {"total_edges": len(edges), "crosswalk_version": xw_version, "stats": stats,
            "resolution_rate": round(stats["resolved"] / len(edges), 4) if edges else 0.0}


def _tally(edges: List[tuple]) -> Dict[str, int]:
    by_method: Dict[str, int] = {}
    resolved = 0
    for e in edges:
        method = e[5]
        by_method[method] = by_method.get(method, 0) + 1
        if e[4] is not None:                                 # resolved_concept_id present
            resolved += 1
    return {"resolved": resolved, "unresolved": by_method.get("unresolved", 0),
            "ambiguous": by_method.get("ambiguous", 0), "self_loop": by_method.get("self_loop", 0),
            "by_method": dict(sorted(by_method.items()))}


# ── query helpers (read-only) ──────────────────────────────────────────────────────────────────────────
def prerequisites_of(concept_id: str, graph_path=None, resolved_only: bool = True) -> List[str]:
    """Resolved prerequisite concept_ids for `concept_id`. `resolved_only` drops honest-null (unresolved/ambig)."""
    conn = ST.open_store(graph_path, writable=False)
    try:
        q = "SELECT resolved_concept_id FROM prereq_edge WHERE concept_id=?"
        if resolved_only:
            q += " AND resolved_concept_id IS NOT NULL"
        return [r[0] for r in conn.execute(q, (concept_id,)) if r[0] is not None or not resolved_only]
    finally:
        conn.close()


def resolution_report(graph_path=None) -> Dict[str, object]:
    conn = ST.open_store(graph_path, writable=False)
    try:
        total = conn.execute("SELECT COUNT(*) FROM prereq_edge").fetchone()[0]
        by_method = {r[0]: r[1] for r in conn.execute(
            "SELECT resolution_method, COUNT(*) FROM prereq_edge GROUP BY resolution_method ORDER BY 2 DESC")}
        resolved = conn.execute("SELECT COUNT(*) FROM prereq_edge WHERE resolved_concept_id IS NOT NULL"
                                ).fetchone()[0]
        ver = conn.execute("SELECT value FROM prereq_meta WHERE key='crosswalk_version'").fetchone()
        return {"total_edges": total, "resolved": resolved,
                "resolution_rate": round(resolved / total, 4) if total else 0.0,
                "by_method": by_method, "crosswalk_version": ver[0] if ver else None,
                "note": "unresolved + ambiguous names are honest-null (never guessed); rate is not inflated."}
    finally:
        conn.close()


if __name__ == "__main__":
    print(json.dumps(build(), indent=2))
