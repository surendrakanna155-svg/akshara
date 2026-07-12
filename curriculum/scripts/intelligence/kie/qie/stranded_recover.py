"""Governed reuse bridge for STRANDED kie.db exam sources (Phase B9).

The corpus-discovery audit found that kie.db already ingested (parsed + OCR'd + chunked) ~362 foundation-exam
docs — NEET, JEE_Main, JEE_Advanced, AIIMS, AIPMT, Practice_Resources, NCERT, boards — that qcorpus never
contained. The miner recovers NEET well (its DPP-style '(1)opt..(4)opt Answer(n)' format), but recovers ~0
from JEE_Main / JEE_Advanced / AIIMS / Practice_Resources because those use OTHER option markers
('1. opt', '(A) opt') and keep answers in SEPARATE key/solution docs.

This bridge REUSES the existing chunk text (NO re-OCR) and recovers the stranded questions with a flexible
multi-format parser, yielding ONLY items for which a SOURCE answer is present (inline 'Answer/Ans (n)', or a
same-document answer-key grid keyed by question number). It preserves provenance (exam, doc_id, question
number, recovery method), never fabricates an answer, and is strictly READ-ONLY on kie.db. Items are meant to
be fed as `extra_items` into the UNCHANGED miner/KVS/Tier-2 pipeline; the caller de-duplicates against the
existing stream by normalized stem. Deterministic, stdlib-only.
"""
from __future__ import annotations

import re
import sqlite3
from typing import Dict, Iterator, List, Optional

from kie.qie import mine

# Sources the base miner strands (NEET recovers natively; textbooks have ~no MCQs). Kept explicit so the
# bridge only ever ADDS the under-recovered exam papers and never reshapes the working NEET/qcorpus streams.
STRANDED_SOURCES = ("JEE_Main", "JEE_Advanced", "AIIMS", "AIPMT", "Practice_Resources", "NTA_Sample")

# Only recover from QUESTION-PAPER doc types. Solution / answer-key docs are prose OCR (esp. scanned AIIMS
# solutions), where a flexible parser mistakes explanation fragments + question numbers for options — noise
# we must not inject. Excluding them keeps the bridge honest: recover clean questions, never solution text.
QUESTION_DOC_TYPES = frozenset({"previous_paper", "sample_paper", "mock_test", "dpp", "collection", "unknown"})

_QNUM = re.compile(r"(?:^|\n)\s*(?:Q\.?\s*)?(\d{1,3})\s*[.\)]\s+")
_OPT_PAREN_NUM = re.compile(r"\((\d)\)\s*([^\(\n]{1,140}?)(?=\s*\(\d\)|\n|$)")
_OPT_DOT_NUM = re.compile(r"(?:^|\s)([1-4])\.\s+([^\n]{1,120}?)(?=\s+[1-4]\.\s|\n|$)")
_OPT_PAREN_ALPHA = re.compile(r"\(([a-dA-D])\)\s*([^\(\n]{1,140}?)(?=\s*\([a-dA-D]\)|\n|$)")
_ANS_INLINE = re.compile(r"Ans(?:wer)?\s*[:.\-]?\s*\(?([1-4a-dA-D])\)?", re.I)
# answer-key grid entry: 'N. (x)' or 'N. x' with x in 1-4 (built into a per-doc {qnum: ans} map)
_GRID_ENTRY = re.compile(r"\b(\d{1,3})\s*[.\)]\s*\(?([1-4])\)?(?![0-9])")

_ALPHA = {"a": "1", "b": "2", "c": "3", "d": "4"}


def _norm_label(lab: str) -> Optional[str]:
    lab = lab.strip().lower()
    if lab in ("1", "2", "3", "4"):
        return lab
    return _ALPHA.get(lab)


def parse_options_multiformat(seg: str) -> Dict[str, str]:
    """Parse an option block trying, in order, '(1)opt', '1. opt', '(a)opt'. Returns {label(1-4): text} with
    >=3 options or {}."""
    for rx in (_OPT_PAREN_NUM, _OPT_DOT_NUM, _OPT_PAREN_ALPHA):
        out: Dict[str, str] = {}
        for lab, txt in rx.findall(seg):
            nl = _norm_label(lab)
            txt = txt.strip()
            if nl and nl not in out and txt:
                out[nl] = txt
        if len(out) >= 3:
            return out
    return {}


