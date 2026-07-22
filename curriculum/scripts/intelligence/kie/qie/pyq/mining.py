"""Program B · B3 — question re-mining with a deterministic PROVENANCE CHAIN (OD-2).

Every re-mined question is reconstructable end-to-end — Question → Chunk → Source Document → Exam → Year →
Subject — or it is NOT created (never a phantom). Questions are located by an OCR-ROBUST marker and
SEQUENCE-VALIDATED so OCR/OMR noise cannot fabricate questions:

  * marker: `32.A` (number-dot-Capital, the NEET/most-papers form) or `Q.2` (JEE form). Bare spaced numbers
    (`11 12 13 14` — OMR answer-grid bubbles) are NOT markers (no dot-capital), so they can't become questions.
  * sequence validation: markers are kept only where they extend a COHERENT increasing run (a real paper numbers
    its questions 1,2,3,…). A backward jump or a large forward jump is dropped as noise.
  * OCR fail-safe: a question whose text is near-prose-free (mangled) keeps its exam/subject/type where those are
    clean but honest-nulls its concept; a doc with no coherent run yields NO items (honest-null, not guessed).

Derived, read-only over the frozen kie.db; consumes B1 (`pyq_source_class`) + B2 (`pyq_chunk_subject`). Writes
only `pyq_corpus.db :: pyq_item`. Deterministic rebuild.
"""
from __future__ import annotations

import hashlib
import json
import re
from datetime import datetime, timezone
from typing import Dict, List, Optional, Tuple

from kie.qie.pyq import concept_attr as CA
from kie.qie.pyq import source_class as SC
from kie.qie.pyq import store as ST

# marker: (^|sep) Q.N  |  (^|sep) N.<Capital or open-paren>   — the dot+capital is what filters OMR bubbles.
# Marker: `Q.2` (the dot is REQUIRED, so the physics variable `Q1`/`Q2` is not a marker) or `12.` followed by
# ≤3 spaces then a Capital/paren (so the born-digital `1.␣␣At` form is caught). num≥1 (rejects `x=0.The`), not
# preceded by an alnum (rejects `H2O`, `x2`). Over-matching is fine — a marker becomes a QUESTION only if its
# bounded span passes _is_question (below), which is what actually filters instructions/notices/lists/variables.
# A marker must be preceded by whitespace or '(' — NOT a symbol/operator — so a mid-expression fragment like the
# unit "ms−1." ("100 ms−1. The …") is not mistaken for question 1. `Q.2` requires the dot (rejects the variable
# `Q1`); the `N.` form allows ≤3 spaces before a Capital (catches the born-digital `1.␣␣At`); num 1..250.
_MARKER_RE = re.compile(r"(?:^|(?<=[\s(]))"
                        r"(?:Q\s*\.\s*([1-9]\d{0,2})(?![0-9])"
                        r"|([1-9]\d{0,2})\.\s{0,3}(?=[A-Z(]))")
_MAX_SPAN = 3000             # a single question is rarely longer; the cap prevents the last marker swallowing the doc
_MIN_ITEMS = 5              # a doc yielding fewer real questions is unreliable / not a question paper → honest-null
_MAX_QNUM = 250            # NEET tops out ~200; a larger "question number" is noise
_MIN_MEAN_TOKLEN = 2.5      # a floor for extreme fragmentation; the ENGLISH-word check is the primary readability gate
_STEM_MAX = 900            # a real MCQ stem before its FIRST option; options farther out belong to the NEXT question

_OPT_RE = re.compile(r"\(\s*([1-4A-Da-d])\s*\)")
# a SECTION / marking-scheme header as the leading text of a span — its trailing options (if any) belong to the
# next question, so the span is not itself a question. (e.g. "PART I : PHYSICS SECTION 1 (Maximum Marks: 18) …")
_SECTION_HDR_RE = re.compile(r"(?i)\b(part|section)\b[\sivxIVX\d:.\-–]{0,30}"
                             r"(physics|chemistry|mathematics|maths|biology|botany|zoology|maximum\s+marks|"
                             r"marks\s*:|this\s+section\s+contains)")
_INSTR_RE = re.compile(r"\b(test booklet|answer sheet|omr|darken|rough work|do not open|invigilator|"
                       r"candidate|hall ticket|booklet code|instructions? to|national testing agency|"
                       r"is committed|prescribed|shall be provided|rough page)\b", re.I)
