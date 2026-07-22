"""Program B · B2 (part 1) — subject attribution from the SOURCE DOCUMENT's own structure (OD-4).

A competitive exam paper is multi-subject; the subject of a question is fixed by which subject SECTION it sits
in, not by any concept-code prefix (the mislabelled prefix is defect D3, never consulted here). This walks each
DNA-eligible paper's chunks IN DOCUMENT ORDER and attributes a subject to every chunk:
  * `section_path` names a subject   → that subject (the parser's own structural heading; authoritative)
  * else an in-text subject HEADER   → that subject, and it (re)sets the CURRENT subject for following chunks
  * else                             → inherit the current subject (last header wins)
  * before any header / no header     → honest-null (subject NULL), never guessed.

A header must name EXACTLY ONE subject next to a PART/SECTION cue — a multi-subject cover line
("NEET 2016 (Physics, Chemistry and Biology)") is NOT a header. Derived, read-only over the frozen kie.db.
"""
from __future__ import annotations

import json
import re
from datetime import datetime, timezone
from typing import Dict, List, Optional, Tuple

from kie.qie.pyq import store as ST
from kie.qie.pyq import source_class as SC
from kie.qie.pyq import taxonomy as TX

_SUBJ = r"physics|chemistry|mathematics|maths|biology|botany|zoology"
# A subject-section HEADER: a subject name TIGHTLY bound to a PART/SECTION cue (either order).
#  * subject-first ("Physics : Section", "PHYSICS SECTION"): subject then ≤3 separator chars then section/part.
#  * section-first ("PART II PHYSICS", "SECTION-A BOTANY"): the cue is \b-anchored (so 'particle'/'department'/
#    'apart' never match) and only NUMERALS + section punctuation may sit between it and the subject (so prose
#    like "part of physics" — 'of' is neither — never matches).
_HEADER_RE = re.compile(
    rf"(?:{_SUBJ})[\s:.\-–]{{0,3}}(?:section|part)\b"
    # section-first: cue, then an OPTIONAL section label — a single letter (A/B…) or a roman/arabic numeral
    # (so "SECTION-A", "PART II", "PART – 1" match) but NOT a word like "of" — then the subject.
    rf"|\b(?:section|part)\b[\s:.\-–]*(?:[a-z]\b|[ivx\d]+)?[\s:.\-–]*(?:{_SUBJ})",
    re.I)
# a header within the first _START_WINDOW chars is a clean section START (the whole chunk is the new subject);
# a header DEEPER than that means the chunk straddles a boundary (prior-subject content precedes it).
_START_WINDOW = 50


def _single_subject(text: str) -> Optional[str]:
    """The subject named in `text` iff EXACTLY ONE canonical subject appears, else None (multi-subject → None)."""
    subs = TX.subject_signals(text or "")
    return next(iter(subs)) if len(subs) == 1 else None


def _headers_in_text(text: str) -> List[Tuple[int, str]]:
    """[(offset, subject)] for each subject-section header in `text`, left to right. Deterministic."""
    out: List[Tuple[int, str]] = []
    for m in _HEADER_RE.finditer(text or ""):
        s = TX.canonical_subject(m.group(0))
        if s:
            out.append((m.start(), s))
    return out


def detect_header_subject(section_path: str, text: str) -> Tuple[Optional[str], Optional[str]]:
    """(subject, method) if this chunk is a CLEAN subject-section start, else (None, None). A chunk that straddles
    a boundary (a header deep in the chunk, or >1 distinct subject header) is NOT a clean header — segment_doc
    handles those as honest-null. `section_path` naming one subject (with no in-text header) is authoritative."""
    hs = _headers_in_text(text)
    subs = {s for _, s in hs}
    if hs:
        if len(subs) == 1 and hs[0][0] <= _START_WINDOW:
            return next(iter(subs)), "text_header"          # clean new-section start
        return None, None                                    # boundary/multi-subject chunk → not a clean header
    sp_subj = _single_subject((section_path or "").split(">")[0])
    if sp_subj:
        return sp_subj, "section_path"
    return None, None


