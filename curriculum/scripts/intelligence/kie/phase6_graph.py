"""Phase 6 — Knowledge Graph (the AIMS Concept Graph). Deterministic edge building.

This is NOT a second graph: it populates concept_edges (mirrors
concept_prerequisites) + concept_board_mappings over the concepts mined in Phase 5.
No AI. Edges are derived deterministically:
  * parent_child  — from the section hierarchy (breadcrumb path A > B > C);
  * related       — concepts co-occurring in the same chunk (≥ MIN_COOCCUR chunks);
  * confused_with — "difference/distinguish between X and Y", "X versus Y";
  * prerequisite  — cue phrases ("based on/requires/prerequisite ...") — DAG-validated
                    (edges that would create a prerequisite cycle are skipped).
Board mappings tie each concept to the foundation (JEE/NEET) exam profile.
"""
from __future__ import annotations

import re
from collections import defaultdict
from typing import Dict, List, Optional, Set, Tuple

from kie import config, ledger, store

MIN_COOCCUR = 2
MAX_RELATED_PER_CONCEPT = 12
# a concept-name group ends at punctuation or a continuation/function word.
_END = r"(?=[\.\,\;\n]|\s+(?:is|are|was|were|has|have|in|of|and|or|over|to|for|with|which|that|the|by)\b|$)"
_CONTRAST = re.compile(
    r"(?:difference between|distinguish between|differentiate between)\s+"
    r"([A-Za-z][A-Za-z \-]{2,40}?)\s+and\s+([A-Za-z][A-Za-z \-]{2,40}?)" + _END, re.I
)
_VERSUS = re.compile(r"\b([A-Z][A-Za-z\-]{3,30})\s+(?:versus|vs\.?)\s+([A-Z][A-Za-z\-]{3,30})\b")
_PREREQ = re.compile(
    r"\b(?:based on|builds? on|requires? knowledge of|prerequisite[s]?(?: is| are|:)?|assumes knowledge of)\s+"
    r"([A-Za-z][A-Za-z \-]{2,40}?)" + _END, re.I
)


# ── concept lookup for matching mentions in text ─────────────────────────────────
def concept_index(conn) -> Tuple[Dict[str, str], "re.Pattern"]:
    """Return ({title_lower: code}, alternation regex). Only titles ≥ 5 chars are
    matchable, to avoid over-connecting on very short common words."""
    rows = conn.execute("SELECT concept_code, title FROM concepts").fetchall()
    by_title: Dict[str, str] = {}
    titles: List[str] = []
    for r in rows:
        t = r["title"].strip()
        if len(t) >= 5 and t.lower() not in by_title:
            by_title[t.lower()] = r["concept_code"]
            titles.append(t)
    if not titles:
        return {}, re.compile(r"(?!x)x")  # matches nothing
    titles.sort(key=len, reverse=True)
    pattern = re.compile(r"\b(" + "|".join(re.escape(t) for t in titles) + r")\b", re.I)
    return by_title, pattern


def mentions(text: str, by_title, pattern) -> Set[str]:
    return {by_title[m.group(1).lower()] for m in pattern.finditer(text) if m.group(1).lower() in by_title}


# ── DAG-validated edge insertion ─────────────────────────────────────────────────
def _prereq_creates_cycle(conn, frm: str, to: str) -> bool:
    """True if adding prerequisite frm->to would create a cycle (to can already reach frm)."""
    seen, stack = set(), [to]
    while stack:
        node = stack.pop()
        if node == frm:
            return True
        if node in seen:
            continue
        seen.add(node)
        stack.extend(
            r["to_concept"] for r in conn.execute(
                "SELECT to_concept FROM concept_edges WHERE from_concept=? AND relationship_type='prerequisite'",
                (node,),
            ).fetchall()
        )
    return False


def add_edge(conn, frm: str, to: str, rel: str, strength: float, notes: str = "") -> bool:
    if frm == to:
        return False
    if rel == "prerequisite" and _prereq_creates_cycle(conn, frm, to):
        return False
    conn.execute(
        """INSERT INTO concept_edges(from_concept, to_concept, relationship_type, strength, notes)
           VALUES (?,?,?,?,?)
           ON CONFLICT(from_concept, to_concept, relationship_type)
           DO UPDATE SET strength = excluded.strength""",
        (frm, to, rel, strength, notes),
    )
    return True


