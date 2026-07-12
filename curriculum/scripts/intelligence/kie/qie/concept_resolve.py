"""Canonical concept resolution / entity-linking (Phase B7) — strict, confidence-gated.

The B6 blocker: noisy OCR'd stems map to coarse keyword buckets ("Biology:cell") instead of resolved
canonical concepts ("BIO_MITOCHONDRIA"), so their abundant evidence can't be verified. This resolver links an
item to a REAL existing active concept using the strongest available signal — the CORRECT ANSWER text, which
in biology/chemistry MCQs is very often the canonical concept name ("mitochondrion", "nephron") — with a
salient-stem-noun fallback. It NEVER forces an uncertain mapping: below the confidence threshold it returns
None and the item keeps its coarse key (unresolved, hence unverifiable — honest).

Only maps to concepts that ALREADY EXIST and are active (no new concepts invented). Deterministic, stdlib.
"""
from __future__ import annotations

import re
import sqlite3
from typing import Dict, List, Optional, Tuple

MIN_CONFIDENCE = 0.85   # strict — do not lower (owner: do not weaken concept-resolution confidence)
_STOP = {"the", "a", "an", "of", "in", "is", "are", "and", "or", "to", "for", "which", "what", "following",
         "correct", "statement", "not", "all", "these", "that", "with", "by", "as", "on", "at"}


def _norm(s: str) -> str:
    return re.sub(r"[^a-z0-9 ]+", " ", (s or "").lower()).strip()


def _root(word: str) -> str:
    """Crude singular/latin-plural root so 'mitochondria' and 'mitochondrion' collapse to one root."""
    w = word
    for suf in ("ondria", "ondrion"):
        if w.endswith(suf):
            return w[: -len(suf)] + "ondri"
    for suf in ("ae", "um", "us", "on", "a", "es", "s"):
        if len(w) - len(suf) >= 4 and w.endswith(suf):
            return w[: -len(suf)]
    return w


def build_index(kconn: sqlite3.Connection, subject: Optional[str] = None) -> List[Tuple[str, str, str]]:
    """(concept_code, normalized_title, title_root) for active concepts with a clean, specific title."""
    kconn.row_factory = sqlite3.Row
    idx = []
    for r in kconn.execute("SELECT concept_code, title, subject_domain FROM concepts WHERE status='active'"):
        if subject and r["subject_domain"] != subject:
            continue
        t = _norm(r["title"])
        toks = [w for w in t.split() if w not in _STOP]
        if not toks or len(t) < 4 or len(t) > 45:
            continue
        # skip multi-word section-y titles; keep specific 1-3 token concept names
        if len(toks) > 3:
            continue
        idx.append((r["concept_code"], t, " ".join(_root(w) for w in toks)))
    return idx


def _score(answer_norm: str, title_norm: str, title_root: str) -> float:
    a_toks = [w for w in answer_norm.split() if w not in _STOP]
    if not a_toks:
        return 0.0
    a_root = " ".join(_root(w) for w in a_toks)
    if answer_norm == title_norm:
        return 1.0
    if a_root == title_root:
        return 0.95
    # single decisive token match (>=6 chars) between answer and a 1-token title
    if " " not in title_root and len(title_root) >= 6:
        if title_root in a_root.split():
            return 0.9
    # answer is exactly the title (whole-phrase containment, both specific)
    if len(title_norm) >= 6 and (f" {title_norm} " in f" {answer_norm} "):
        return 0.88
    return 0.0


def resolve(stem: str, answer: str, index: List[Tuple[str, str, str]],
            min_conf: float = MIN_CONFIDENCE) -> Optional[str]:
    """Return a canonical concept_code iff a confident (>= min_conf) answer/stem->concept link exists, else
    None. Answer signal first (strongest for bio/chem), then a salient stem-noun pass at the same strict bar."""
    a = _norm(answer)
    best_code, best = None, 0.0
    if len(a) >= 4:
        for code, tnorm, troot in index:
            c = _score(a, tnorm, troot)
            if c > best:
                best_code, best = code, c
    if best >= min_conf:
        return best_code
    # stem fallback — only accept a title that appears as a whole specific phrase in the stem
    s = _norm(stem)
    for code, tnorm, troot in index:
        if len(tnorm) >= 7 and " " in tnorm and f" {tnorm} " in f" {s} ":
            return code
    return None


def build_resolver(kconn: sqlite3.Connection):
    """Return a callable(stem, answer, subject) -> concept_code|None using per-subject indices."""
    idx_by_subj: Dict[str, list] = {}
    for subj in ("Biology", "Chemistry", "Physics", "Mathematics"):
        idx_by_subj[subj] = build_index(kconn, subject=subj)

    def _resolve(stem: str, answer: str, subject: str) -> Optional[str]:
        return resolve(stem, answer, idx_by_subj.get(subject, []))
    _resolve.index_sizes = {s: len(v) for s, v in idx_by_subj.items()}  # type: ignore[attr-defined]
    return _resolve
