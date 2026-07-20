"""KNOWLEDGE FOUNDATION v1.3 — TOC-anchoring recovery (ADDITIVE, spine stays frozen).

WHY THIS EXISTS
`spine.extract_spine` anchors a numbered section to the FIRST chunk its heading appears in, in book
order (`spine._admit`, "FIRST WINS"). That is correct for the body-vs-exercise case it was written for.
But some OCR'd senior NCERT books print (or the OCR surfaced) a section's clean "N.M Title" string ONLY
on the CONTENTS PAGE, never as a line-anchored body heading. There, the section anchors to the
table-of-contents chunk, so `section_evidence` walks the TOC listing instead of the section's teaching
body — and the engineer, shown a list of other headings, can propose no real concept. Those sections are
the `low_yield` gaps in the v1.2 freeze (kech1dd Thermodynamic Terms/Spontaneity/Ionic Bond/Electronic
Configs/Quantum Model; keph1dd Universal Law of Gravitation; lech1dd Secondary Batteries; ...).

THE FIX, done safely
This module does NOT edit the frozen spine. It runs AFTER `extract_spine`, and for a section whose anchor
is a TOC-shaped chunk it RE-ANCHORS to the first NON-TOC body chunk that contains the section title as
prose. It is used to recover ONLY sections that are currently UNCERTIFIED — a certified concept's anchor is
never touched, so v1.3 recovery cannot, by construction, downgrade any of the 1,976 v1.2 concepts.

Deterministic, stdlib-only, read-only w.r.t. kie.db. The knowledge writes happen through the normal
`engineer.ingest_engineer` / `engineer.ingest_audit` path on a SEPARATE v1.3 index copy.
"""
from __future__ import annotations

import re
import sqlite3
from typing import Dict, List, Optional, Tuple

from kie.qie.knowledge import spine as S

# A "N.M Title" reference inside a chunk (the shape a contents page is built out of).
_SECREF = re.compile(r"(?<!\d)(\d{1,2})\.(\d{1,2})(?:\.\d{1,2})?\s+[A-Za-z]")
# Front-matter markers that only ever appear on a contents / rationalisation page.
_TOC_MARK = re.compile(r"Rationalisation of Content|Table of Contents|^\s*Contents\b", re.I)


def is_toc_chunk(text: Optional[str]) -> bool:
    """A contents/TOC-shaped chunk: an explicit contents marker, OR a dense list of section references
    spanning several chapters (a body chunk lives inside ONE section and never references six sections
    across three chapters). Deliberately strict so a normal body chunk is not mistaken for a TOC — and,
    because recovery only ever RE-ANCHORS uncertified sections, a false positive here can at worst leave a
    section unrecovered, never corrupt a certified one.
    """
    if not text:
        return False
    if _TOC_MARK.search(text):
        return True
    refs = _SECREF.findall(text)
    return len(refs) >= 6 and len({int(a) for a, _ in refs}) >= 3


def _norm(s: str) -> str:
    return re.sub(r"\s+", " ", (s or "")).strip()


def find_body_anchor(kconn: sqlite3.Connection, doc_id: str, title: str,
                     toc_ordinal: int) -> Optional[Tuple[str, int]]:
    """First NON-TOC body chunk (after the TOC) whose text contains the section title as prose.

    Returns (chunk_id, ordinal) or None. Matches on a 24-char title prefix, case-insensitively (OCR prints
    headings ALL-CAPS while the title is Title-Case). Requires a reasonably specific title (>=6 chars) so a
    stub like "Volume" cannot mis-match.
    """
    key = _norm(title)[:24]
    if len(key) < 6:
        return None
    kl = key.lower()
    for r in kconn.execute(
            "SELECT chunk_id, ordinal, text FROM chunks WHERE doc_id=? ORDER BY ordinal", (doc_id,)):
        if r["ordinal"] == toc_ordinal or is_toc_chunk(r["text"]):
            continue
        if kl in _norm(r["text"]).lower():
            return r["chunk_id"], r["ordinal"]
    return None


