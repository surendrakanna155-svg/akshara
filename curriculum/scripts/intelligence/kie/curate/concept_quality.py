"""Knowledge Layer — Phase 6: residual concept-quality repair (at rest).

Phase-1 `cleanup` rejects exactly what the frozen engine's runtime sanitizer
(`qpgen.sanitize.is_clean_concept`) already drops — a deliberate zero-regression
invariant. That leaves a residue of titles that ARE clean tokens yet are NOT
teachable concepts, so they get selected as question topics and produce output
like "Explain litres." or "Define Ohmwas led to his law." (see the 2026-07-11
output-quality audit).

This ADDITIVE pass raises quality beyond the runtime sanitizer, using ONLY
high-precision, individually-calibrated rules (verified against the live corpus to
reject true non-concepts and ZERO real concepts):

  1. reject_residual_noise — status='rejected' for:
       * publication / scaffolding names  ("Ganita Prakash", "Textbook for Class X",
         "Contents of Physics Part I", "Subject : Chemistry");
       * OCR-glued chapter headings       ("Animal Kingdomchapter 4");
       * clause / instruction extractions ("Coulomb discovered his law",
         "Verify the distributive law");
       * pedagogy scaffolds               ("Meet a Scientist", "Just for FUN");
       * a tight, hand-verified stoplist of bare generic non-concepts
         ("Curiosity", "Numbers", "litres", "minutes", ...).
  2. fix_subject_mislabels — reassign subject_domain for concepts whose title is
     unambiguously another subject ("Logarithms"/"Baye's theorem" tagged non-Math).

A rejected concept is skipped by the engine at query time (scope.py filters
status='active'), so it never reaches a paper. Nothing is fabricated or invented;
a rejected concept's evidence rows are left in place (recoverable). Deterministic,
idempotent, recovery-safe, and it NEVER edits `qpgen` (the frozen engine).
"""
from __future__ import annotations

import json
import re
from typing import Dict, Optional

from kie import ledger, store
from kie.qpgen import sanitize

STAGE = "concept_quality"
DOC = "__knowledge__"

# ── high-precision residual-noise rules (calibrated on the live corpus) ──────────────
# publication / textbook / scaffolding names — never a concept
_PUBLICATION = re.compile(
    r"\b(ganita|prakash|manjari)\b|\btextbook\b|\bfor (class|grade)\b|"
    r"^contents of\b|^subject\s*:|\bpart\s+[ivx]+$",
    re.I,
)
# OCR-glued chapter/exercise heading ("Animal Kingdomchapter 4", "... Exercise")
_GLUE_CAP = re.compile(r"[a-z][A-Z]")                       # case-SENSITIVE internal-cap glue
_GLUE_NUM = re.compile(r"(chapter|exercise)\s*\d|\b(chapter|exercise)$", re.I)
# a clause / instruction extraction (a sentence, not a noun-phrase concept)
_CLAUSE = re.compile(
    r"\b(discovered|formulated|invented|proposed|derived)\b|\bled to\b|"
    r"^verify\b|\bwhether the law\b",
    re.I,
)
# pedagogy / activity scaffolding phrasing
_SCAFFOLD = re.compile(
    r"meet (a|the) scientist|some basic concepts|just for fun|did you know|"
    r"\bconsiderations$|\bshortcuts$|\btricks$|in disguise$",
    re.I,
)
# bare generic words that are never a teachable science/math CONCEPT on their own.
# Tight + hand-verified: every entry was confirmed a non-concept in the live corpus.
_GENERIC_STOP = {
    "curiosity", "storage", "balance", "forests", "discussion", "multiply", "construct",
    "counting", "proportional", "equality", "numbers", "minutes", "litres", "litre", "metres",
    "seconds", "ratios", "combination", "operations", "collection", "arrangement",
    "objects", "things", "quantities", "story", "stories", "puzzle", "puzzles", "matter",
}


