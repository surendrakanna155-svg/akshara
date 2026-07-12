"""Staged DPP corpus integration (Phase B4) — bounded, local-only.

Extracts text from DPP (Daily Practice Problem) PDFs (PyMuPDF) OUTSIDE the immutable kie.db baseline and
runs the same recovery/verification the corpus miner uses, so DPP practice problems can add DNA + KVS
corroboration WITHOUT re-ingesting through the frozen phases or touching the 360-doc baseline.

Honest bound: many DPP sheets are IMAGE-HEAVY (options/figures rendered as images, no inline answer key), so
text extraction recovers few complete keyed MCQs from them — those need the visual ingestion pipeline
(Phase E-full). This module reports the actual extractable yield rather than assuming DPPs are text-minable.

Read-only on the PDFs + kie.db (for the concept lexicon); writes qie.db (local). stdlib + PyMuPDF.
"""
from __future__ import annotations

import glob
import re
import sqlite3
from typing import Dict, List, Optional, Set

from kie.qie import mine

# DPP numbering can be "Q1." / "1." — accept both.
_DPP_QNUM = re.compile(r"(?:^|\n)\s*(?:Q\s*)?(\d{1,3})\s*[.\)]\s+", re.I)


def _pdf_text_pages(path: str) -> List[str]:
    import fitz  # imported lazily so the module loads without PyMuPDF for unit tests
    doc = fitz.open(path)
    return [pg.get_text() for pg in doc]


def recover_dpp(text: str) -> List[dict]:
    """Like mine.split_and_recover but tolerant of 'Q1.' numbering."""
    out = []
    idxs = [(m.start(), m.group(1)) for m in _DPP_QNUM.finditer(text)]
    for i, (pos, num) in enumerate(idxs):
        end = idxs[i + 1][0] if i + 1 < len(idxs) else len(text)
        seg = text[pos:end]
        opts = mine.parse_options(seg)
        if len(opts) != 4:
            continue
        stem = seg[:seg.find("(1)")].strip() if "(1)" in seg else seg[:160]
        stem = re.sub(r"^(?:Q\s*)?\d{1,3}\s*[.\)]\s*", "", stem, flags=re.I).strip()
        am = mine._ANS.search(seg) or re.search(r"Ans(?:wer)?\s*[:.\-]?\s*\(?([1-4])\)?", seg, re.I)
        out.append({"stem": stem, "options": opts, "key": int(am.group(1)) if am else None})
    return out


def mine_paths(paths: List[str], by_title: Dict[str, str], verified_facts: Optional[Set[str]] = None,
               max_files: Optional[int] = None) -> dict:
    """Bounded DPP mine. Returns honest yield: files, pages, recovered complete MCQs, keyed, numeric-verified."""
    verified_facts = verified_facts or set()
    files = paths[:max_files] if max_files else paths
    stat = {"files": 0, "pages": 0, "recovered_complete": 0, "with_key": 0,
            "numeric_verified": 0, "kvs_corroborated": 0, "by_subject": {}}
    subj_count: Dict[str, int] = {}
    for p in files:
        try:
            pages = _pdf_text_pages(p)
        except Exception:
            continue
        stat["files"] += 1
        stat["pages"] += len(pages)
        for text in pages:
            for rec in recover_dpp(text):
                stat["recovered_complete"] += 1
                subj = mine.guess_subject(rec["stem"])
                if subj:
                    subj_count[subj] = subj_count.get(subj, 0) + 1
                if rec["key"] is None:
                    continue
                stat["with_key"] += 1
                keyopt = rec["options"].get(rec["key"])
                kv = mine.R.first_number(keyopt) if keyopt else None
                given = mine.R.parse_numbers(rec["stem"])
                if kv is not None and given and subj and mine.R.verify(given, kv, subject=subj):
                    stat["numeric_verified"] += 1
                elif subj and keyopt and mine.is_semantic_answer(keyopt):
                    ck = mine.concept_key(rec["stem"], subj, by_title)
                    if mine.is_resolved_concept(ck) and mine.fact_key(ck, keyopt) in verified_facts:
                        stat["kvs_corroborated"] += 1
    stat["by_subject"] = subj_count
    return stat


def find_dpp_pdfs(root: str) -> List[str]:
    return sorted(glob.glob(f"{root}/**/*.pdf", recursive=True))
