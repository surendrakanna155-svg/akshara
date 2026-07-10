"""Knowledge Layer — Phase 3: KIE quality (extraction, relationships, graph, taxonomy, evidence).

Builds on the cleaned + enriched spine. Deterministic, idempotent, engine-frozen:

  1. extend_rejection   — reject residual NON-concepts the engine's own filter misses but
                          that carry evidence and would otherwise become junk questions:
                          exam/publication boilerplate ('Test Booklet Code', 'Members',
                          'Foreword') and clause fragments ('and Life', 'IN TWO Variables').
                          This improves concept-extraction + generated-question quality.
  2. fuzzy_merge        — merge same-subject concepts whose titles are the same up to
                          apostrophe / case / word-order ("Huygen's principle" == "Huygens
                          Principle"), re-pointing evidence (reuses the Phase-1 merge engine).
  3. rebuild_graph      — rebuild concept_edges over the ACTIVE, cleaned concept set only
                          (the original graph was built pre-cleanup and ~1/3 of its edges
                          touch now-rejected noise). Reuses the frozen phase6 builders with an
                          active-only, title-normalized index.
  4. map_chapters       — write the richer knowledge-layer chapter (curate.taxonomy, a strict
                          superset of the engine's) into concept_board_mappings.chapter.
  5. strengthen_evidence — record copyright-SAFE provenance counts on each concept
                          (pattern/formula/chunk-mention/doc counts — NEVER source text).

The certified engine (kie.qpgen) is never edited; it only benefits from cleaner data. No AI,
no fabrication. Reuses kie.curate.cleanup, kie.phase6_graph, kie.curate.taxonomy.
"""
from __future__ import annotations

import json
import re
from typing import Dict, List, Optional, Tuple

from kie import ledger, phase6_graph as p6, store
from kie.curate import cleanup, taxonomy
from kie.qpgen import sanitize

QUALITY_STAGE = "quality"
QUALITY_DOC = "__knowledge__"

# ── residual non-concept vocabulary (evidence-bearing junk the engine filter misses) ──
_NOISE_PHRASES = (
    "important instruction", "test booklet", "question booklet", "instructions to",
    "time allowed", "maximum marks", "roll number", "omr sheet", "answer sheet",
    "seating plan", "hall ticket", "examination centre", "do not open",
    "foreword", "textbook development", "development committee", "development team",
    "reprint", "national council", "publication division", "printed at", "chief advisor",
    "chief editor", "co-ordinator", "coordinator committee", "convener", "syllabus committee",
    "rationalisation of content", "note to the",
)
_NOISE_EXACT = {
    "members", "member", "understanding", "introduction", "conclusion", "overview",
    "preliminaries", "acknowledgement", "acknowledgements", "contents", "index",
    "answers", "solutions", "appendix", "references",
}
_CONJUNCTIONS = {"and", "or", "but", "nor", "so", "yet"}
_PREPOSITIONS = {"of", "to", "in", "for", "with", "by", "as", "from", "at", "on",
                 "into", "onto", "upon", "about", "over", "under"}
_ARTICLES = {"the", "a", "an"}
# A title starting with an UNAMBIGUOUS finite verb is a subject-less clause fragment
# ("Follows Zaitsev rule"). Deliberately excludes verbs that are also common nouns/gerunds
# ("states" in "States of Matter", "uses", "means", "find", "using") to avoid false positives.
_LEAD_VERBS = {
    "follows", "shows", "gives", "makes", "causes", "requires", "depends", "occurs",
    "consists", "represents", "describes", "explains", "denotes", "involves", "implies",
    "yields", "produces", "becomes", "remains", "contains", "exhibits", "undergoes", "obeys",
}


def _is_fragment(title: str) -> bool:
    toks = title.split()
    if not toks:
        return True
    first = toks[0]
    fl = first.lower().strip(".,;:'\"")
    if fl in _CONJUNCTIONS or fl in _PREPOSITIONS:      # "and Life", "IN TWO Variables", "To check"
        return True
    if fl in _LEAD_VERBS:                                # "Follows Zaitsev rule" — subject-less clause
        return True
    if fl in _ARTICLES and first[:1].islower():         # lowercase leading article = mid-sentence cut
        return True
    return False


