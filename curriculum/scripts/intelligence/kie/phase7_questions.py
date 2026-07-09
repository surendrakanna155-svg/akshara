"""Phase 7 — Question Intelligence. Deterministic PYQ pattern mining (analysis-only).

From previous-year-question chunks this derives, with NO AI and NO verbatim
copying (D8 / Rule 7 — PYQs are L2 analysis-only reference):
  * question TYPE (mcq / numerical / assertion_reason / match / short_answer);
  * BLOOM level (verb signatures) and DIFFICULTY (deterministic heuristic);
  * CONCEPT linkage (mentions of Phase-5 concepts);
  * TRENDS — frequency + year distribution per (concept, type, bloom, difficulty).

It stores only STRUCTURE (a de-identified skeleton + counts), never the original
question text, and rolls concepts up into draft question_families — the seeds the
(gated) Phase-8 authoring / deterministic instantiation will turn into unlimited
ORIGINAL questions. Families are drafts; nothing is certified here (D-6).
"""
from __future__ import annotations

import hashlib
import json
import re
from collections import defaultdict
from typing import Dict, List, Optional, Set, Tuple

from kie import config, ledger, phase6_graph, store

_OPT = re.compile(r"\(([A-Da-d1-4])\)")
_ASSERTION = re.compile(r"\bassertion\b", re.I)
_REASON = re.compile(r"\breason\b", re.I)
_MATCH = re.compile(r"match the following|column\s+I\b|column\s+II\b", re.I)
_NUMERIC = re.compile(r"\b(value of|calculate|evaluate|find the value|integer|correct to)\b", re.I)

BLOOM_VERBS: Dict[str, Tuple[str, ...]] = {
    "remember": ("define", "state", "name", "list", "identify", "recall", "what is", "label"),
    "understand": ("explain", "describe", "classify", "summarize", "interpret", "why", "discuss"),
    "apply": ("calculate", "find", "compute", "solve", "determine", "apply", "use"),
    "analyze": ("compare", "contrast", "analyze", "differentiate", "distinguish", "deduce", "relate"),
    "hots": ("derive", "design", "formulate", "prove", "construct", "evaluate", "justify"),
}
BLOOM_ORDER = ("remember", "understand", "apply", "analyze", "hots")
_HARD = ("derive", "prove", "hence show", "hence prove", "integrate", "differentiate", "hots")
_EASY = ("define", "state", "name", "list", "what is", "identify")


def is_question(text: str) -> bool:
    return (
        len({m.group(1).upper() for m in _OPT.finditer(text)}) >= 2
        or "?" in text
        or (_ASSERTION.search(text) and _REASON.search(text))
        or bool(_MATCH.search(text))
    )


def classify_type(text: str) -> str:
    if _ASSERTION.search(text) and _REASON.search(text):
        return "assertion_reason"
    if _MATCH.search(text):
        return "match"
    opts = {m.group(1).upper() for m in _OPT.finditer(text)}
    opts = {o for o in opts if o in "ABCD1234"}
    if len(opts) >= 3:
        return "mcq"
    if _NUMERIC.search(text):
        return "numerical"
    return "short_answer"


def estimate_bloom(text: str) -> str:
    tl = text.lower()
    best = "understand"
    for level in BLOOM_ORDER:
        if any(re.search(r"\b" + re.escape(v) + r"\b", tl) for v in BLOOM_VERBS[level]):
            best = level
    return best


def estimate_difficulty(text: str) -> str:
    tl = text.lower()
    if any(w in tl for w in _HARD) or len(text) > 600:
        return "hard"
    if any(w in tl for w in _EASY) and len(text) < 300:
        return "easy"
    return "medium"


def option_count(text: str) -> int:
    return len({m.group(1).upper() for m in _OPT.finditer(text) if m.group(1).upper() in "ABCD1234"})


