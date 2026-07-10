"""Knowledge Layer — Phase 2: deterministic concept enrichment (grounded, no AI).

Phase 1 cleaned the spine; this pass STRENGTHENS each surviving concept from
evidence ALREADY in the KIE — never inventing a fact:

  1. backfill_subject   — NULL subject_domain ← concept-code prefix (PHY/CHE/...).
  2. enrich_metadata    — bloom_levels / difficulty band ← the concept's own linked
                          question_patterns; typical grade band ← its evidencing
                          document; reference_facts ← its mined formulas/laws;
                          common_misconceptions ← confused_with graph edges.
                          (The frozen engine reads NONE of these fields, so they are
                          zero-risk; they strengthen the layer for graph work and the
                          eventual Postgres promotion.)
  3. mine_definitions   — backfill a missing definition with a STRICT, high-precision
                          definitional sentence lifted verbatim from the certified
                          corpus (short factual statement + chunk evidence). This is
                          the ONE field the engine consumes (as a model answer and an
                          evidence signal), so the miner errs hard toward precision:
                          a wrong answer is worse than the honest marking-guideline
                          fallback, so anything not clearly a clean definition is
                          skipped. Copyright-safe: facts only, terse, attributed.

Everything is deterministic, idempotent and recovery-safe. It reuses the frozen
engine's own gates (qpgen.materialize.usable_definition, qpgen.sanitize) so a
backfilled definition is judged exactly as the engine would judge it.
"""
from __future__ import annotations

import json
import re
from typing import Dict, List, Optional, Tuple

from kie import ledger, store
from kie.qpgen import materialize, sanitize

ENRICH_STAGE = "enrich"
ENRICH_DOC = "__knowledge__"

_PREFIX_SUBJECT = {"PHY": "Physics", "CHE": "Chemistry", "MAT": "Mathematics", "BIO": "Biology"}
_BLOOM_ORDER = ("remember", "understand", "apply", "analyze", "hots")
_DIFF_ORDER = ("easy", "medium", "hard")
_CLASS_RE = re.compile(r"class\s*(\d{1,2})", re.I)
_COMPETITIVE = {"JEE", "JEE_Main", "JEE_Advanced", "NEET", "AIIMS", "KVPY", "BITSAT"}


# ── json helpers (preserve existing evidence keys) ─────────────────────────────────
def _load(raw: Optional[str]) -> dict:
    if not raw:
        return {}
    try:
        v = json.loads(raw)
        return v if isinstance(v, dict) else {"_prev": v}
    except (ValueError, TypeError):
        return {}


def _stamp_evidence(conn, code: str, patch: dict) -> None:
    row = conn.execute("SELECT evidence FROM concepts WHERE concept_code=?", (code,)).fetchone()
    ev = _load(row["evidence"] if row else None)
    ev["enrich"] = {**ev.get("enrich", {}), **patch}
    conn.execute("UPDATE concepts SET evidence=? WHERE concept_code=?",
                 (json.dumps(ev, sort_keys=True), code))


# ── pass 1: subject backfill ───────────────────────────────────────────────────────
def backfill_subject(conn) -> int:
    n = 0
    for r in conn.execute(
        "SELECT concept_code FROM concepts WHERE status='active' AND "
        "(subject_domain IS NULL OR subject_domain='')"
    ).fetchall():
        subj = _PREFIX_SUBJECT.get(r["concept_code"].split("_", 1)[0])
        if subj:
            conn.execute("UPDATE concepts SET subject_domain=? WHERE concept_code=?",
                         (subj, r["concept_code"]))
            n += 1
    return n


# ── pass 2: metadata from linked evidence ──────────────────────────────────────────
def _pattern_facets(conn) -> Dict[str, Tuple[List[str], List[str]]]:
    """concept_code → (sorted blooms, sorted difficulties) from its question_patterns."""
    out: Dict[str, Tuple[set, set]] = {}
    for r in conn.execute(
        "SELECT concept_code, bloom, difficulty FROM question_patterns WHERE concept_code IS NOT NULL"
    ).fetchall():
        b, d = out.setdefault(r["concept_code"], (set(), set()))
        if r["bloom"]:
            b.add(r["bloom"].lower())
        if r["difficulty"]:
            d.add(r["difficulty"].lower())
    return out