def _is_residual_noise(title: str) -> bool:
    low = title.strip().lower()
    if low in _NOISE_EXACT:
        return True
    if any(p in low for p in _NOISE_PHRASES):
        return True
    return _is_fragment(title)


def extend_rejection(conn) -> Dict[str, int]:
    reasons: Dict[str, int] = {}
    for r in conn.execute(
        "SELECT concept_code, title FROM concepts WHERE status='active'"
    ).fetchall():
        title = r["title"] or ""
        if not _is_residual_noise(title):
            continue
        low = title.strip().lower()
        reason = ("boilerplate" if (low in _NOISE_EXACT or any(p in low for p in _NOISE_PHRASES))
                  else "fragment")
        conn.execute("UPDATE concepts SET status='rejected' WHERE concept_code=?",
                     (r["concept_code"],))
        cleanup._stamp(conn, r["concept_code"], {"action": "rejected", "reason": "residual_" + reason})
        reasons[reason] = reasons.get(reason, 0) + 1
    return reasons


# ── subject reassignment for mis-tagged named laws (fixes a syllabus-boundary leak) ──
# UNAMBIGUOUS single-subject law names only. Each maps to exactly one subject, and we
# require the title to also say "law"/"laws" so a bare surname (e.g. the biologist Hooke)
# is never moved. Deliberately EXCLUDES ambiguous names: 'faraday' (electrolysis = Chemistry),
# 'henry' (the unit vs Henry's law), 'gauss' (physics vs maths), 'kirchhoff' (circuits vs
# thermochemistry) — those may legitimately sit in another subject.
_LAW_SUBJECT = {
    "newton": "Physics", "ohm": "Physics", "coulomb": "Physics", "lenz": "Physics",
    "ampere": "Physics", "kepler": "Physics", "lorentz": "Physics", "biot": "Physics",
    "hooke": "Physics", "bernoulli": "Physics", "torricelli": "Physics",
    "markovnikov": "Chemistry", "saytzeff": "Chemistry", "zaitsev": "Chemistry",
    "raoult": "Chemistry", "le chatelier": "Chemistry",
    "mendel": "Biology",
}


def reassign_subject(conn) -> Dict[str, int]:
    """Move a concept whose title is an UNAMBIGUOUS named law to that law's real subject,
    so e.g. 'Ohm's law' cannot leak into a Chemistry-only paper. Conservative + deterministic."""
    moved: Dict[str, int] = {}
    for r in conn.execute(
        "SELECT concept_code, title, subject_domain FROM concepts WHERE status='active'"
    ).fetchall():
        low = (r["title"] or "").lower()
        if "law" not in low:
            continue
        target = next((subj for key, subj in _LAW_SUBJECT.items() if key in low), None)
        if target and r["subject_domain"] != target:
            conn.execute("UPDATE concepts SET subject_domain=? WHERE concept_code=?",
                         (target, r["concept_code"]))
            cleanup._stamp(conn, r["concept_code"],
                           {"action": "resubject", "from": r["subject_domain"], "to": target})
            moved[target] = moved.get(target, 0) + 1
    return moved


# ── fuzzy duplicate merge (apostrophe / case / word-order) ──────────────────────────
_STOP_TOKENS = {"the", "a", "an", "of", "s", "and", "in", "to", "for"}


def _canon_key(title: str) -> str:
    t = re.sub(r"[^a-z0-9 ]", " ", title.lower())
    toks = [w for w in t.split() if w and w not in _STOP_TOKENS]
    return " ".join(sorted(toks))