def build_answer_grid(text: str) -> Dict[int, str]:
    """Extract a same-document answer-key grid {qnum: '1'..'4'} from a clean RUN of 'N. (x)' entries. Requires
    >=5 monotonically increasing entries so a couple of stray 'N. d' inside prose can't masquerade as a key."""
    entries = [(int(m.group(1)), m.group(2)) for m in _GRID_ENTRY.finditer(text)]
    if len(entries) < 5:
        return {}
    # keep the longest increasing run (a real key lists answers in question order)
    best: List = []
    cur: List = []
    for q, a in entries:
        if not cur or q > cur[-1][0]:
            cur.append((q, a))
        else:
            if len(cur) > len(best):
                best = cur
            cur = [(q, a)]
    if len(cur) > len(best):
        best = cur
    if len(best) < 5:
        return {}
    return {q: a for q, a in best}


def _iter_source_chunks(kconn: sqlite3.Connection, sources):
    kconn.row_factory = sqlite3.Row
    meta = {r["doc_id"]: (r["exam"], r["doc_type"]) for r in
            kconn.execute("SELECT doc_id, exam, doc_type FROM source_documents")}
    want = set(sources)
    for r in kconn.execute("SELECT doc_id, text FROM chunks"):
        ex, dt = meta.get(r["doc_id"], (None, None))
        if ex in want and (dt in QUESTION_DOC_TYPES):
            yield r["doc_id"], ex, r["text"]


def recovered_items(kconn: sqlite3.Connection, sources=STRANDED_SOURCES) -> Iterator[dict]:
    """Yield normalized items {stem, options, answer_label, answer_text, subject, doc_id, source, qnum,
    recovery} recovered from stranded-source chunks, ONLY where a source answer is available (inline or
    same-doc grid). No fabrication; subject via the same guess_subject the miner uses."""
    # pass 1: per-doc answer grids (join whole doc text so a trailing key page is visible to its questions)
    doc_text: Dict[str, List[str]] = {}
    doc_source: Dict[str, str] = {}
    for doc_id, ex, text in _iter_source_chunks(kconn, sources):
        doc_text.setdefault(doc_id, []).append(text)
        doc_source[doc_id] = ex
    for doc_id, parts in doc_text.items():
        full = "\n".join(parts)
        grid = build_answer_grid(full)
        source = doc_source[doc_id]
        for text in parts:
            idxs = [(m.start(), int(m.group(1))) for m in _QNUM.finditer(text)]
            for i, (pos, qnum) in enumerate(idxs):
                end = idxs[i + 1][0] if i + 1 < len(idxs) else len(text)
                seg = text[pos:end]
                opts = parse_options_multiformat(seg)
                if len(opts) < 3:
                    continue
                stem = re.sub(r"^\s*(?:Q\.?\s*)?\d{1,3}\s*[.\)]\s*", "", seg[:220]).strip()
                # answer: inline first, else same-doc grid by question number
                ans_label = None
                recovery = None
                am = _ANS_INLINE.search(seg)
                if am:
                    ans_label = _norm_label(am.group(1))
                    recovery = "inline_answer"
                elif qnum in grid:
                    ans_label = grid[qnum]
                    recovery = "answer_grid"
                if not ans_label:
                    continue
                ans_text = opts.get(ans_label)
                if not ans_text:
                    continue
                subj = mine.guess_subject(stem)
                if not subj:
                    continue
                yield {"stem": stem, "options": opts, "answer_label": ans_label, "answer_text": ans_text,
                       "subject": subj, "doc_id": doc_id, "source": source, "qnum": qnum,
                       "recovery": recovery, "visual_dependent": False}


def coverage(kconn: sqlite3.Connection, sources=STRANDED_SOURCES) -> dict:
    from collections import Counter
    by_src_subj = Counter()
    by_recovery = Counter()
    for it in recovered_items(kconn, sources):
        by_src_subj[(it["source"], it["subject"])] += 1
        by_recovery[it["recovery"]] += 1
    return {"by_source_subject": {f"{s}/{j}": n for (s, j), n in by_src_subj.items()},
            "by_recovery_method": dict(by_recovery),
            "total": sum(by_src_subj.values())}