def _formulas_by_concept(conn) -> Dict[str, List[dict]]:
    out: Dict[str, List[dict]] = {}
    for r in conn.execute(
        "SELECT concept_code, kind, expression FROM formulas WHERE concept_code IS NOT NULL "
        "ORDER BY formula_id"
    ).fetchall():
        out.setdefault(r["concept_code"], []).append(
            {"kind": r["kind"], "expression": (r["expression"] or "").strip()})
    return out


def _misconceptions_by_concept(conn) -> Dict[str, List[str]]:
    """confused_with edges → the titles a learner is likely to confuse this concept with."""
    title_of = {r["concept_code"]: r["title"]
                for r in conn.execute("SELECT concept_code, title FROM concepts").fetchall()}
    out: Dict[str, set] = {}
    for r in conn.execute(
        "SELECT from_concept, to_concept FROM concept_edges WHERE relationship_type='confused_with'"
    ).fetchall():
        for a, b in ((r["from_concept"], r["to_concept"]), (r["to_concept"], r["from_concept"])):
            if b in title_of:
                out.setdefault(a, set()).add(title_of[b])
    return out


def _grade_band(class_label: Optional[str], exam: Optional[str]) -> Optional[Tuple[int, int]]:
    if class_label:
        m = _CLASS_RE.search(class_label)
        if m:
            g = int(m.group(1))
            return (g, g)
    if exam in _COMPETITIVE:
        return (11, 12)
    return None


def enrich_metadata(conn) -> Dict[str, int]:
    facets = _pattern_facets(conn)
    formulas = _formulas_by_concept(conn)
    misconceptions = _misconceptions_by_concept(conn)
    counts = {"bloom": 0, "difficulty": 0, "grade": 0, "reference_facts": 0, "misconceptions": 0}

    for r in conn.execute(
        "SELECT c.concept_code, c.evidence, sd.class_label, sd.exam "
        "FROM concepts c LEFT JOIN source_documents sd "
        "ON sd.doc_id = json_extract(c.evidence,'$.doc') WHERE c.status='active'"
    ).fetchall():
        code = r["concept_code"]
        sets = {}
        blooms, diffs = facets.get(code, (set(), set()))
        if blooms:
            ordered = [b for b in _BLOOM_ORDER if b in blooms] + sorted(blooms - set(_BLOOM_ORDER))
            sets["bloom_levels"] = json.dumps(ordered)
            counts["bloom"] += 1
        if diffs:
            ordered = [d for d in _DIFF_ORDER if d in diffs]
            if ordered:
                sets["difficulty_min"] = ordered[0]
                sets["difficulty_max"] = ordered[-1]
                counts["difficulty"] += 1
        band = _grade_band(r["class_label"], r["exam"])
        if band:
            sets["typical_grade_low"], sets["typical_grade_high"] = band
            counts["grade"] += 1
        facts = formulas.get(code)
        if facts:
            sets["reference_facts"] = json.dumps(facts, sort_keys=True)
            counts["reference_facts"] += 1
        misc = misconceptions.get(code)
        if misc:
            sets["common_misconceptions"] = json.dumps(sorted(misc))
            counts["misconceptions"] += 1
        if sets:
            assigns = ", ".join(f"{k}=?" for k in sets)
            conn.execute(f"UPDATE concepts SET {assigns} WHERE concept_code=?",
                         (*sets.values(), code))
    return counts


