"""Knowledge Layer — Phase 1: deterministic concept cleanup (at rest).

The certified KIE concept spine is noisy: OCR garbage ("ACENTHUSE"), textbook
boilerplate ("Acknowledgements", "Contents"), merged words ("Newton'sthird"),
broken capitalisation ("ACKNOWLEDGEMENTS"), and a few OCR-split duplicates
("PHY_NEWTON_S_SECOND_LAW" vs "PHY_NEWTON_SSECOND_LAW"). The frozen QP engine
already defends itself at query time, but the STORED knowledge stays dirty, which
pollutes enrichment (Phase 2) and the graph/taxonomy (Phase 3).

This pass cleans the `concepts` table IN PLACE using the SAME deterministic
functions the engine uses at runtime (`qpgen.sanitize`, `qpgen.chapters`):

  1. normalize_titles  — repair OCR/extraction artefacts to the engine's own
                         fixed point (idempotent: normalize(normalize(t)) == t).
  2. reject_noise      — a concept the engine can never use (is_clean_concept is
                         False) is marked status='rejected'. The engine ALREADY
                         drops these at runtime, so generation output is unchanged
                         (ZERO regression); the knowledge layer is now honest.
  3. merge_duplicates  — concepts with the same normalized title + subject are
                         OCR splits of one concept; the strongest is kept canonical
                         and every dependent row (patterns / formulas / edges /
                         families / templates / distractors / mappings) is
                         re-pointed to it, so no evidence is lost.
  4. map_chapters      — each surviving concept's canonical syllabus chapter
                         (chapters.resolve_chapter — the engine's own resolver) is
                         written to concept_board_mappings.chapter.

No AI. No fabrication. Fully idempotent and recovery-safe — re-running is a no-op.
It NEVER edits `qpgen` (the frozen engine); it only imports its pure helpers.
"""
from __future__ import annotations

import json
import re
from typing import Dict, List, Optional, Tuple

from kie import ledger, store
from kie.qpgen import chapters, sanitize

CLEANUP_STAGE = "cleanup"
CLEANUP_DOC = "__knowledge__"

# Concept-code prefix (kie.phase5_concept.SUBJ3) → subject_domain, for chapter mapping
# of concepts whose subject_domain is NULL (a handful of early-extraction rows).
_PREFIX_SUBJECT = {"PHY": "Physics", "CHE": "Chemistry", "MAT": "Mathematics", "BIO": "Biology"}

# Dependent tables that reference concepts(concept_code); a merged concept's rows
# are re-pointed to the canonical code across ALL of them so evidence survives.
# (table, single-column) — concept_edges has two columns and is handled separately.
_DEP_SINGLE_COL = (
    ("question_patterns", "concept_code"),
    ("question_families", "concept_code"),
    ("question_templates", "concept_code"),
    ("distractors", "concept_code"),
    ("formulas", "concept_code"),
    ("generated_items", "concept_code"),
    ("concept_board_mappings", "concept_code"),
)

# ── reason labelling (audit metadata only; the AUTHORITATIVE reject decision is
#    the engine's own sanitize.is_clean_concept, so labels can never diverge from it) ──
_RE_ACTIVITY = re.compile(r"\bactivity\b|\bexample\b|\bexercise\b|\d+\.\d+", re.I)
_RE_PEDAGOGY = re.compile(
    r"let us |think, discuss|try these|pause and ponder|probe and ponder|"
    r"threads of curiosity|step further|be a scientist|scientific heritage|"
    r"bridging science|just for fun|did you know|points to remember|test yourself",
    re.I,
)
_BOILERPLATE_WORDS = {
    "introduction", "contents", "content", "preface", "index", "summary", "glossary",
    "acknowledgement", "acknowledgements", "appendix", "keywords", "objectives",
    "references", "reference", "recap", "revision", "answers", "answer", "solutions",
    "solution", "questions",
}


def _reject_reason(title: str) -> str:
    """Best-effort deterministic label for WHY a title is not a usable concept.
    Metadata only — reject/keep is decided solely by sanitize.is_clean_concept."""
    t = title.strip()
    low = t.lower()
    if sanitize._looks_like_ocr_garbage(t):          # OCR scramble / consonant run / no-vowel
        return "ocr_garbage"
    if low in _BOILERPLATE_WORDS or "rationalisation of content" in low or \
            low.startswith("textbook for") or "note to the" in low:
        return "boilerplate"
    if _RE_PEDAGOGY.search(low):
        return "pedagogy_scaffold"
    if _RE_ACTIVITY.search(low):
        return "activity_or_example"
    words = re.findall(r"[A-Za-z][A-Za-z'\-]*", t)
    if len(words) > sanitize.MAX_WORDS:
        return "too_long"
    return "sentence_fragment"


