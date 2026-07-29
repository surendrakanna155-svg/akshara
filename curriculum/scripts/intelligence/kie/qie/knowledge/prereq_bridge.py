"""Read-only bridge from the prerequisite graph into the planner.

WHY THIS EXISTS. `graph_edges.db prereq_edge` holds 1,805 prerequisite edges, 1,183 of them resolved to
certified `KC_` concept ids. It was built in the R5 wave, it is correct, it is already in the certified
namespace — and the repository inventory found it had **no consumer anywhere outside its own module and
tests**. The planner, meanwhile, has no notion of prerequisite structure at all: its rule for a
multi-concept composition is only "same subject, not above class", which admits any two arbitrary
concepts that happen to share a subject.

WHAT THIS IS, AND IS NOT.

  * It is a READ-ONLY ADAPTER. It opens `graph_edges.db` read-only, resolves edges in memory, and returns
    a value object. No store is written, no store is migrated, and no identifier is translated — the graph
    is already KC-native, which is precisely why it was chosen as the first integration.
  * It is REVERSIBLE by construction. If `graph_edges.db` is absent, `load()` returns an EMPTY graph and
    every consumer behaves exactly as it did before this module existed. Deleting this file restores the
    prior planner unchanged.
  * It is DETERMINISTIC. Pure joins over a frozen table; no model, no heuristic scoring, no randomness.

HONEST-NULL DISCIPLINE. `prereq_edge` records its own resolution quality: of 1,805 edges, 1,183 resolved,
552 unresolved and 70 ambiguous. **Only `resolution_method IN ('subject_name','cross_subject_unique')`
edges are loaded.** An ambiguous edge is one whose prerequisite name matched several concepts; admitting it
would mean guessing which, and the graph builder deliberately refused to guess. This module does not
second-guess that refusal.
"""
from __future__ import annotations

import sqlite3
from dataclasses import dataclass, field
from typing import Dict, FrozenSet, List, Optional, Set

from kie import config

GRAPH_DB_PATH = config.KIE_HOME / "graph_edges.db"

# Only edges whose prerequisite name resolved to exactly ONE certified concept. `ambiguous` (70) and
# `unresolved` (552) are excluded — see the honest-null note above.
_TRUSTED_METHODS = ("subject_name", "cross_subject_unique")

# A concept graph should be shallow; this cap is a cycle guard, not a modelling choice. `prereq_edge` is
# not guaranteed acyclic (the older `concept_edges` table contains bidirectional pairs), so every traversal
# is bounded and visited-tracked.
_MAX_CHAIN = 12


@dataclass(frozen=True)
class PrereqGraph:
    """concept_id -> the certified concepts it declares as prerequisites."""
    edges: Dict[str, FrozenSet[str]] = field(default_factory=dict)
    loaded: bool = False
    n_edges: int = 0
    n_concepts: int = 0

    def prerequisites(self, concept_id: str) -> FrozenSet[str]:
        return self.edges.get(concept_id, frozenset())

    def transitive_prerequisites(self, concept_id: str, cap: int = _MAX_CHAIN) -> Set[str]:
        """Everything `concept_id` transitively rests on. Cycle-safe and depth-bounded."""
        seen: Set[str] = set()
        frontier = [(concept_id, 0)]
        while frontier:
            cid, d = frontier.pop()
            if d >= cap:
                continue
            for p in self.edges.get(cid, ()):  # type: ignore[arg-type]
                if p not in seen:
                    seen.add(p)
                    frontier.append((p, d + 1))
        return seen

    def depth(self, concept_id: str, cap: int = _MAX_CHAIN) -> int:
        """Longest prerequisite chain beneath this concept. 0 = a root (nothing declared beneath it).

        This is a STRUCTURAL property of the certified curriculum, not a difficulty score. It says how far
        down the taught dependency chain a concept sits, which is a defensible input to sequencing and to
        judging whether two concepts genuinely belong in one question.
        """
        best = 0
        stack = [(concept_id, 0, frozenset({concept_id}))]
        while stack:
            cid, d, path = stack.pop()
            if d > best:
                best = d
            if d >= cap:
                continue
            for p in self.edges.get(cid, ()):  # type: ignore[arg-type]
                if p not in path:
                    stack.append((p, d + 1, path | {p}))
        return best

    def related(self, a: str, b: str, cap: int = _MAX_CHAIN) -> bool:
        """Does either concept transitively rest on the other?

        This is the question the planner could not previously ask. Two concepts sharing a subject is not
        evidence that they belong in one question; one being a prerequisite of the other IS.
        """
        if a == b:
            return False
        return b in self.transitive_prerequisites(a, cap) or a in self.transitive_prerequisites(b, cap)


EMPTY = PrereqGraph()


def load(db_path=None, certified_ids: Optional[Set[str]] = None) -> PrereqGraph:
    """Load the trusted, resolved prerequisite edges. Returns EMPTY (not an error) when the store is
    absent — that is the reversibility guarantee: no graph, prior behaviour.

    `certified_ids`, when supplied, restricts both endpoints to concepts that are CERTIFIED today. An edge
    pointing at a concept that has since been quarantined must not silently re-admit it.
    """
    path = db_path or GRAPH_DB_PATH
    try:
        conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    except sqlite3.Error:
        return EMPTY
    try:
        conn.row_factory = sqlite3.Row
        q = ("SELECT concept_id, resolved_concept_id FROM prereq_edge "
             "WHERE resolved_concept_id IS NOT NULL AND resolution_method IN (%s)"
             % ",".join("?" * len(_TRUSTED_METHODS)))
        rows = conn.execute(q, _TRUSTED_METHODS).fetchall()
    except sqlite3.Error:
        return EMPTY
    finally:
        conn.close()

    acc: Dict[str, Set[str]] = {}
    n = 0
    for r in rows:
        src, dst = r["concept_id"], r["resolved_concept_id"]
        if src == dst:
            continue                                   # a concept is not its own prerequisite
        if certified_ids is not None and (src not in certified_ids or dst not in certified_ids):
            continue
        acc.setdefault(src, set()).add(dst)
        n += 1
    edges = {k: frozenset(v) for k, v in acc.items()}
    return PrereqGraph(edges=edges, loaded=True, n_edges=n, n_concepts=len(edges))