def fuzzy_merge(conn) -> Dict[str, int]:
    groups: Dict[Tuple[Optional[str], str], List[str]] = {}
    for r in conn.execute(
        "SELECT concept_code, title, subject_domain FROM concepts WHERE status='active'"
    ).fetchall():
        key = _canon_key(sanitize.normalize_concept_title(r["title"]))
        if not key:
            continue
        groups.setdefault((r["subject_domain"], key), []).append(r["concept_code"])

    merged = groups_merged = 0
    for (_subject, _key), codes in groups.items():
        if len(codes) < 2:
            continue
        canon = sorted(codes, key=lambda c: (*(-x for x in cleanup._evidence_strength(conn, c)), c))[0]
        groups_merged += 1
        for loser in codes:
            if loser == canon:
                continue
            for table, col in cleanup._DEP_SINGLE_COL:
                cleanup._repoint(conn, table, col, loser, canon)
            cleanup._repoint(conn, "concept_edges", "from_concept", loser, canon)
            cleanup._repoint(conn, "concept_edges", "to_concept", loser, canon)
            conn.execute("DELETE FROM concept_edges WHERE from_concept = to_concept")
            conn.execute("UPDATE concepts SET status='merged', merged_into=? WHERE concept_code=?",
                         (canon, loser))
            cleanup._stamp(conn, loser, {"action": "merged", "into": canon, "method": "fuzzy"})
            merged += 1
    return {"groups": groups_merged, "concepts_merged": merged}


# ── graph rebuild over the ACTIVE concept set (reuse frozen phase6 builders) ─────────
def _active_index(conn):
    """phase6.concept_index restricted to active concepts, matching on NORMALIZED titles."""
    by_title: Dict[str, str] = {}
    titles: List[str] = []
    for r in conn.execute("SELECT concept_code, title FROM concepts WHERE status='active'").fetchall():
        t = sanitize.normalize_concept_title(r["title"]).strip()
        if len(t) >= 5 and t.lower() not in by_title:
            by_title[t.lower()] = r["concept_code"]
            titles.append(t)
    if not titles:
        return {}, re.compile(r"(?!x)x")
    titles.sort(key=len, reverse=True)
    pattern = re.compile(r"\b(" + "|".join(re.escape(t) for t in titles) + r")\b", re.I)
    return by_title, pattern


def rebuild_graph(conn) -> Dict[str, int]:
    _cache: Dict[str, Optional[str]] = {}

    def code_of(title: str) -> Optional[str]:
        t = sanitize.normalize_concept_title(re.sub(r"\s+", " ", title).strip())
        if not t:
            return None
        if t not in _cache:
            row = conn.execute(
                "SELECT concept_code FROM concepts WHERE title = ? COLLATE NOCASE AND status='active'",
                (t,),
            ).fetchone()
            _cache[t] = row["concept_code"] if row else None
        return _cache[t]

    conn.execute("DELETE FROM concept_edges")
    by_title, pattern = _active_index(conn)
    pc = p6.build_parent_child(conn, code_of)
    rel = p6.build_related(conn, by_title, pattern)
    conf, pre = p6.build_contrast_and_prereq(conn, code_of, by_title, pattern)
    return {"parent_child": pc, "related": rel, "confused_with": conf, "prerequisite": pre,
            "edges_total": conn.execute("SELECT COUNT(*) n FROM concept_edges").fetchone()["n"]}


# ── richer chapter mapping (knowledge-layer taxonomy; engine untouched) ─────────────
def map_chapters(conn) -> int:
    n = 0
    for r in conn.execute(
        "SELECT concept_code, title, subject_domain FROM concepts WHERE status='active'"
    ).fetchall():
        subject = r["subject_domain"] or cleanup._PREFIX_SUBJECT.get(r["concept_code"].split("_", 1)[0])
        chapter = taxonomy.resolve_chapter(subject, r["title"])
        conn.execute(
            "DELETE FROM concept_board_mappings WHERE concept_code=? AND board_code='FOUNDATION' "
            "AND exam_profile_code='jee_neet_foundation' AND topic=''",
            (r["concept_code"],),
        )
        conn.execute(
            "INSERT INTO concept_board_mappings"
            "(concept_code, board_code, exam_profile_code, chapter, topic, alignment) "
            "VALUES (?, 'FOUNDATION', 'jee_neet_foundation', ?, '', 'exact') ON CONFLICT DO NOTHING",
            (r["concept_code"], chapter),
        )
        n += 1
    return n