# ── json evidence helpers ─────────────────────────────────────────────────────────
def _load_evidence(raw: Optional[str]) -> dict:
    if not raw:
        return {}
    try:
        val = json.loads(raw)
        return val if isinstance(val, dict) else {"_prev": val}
    except (ValueError, TypeError):
        return {}


def _stamp(conn, code: str, patch: dict) -> None:
    row = conn.execute("SELECT evidence FROM concepts WHERE concept_code=?", (code,)).fetchone()
    ev = _load_evidence(row["evidence"] if row else None)
    ev["cleanup"] = {**ev.get("cleanup", {}), **patch}
    conn.execute("UPDATE concepts SET evidence=? WHERE concept_code=?",
                 (json.dumps(ev, sort_keys=True), code))


def _subject_of(code: str, subject_domain: Optional[str]) -> Optional[str]:
    if subject_domain:
        return subject_domain
    return _PREFIX_SUBJECT.get(code.split("_", 1)[0])


# ── pass 1: title normalization ───────────────────────────────────────────────────
def normalize_titles(conn) -> int:
    changed = 0
    for r in conn.execute(
        "SELECT concept_code, title FROM concepts WHERE status='active'"
    ).fetchall():
        norm = sanitize.normalize_concept_title(r["title"])
        if norm and norm != r["title"]:
            conn.execute("UPDATE concepts SET title=? WHERE concept_code=?",
                         (norm, r["concept_code"]))
            changed += 1
    return changed


# ── pass 2: reject non-concepts (engine already drops these at runtime) ────────────
def reject_noise(conn) -> Dict[str, int]:
    reasons: Dict[str, int] = {}
    for r in conn.execute(
        "SELECT concept_code, title FROM concepts WHERE status='active'"
    ).fetchall():
        title = sanitize.normalize_concept_title(r["title"])
        if sanitize.is_clean_concept(title):
            continue
        reason = _reject_reason(title)
        conn.execute("UPDATE concepts SET status='rejected' WHERE concept_code=?",
                     (r["concept_code"],))
        _stamp(conn, r["concept_code"], {"action": "rejected", "reason": reason})
        reasons[reason] = reasons.get(reason, 0) + 1
    return reasons


# ── pass 3: merge OCR-split duplicates ─────────────────────────────────────────────
def _evidence_strength(conn, code: str) -> Tuple[int, int, int]:
    """(pattern_frequency, formula_count, has_definition) — for canonical selection."""
    freq = conn.execute(
        "SELECT COALESCE(SUM(frequency),0) f FROM question_patterns WHERE concept_code=?",
        (code,),
    ).fetchone()["f"]
    formulas = conn.execute(
        "SELECT COUNT(*) n FROM formulas WHERE concept_code=?", (code,)
    ).fetchone()["n"]
    row = conn.execute("SELECT definition FROM concepts WHERE concept_code=?", (code,)).fetchone()
    has_def = 1 if (row and (row["definition"] or "").strip()) else 0
    return int(freq or 0), int(formulas or 0), has_def


def _repoint(conn, table: str, col: str, loser: str, canon: str) -> None:
    # move rows to the canonical code where the destination row does not already
    # exist (OR IGNORE skips PK/unique/CHECK collisions), then drop any leftovers
    # that could not move because the canonical already carries the equivalent row.
    conn.execute(f"UPDATE OR IGNORE {table} SET {col}=? WHERE {col}=?", (canon, loser))
    conn.execute(f"DELETE FROM {table} WHERE {col}=?", (loser,))