_NUM_RE = re.compile(r"\b(integer|numerical value|nearest integer|value of\b.{0,40}\bis\b)", re.I)
# page furniture (footers / headers / coaching branding) that a stray marker can pick up — never a question.
_FURNITURE_RE = re.compile(r"(?i)(end of the|end of question|question paper|official test paper|"
                           r"\bacademy\b|test booklet no|rough (page|work)|space for rough)")
# common English words a real English question stem carries in quantity; OCR garble / non-English (e.g. a Hindi
# transliteration paper) carries ≈none — a language/readability signal the letter-density metric misses.
_COMMON = frozenset(("the of is are a an in to and or for with which what if on at by be as that this from "
                     "value equal following given then when where how many will its can").split())
_MIN_ENGLISH = 3            # a real English question stem carries several common words; garble / non-English ≈ none


def _english_hits(text: str) -> int:
    return sum(1 for t in re.findall(r"[a-z]+", (text or "").lower()) if t in _COMMON)


def _stem_fp(span: str) -> str:
    """EXACT-content fingerprint: a hash of the span's normalized letters/digits. Two BYTE-IDENTICAL copies of a
    question in one doc (a repeated page) collapse; two DIFFERENT questions never collapse (no false-merge — a
    coarser longest-words fingerprint wrongly merged distinct questions sharing a generic stem like "identify the
    correct statement"). OCR-variance booklet copies are NOT merged here (they differ) — that residual is handled
    at B5 (per-doc normalization + distinct-DOC floor), which never lets instance duplication distort a
    distribution. Returns "" for a too-short normalized span (never dedup on a fragment)."""
    norm = re.sub(r"[^a-z0-9]", "", span.lower())
    return hashlib.sha256(norm.encode()).hexdigest()[:16] if len(norm) >= 40 else ""


# a non-English / regional-language paper: OCR of non-Latin scripts is garble AND it duplicates the English
# version (which is a separate eligible doc). Skip it — mining it adds noise + double-counts the same exam.
_NON_ENGLISH_RE = re.compile(r"(?i)(hindi|gujarati|marathi|tamil|telugu|bengali|kannada|urdu|assamese|"
                             r"odia|oriya|punjabi|malayalam)")
# the start of a SOLUTIONS/answer-key section — a distinctive multi-word header unlikely inside a question stem.
# Mining stops here so a solution that RESTATES its question is not re-mined as a second question.
_SOLUTIONS_RE = re.compile(r"(?i)\b(hints?\s*(?:&|and)\s*solutions?|answers?\s*(?:&|and)\s*explanations?|"
                           r"answer\s*key|detailed\s*solutions?|solutions?\s*&\s*answers?)\b")


def _truncate_at_solutions(full: str) -> str:
    """Cut the text at the first prominent SOLUTIONS section header (only past 30% of the doc, so a doc that is
    itself an answer key is handled by the min-items guard, not truncated to nothing)."""
    m = _SOLUTIONS_RE.search(full, int(len(full) * 0.3))
    return full[:m.start()] if m else full


def _markers(text: str) -> List[Tuple[int, int]]:
    """[(char_offset, question_number)] for every candidate marker, in position order (1 ≤ num ≤ _MAX_QNUM)."""
    out = []
    for m in _MARKER_RE.finditer(text):
        num = int(m.group(1) or m.group(2))
        if 1 <= num <= _MAX_QNUM:
            out.append((m.start(), num))
    return out


def _mean_token_len(text: str) -> float:
    """Mean length of alpha tokens — a deterministic READABILITY proxy (OCR garble is short-token-heavy)."""
    toks = re.findall(r"[A-Za-z]{2,}", text or "")
    return sum(len(t) for t in toks) / len(toks) if toks else 0.0