# ── pass 3: strict grounded definition mining ──────────────────────────────────────
# strong, low-false-positive definitional connectives (the body that follows is the definition)
_STRONG = (
    "is defined as", "are defined as", "is defined to be", "is called", "are called",
    "is known as", "are known as", "is referred to as", "refers to", "is the process of",
    "is a process", "is the phenomenon", "is a phenomenon", "is the measure of",
    "is a measure of", "is the ratio of", "is the rate of change of", "is the rate of",
    "is the branch of", "is that branch of", "is the study of", "is the tendency of",
    "is the ability of", "is the amount of", "is the property of", "is the force",
    "is the minimum", "is the maximum", "is the number of",
)
_SENT_SPLIT = re.compile(r"(?<=[.!?])\s+|\n+")
_BAD_BODY = re.compile(
    r"\(\s*[0-9a-eiv]+\s*\)|\bnone of these\b|\bwhich of\b|\bfollowing\b|\?|"
    r"[=+*/^_<>{}\\|]|\bthen\b|\bhence\b|\bfig\b|\btable\b|:\s*\d|"
    # meta-references ("as below", "as follows", "broad term") are not definitions
    r"\bas below\b|\bas follows\b|\bgiven below\b|\bas shown\b|\bshown in\b|"
    r"\bbroad term\b|\bsee above\b|\bdescribed below\b|\brefer to\b|"
    # relative-clause / process openers usually precede a verb that OCR truncation drops
    # ("...the phenomenon in which nuclei of a given species."), so a short sentence carrying
    # them is very likely a cut fragment → reject (precision-first).
    r"\bin which\b|\bby which\b|\bthrough which\b|\bwhereby\b|\bsuch that\b",
    re.I,
)
_PUNCT_ARTIFACT = re.compile(r",\s*\.|;\s*\.|\s,|\.{2,}|--")
_MULTI_DIGIT = re.compile(r"\d")
_DEF_MAX = 240
_DEF_BODY_MIN_WORDS = 5
_DEF_BODY_MIN_CHARS = 25

# 'of' fused to the next word ('ofreproduction'): real 'off*' words start 'of'+'f', so a
# single-'f' 'of' + long remainder is a safe merge signal ('office'/'offer'/'often' never match).
_OF_MERGE = re.compile(r"^of[b-eg-z][a-z]{4,}$")
# A prefix heuristic on 'the'/'for'/'with' false-positives on real words (thermal, forest,
# within), so we DON'T use one. Merged runs are caught only by an over-long token (real
# English/science words seldom reach 18 chars) plus the narrow, safe 'of'-merge signal.
_MERGE_MAX_TOKEN = 18


def _looks_merged(sentence: str) -> bool:
    """True if the sentence carries a likely OCR merged-word artefact (deterministic proxy).
    Precision-first and conservative: only unambiguous signals, so real long science terms
    ('electromagnetic', 'characteristics') are never rejected."""
    for tok in re.findall(r"[A-Za-z]+", sentence):
        low = tok.lower()
        if len(low) >= _MERGE_MAX_TOKEN:         # 'speciestransformby'-style glued run
            return True
        if _OF_MERGE.match(low):                 # 'ofreproduction'
            return True
    return False


def _definition_from_text(title: str, text: str) -> Optional[str]:
    """Return a clean definitional sentence for `title` found in `text`, else None.

    STRICT and precision-first: a wrong model answer is worse than the honest
    marking-guideline fallback, so anything not clearly a complete, clean, factual
    definition is skipped. Verbatim (facts only) + capitalised title."""
    tl = title.lower()
    for raw in _SENT_SPLIT.split(text):
        s = re.sub(r"\s+", " ", raw).strip()
        low = s.lower()
        if not low.startswith(tl):                          # title must be the subject
            continue
        after = low[len(tl):].lstrip(" ,")
        connective = next((c for c in _STRONG if after.startswith(c)), None)
        if not connective:                                  # require a strong connective
            continue
        # the definition body must be substantive (not a truncated clause)
        body = after[len(connective):].strip(" ,.")
        body_words = re.findall(r"[A-Za-z][A-Za-z'\-]*", body)
        if len(body_words) < _DEF_BODY_MIN_WORDS or len(body) < _DEF_BODY_MIN_CHARS:
            continue
        if not s.endswith("."):
            s = s + "."
        if not (15 <= len(s) <= _DEF_MAX):
            continue
        if _BAD_BODY.search(s):                             # option lists / math / meta-refs
            continue
        if _PUNCT_ARTIFACT.search(s):                       # ",." / doubled punctuation
            continue
        if len(_MULTI_DIGIT.findall(s)) > 2:               # a real short definition is word-heavy
            continue
        if sanitize._looks_like_ocr_garbage(s) or _looks_merged(s):
            continue
        # final gate: the engine's OWN model-answer completeness check
        if not materialize.usable_definition(s):
            continue
        # present the title with a capital (kept verbatim otherwise — a factual statement)
        return s[0].upper() + s[1:]
    return None


