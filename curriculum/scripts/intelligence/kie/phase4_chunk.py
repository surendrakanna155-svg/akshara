"""Phase 4 — Chunking Engine. Deterministic, structure-aware chunking + FTS5 index.

Splits parsed documents (Phase 2) into retrieval-sized chunks that respect
structure: section headings bound chunks, tables stay atomic, and a token cap
prevents over-long chunks. Born-digital docs use PyMuPDF block/font structure;
OCR docs (no blocks) fall back to paragraph splitting. Each chunk carries page +
section-path provenance and is indexed into the FTS5 lexical search table (the
deterministic default retrieval layer; no embeddings, no AI).
"""
from __future__ import annotations

import hashlib
import json
import re
from typing import Iterator, List, Optional, Tuple

from kie import config, ledger, store

TARGET_TOKENS = 350
_HEADING_RATIO = 1.15
_WS = re.compile(r"\s+")
_PARA = re.compile(r"\n\s*\n")


def _tokens(text: str) -> int:
    return len(_WS.findall(text.strip())) + 1 if text.strip() else 0


def _median(values: List[float]) -> float:
    s = sorted(values)
    n = len(s)
    if n == 0:
        return 0.0
    return s[n // 2] if n % 2 else (s[n // 2 - 1] + s[n // 2]) / 2


def _looks_like_heading(text: str) -> bool:
    t = text.strip()
    return 2 <= len(t) <= 120 and bool(re.search(r"[A-Za-z]", t)) and len(t.split()) <= 14


def _stream_blocks(pages: List[dict]) -> Iterator[Tuple[int, str, float]]:
    """(page, text, size). OCR pages (no blocks) split into size-0 paragraphs."""
    for p in pages:
        blocks = p.get("blocks")
        if blocks:
            for b in blocks:
                t = (b.get("text") or "").strip()
                if t:
                    yield p["page"], t, round(float(b.get("size", 0.0)), 1)
        else:
            for para in _PARA.split(p.get("text", "") or ""):
                para = para.strip()
                if para:
                    yield p["page"], para, 0.0


def chunk_pages(pages: List[dict], tables: Optional[List[dict]] = None,
                target_tokens: int = TARGET_TOKENS) -> List[dict]:
    stream = list(_stream_blocks(pages))
    sized = [s for _, _, s in stream if s > 0]
    body = _median(sized)
    heading_sizes = {s for s in set(sized) if body and s >= body * _HEADING_RATIO}
    level_of = {s: i + 1 for i, s in enumerate(sorted(heading_sizes, reverse=True))}

    chunks: List[dict] = []
    crumb: List[str] = []
    buf: List[str] = []
    buf_pages: List[int] = []
    ordinal = 0

    def flush(block_type: str = "paragraph") -> None:
        nonlocal ordinal, buf, buf_pages
        text = "\n".join(buf).strip()
        buf, buf_pages_local = [], buf_pages
        buf_pages = []
        if not text:
            return
        ordinal += 1
        chunks.append({
            "ordinal": ordinal,
            "page_start": buf_pages_local[0] if buf_pages_local else None,
            "page_end": buf_pages_local[-1] if buf_pages_local else None,
            "block_type": block_type,
            "section_path": " > ".join(crumb),
            "text": text,
            "token_est": _tokens(text),
        })

    for page, text, size in stream:
        if size in heading_sizes and _looks_like_heading(text):
            flush()
            crumb = crumb[: level_of[size] - 1] + [text]
            continue
        buf.append(text)
        buf_pages.append(page)
        if _tokens("\n".join(buf)) >= target_tokens:
            flush()
    flush()

    # tables are atomic chunks (kept out of prose flow)
    for t in (tables or []):
        rows = t.get("rows") or []
        rendered = "\n".join(" | ".join((c or "") for c in row) for row in rows).strip()
        if not rendered:
            continue
        ordinal += 1
        chunks.append({
            "ordinal": ordinal, "page_start": t.get("page"), "page_end": t.get("page"),
            "block_type": "table", "section_path": "", "text": rendered, "token_est": _tokens(rendered),
        })
    return chunks


def process_document(conn, doc_row) -> int:
    did = doc_row["doc_id"]
    parsed = json.loads((config.PARSED_DIR / f"{did}.json").read_text())
    chunks = chunk_pages(parsed.get("pages", []), parsed.get("tables"))
    with store.txn(conn):
        # Delete FTS rows FIRST (they are found via the chunks table), then the chunks.
        conn.execute(
            "DELETE FROM chunks_fts WHERE chunk_id IN (SELECT chunk_id FROM chunks WHERE doc_id = ?)",
            (did,),
        )
        conn.execute("DELETE FROM chunks WHERE doc_id = ?", (did,))
        for c in chunks:
            cid = f"{did}#{c['ordinal']}"
            sha = hashlib.sha256(c["text"].encode("utf-8")).hexdigest()
            conn.execute(
                """INSERT INTO chunks(chunk_id, doc_id, ordinal, page_start, page_end, char_start, char_end,
                                      block_type, section_path, text, token_est, sha256, lang)
                   VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                (cid, did, c["ordinal"], c["page_start"], c["page_end"], None, None,
                 c["block_type"], c["section_path"], c["text"], c["token_est"], sha, "en"),
            )
            conn.execute("INSERT INTO chunks_fts(text, chunk_id) VALUES (?, ?)", (c["text"], cid))
        ledger.record(conn, did, "chunk", "done", input_sha256=doc_row["sha256"],
                      output_ref=f"chunks:{len(chunks)}")
    return len(chunks)


def run(conn, limit: Optional[int] = None, force: bool = False) -> dict:
    summary = {"processed": 0, "skipped": 0, "failed": 0, "chunks": 0}
    rows = conn.execute(
        "SELECT s.* FROM source_documents s JOIN parsed_documents p ON p.doc_id = s.doc_id "
        "WHERE s.certify_status = 'certified' ORDER BY s.doc_id"
    ).fetchall()
    for doc_row in rows:
        if limit and summary["processed"] >= limit:
            break
        did = doc_row["doc_id"]
        if not ledger.needs_run(conn, did, "chunk", doc_row["sha256"], force=force):
            summary["skipped"] += 1
            continue
        try:
            n = process_document(conn, doc_row)
        except Exception as exc:
            ledger.record(conn, did, "chunk", "failed", input_sha256=doc_row["sha256"],
                          error=f"{type(exc).__name__}: {exc}")
            conn.commit()
            summary["failed"] += 1
            continue
        summary["processed"] += 1
        summary["chunks"] += n
    return summary


def search(conn, query: str, limit: int = 10) -> List[dict]:
    """Deterministic BM25 lexical retrieval over chunks (FTS5)."""
    rows = conn.execute(
        "SELECT c.chunk_id, c.doc_id, c.section_path, c.text "
        "FROM chunks_fts f JOIN chunks c ON c.chunk_id = f.chunk_id "
        "WHERE chunks_fts MATCH ? ORDER BY bm25(chunks_fts) LIMIT ?",
        (query, limit),
    ).fetchall()
    return [dict(r) for r in rows]