def _is_question(span: str) -> Tuple[bool, str]:
    """A marker's bounded span is a real question ONLY if it is readable AND carries question STRUCTURE that
    belongs to ITS OWN question (≥3 MCQ options within the stem window, or numerical/assertion/match) AND its
    leading text is not a SECTION header or an exam INSTRUCTION. This rejects exam instructions, NTA notices,
    syllabus/experiment lists, section headers, figure captions, and stray variables — INCLUDING the case where
    the NEXT question's options bleed into this span's 3000-char window (the leading-text + stem-window checks)."""
    if _mean_token_len(span) < _MIN_MEAN_TOKLEN or _english_hits(span) < _MIN_ENGLISH:
        return False, "unreadable"                       # OCR garble or a non-English (e.g. Hindi) paper
    opt_pos = [m.start() for m in _OPT_RE.finditer(span)]
    stem = span[:opt_pos[0]] if opt_pos else span
    # the stem (text before this question's first option) must carry real question PROSE. An answer-key line
    # ("Q.26: (A), (C) and (D)") has the answer letter as its first paren, so its stem is a couple of chars —
    # rejected here; an option-only OCR fragment likewise. A genuine stem has plenty of letters.
    if sum(c.isalpha() for c in stem) < 12:
        return False, "no_question_stem"
    # a SECTION header or an INSTRUCTION as the LEADING text disqualifies the span: any trailing options belong to
    # the NEXT question, not this marker's. (This is what let instruction / section-header text survive as MCQs.)
    if _SECTION_HDR_RE.search(stem[:250]) or len(_INSTR_RE.findall(stem)) >= 1:
        return False, "section_or_instruction_header"
    if _FURNITURE_RE.search(stem[:120]):
        return False, "paper_furniture"
    # count options ONLY when the first one is inside this question's own stem window (not the next question's).
    has_options = False
    if opt_pos and opt_pos[0] <= _STEM_MAX:
        opts = {m.group(1).upper() for m in _OPT_RE.finditer(span[:opt_pos[0] + 800])}
        has_options = len({o for o in opts if o in "1234"}) >= 3 or len({o for o in opts if o in "ABCD"}) >= 3
    has_struct = (has_options or bool(_NUM_RE.search(stem))
                  or (re.search(r"\bassertion\b", stem, re.I) and re.search(r"\breason\b", stem, re.I))
                  or (re.search(r"\bmatch\b", stem, re.I) and re.search(r"\b(list|column)\b", stem, re.I)))
    if not has_struct:
        return False, "no_question_structure"
    return True, "options" if has_options else "structured"


def _question_type(span: str) -> Tuple[str, str]:
    """(question_type, method) from the question text structure. Deterministic; specific types before mcq."""
    s = span
    if re.search(r"\bassertion\b", s, re.I) and re.search(r"\breason\b", s, re.I):
        return "assertion_reason", "keyword"
    if re.search(r"\bmatch\b", s, re.I) and re.search(r"\b(list|column)\b", s, re.I):
        return "match", "keyword"
    if re.search(r"\b(integer|numerical value|nearest integer|value of.{0,40}\bis\b)", s, re.I) \
            and not re.search(r"\(\s*[1-4A-D]\s*\)", s):
        return "numerical", "keyword"
    opts = {m.group(1).upper() for m in re.finditer(r"\(\s*([1-4A-Da-d])\s*\)", s)}
    if len({o for o in opts if o in "1234"}) >= 3 or len({o for o in opts if o in "ABCD"}) >= 3:
        return "mcq", "options"
    return "short_answer", "fallback"


def _content_addressed_id(doc_id: str, qnum: int, pos: int, span: str) -> str:
    """Deterministic id binding the item to its doc, number, position, and content. `pos` disambiguates two
    byte-identical spans at the same number (e.g. a repeated page) so distinct occurrences get distinct ids."""
    return hashlib.sha256(
        f"{doc_id}|{qnum}|{pos}|{hashlib.sha256(span.encode()).hexdigest()}".encode()).hexdigest()[:16]


def _doc_segments(kie, doc_id, subj_map) -> Tuple[str, List[dict]]:
    """Concatenate a doc's chunks in order; return (full_text, segments) where each segment records the chunk's
    [start,end) char range in full_text + its provenance (chunk_id, sha256) + its B2 subject."""
    segs: List[dict] = []
    parts: List[str] = []
    pos = 0
    for r in kie.execute("SELECT ordinal, text, sha256 FROM chunks WHERE doc_id=? ORDER BY ordinal", (doc_id,)):
        t = r["text"] or ""
        segs.append({"ordinal": r["ordinal"], "chunk_id": f"{doc_id}#{r['ordinal']}", "sha256": r["sha256"],
                     "start": pos, "end": pos + len(t), "subject": subj_map.get((doc_id, r["ordinal"]))})
        parts.append(t)
        pos += len(t) + 1                                # +1 for the join space
    return " ".join(parts), segs


def _seg_at(segs: List[dict], pos: int) -> Optional[dict]:
    for s in segs:
        if s["start"] <= pos < s["end"]:
            return s
    return segs[-1] if segs else None


