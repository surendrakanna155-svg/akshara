"""Concept-canonicalization CANDIDATE identifier (Phase-A0 analysis; Phase-A2 executes).

Phase-0b proved the retained yield gate (>=8 Item Models/subject) is blocked by concept-quality debt: the
certified concept layer holds OCR-junk pseudo-concepts (e.g. `BIO_CHOOSE_THE_COR`, a garbled "choose the
correct" fragment) that qualified as spurious "models" across all four subjects, plus cross-subject-mistagged
and non-concept fragments.

This module reads kie.db READ-ONLY and flags quarantine CANDIDATES with reasons + evidence. It writes them to
qie.db `concept_canon_ledger` with applied=0 (candidate only) and NEVER mutates kie.db. Phase A2, with a
backup, applies the quarantine via the existing curate lane.
"""
from __future__ import annotations

import re
import sqlite3
from dataclasses import dataclass
from typing import List, Optional

# Question-fragment / non-concept phrases that should never be a "concept" title.
_NON_CONCEPT = (
    "choose the cor", "choose the correct", "which of the follow", "the following", "assertion",
    "reason", "match the", "academic standard", "amazing fact", "activity", "exercise", "example",
    "alternative arrangement", "let us", "do you know", "try these", "fill in the blank",
    "true or false", "answer the", "figure ", "table ", "solution", "objective type",
)
# subject_domain prefix map for cross-subject mistag detection
_PREFIX = {"PHY_": "Physics", "CHE_": "Chemistry", "BIO_": "Biology", "MAT_": "Mathematics", "MATH_": "Mathematics"}


@dataclass(frozen=True)
class Candidate:
    concept_code: str
    title: str
    subject_domain: Optional[str]
    reason: str
    evidence: str
    proposed_status: str = "rejected"   # rejected = quarantine candidate; review = needs human/curate check


def _has_phrase(low: str) -> Optional[str]:
    """Match a non-concept phrase at WORD boundaries (never as a bare substring — so 'radioactivity'
    and 'reactivity' are NOT flagged by the phrase 'activity')."""
    for p in _NON_CONCEPT:
        if re.search(r"(?<![a-z])" + re.escape(p) + r"(?![a-z])", low):
            return p
    return None


def _is_ocr_junk(title: str) -> bool:
    t = (title or "").strip()
    if len(t) < 3:
        return True
    low = t.lower()
    # implausibly long single token (merged words; real science terms like "photosynthesis"=14 or
    # "electromagnetic"=15 must NOT trip this, so the bar is deliberately high), or a long consonant run.
    for tok in re.findall(r"[a-z]+", low):
        if len(tok) >= 20:
            return True
        if re.search(r"[bcdfghjklmnpqrstvwxz]{6,}", tok):
            return True
    # title is mostly non-alphabetic
    letters = sum(c.isalpha() for c in t)
    if letters and letters / max(len(t), 1) < 0.5:
        return True
    return False


def find_candidates(conn: sqlite3.Connection) -> List[Candidate]:
    """conn must be an open (read-only is fine) kie.db connection."""
    conn.row_factory = sqlite3.Row
    rows = conn.execute(
        "SELECT concept_code, title, subject_domain FROM concepts WHERE status='active'"
    ).fetchall()
    out: List[Candidate] = []
    for r in rows:
        code = r["concept_code"]
        title = r["title"] or ""
        subj = r["subject_domain"]
        low = title.lower().strip()
        reason = None
        evidence = ""
        status = "rejected"
        phrase = _has_phrase(low)
        if phrase:
            reason = "non_concept"
            evidence = f"title contains the section/question phrase {phrase!r}: {title!r}"
        elif _is_ocr_junk(title):
            reason = "ocr_junk"
            evidence = f"title fails OCR-plausibility heuristic: {title!r}"
        else:
            for pref, want in _PREFIX.items():
                if code.startswith(pref) and subj and subj != want:
                    # AMBIGUOUS: the domain may be a correction (correct) with a legacy prefix, or a genuine
                    # mistag. Never auto-quarantine — flag for review (A2 decides via the curate lane).
                    reason = "prefix_domain_mismatch"
                    evidence = f"code prefix {pref} implies {want} but subject_domain={subj} (review, not auto-reject)"
                    status = "review"
                    break
        if reason:
            out.append(Candidate(code, title, subj, reason, evidence, status))
    return out


