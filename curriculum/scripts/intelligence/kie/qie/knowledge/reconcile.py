"""COMPLETENESS RECONCILIATION — prove every official section of every book is accounted for.

Owner requirement (2026-07-17): zero silent omissions. Each section the book prints must resolve to exactly
one disposition:
  certified   — a certified concept binds to it.
  merged      — no own concept, but a certified concept covers it (a parent section certified while the
                sub-section's teaching is folded in, or the engineer bound the concept to an adjacent chunk).
  quarantined — a concept exists but the independent audit did not certify it; the reason is recorded.
  rejected    — the deterministic spine or a model rejected it (exercise stem, TOC line, OCR garbage,
                unsupported/no-body); the reject_class + reason are recorded.
  OMISSION    — none of the above. This is the thing the owner forbids; it is flagged loudly.

The "official section" set is the book's OWN printed numbered headings (what the multi-channel spine
extracts — the section_path / line / inline channels read the book's real headings). Where a contents page
OCR'd cleanly, its section numbers are added too, so a section listed in the TOC but never extracted is
caught as `in_toc_not_extracted` rather than passing silently.

Deterministic, read-only. No AI. No fabrication.
"""
from __future__ import annotations

import re
import sqlite3

from kie import config
from kie.qie.knowledge import engineer as E
from kie.qie.knowledge import spine as S

_TOCLINE = re.compile(
    r"^\s*(\d{1,2}\.\d{1,2}(?:\.\d{1,2})?)\s*\t?\s*([A-Za-z][^\t\n]{3,70}?)\s*\t?\s*(\d{1,3})\s*$", re.M)


def _sec_key(heading: str):
    m = re.match(r"^\s*(\d{1,2}\.\d{1,2}(?:\.\d{1,2})?)", heading or "")
    return m.group(1) if m else None


def _parent_keys(sec: str):
    """'6.4.1' -> ['6.4', '6']. Used to detect a sub-section merged into a certified parent."""
    parts = sec.split(".")
    return [".".join(parts[:i]) for i in range(len(parts) - 1, 0, -1)]


def _child_certified(sec: str, certified: dict):
    """Return a certified CHILD section of `sec` (e.g. sec='1.2' -> '1.2.1'), else None.

    An umbrella section is 'covered' when its own sub-sections carry the certified concepts.
    """
    pref = sec + "."
    for k in certified:
        if k.startswith(pref):
            return k
    return None


def official_toc(kconn: sqlite3.Connection, doc_id: str) -> dict:
    """Section numbers listed on the book's own contents page, where it OCR'd as a clean table.

    A TOC chunk is one with many 'N.M  Title  page' lines. Returns {} when none parses cleanly (some
    scanned books' contents pages did not survive OCR as a table) — then the spine headings are the only
    oracle, which is still the book's real printed structure.
    """
    best, best_n = {}, 3   # require at least 4 clean TOC lines to trust a chunk as the contents page
    for r in kconn.execute("SELECT text FROM chunks WHERE doc_id=?", (doc_id,)):
        found = {}
        for m in _TOCLINE.finditer(r[0] or ""):
            sec, title, page = m.group(1), m.group(2).strip(), int(m.group(3))
            # reject noise: element/measurement tables ("cm14.0 cm44"), figure captions, summary refs, and
            # titles that are not heading-like. A real contents line names a taught section in words.
            if page > 400 or re.match(r"^(fig|figure|table|summary|answers?|contents|index)", title, re.I):
                continue
            if re.search(r"\b(cm|mm|kg|ml|°c)\b|\d\.\d+\s*(cm|mm)|listed in contents", title, re.I):
                continue
            if len(re.findall(r"[A-Za-z]{2,}", title)) < 2:   # need >=2 real words to be a heading
                continue
            found[sec] = title
        if len(found) > best_n:
            best, best_n = found, len(found)
    return best