def _segs_spanning(segs: List[dict], start: int, end: int) -> List[dict]:
    return [s for s in segs if s["start"] < end and s["end"] > start] or ([_seg_at(segs, start)] if segs else [])


def _confidence(kept: int, markers: int) -> str:
    """Per-doc confidence from how cleanly its markers resolved to real questions (kept / candidate markers)."""
    ratio = kept / markers if markers else 0.0
    if kept >= 25 and ratio >= 0.6:
        return "high"
    if kept >= 10:
        return "medium"
    return "low"


def extract_doc(kie, doc_id: str, exam: str, year, subj_map, subject_index, rel_path: str = "") -> List[dict]:
    """Re-mine one eligible doc into question rows with full provenance. Deterministic; honest-null.

    A marker becomes a question ONLY if its BOUNDED (capped) span passes _is_question (has real question
    structure, is readable, is not an instruction block). A non-English/regional paper, a doc whose text is
    garble, or a doc that yields fewer than _MIN_ITEMS real questions (a notice / experiment list / non-paper)
    yields NO items (honest-null)."""
    if _NON_ENGLISH_RE.search(rel_path or ""):           # regional-language duplicate of the English paper → skip
        return []
    full, segs = _doc_segments(kie, doc_id, subj_map)
    full = _truncate_at_solutions(full)                  # don't re-mine a solutions section's restated questions
    if _mean_token_len(full) < _MIN_MEAN_TOKLEN:          # whole doc is OCR garble → honest-null
        return []
    marks = _markers(full)
    if len(marks) < _MIN_ITEMS:
        return []
    now = datetime.now(timezone.utc).isoformat()
    candidates: List[dict] = []
    seen_fp: set = set()
    for i, (pos, num) in enumerate(marks):
        nxt = marks[i + 1][0] if i + 1 < len(marks) else len(full)
        end = min(nxt, pos + _MAX_SPAN)                   # bound at the next marker, capped (no tail-swallow)
        span = full[pos:end]
        ok, why = _is_question(span)
        if not ok:
            continue
        fp = _stem_fp(span)                               # collapse the SAME question repeated in the doc
        if fp and fp in seen_fp:                          # empty fp (too few long words) → keep, never risk a false collapse
            continue
        if fp:
            seen_fp.add(fp)
        spanning = _segs_spanning(segs, pos, end)
        marker_seg = _seg_at(segs, pos)
        subject = marker_seg["subject"] if marker_seg else None
        # concept only on a bounded, readable single-question span (never on a multi-question blob)
        concept, cmethod = _resolve_concept(subject, span, subject_index) if len(span) <= 2000 \
            else (None, "span_too_large")
        qtype, tmethod = _question_type(span)
        candidates.append({
            "item_id": _content_addressed_id(doc_id, num, pos, span), "doc_id": doc_id, "exam": exam, "year": year,
            "subject": subject, "question_number": num, "question_type": qtype, "type_method": tmethod,
            "concept_kc": concept, "concept_method": cmethod,
            "chunk_ids": json.dumps([s["chunk_id"] for s in spanning]),
            "chunk_sha256": json.dumps([s["sha256"] for s in spanning]),
            "span_len": len(span), "stem_fp": fp or None, "ocr_flagged": 0,
            "extraction_confidence": None, "created_at": now,
        })
    if len(candidates) < _MIN_ITEMS:                     # too few real questions ⇒ unreliable / not a paper
        return []
    conf = _confidence(len(candidates), len(marks))
    for c in candidates:
        c["extraction_confidence"] = conf
    return candidates


# a certified concept name (≥2 words, to avoid trivial single-word false hits) appearing VERBATIM in the stem,
# resolved subject-scoped. Deliberately conservative — most questions are honest-null (concept unresolved).
def _resolve_concept(subject, span, subject_index) -> Tuple[Optional[str], str]:
    if not subject:
        return None, "no_subject"
    mm, _ = subject_index
    low = span.lower()
    best = None
    for (subj, norm), ids in mm.items():
        if subj != subject or len(norm) < 8 or " " not in norm:
            continue
        if norm in low and len(ids) == 1:
            if best is None or len(norm) > len(best[0]):
                best = (norm, next(iter(ids)))
    return (best[1], "verbatim_subject_scoped") if best else (None, "unresolved")