def noise_reason(title: str) -> Optional[str]:
    """Deterministic reason a CLEAN title is still not a usable concept, else None.
    High precision: returns non-None only for verified non-concept categories."""
    t = (title or "").strip()
    if not t:
        return None
    low = t.lower()
    if _PUBLICATION.search(t):
        return "publication_scaffold"
    if _GLUE_CAP.search(t) or _GLUE_NUM.search(t):
        return "ocr_glue"
    if _CLAUSE.search(t):
        return "clause_extraction"
    if _SCAFFOLD.search(t):
        return "pedagogy_scaffold"
    if low in _GENERIC_STOP:
        return "generic_noise"
    return None


# ── subject mislabels: title unambiguously belongs to another subject ────────────────
# conservative: only tokens with a single unambiguous home subject.
_SUBJECT_TOKENS = (
    (re.compile(r"\blogarithm|\bbaye'?s theorem\b|exponential notation", re.I), "Mathematics"),
)


def _stamp(conn, code: str, patch: dict) -> None:
    row = conn.execute("SELECT evidence FROM concepts WHERE concept_code=?", (code,)).fetchone()
    try:
        ev = json.loads(row["evidence"]) if row and row["evidence"] else {}
        if not isinstance(ev, dict):
            ev = {"_prev": ev}
    except (ValueError, TypeError):
        ev = {}
    ev["concept_quality"] = {**ev.get("concept_quality", {}), **patch}
    conn.execute("UPDATE concepts SET evidence=? WHERE concept_code=?",
                 (json.dumps(ev, sort_keys=True), code))


def reject_residual_noise(conn) -> Dict[str, int]:
    reasons: Dict[str, int] = {}
    for r in conn.execute(
        "SELECT concept_code, title FROM concepts WHERE status='active'"
    ).fetchall():
        title = sanitize.normalize_concept_title(r["title"])
        # only touch titles the engine itself considers CLEAN (else Phase-1 already handled them)
        if not sanitize.is_clean_concept(title):
            continue
        reason = noise_reason(title)
        if not reason:
            continue
        conn.execute("UPDATE concepts SET status='rejected' WHERE concept_code=?",
                     (r["concept_code"],))
        _stamp(conn, r["concept_code"], {"action": "rejected", "reason": reason})
        reasons[reason] = reasons.get(reason, 0) + 1
    return reasons


def fix_subject_mislabels(conn) -> int:
    fixed = 0
    for r in conn.execute(
        "SELECT concept_code, title, subject_domain FROM concepts WHERE status='active'"
    ).fetchall():
        title = sanitize.normalize_concept_title(r["title"])
        for rx, subject in _SUBJECT_TOKENS:
            if rx.search(title) and r["subject_domain"] != subject:
                conn.execute("UPDATE concepts SET subject_domain=? WHERE concept_code=?",
                             (subject, r["concept_code"]))
                _stamp(conn, r["concept_code"],
                       {"action": "resubject", "from": r["subject_domain"], "to": subject})
                fixed += 1
                break
    return fixed


def _snapshot(conn) -> dict:
    return {
        "active": conn.execute(
            "SELECT COUNT(*) n FROM concepts WHERE status='active'").fetchone()["n"],
        "rejected": conn.execute(
            "SELECT COUNT(*) n FROM concepts WHERE status='rejected'").fetchone()["n"],
    }


def run(conn, dry_run: bool = False) -> dict:
    before = _snapshot(conn)
    try:
        rejected = reject_residual_noise(conn)
        resubjected = fix_subject_mislabels(conn)
        summary = {
            "rejected": sum(rejected.values()),
            "rejected_by_reason": rejected,
            "subjects_fixed": resubjected,
            "before": before,
            "after": _snapshot(conn),
        }
        if dry_run:
            conn.rollback()
            summary["dry_run"] = True
            return summary
        ledger.record(conn, DOC, STAGE, "done",
                      output_ref=json.dumps({"rejected": summary["rejected"],
                                             "subjects_fixed": resubjected}, sort_keys=True))
        conn.commit()
        return summary
    except Exception:
        conn.rollback()
        raise


def main(argv=None) -> int:
    import argparse
    ap = argparse.ArgumentParser(prog="kie.curate.concept_quality",
                                 description="Phase 6 — residual concept-quality repair")
    ap.add_argument("--db", default=None)
    ap.add_argument("--dry-run", action="store_true")
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
