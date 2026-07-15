"""Deterministic target selection — WHICH owned source pages are worth re-reading from the image.

Recovery cost is per-page, so targeting is the difference between a demo and a program. Two deterministic
signals, no model:
  * MATH-DAMAGE score (`sources.math_damage_score`) — pages whose equations were flattened by text extraction
    are exactly the pages whose notation must be recovered from the image;
  * FORMULA DENSITY — a chapter's SUMMARY/POINTS-TO-PONDER section restates every key relation of the chapter
    in one place, so it yields many relations per page read (highest recovery-per-cost).

Targets are ordered so the concepts that close current paper gaps come first.
"""
from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Dict, List, Optional

from kie.qie.convert.notation import sources as S

_SUMMARY = re.compile(r"\bSUMMARY\b|\bPOINTS TO PONDER\b", re.I)
_CHAPTER_TITLE = re.compile(r"CHAPTER\s+[A-Z]+|Chapter\s+[A-Z][a-z]+")


@dataclass
class Target:
    page: S.SourcePage
    chapter_title: str
    damage: float
    is_summary: bool
    score: float


def _chapter_of(first_page_text: str) -> str:
    lines = [l.strip() for l in (first_page_text or "").splitlines() if l.strip()]
    for l in lines[:8]:
        if l.isupper() and len(l) > 5 and not l.startswith(("PHYSICS", "CHEMISTRY", "REPRINT")):
            return l.title()
    return (lines[1] if len(lines) > 1 else (lines[0] if lines else "")).title()


def scan_entry(store_rel: str, entry: str, subject: str, doc_id: str = "") -> List[Target]:
    """Score every page of one chapter PDF."""
    out: List[Target] = []
    chapter = ""
    for sp, text in S.iter_pages(store_rel, entry, doc_id=doc_id, subject=subject):
        if sp.page == 0:
            chapter = _chapter_of(text)
        dmg = S.math_damage_score(text)
        is_sum = bool(_SUMMARY.search(text or ""))
        # summary pages restate every relation of the chapter -> strongly preferred
        score = dmg + (0.6 if is_sum else 0.0)
        out.append(Target(S.SourcePage(doc_id, store_rel, entry, sp.page, subject, chapter),
                          chapter, dmg, is_sum, round(score, 3)))
    return out


def select(store_rel: str, subject: str, doc_id: str = "", per_chapter: int = 1,
           min_damage: float = 0.15, chapter_filter: Optional[List[str]] = None) -> List[Target]:
    """Best page(s) per chapter of an owned textbook zip, highest recovery-per-read first."""
    picks: List[Target] = []
    for entry in S.list_pdf_entries(store_rel):
        base = entry.split("/")[-1].lower()
        if any(k in base for k in ("ps.pdf", "an.pdf", "a1.pdf")):   # cover/answers/appendix — no relations
            continue
        try:
            scored = scan_entry(store_rel, entry, subject, doc_id)
        except Exception:
            continue
        if not scored:
            continue
        chap = scored[0].chapter_title
        if chapter_filter and not any(k.lower() in chap.lower() for k in chapter_filter):
            continue
        good = [t for t in scored if t.damage >= min_damage or t.is_summary]
        good.sort(key=lambda t: -t.score)
        picks.extend(good[:per_chapter])
    picks.sort(key=lambda t: -t.score)
    return picks


def summarize(targets: List[Target]) -> List[dict]:
    return [{"chapter": t.chapter_title, "page": t.page.page, "entry": t.page.entry,
             "damage": t.damage, "summary_page": t.is_summary, "score": t.score} for t in targets]
