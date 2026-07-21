"""R5-5 [#knowledge-ia-8] — cross-class "revisits / deepens" edges over the frozen index.

15 certified concept NAMES recur across classes as disjoint nodes (e.g. "Area of a rectangle" is a separate
certified concept in Class 6 and in Class 8). The dead `ki_mention` table (0 rows, 0 code refs) never captured
this, so a mastery/adaptive layer treats Class 8's node as unrelated to Class 6's. This builds a DERIVED edge
table linking the earlier node to the later (deepening) one, ON TOP of the frozen index (opened mode=ro — no
foundation mutation). Class order is parsed from `taught_at_class`; a pair whose order cannot be established is
recorded as an undirected co-occurrence (directed=0) — never a guessed direction.
"""
from __future__ import annotations

import re
from itertools import combinations
from typing import Dict, List, Optional, Tuple

from kie.qie.graph import store as ST
from kie.qie.inventory import crosswalk as XW


def _class_order(taught_at_class) -> Optional[int]:
    """Leading integer of a class label ('6', 'Class 8', '11-12' -> 11), or None if none parseable."""
    m = re.search(r"\d+", str(taught_at_class or ""))
    return int(m.group()) if m else None


def build(graph_path=None, index_path=XW.INDEX_DB_PATH) -> Dict[str, object]:
    """Link certified concepts that share a (subject, normalized name) across >1 class. READ-ONLY over the frozen
    index; writes only graph_edges.db. Idempotent."""
    idx = XW.open_index_ro(index_path)
    try:
        by_name: Dict[Tuple[str, str], List[dict]] = {}
        for r in idx.execute("SELECT concept_id, subject, canonical_name, taught_at_class FROM ki_concept "
                            "WHERE status='certified'"):
            key = (r["subject"] or "", XW._norm(r["canonical_name"]))
            if not key[1]:
                continue
            by_name.setdefault(key, []).append(
                {"kc": r["concept_id"], "class": r["taught_at_class"], "order": _class_order(r["taught_at_class"])})
    finally:
        idx.close()

    rows: List[tuple] = []
    for (subject, norm), nodes in by_name.items():
        classes = {n["class"] for n in nodes}
        if len(classes) < 2:                                   # a genuine cross-class recurrence needs >1 class
            continue
        for a, b in combinations(sorted(nodes, key=lambda n: (n["order"] is None, n["order"] or 0, n["kc"])), 2):
            if a["kc"] == b["kc"] or a["class"] == b["class"]:
                continue
            oa, ob = a["order"], b["order"]
            if oa is not None and ob is not None and oa != ob:
                earlier, later = (a, b) if oa < ob else (b, a)
                directed = 1
            else:
                earlier, later, directed = a, b, 0             # order unknown -> undirected co-occurrence
            rows.append((subject, norm, earlier["kc"], earlier["class"], later["kc"], later["class"], directed))

    conn = ST.open_store(graph_path, writable=True)
    try:
        conn.execute("DELETE FROM revisits_edge")
        conn.executemany(
            "INSERT OR REPLACE INTO revisits_edge (subject, concept_norm, earlier_kc, earlier_class, later_kc, "
            "later_class, directed) VALUES (?,?,?,?,?,?,?)", rows)
        conn.execute("INSERT INTO prereq_meta(key, value) VALUES ('revisits_index_version', ?) "
                     "ON CONFLICT(key) DO UPDATE SET value=excluded.value", (XW.build(index_path).version,))
        conn.commit()
    finally:
        conn.close()
    directed = sum(1 for r in rows if r[6] == 1)
    return {"edges": len(rows), "directed": directed, "co_occurrence": len(rows) - directed,
            "recurring_concepts": sum(1 for _k, v in by_name.items() if len({n['class'] for n in v}) > 1),
            "note": "ki_mention (0 rows, dead) is superseded by this derived layer; class order never guessed."}


def deepens(concept_id: str, graph_path=None) -> List[str]:
    """concept_ids that this concept DEEPENS (i.e. earlier nodes it revisits). Directed edges only."""
    conn = ST.open_store(graph_path, writable=False)
    try:
        return [r[0] for r in conn.execute(
            "SELECT earlier_kc FROM revisits_edge WHERE later_kc=? AND directed=1", (concept_id,))]
    finally:
        conn.close()


if __name__ == "__main__":
    import json
    print(json.dumps(build(), indent=2))