# ── copyright-safe evidence strengthening ───────────────────────────────────────────
def strengthen_evidence(conn) -> int:
    freq = {r["concept_code"]: (r["n"], r["f"]) for r in conn.execute(
        "SELECT concept_code, COUNT(*) n, COALESCE(SUM(frequency),0) f FROM question_patterns "
        "WHERE concept_code IS NOT NULL GROUP BY concept_code")}
    formulas = {r["concept_code"]: r["n"] for r in conn.execute(
        "SELECT concept_code, COUNT(*) n FROM formulas WHERE concept_code IS NOT NULL GROUP BY concept_code")}
    n = 0
    for r in conn.execute("SELECT concept_code, title, evidence FROM concepts WHERE status='active'").fetchall():
        code = r["concept_code"]
        pats = freq.get(code, (0, 0))
        try:
            mentions = conn.execute(
                "SELECT COUNT(*) n FROM chunks c JOIN chunks_fts f ON f.rowid=c.rowid "
                "WHERE chunks_fts MATCH ?", (f'"{r["title"]}"',)).fetchone()["n"]
        except Exception:
            mentions = 0
        prov = {"pattern_rows": pats[0], "pattern_frequency": pats[1],
                "formula_count": formulas.get(code, 0), "chunk_mentions": mentions}
        ev = cleanup._load_evidence(r["evidence"])
        ev["provenance"] = prov                              # counts/ids only — NO source text
        conn.execute("UPDATE concepts SET evidence=? WHERE concept_code=?",
                     (json.dumps(ev, sort_keys=True), code))
        n += 1
    return n


# ── orchestration ──────────────────────────────────────────────────────────────────
def run(conn, dry_run: bool = False) -> dict:
    before = _snapshot(conn)
    try:
        rejected = extend_rejection(conn)
        resubjected = reassign_subject(conn)
        merged = fuzzy_merge(conn)
        graph = rebuild_graph(conn)
        chapters_mapped = map_chapters(conn)
        evidence = strengthen_evidence(conn)
        summary = {
            "rejected": sum(rejected.values()), "rejected_by_reason": rejected,
            "resubjected": sum(resubjected.values()), "resubjected_by_subject": resubjected,
            "fuzzy_groups_merged": merged["groups"], "concepts_merged": merged["concepts_merged"],
            "graph": graph, "chapters_mapped": chapters_mapped, "evidence_strengthened": evidence,
            "before": before, "after": _snapshot(conn),
        }
        if dry_run:
            conn.rollback()
            summary["dry_run"] = True
            return summary
        ledger.record(conn, QUALITY_DOC, QUALITY_STAGE, "done",
                      output_ref=json.dumps({"rejected": sum(rejected.values()),
                                             "merged": merged["concepts_merged"], **graph},
                                            sort_keys=True))
        conn.commit()
        return summary
    except Exception:
        conn.rollback()
        raise


def _snapshot(conn) -> dict:
    q = lambda w: conn.execute(f"SELECT COUNT(*) n FROM {w}").fetchone()["n"]
    return {
        "concepts_active": q("concepts WHERE status='active'"),
        "concepts_rejected": q("concepts WHERE status='rejected'"),
        "concepts_merged": q("concepts WHERE status='merged'"),
        "edges_total": q("concept_edges"),
        "edges_to_noise": conn.execute(
            "SELECT COUNT(*) n FROM concept_edges e WHERE "
            "e.from_concept NOT IN (SELECT concept_code FROM concepts WHERE status='active') "
            "OR e.to_concept NOT IN (SELECT concept_code FROM concepts WHERE status='active')"
        ).fetchone()["n"],
        "chapters_general": conn.execute(
            "SELECT COUNT(*) n FROM concept_board_mappings WHERE chapter LIKE 'General%'").fetchone()["n"],
        "chapters_specific": conn.execute(
            "SELECT COUNT(*) n FROM concept_board_mappings WHERE chapter<>'' AND chapter NOT LIKE 'General%'").fetchone()["n"],
    }


def main(argv=None) -> int:
    import argparse

    ap = argparse.ArgumentParser(prog="kie.curate.quality",
                                 description="Phase 3 — KIE quality (graph/taxonomy/evidence)")
    ap.add_argument("--db", default=None, help="SQLite store path (default: knowledge/kie/kie.db)")
    ap.add_argument("--dry-run", action="store_true", help="preview impact; write nothing")
    args = ap.parse_args(argv)

    conn = store.open_store(args.db)
    try:
        summary = run(conn, dry_run=args.dry_run)
    finally:
        conn.close()
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    import sys
    sys.exit(main())
