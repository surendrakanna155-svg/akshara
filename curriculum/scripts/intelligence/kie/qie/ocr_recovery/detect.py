"""Detect low-quality OCR documents against the FROZEN kie.db (opened mode=ro).

A document is a recovery candidate when EITHER:
  * its parser_class is 'scanned_image' or 'sparse_text' (the classes that went through OCR / had little
    embedded text — the structural signal), OR
  * the deterministic quality.score() of its concatenated chunk text is below LOW_SCORE_THRESHOLD (a
    content signal — catches a doc mislabeled born-digital that is nonetheless garbage).

For each candidate we record the current per-doc score and the WORST-scoring pages (the re-OCR targets), so
the pipeline re-OCRs only the pages that need it, not every page. This module WRITES only the derived store;
kie.db is read-only throughout and left byte-identical.
"""
from __future__ import annotations

import json
from collections import defaultdict
from datetime import datetime, timezone
from typing import List, Optional

from kie.qie.ocr_recovery import quality as Q
from kie.qie.ocr_recovery import store as ST

# parser_class values that are structurally OCR-suspect.
SUSPECT_CLASSES = ("scanned_image", "sparse_text")
# A born-digital doc whose text nonetheless scores below this is flagged on the content signal.
LOW_SCORE_THRESHOLD = 0.62
# How many worst pages to record as re-OCR targets per candidate (keeps the bounded run bounded).
WORST_PAGES_KEEP = 6


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _page_texts(kie, doc_id: str) -> "tuple[dict[int, str], int]":
    """Concatenate chunk text per page (page_start..page_end inclusive) — an approximation of the frozen
    per-page OCR text, in document order. A chunk spanning pages contributes to each page it covers."""
    rows = kie.execute(
        "SELECT ordinal, page_start, page_end, text FROM chunks WHERE doc_id=? ORDER BY ordinal", (doc_id,)
    ).fetchall()
    by_page: "dict[int, list]" = defaultdict(list)
    for r in rows:
        ps = r["page_start"] if r["page_start"] is not None else 1
        pe = r["page_end"] if r["page_end"] is not None else ps
        for p in range(ps, pe + 1):
            by_page[p].append(r["text"] or "")
    return {p: "\n".join(parts) for p, parts in by_page.items()}, len(rows)


def scan(kie, *, limit: Optional[int] = None) -> List[dict]:
    """Pure detection: return candidate dicts (no writes). Ordered deterministically by doc_id."""
    docs = kie.execute(
        "SELECT doc_id, corpus, rel_path, sha256, pages, parser_class, kind "
        "FROM source_documents ORDER BY doc_id"
    ).fetchall()
    out: List[dict] = []
    for d in docs:
        if d["kind"] not in ("pdf", "file"):     # OCR recovery only applies to page-rendered PDFs
            continue
        structural = d["parser_class"] in SUSPECT_CLASSES
        page_texts, n_chunks = _page_texts(kie, d["doc_id"])
        concat = "\n".join(page_texts[p] for p in sorted(page_texts))
        cur_score = Q.score(concat) if concat.strip() else 0.0
        content_low = bool(concat.strip()) and cur_score < LOW_SCORE_THRESHOLD
        if not (structural or content_low):
            continue
        trigger = "+".join([s for s, ok in (("parser_class", structural), ("low_score", content_low)) if ok])
        worst = sorted(((p, Q.score(t)) for p, t in page_texts.items() if t.strip()), key=lambda x: (x[1], x[0]))
        worst_pages = [{"page": p, "score": round(s, 6)} for p, s in worst[:WORST_PAGES_KEEP]]
        out.append({
            "doc_id": d["doc_id"], "corpus": d["corpus"], "rel_path": d["rel_path"], "sha256": d["sha256"],
            "pages": d["pages"], "parser_class": d["parser_class"], "trigger": trigger,
            "current_score": round(cur_score, 6), "worst_pages": worst_pages, "n_chunks": n_chunks,
        })
        if limit and len(out) >= limit:
            break
    return out


def build(*, out_db_path=None, kie_db_path=None, limit: Optional[int] = None) -> dict:
    """Detect candidates and persist them into the derived store (idempotent upsert). Returns a summary."""
    kie = ST.open_kie_ro(kie_db_path)
    try:
        candidates = scan(kie, limit=limit)
    finally:
        kie.close()
    conn = ST.open_store(out_db_path, writable=True)
    try:
        now = _now()
        for c in candidates:
            conn.execute(
                "INSERT INTO recovery_candidate(doc_id, corpus, rel_path, sha256, pages, parser_class, trigger, "
                "current_score, worst_pages, n_chunks, detected_at) VALUES (?,?,?,?,?,?,?,?,?,?,?) "
                "ON CONFLICT(doc_id) DO UPDATE SET current_score=excluded.current_score, "
                "worst_pages=excluded.worst_pages, trigger=excluded.trigger, detected_at=excluded.detected_at",
                (c["doc_id"], c["corpus"], c["rel_path"], c["sha256"], c["pages"], c["parser_class"],
                 c["trigger"], c["current_score"], json.dumps(c["worst_pages"]), c["n_chunks"], now),
            )
        conn.commit()
    finally:
        conn.close()
    by_trigger: "dict[str,int]" = defaultdict(int)
    for c in candidates:
        by_trigger[c["trigger"]] += 1
    return {"candidates": len(candidates), "by_trigger": dict(by_trigger)}