def merge_duplicates(conn) -> Dict[str, int]:
    groups: Dict[Tuple[Optional[str], str], List[str]] = {}
    for r in conn.execute(
        "SELECT concept_code, title, subject_domain FROM concepts WHERE status='active'"
    ).fetchall():
        title = sanitize.normalize_concept_title(r["title"])
        key = (r["subject_domain"], title.casefold())
        groups.setdefault(key, []).append(r["concept_code"])

    merged = 0
    groups_merged = 0
    for (_subject, _title), codes in groups.items():
        if len(codes) < 2:
            continue
        # canonical = strongest evidence; deterministic tie-break on concept_code.
        canon = sorted(codes, key=lambda c: (*(-x for x in _evidence_strength(conn, c)), c))[0]
        groups_merged += 1
        for loser in codes:
            if loser == canon:
                continue
            for table, col in _DEP_SINGLE_COL:
                _repoint(conn, table, col, loser, canon)
            _repoint(conn, "concept_edges", "from_concept", loser, canon)
            _repoint(conn, "concept_edges", "to_concept", loser, canon)
            conn.execute("DELETE FROM concept_edges WHERE from_concept = to_concept")
            conn.execute(
                "UPDATE concepts SET status='merged', merged_into=? WHERE concept_code=?",
                (canon, loser),
            )
            _stamp(conn, loser, {"action": "merged", "into": canon})
            merged += 1
    return {"groups": groups_merged, "concepts_merged": merged}


# ── pass 4: canonical chapter mapping ──────────────────────────────────────────────
def map_chapters(conn) -> int:
    n = 0
    for r in conn.execute(
        "SELECT concept_code, title, subject_domain FROM concepts WHERE status='active'"
    ).fetchall():
        subject = _subject_of(r["concept_code"], r["subject_domain"])
        chapter = chapters.resolve_chapter(subject, r["title"])
        # PK includes `chapter`, so replace the blank-chapter foundation row with the
        # resolved one (idempotent — re-running leaves the resolved row untouched).
        conn.execute(
            "DELETE FROM concept_board_mappings "
            "WHERE concept_code=? AND board_code='FOUNDATION' "
            "AND exam_profile_code='jee_neet_foundation' AND chapter='' AND topic=''",
            (r["concept_code"],),
        )
        conn.execute(
            "INSERT INTO concept_board_mappings"
            "(concept_code, board_code, exam_profile_code, chapter, topic, alignment) "
            "VALUES (?, 'FOUNDATION', 'jee_neet_foundation', ?, '', 'exact') "
            "ON CONFLICT DO NOTHING",
            (r["concept_code"], chapter),
        )
        n += 1
    return n


# ── orchestration ──────────────────────────────────────────────────────────────────
def run(conn, dry_run: bool = False) -> dict:
    """Run the full deterministic cleanup in one transaction.

    dry_run=True computes the same summary but rolls back (no writes persist),
    so operators can preview the impact before applying it.
    """
    before = _snapshot(conn)
    try:
        normalized = normalize_titles(conn)
        rejected = reject_noise(conn)
        merged = merge_duplicates(conn)
        chapters_mapped = map_chapters(conn)
        summary = {
            "titles_normalized": normalized,
            "rejected": sum(rejected.values()),
            "rejected_by_reason": rejected,
            "duplicate_groups_merged": merged["groups"],
            "concepts_merged": merged["concepts_merged"],
            "chapters_mapped": chapters_mapped,
            "before": before,
            "after": _snapshot(conn),
        }
        if dry_run:
            conn.rollback()
            summary["dry_run"] = True
            return summary
        ledger.record(conn, CLEANUP_DOC, CLEANUP_STAGE, "done",
                      output_ref=json.dumps({k: summary[k] for k in (
                          "titles_normalized", "rejected", "duplicate_groups_merged",
                          "concepts_merged", "chapters_mapped")}, sort_keys=True))
        conn.commit()
        return summary
    except Exception:
        conn.rollback()
        raise


def _snapshot(conn) -> dict:
    return {
        "concepts_active": conn.execute(
            "SELECT COUNT(*) n FROM concepts WHERE status='active'").fetchone()["n"],
        "concepts_rejected": conn.execute(
            "SELECT COUNT(*) n FROM concepts WHERE status='rejected'").fetchone()["n"],
        "concepts_merged": conn.execute(
            "SELECT COUNT(*) n FROM concepts WHERE status='merged'").fetchone()["n"],
        "chapters_set": conn.execute(
            "SELECT COUNT(*) n FROM concept_board_mappings WHERE chapter <> ''").fetchone()["n"],
    }


def main(argv=None) -> int:
    import argparse

    ap = argparse.ArgumentParser(prog="kie.knowledge.cleanup",
                                 description="Phase 1 — deterministic concept cleanup")
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