def _pattern_id(concept: str, qtype: str, bloom: str, difficulty: str) -> str:
    return "QP_" + hashlib.sha256(f"{concept}|{qtype}|{bloom}|{difficulty}".encode()).hexdigest()[:16]


def run(conn, force: bool = False) -> dict:
    by_title, pattern = phase6_graph.concept_index(conn)
    # (concept, type, bloom, difficulty) -> {freq, years:set, opts:max}
    agg: Dict[Tuple[str, str, str, str], dict] = defaultdict(lambda: {"freq": 0, "years": set(), "opts": 0})
    questions = 0

    rows = conn.execute(
        "SELECT c.text, s.year FROM chunks c JOIN source_documents s ON s.doc_id = c.doc_id "
        "WHERE s.certify_status = 'certified'"
    ).fetchall()
    for r in rows:
        text = r["text"]
        if not is_question(text):
            continue
        questions += 1
        qtype = classify_type(text)
        bloom = estimate_bloom(text)
        diff = estimate_difficulty(text)
        opts = option_count(text)
        concepts = phase6_graph.mentions(text, by_title, pattern) or {"__unmapped__"}
        for concept in concepts:
            a = agg[(concept, qtype, bloom, diff)]
            a["freq"] += 1
            if r["year"]:
                a["years"].add(int(r["year"]))
            a["opts"] = max(a["opts"], opts)

    with store.txn(conn):
        for tbl in ("distractors", "question_templates", "question_families", "question_patterns"):
            conn.execute(f"DELETE FROM {tbl}")
        concept_types: Dict[str, Set[str]] = defaultdict(set)
        for (concept, qtype, bloom, diff), a in sorted(agg.items()):
            years = sorted(a["years"])
            skeleton = f"{qtype}|bloom={bloom}|difficulty={diff}|options={a['opts']}"  # structure only, no source text
            concept_ref = None if concept == "__unmapped__" else concept
            conn.execute(
                """INSERT INTO question_patterns(pattern_id, concept_code, exam, subject, question_type,
                       bloom, difficulty, stem_skeleton, frequency, years, evidence)
                   VALUES (?,?,?,?,?,?,?,?,?,?,?)""",
                (_pattern_id(concept, qtype, bloom, diff), concept_ref, "foundation", None, qtype,
                 bloom, diff, skeleton, a["freq"], json.dumps(years), json.dumps({"analysis": "pyq_pattern"})),
            )
            if concept_ref:
                concept_types[concept_ref].add(qtype)

        # draft families per (concept, dominant question-type) — seeds for Phase 8
        for concept, types in sorted(concept_types.items()):
            title = conn.execute("SELECT title FROM concepts WHERE concept_code=?", (concept,)).fetchone()
            tname = title["title"] if title else concept
            for qtype in sorted(types):
                fcode = f"FAM_{concept}_{qtype}".upper()
                conn.execute(
                    """INSERT INTO question_families(family_code, concept_code, title, description, status, created_at)
                       VALUES (?,?,?,?, 'draft', datetime('now'))
                       ON CONFLICT(family_code) DO NOTHING""",
                    (fcode, concept, f"{tname} — {qtype}", "PYQ-derived draft family (analysis-only, original)"),
                )
        ledger.record(conn, "__questions__", "questions", "done",
                      output_ref=f"patterns={len(agg)},questions={questions}")

    return {
        "questions_detected": questions,
        "patterns": conn.execute("SELECT COUNT(*) n FROM question_patterns").fetchone()["n"],
        "families": conn.execute("SELECT COUNT(*) n FROM question_families").fetchone()["n"],
        "mapped_patterns": conn.execute(
            "SELECT COUNT(*) n FROM question_patterns WHERE concept_code IS NOT NULL"
        ).fetchone()["n"],
    }


def type_distribution(conn) -> Dict[str, int]:
    return {r["question_type"]: r["n"] for r in conn.execute(
        "SELECT question_type, SUM(frequency) n FROM question_patterns GROUP BY question_type ORDER BY n DESC"
    ).fetchall()}