def segment_doc(chunks: List[Tuple[int, str, str]]) -> List[Tuple[int, Optional[str], str, int]]:
    """Attribute a subject to each (ordinal, section_path, text) chunk, IN DOCUMENT ORDER. Offset-aware, so a
    chunk that STRADDLES a subject boundary is honest-null (never stamped with one wrong subject) while the
    current subject still advances. Returns (ordinal, subject, method, is_header). Pure + deterministic."""
    out: List[Tuple[int, Optional[str], str, int]] = []
    current: Optional[str] = None
    for ordinal, sp, text in chunks:
        hs = _headers_in_text(text or "")
        subs = {s for _, s in hs}
        if hs:
            if len(subs) > 1:
                # ≥2 distinct subject headers in one chunk → it straddles a boundary. Honest-null (no single
                # subject is correct) but advance `current` to the LAST header's subject.
                current = hs[-1][1]
                out.append((ordinal, None, "mixed_boundary", 0))
            else:
                s = next(iter(subs))
                if hs[0][0] <= _START_WINDOW:
                    current = s                              # clean new-section start → whole chunk is new subject
                    out.append((ordinal, s, "text_header", 1))
                elif s == current:
                    # a deep header naming the SAME subject already in force is a CONTINUATION (a sub-section /
                    # a per-question subject tag), NOT a boundary — attribute it (no false-subject risk).
                    out.append((ordinal, s, "continuation", 0))
                else:
                    # a deep header naming a DIFFERENT subject → the chunk straddles a real boundary → honest-null,
                    # advance `current` to the new subject for the chunks that follow.
                    current = s
                    out.append((ordinal, None, "mixed_boundary", 0))
            continue
        sp_subj = _single_subject((sp or "").split(">")[0])
        if sp_subj:                                          # no in-text header → trust the parser's structural path
            current = sp_subj
            out.append((ordinal, sp_subj, "section_path", 0))
        elif current is not None:
            out.append((ordinal, current, "inherited_from_header", 0))
        else:
            out.append((ordinal, None, "honest_null", 0))
    return out


def build(pyq_db_path=None) -> Dict[str, object]:
    """Materialize pyq_chunk_subject for every DNA-eligible doc. Idempotent. READ-ONLY over kie.db.
    Requires B1 (pyq_source_class) to have been built first."""
    # 1) eligible doc ids from the B1 store
    store = ST.open_store(pyq_db_path, writable=True)
    try:
        eligible_ids = [r[0] for r in store.execute(
            "SELECT doc_id FROM pyq_source_class WHERE eligible_for_dna=1")]
    finally:
        store.close()

    # 2) read each eligible doc's chunks (ordered) from the frozen kie.db, segment, collect rows
    kie = SC._open_kie_ro()
    rows: List[tuple] = []
    try:
        for doc_id in eligible_ids:
            chunks = [(r["ordinal"], r["section_path"], r["text"]) for r in kie.execute(
                "SELECT ordinal, section_path, text FROM chunks WHERE doc_id=? ORDER BY ordinal", (doc_id,))]
            for ordinal, subj, method, is_hdr in segment_doc(chunks):
                rows.append((doc_id, ordinal, subj, method, is_hdr))
    finally:
        kie.close()

    now = datetime.now(timezone.utc).isoformat()
    conn = ST.open_store(pyq_db_path, writable=True)
    try:
        conn.execute("DELETE FROM pyq_chunk_subject")
        conn.executemany("INSERT INTO pyq_chunk_subject (doc_id, ordinal, subject, subject_method, is_header) "
                         "VALUES (?,?,?,?,?)", rows)
        stats = _tally(rows, len(eligible_ids))
        conn.execute("INSERT INTO pyq_meta(key,value) VALUES ('b2_subject_built_at', ?) "
                     "ON CONFLICT(key) DO UPDATE SET value=excluded.value", (now,))
        conn.execute("INSERT INTO pyq_meta(key,value) VALUES ('b2_subject_stats', ?) "
                     "ON CONFLICT(key) DO UPDATE SET value=excluded.value", (json.dumps(stats, sort_keys=True),))
        conn.commit()
    finally:
        conn.close()
    return {"eligible_docs": len(eligible_ids), "chunks": len(rows), "stats": stats}


def _tally(rows: List[tuple], n_docs: int) -> Dict[str, object]:
    by_subject: Dict[str, int] = {}
    docs_with_subject = set()
    for doc_id, ordinal, subj, method, is_hdr in rows:
        # keep the two honest-null states DISTINCT in the summary (the DB column already distinguishes them):
        # a straddling boundary vs a genuinely header-less chunk.
        key = subj if subj else ("(mixed_boundary)" if method == "mixed_boundary" else "(honest_null)")
        by_subject[key] = by_subject.get(key, 0) + 1
        if subj:
            docs_with_subject.add(doc_id)
    return {"chunks_by_subject": dict(sorted(by_subject.items())),
            "docs_with_any_subject": len(docs_with_subject), "eligible_docs": n_docs,
            "subject_doc_coverage": round(len(docs_with_subject) / n_docs, 4) if n_docs else 0.0}


def subject_of_chunk(doc_id: str, ordinal: int, pyq_db_path=None) -> Optional[str]:
    """The attributed subject of one chunk (honest-null → None). Used by B3 to inherit a question's subject."""
    conn = ST.open_store(pyq_db_path, writable=False)
    try:
        r = conn.execute("SELECT subject FROM pyq_chunk_subject WHERE doc_id=? AND ordinal=?",
                         (doc_id, ordinal)).fetchone()
        return r[0] if r else None
    finally:
        conn.close()


if __name__ == "__main__":
    print(json.dumps(build(), indent=2))