def _candidate_chunks(conn, title: str, limit: int = 25) -> List[str]:
    """FTS-narrowed chunks that mention the concept title (phrase match; falls back to none)."""
    try:
        rows = conn.execute(
            "SELECT c.text FROM chunks c JOIN chunks_fts f ON f.rowid = c.rowid "
            "WHERE chunks_fts MATCH ? LIMIT ?",
            (f'"{title}"', limit),
        ).fetchall()
    except Exception:
        return []
    return [r["text"] for r in rows]


def demote_garbled_definitions(conn) -> int:
    """Blank a pre-existing definition that carries a DETECTABLE OCR merge artefact, so the
    engine falls back to its safe marking-guideline answer instead of showing garbled prose.

    Precision-safe: only the unambiguous merge signals (_looks_merged: an over-long glued run
    or an 'of'-merge). Shorter lowercase merges ('thelimit', 'ofthe') can't be split without a
    dictionary — those are a phase5 EXTRACTION defect handled in Phase 3, not guessed at here.
    Never fabricates; only removes a bad answer. A blanked concept can be re-filled by the clean
    miner below if the corpus offers a clean sentence."""
    n = 0
    for r in conn.execute(
        "SELECT concept_code, definition FROM concepts WHERE status='active' "
        "AND definition IS NOT NULL AND definition <> ''"
    ).fetchall():
        d = r["definition"]
        if materialize.usable_definition(d) and _looks_merged(d):
            conn.execute("UPDATE concepts SET definition='' WHERE concept_code=?",
                         (r["concept_code"],))
            _stamp_evidence(conn, r["concept_code"], {"definition_demoted": "ocr_merge"})
            n += 1
    return n


def mine_definitions(conn) -> int:
    filled = 0
    for r in conn.execute(
        "SELECT concept_code, title, definition FROM concepts WHERE status='active'"
    ).fetchall():
        if materialize.usable_definition(r["definition"] or ""):
            continue                                        # already has a usable definition
        title = (r["title"] or "").strip()
        if len(title) < 4:
            continue
        for text in _candidate_chunks(conn, title):
            definition = _definition_from_text(title, text)
            if definition:
                conn.execute("UPDATE concepts SET definition=? WHERE concept_code=?",
                             (definition, r["concept_code"]))
                _stamp_evidence(conn, r["concept_code"],
                                {"definition_source": "mined", "method": "corpus_sentence"})
                filled += 1
                break
    return filled


# ── orchestration ──────────────────────────────────────────────────────────────────
def run(conn, dry_run: bool = False) -> dict:
    before = _snapshot(conn)
    try:
        subjects = backfill_subject(conn)
        demoted = demote_garbled_definitions(conn)
        definitions = mine_definitions(conn)
        meta = enrich_metadata(conn)
        summary = {
            "subjects_backfilled": subjects,
            "definitions_demoted": demoted,
            "definitions_mined": definitions,
            "metadata": meta,
            "before": before,
            "after": _snapshot(conn),
        }
        if dry_run:
            conn.rollback()
            summary["dry_run"] = True
            return summary
        ledger.record(conn, ENRICH_DOC, ENRICH_STAGE, "done",
                      output_ref=json.dumps({"subjects": subjects, "demoted": demoted,
                                             "definitions": definitions, **meta}, sort_keys=True))
        conn.commit()
        return summary
    except Exception:
        conn.rollback()
        raise


def _snapshot(conn) -> dict:
    active = "WHERE status='active'"
    q = lambda where: conn.execute(f"SELECT COUNT(*) n FROM concepts {where}").fetchone()["n"]
    return {
        "concepts_active": q(active),
        "with_usable_definition": sum(
            1 for r in conn.execute(f"SELECT definition FROM concepts {active}")
            if materialize.usable_definition(r["definition"] or "")),
        "with_bloom": q(active + " AND bloom_levels IS NOT NULL AND bloom_levels<>''"),
        "with_difficulty": q(active + " AND difficulty_min IS NOT NULL AND difficulty_min<>''"),
        "with_grade": q(active + " AND typical_grade_low IS NOT NULL"),
        "with_reference_facts": q(active + " AND reference_facts IS NOT NULL AND reference_facts<>''"),
    }


def main(argv=None) -> int:
    import argparse

    ap = argparse.ArgumentParser(prog="kie.curate.enrich",
                                 description="Phase 2 — deterministic concept enrichment")
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