def reanchor_uncertified(kconn: sqlite3.Connection, idx_conn: sqlite3.Connection, doc_id: str,
                         subject: str, taught_at_class: int) -> Dict[int, dict]:
    """Return a REDUCED {chapter_no: chapter_dict} containing ONLY the sections this pass recovered.

    A section is recovered when ALL hold:
      1. its current spine anchor is a TOC-shaped chunk (bad evidence);
      2. its title is findable as prose in a non-TOC body chunk (re-anchorable);
      3. no CERTIFIED concept already cites this exact section_heading for this book
         (so we never re-propose, and never risk resetting, a certified concept).
    The recovered section's `chunk_id`/`page` are rewritten to the body anchor, so the downstream
    `section_evidence` / engineer worksheet see the teaching body, not the contents page.
    """
    chapters, _ = S.extract_spine(kconn, doc_id)

    # section_headings already certified for THIS book — never re-touch them
    certified_headings = {
        _norm(r["section_heading"]).lower()
        for r in idx_conn.execute(
            "SELECT c.section_heading FROM ki_concept c "
            "JOIN ki_chapter ch ON ch.chapter_id=c.chapter_id "
            "WHERE ch.doc_id=? AND c.status='certified'", (doc_id,))
        if r["section_heading"]}

    out: Dict[int, dict] = {}
    for ch_no, cd in chapters.items():
        kept = {}
        for sec, t in cd["topics"].items():
            anchor = t.get("chunk_id")
            if not anchor:
                continue
            arow = kconn.execute(
                "SELECT ordinal, text FROM chunks WHERE chunk_id=?", (anchor,)).fetchone()
            if not (arow and is_toc_chunk(arow["text"])):
                continue  # already body-anchored — leave it exactly as v1.2 had it
            heading = _norm(f"{sec} {t['title']}").lower()
            if heading in certified_headings or _norm(t["title"]).lower() in certified_headings:
                continue  # already certified from this section — do not re-propose
            hit = find_body_anchor(kconn, doc_id, t["title"], arow["ordinal"])
            if not hit:
                continue  # title not present in any body chunk — genuinely unrecoverable, stays honest
            body_chunk, body_ord = hit
            page = kconn.execute(
                "SELECT page_start FROM chunks WHERE chunk_id=?", (body_chunk,)).fetchone()[0]
            kept[sec] = {**t, "chunk_id": body_chunk, "page": page,
                         "reanchored_from_toc": arow["ordinal"], "reanchored_to": body_ord}
        if kept:
            out[ch_no] = {"topics": kept, "raw": cd["raw"],
                          "chunk_ids": [kept[s]["chunk_id"] for s in kept], "pages": set()}
    return out


def recovery_worklist(kconn: sqlite3.Connection, idx_conn: sqlite3.Connection, doc_id: str,
                      subject: str, taught_at_class: int) -> List[dict]:
    """Flat, human-auditable list of recovered sections with their NEW body evidence — the engineer input."""
    reduced = reanchor_uncertified(kconn, idx_conn, doc_id, subject, taught_at_class)
    items: List[dict] = []
    for ch_no, cd in reduced.items():
        ev = S.section_evidence(kconn, cd)
        for sec in sorted(cd["topics"], key=lambda s: tuple(int(p) for p in s.split("."))):
            t = cd["topics"][sec]
            e = ev.get(sec)
            items.append({
                "chapter_no": ch_no, "section": sec, "title": t["title"],
                "section_heading": f"{sec} {t['title']}",
                "reanchored_from_toc_ordinal": t["reanchored_from_toc"],
                "reanchored_to_body_ordinal": t["reanchored_to"],
                "anchor_chunk": t["chunk_id"],
                "evidence": (e["text"] if e else ""),
            })
    return items