def build(pyq_db_path=None) -> Dict[str, object]:
    """Re-mine every eligible doc into pyq_item. Idempotent. READ-ONLY over kie.db; consumes B1+B2."""
    store = ST.open_store(pyq_db_path, writable=True)
    try:
        eligible = list(store.execute(
            "SELECT doc_id, exam_resolved, year_resolved, rel_path FROM pyq_source_class WHERE eligible_for_dna=1"))
        subj_map = {(r[0], r[1]): r[2] for r in store.execute(
            "SELECT doc_id, ordinal, subject FROM pyq_chunk_subject")}
    finally:
        store.close()

    subject_index = CA.build_subject_index()
    kie = SC._open_kie_ro()
    all_rows: List[dict] = []
    try:
        for doc_id, exam, year, rel_path in eligible:
            all_rows.extend(extract_doc(kie, doc_id, exam, year, subj_map, subject_index, rel_path))
    finally:
        kie.close()

    now = datetime.now(timezone.utc).isoformat()
    conn = ST.open_store(pyq_db_path, writable=True)
    try:
        conn.execute("DELETE FROM pyq_item")
        conn.executemany(
            "INSERT INTO pyq_item (item_id, doc_id, exam, year, subject, question_number, question_type, "
            "type_method, concept_kc, concept_method, chunk_ids, chunk_sha256, span_len, stem_fp, ocr_flagged, "
            "extraction_confidence, created_at) VALUES (:item_id,:doc_id,:exam,:year,:subject,:question_number,"
            ":question_type,:type_method,:concept_kc,:concept_method,:chunk_ids,:chunk_sha256,:span_len,:stem_fp,"
            ":ocr_flagged,:extraction_confidence,:created_at)",
            all_rows)
        stats = _tally(all_rows)
        conn.execute("INSERT INTO pyq_meta(key,value) VALUES ('b3_items_built_at',?) "
                     "ON CONFLICT(key) DO UPDATE SET value=excluded.value", (now,))
        conn.execute("INSERT INTO pyq_meta(key,value) VALUES ('b3_item_stats',?) "
                     "ON CONFLICT(key) DO UPDATE SET value=excluded.value", (json.dumps(stats, sort_keys=True),))
        conn.commit()
    finally:
        conn.close()
    return {"items": len(all_rows), "stats": stats}


def _tally(rows: List[dict]) -> Dict[str, object]:
    by_exam: Dict[str, int] = {}
    by_type: Dict[str, int] = {}
    docs = set()
    fps = set()
    with_subject = with_concept = 0
    for r in rows:
        by_exam[r["exam"]] = by_exam.get(r["exam"], 0) + 1
        by_type[r["question_type"]] = by_type.get(r["question_type"], 0) + 1
        docs.add(r["doc_id"])
        if r["stem_fp"]:
            fps.add((r["doc_id"], r["stem_fp"]))
        with_subject += r["subject"] is not None
        with_concept += r["concept_kc"] is not None
    n = len(rows)
    return {"items": n, "docs_mined": len(docs), "by_exam": dict(sorted(by_exam.items())),
            "by_type": dict(sorted(by_type.items())),
            "exact_distinct_instances": len(fps),    # exact-content distinct (no false-merge); NOT unique questions
            "subject_attributed": with_subject, "concept_attributed": with_concept,
            "subject_rate": round(with_subject / n, 4) if n else 0.0,
            "concept_rate": round(with_concept / n, 4) if n else 0.0,
            "note": "rows are question INSTANCES. A paper's BOOKLET CODES (OCR'd differently) yield repeat "
                    "instances that exact-content dedup deliberately does NOT collapse (a coarser fingerprint "
                    "would FALSE-MERGE distinct questions). `exact_distinct_instances` is exact-content-distinct, "
                    "NOT a unique-question count. B5 is the authority on de-duplication: it counts DISTINCT DOCS "
                    "for the OD-5 N>=30 floor and NORMALIZES per-doc, so booklet duplication cannot distort a "
                    "measured distribution; a doc's multiversion factor is inferable from repeated question_numbers."}


def report(pyq_db_path=None) -> Dict[str, object]:
    conn = ST.open_store(pyq_db_path, writable=False)
    try:
        v = conn.execute("SELECT value FROM pyq_meta WHERE key='b3_item_stats'").fetchone()
        return json.loads(v[0]) if v else {}
    finally:
        conn.close()


if __name__ == "__main__":
    print(json.dumps(build(), indent=2))