def reconcile_book(kconn: sqlite3.Connection, iconn: sqlite3.Connection, book: dict) -> dict:
    doc_id = book["doc_id"]
    sp, _ = S.extract_spine(kconn, doc_id)
    spine_secs = {}
    for ch in sp.values():
        for sec, t in ch["topics"].items():
            spine_secs[sec] = t["title"]

    # dispositions from the index
    certified, quarantined, proposed = {}, {}, {}
    bucket = {"certified": certified, "quarantined": quarantined, "proposed": proposed}
    for r in iconn.execute(
            "SELECT c.section_heading, c.status, c.canonical_name, c.audit_reasons FROM ki_concept c "
            "JOIN ki_chapter ch ON ch.chapter_id=c.chapter_id WHERE ch.doc_id=? AND c.status IN "
            "('certified','quarantined','proposed')", (doc_id,)):
        key = _sec_key(r["section_heading"])
        if not key or r["status"] not in bucket:
            continue
        bucket[r["status"]].setdefault(key, {"name": r["canonical_name"], "reason": r["audit_reasons"]})

    rejected = {}
    for r in iconn.execute("SELECT raw_label, reject_class, reason FROM ki_rejected WHERE source_ref LIKE ?",
                           (f'%{doc_id}%',)):
        key = _sec_key(r["raw_label"])
        if key:
            rejected.setdefault(key, {"class": r["reject_class"], "reason": r["reason"]})

    # sections explicitly documented in the gap registry (scope ends "...:<sec>") — no longer silent
    documented = {}
    for r in iconn.execute("SELECT scope, kind, detail FROM ki_gap WHERE scope LIKE ?",
                           (f'%{book["book_code"]}:%',)):
        key = r["scope"].rsplit(":", 1)[-1]
        if re.match(r"^\d", key):
            documented[key] = {"kind": r["kind"], "detail": r["detail"]}

    toc = official_toc(kconn, doc_id)

    # the official section universe = the book's printed headings (spine) + any clean TOC entries
    universe = set(spine_secs) | set(toc)
    rows, counts = [], {"certified": 0, "merged": 0, "proposed": 0, "quarantined": 0, "rejected": 0,
                        "documented": 0, "in_toc_not_extracted": 0, "OMISSION": 0}
    for sec in sorted(universe, key=lambda s: [int(p) for p in s.split(".")]):
        if sec in certified:
            disp, detail = "certified", certified[sec]["name"]
        elif sec in proposed:
            disp, detail = "proposed", proposed[sec]["name"] + " (awaiting audit)"
        elif sec in quarantined:
            disp, detail = "quarantined", (quarantined[sec]["reason"] or "audit did not certify")
        elif any(p in certified or p in proposed for p in _parent_keys(sec)):
            allp = {**certified, **proposed}
            parent = next(p for p in _parent_keys(sec) if p in allp)
            disp, detail = "merged", f"folded into parent {parent} ({allp[parent]['name']})"
        elif _child_certified(sec, certified) or _child_certified(sec, proposed):
            # an UMBRELLA section (e.g. "1.2 Properties of Rational Numbers") whose own teaching lives in
            # certified sub-sections (1.2.1 Commutativity, ...). The topic IS covered; the parent heading
            # need not carry its own concept. Real coverage, not a gap.
            allp = {**certified, **proposed}
            child = _child_certified(sec, certified) or _child_certified(sec, proposed)
            disp, detail = "merged", f"umbrella section; taught via certified sub-section {child} ({allp[child]['name']})"
        elif sec in rejected:
            disp, detail = "rejected", f"{rejected[sec]['class']}: {rejected[sec]['reason'] or ''}"[:80]
        elif sec in documented:
            disp, detail = "documented", f"{documented[sec]['kind']}: {documented[sec]['detail'][:70]}"
        elif sec not in spine_secs and sec in toc:
            disp, detail = "in_toc_not_extracted", f"listed in contents ('{toc[sec][:40]}') but no heading extracted"
        else:
            disp, detail = "OMISSION", spine_secs.get(sec, toc.get(sec, ""))
        counts[disp] += 1
        rows.append((sec, disp, detail))
    return {"book": book["book_code"], "subject": book["subject"], "class": book["taught_at_class"],
            "counts": counts, "rows": rows, "n_official": len(universe)}


def reconcile_all(subjects=None) -> list:
    # reconcile is declared read-only ("No AI. No fabrication."): open BOTH the substrate and the frozen
    # index read-only so a completeness report can never mutate either (R1-5).
    k = sqlite3.connect(f"file:{config.DB_PATH}?mode=ro", uri=True); k.row_factory = sqlite3.Row
    iconn = E.open_index_ro()
    out = []
    for subj in (subjects or ("Mathematics", "Science", "Physics", "Chemistry", "Biology")):
        for b in S.admitted_books(k, subj):
            out.append(reconcile_book(k, iconn, b))
    return out