def write_candidates(qconn: sqlite3.Connection, candidates: List[Candidate], now: str) -> int:
    """Persist candidates to qie.db concept_canon_ledger with applied=0 (analysis-only)."""
    n = 0
    for c in candidates:
        qconn.execute(
            "INSERT INTO concept_canon_ledger(concept_code, reason, evidence, proposed_status, applied, created_at) "
            "VALUES (?,?,?,?,0,?) ON CONFLICT(concept_code) DO UPDATE SET reason=excluded.reason, "
            "evidence=excluded.evidence, proposed_status=excluded.proposed_status",
            (c.concept_code, c.reason, c.evidence, c.proposed_status, now),
        )
        n += 1
    qconn.commit()
    return n


def apply_quarantine(kconn: sqlite3.Connection, qconn: sqlite3.Connection, now: str) -> dict:
    """REVERSIBLE curate operation. For every ledger row with proposed_status='rejected' and applied=0,
    record the concept's current status (prior_status) and set concepts.status='rejected' in kie.db.

    NEVER touches proposed_status='review' rows (the 17 prefix/domain mismatches — owner instruction). The
    caller MUST have taken a full kie.db backup first (belt-and-braces alongside per-row prior_status).
    """
    rows = qconn.execute(
        "SELECT concept_code FROM concept_canon_ledger WHERE proposed_status='rejected' AND applied=0"
    ).fetchall()
    applied, skipped_missing = 0, 0
    for r in rows:
        code = r[0]
        cur = kconn.execute("SELECT status FROM concepts WHERE concept_code=?", (code,)).fetchone()
        if not cur:
            skipped_missing += 1
            continue
        prior = cur[0]
        if prior == "rejected":            # already rejected upstream — nothing to change, record idempotently
            qconn.execute("UPDATE concept_canon_ledger SET prior_status=?, applied=1, applied_at=? "
                          "WHERE concept_code=?", (prior, now, code))
            continue
        kconn.execute("UPDATE concepts SET status='rejected' WHERE concept_code=?", (code,))
        qconn.execute("UPDATE concept_canon_ledger SET prior_status=?, applied=1, applied_at=? "
                      "WHERE concept_code=?", (prior, now, code))
        applied += 1
    kconn.commit()
    qconn.commit()
    return {"quarantined": applied, "skipped_missing": skipped_missing,
            "review_untouched": qconn.execute(
                "SELECT COUNT(*) FROM concept_canon_ledger WHERE proposed_status='review'").fetchone()[0]}


def rollback(kconn: sqlite3.Connection, qconn: sqlite3.Connection) -> int:
    """Undo apply_quarantine: restore each applied concept's prior_status. Returns count restored."""
    rows = qconn.execute(
        "SELECT concept_code, prior_status FROM concept_canon_ledger WHERE applied=1 AND prior_status IS NOT NULL"
    ).fetchall()
    n = 0
    for code, prior in rows:
        kconn.execute("UPDATE concepts SET status=? WHERE concept_code=?", (prior, code))
        qconn.execute("UPDATE concept_canon_ledger SET applied=0, applied_at=NULL WHERE concept_code=?", (code,))
        n += 1
    kconn.commit()
    qconn.commit()
    return n


def summarize(candidates: List[Candidate]) -> dict:
    from collections import Counter
    by_reason = Counter(c.reason for c in candidates)
    by_subject = Counter(c.subject_domain for c in candidates)
    by_status = Counter(c.proposed_status for c in candidates)
    return {"total_candidates": len(candidates), "by_reason": dict(by_reason),
            "by_status": dict(by_status), "by_subject": dict(by_subject),
            "auto_quarantine_candidates": sum(1 for c in candidates if c.proposed_status == "rejected"),
            "review_candidates": sum(1 for c in candidates if c.proposed_status == "review"),
            "samples": [(c.concept_code, c.title, c.reason, c.proposed_status) for c in candidates[:30]]}