# ── builders ─────────────────────────────────────────────────────────────────────
def build_parent_child(conn, code_of) -> int:
    n = 0
    seen = set()
    for (path,) in conn.execute(
        "SELECT DISTINCT path FROM document_sections WHERE path LIKE '% > %'"
    ).fetchall():
        parts = [p.strip() for p in path.split(" > ") if p.strip()]
        for parent, child in zip(parts, parts[1:]):
            pc, cc = code_of(parent), code_of(child)
            if pc and cc and pc != cc and (pc, cc) not in seen:
                seen.add((pc, cc))
                if add_edge(conn, pc, cc, "parent_child", 1.0):
                    n += 1
    return n


def build_related(conn, by_title, pattern) -> int:
    counts: Dict[Tuple[str, str], int] = defaultdict(int)
    for (text,) in conn.execute("SELECT text FROM chunks").fetchall():
        found = sorted(mentions(text, by_title, pattern))
        for i in range(len(found)):
            for j in range(i + 1, len(found)):
                counts[(found[i], found[j])] += 1
    per_concept: Dict[str, int] = defaultdict(int)
    n = 0
    for (a, b), c in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0])):
        if c < MIN_COOCCUR:
            continue
        if per_concept[a] >= MAX_RELATED_PER_CONCEPT or per_concept[b] >= MAX_RELATED_PER_CONCEPT:
            continue
        if add_edge(conn, a, b, "related", float(c)):
            per_concept[a] += 1
            per_concept[b] += 1
            n += 1
    return n


def build_contrast_and_prereq(conn, code_of, by_title, pattern) -> Tuple[int, int]:
    confused = prereq = 0
    for (text,) in conn.execute("SELECT text FROM chunks").fetchall():
        for m in _CONTRAST.finditer(text):
            a, b = code_of(m.group(1)), code_of(m.group(2))
            if a and b and add_edge(conn, a, b, "confused_with", 1.0):
                confused += 1
        for m in _VERSUS.finditer(text):
            a, b = code_of(m.group(1)), code_of(m.group(2))
            if a and b and add_edge(conn, a, b, "confused_with", 1.0):
                confused += 1
        for target in mentions(text, by_title, pattern):
            for m in _PREREQ.finditer(text):
                src = code_of(m.group(1))
                if src and src != target and add_edge(conn, src, target, "prerequisite", 1.0):
                    prereq += 1
    return confused, prereq


def build_board_mappings(conn) -> int:
    n = 0
    for (code,) in conn.execute("SELECT concept_code FROM concepts").fetchall():
        conn.execute(
            """INSERT INTO concept_board_mappings(concept_code, board_code, exam_profile_code, chapter, topic, alignment)
               VALUES (?, 'FOUNDATION', 'jee_neet_foundation', '', '', 'exact')
               ON CONFLICT DO NOTHING""",
            (code,),
        )
        n += 1
    return n


def run(conn, force: bool = False) -> dict:
    # concepts are stored under subject-specific codes → resolve mentions by title.
    _cache: Dict[str, Optional[str]] = {}

    def code_of(title: str) -> Optional[str]:
        t = re.sub(r"\s+", " ", title).strip()
        if not t:
            return None
        if t not in _cache:
            row = conn.execute(
                "SELECT concept_code FROM concepts WHERE title = ? COLLATE NOCASE", (t,)
            ).fetchone()
            _cache[t] = row["concept_code"] if row else None
        return _cache[t]

    with store.txn(conn):
        conn.execute("DELETE FROM concept_edges")
        conn.execute("DELETE FROM concept_board_mappings")
        by_title, pattern = concept_index(conn)
        pc = build_parent_child(conn, code_of)
        rel = build_related(conn, by_title, pattern)
        conf, pre = build_contrast_and_prereq(conn, code_of, by_title, pattern)
        boards = build_board_mappings(conn)
        ledger.record(conn, "__graph__", "graph", "done",
                      output_ref=f"pc={pc},related={rel},confused={conf},prereq={pre}")
    return {
        "parent_child": pc, "related": rel, "confused_with": conf, "prerequisite": pre,
        "board_mappings": boards,
        "edges_total": conn.execute("SELECT COUNT(*) n FROM concept_edges").fetchone()["n"],
    }
