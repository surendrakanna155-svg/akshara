"""E-lite ingestion boundary (Phase A4) — preserve the structure the frozen phases drop.

The current phase2 extracts images/equations into a parsed side-file and phase4 discards them; question/
option/answer/solution boundaries are never detected. E-lite is an ADDITIVE extractor that runs ALONGSIDE
the frozen phases (it does NOT modify phase2/phase4): given a doc's parsed structure, it detects question
boundaries + options + answer keys and persists visual assets (images/equations/tables) with provenance into
qie.db, so nothing a source question depends on is silently lost when the ~200-300 incoming board PDFs ingest.

Deterministic-first (numbering + option-marker + "Answer (n)" regex — the same signals validated on real
corpus in Phase-0b). Read-only w.r.t. kie.db; writes qie.db (local). stdlib-only.
"""
from __future__ import annotations

import hashlib
import json
import re
import sqlite3
from typing import Dict, List, Optional

_QNUM = re.compile(r"(?:^|\n)\s*(\d{1,3})\s*[.\)]\s+")
_OPT = re.compile(r"\((\d)\)\s*([^\(\n]{0,160}?)(?=\s*\(\d\)|\n|Answer|Sol\.|$)", re.S)
_ANS = re.compile(r"Answer\s*\((\d)\)", re.I)
_SOL = re.compile(r"Sol\.\s*(.{0,240})", re.S | re.I)


def _qid(doc_id: str, page, num: str, stem: str) -> str:
    return "Q_" + hashlib.sha256(f"{doc_id}|{page}|{num}|{stem[:40]}".encode()).hexdigest()[:16]


def _vid(doc_id: str, page, kind: str, digest: str, i: int) -> str:
    return "V_" + hashlib.sha256(f"{doc_id}|{page}|{kind}|{digest}|{i}".encode()).hexdigest()[:16]


def extract_questions(doc_id: str, page_text: str, page: Optional[int] = None) -> List[dict]:
    """Detect question boundaries (stem/options/answer/solution) in one page's text."""
    out = []
    idxs = [(m.start(), m.group(1)) for m in _QNUM.finditer(page_text)]
    for i, (pos, num) in enumerate(idxs):
        end = idxs[i + 1][0] if i + 1 < len(idxs) else len(page_text)
        seg = page_text[pos:end]
        opts = {}
        for n, o in _OPT.findall(seg):
            n = int(n)
            if n in (1, 2, 3, 4) and n not in opts and o.strip():
                opts[n] = o.strip()
        if len(opts) != 4:
            continue
        stem = seg[:seg.find("(1)")].strip() if "(1)" in seg else seg[:160]
        stem = re.sub(r"^\d{1,3}\s*[.\)]\s*", "", stem).strip()
        am = _ANS.search(seg)
        sm = _SOL.search(seg)
        out.append({
            "question_id": _qid(doc_id, page, num, stem),
            "doc_id": doc_id, "page": page, "question_number": num,
            "stem": stem, "options": opts,
            "answer_key": am.group(1) if am else None,
            "solution_ref": sm.group(1).strip() if sm else None,
            "extraction_confidence": 1.0 if (am and len(opts) == 4) else 0.6,
        })
    return out


def extract_visuals(doc_id: str, parsed_pages: List[dict]) -> List[dict]:
    """Pull images + equations from a parsed-doc structure (the phase2 output phase4 discards)."""
    out = []
    for p in parsed_pages:
        page = p.get("page")
        for i, img in enumerate(p.get("images", []) or []):
            out.append({"asset_id": _vid(doc_id, page, "raster", img.get("digest", ""), i),
                        "doc_id": doc_id, "page": page, "kind": "raster",
                        "bbox": json.dumps(img.get("bbox")), "digest": img.get("digest"),
                        "dims": json.dumps([img.get("width"), img.get("height")]), "raw": None})
        for i, eq in enumerate(p.get("equations", []) or []):
            out.append({"asset_id": _vid(doc_id, page, "equation", eq.get("text", "")[:32], i),
                        "doc_id": doc_id, "page": page, "kind": "equation",
                        "bbox": json.dumps(eq.get("bbox")), "digest": None, "dims": None,
                        "raw": eq.get("latex") or eq.get("text")})
    return out


def persist(qconn: sqlite3.Connection, questions: List[dict], visuals: List[dict], now: str) -> dict:
    for q in questions:
        qconn.execute(
            "INSERT OR IGNORE INTO elite_question(question_id,doc_id,page,question_number,stem,options,"
            "answer_key,solution_ref,bbox,linked_visual_ids,extraction_confidence,created_at) "
            "VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
            (q["question_id"], q["doc_id"], q.get("page"), q.get("question_number"), q.get("stem"),
             json.dumps(q.get("options")), q.get("answer_key"), q.get("solution_ref"),
             q.get("bbox"), json.dumps(q.get("linked_visual_ids", [])), q.get("extraction_confidence"), now))
    for v in visuals:
        qconn.execute(
            "INSERT OR IGNORE INTO elite_visual_asset(asset_id,doc_id,page,kind,bbox,digest,dims,raw,"
            "linked_question_id,created_at) VALUES (?,?,?,?,?,?,?,?,?,?)",
            (v["asset_id"], v["doc_id"], v.get("page"), v.get("kind"), v.get("bbox"), v.get("digest"),
             v.get("dims"), v.get("raw"), v.get("linked_question_id"), now))
    qconn.commit()
    return {"questions_persisted": len(questions), "visuals_persisted": len(visuals)}


def ingest_parsed_doc(qconn: sqlite3.Connection, doc_id: str, parsed_pages: List[dict], now: str) -> dict:
    """Full E-lite pass for one parsed document: boundaries + visuals -> qie.db. Never touches kie.db."""
    questions = []
    for p in parsed_pages:
        questions += extract_questions(doc_id, p.get("text", "") or "", p.get("page"))
    visuals = extract_visuals(doc_id, parsed_pages)
    res = persist(qconn, questions, visuals, now)
    res["doc_id"] = doc_id
    return res
