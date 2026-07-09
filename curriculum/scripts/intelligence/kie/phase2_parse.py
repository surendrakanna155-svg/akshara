"""Phase 2 — Parser. Local text / table / OCR extraction, routed by parser_strategy.

Deterministic tooling parses everything it can; nothing is ever sent to an LLM
(AIP v3.0 line 200). PyMuPDF extracts born-digital text + block structure (fonts/
sizes, for structure-aware chunking in Phase 4), pdfplumber extracts tables, and
Tesseract OCRs scanned pages. Only CERTIFIED documents are parsed (D-5). Output is
a normalized parse per document at parsed/<doc_id>.json + a parsed_documents row.
"""
from __future__ import annotations

import io
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from typing import List, Optional, Tuple

from kie import config, ledger, phase1_verify, store

try:
    import fitz  # PyMuPDF
except Exception:  # pragma: no cover
    fitz = None
try:
    import pdfplumber
except Exception:  # pragma: no cover
    pdfplumber = None

OCR_DPI = 300
# Below this many extracted chars/page a "text" doc is treated as scanned → OCR fallback.
TEXT_MIN_CHARS_PER_PAGE = 20


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


class ParserUnavailable(RuntimeError):
    pass


# ── text + structure (PyMuPDF) ──────────────────────────────────────────────────
def extract_text_pages(doc) -> List[dict]:
    """Per-page {page, text, blocks[{bbox,text,size,bold}]} — blocks feed Phase-4 chunking."""
    pages = []
    for i, page in enumerate(doc):
        text = page.get_text("text")
        blocks = []
        for b in page.get_text("dict").get("blocks", []):
            if b.get("type") != 0:  # 0 = text block
                continue
            spans = [s for line in b.get("lines", []) for s in line.get("spans", [])]
            if not spans:
                continue
            btext = "".join(s.get("text", "") for s in spans).strip()
            if not btext:
                continue
            sizes = [s.get("size", 0.0) for s in spans]
            fonts = [s.get("font", "") for s in spans]
            blocks.append({
                "bbox": [round(x, 1) for x in b.get("bbox", [])],
                "text": btext,
                "size": round(max(sizes), 1) if sizes else 0.0,
                "bold": any(("bold" in f.lower() or "black" in f.lower()) for f in fonts),
            })
        pages.append({"page": i + 1, "text": text, "blocks": blocks})
    return pages


def extract_tables(path: Path) -> List[dict]:
    if pdfplumber is None:
        return []
    tables: List[dict] = []
    try:
        with pdfplumber.open(str(path)) as pdf:
            for i, page in enumerate(pdf.pages):
                for t in (page.extract_tables() or []):
                    tables.append({"page": i + 1, "rows": t})
    except Exception:
        return tables
    return tables


# ── OCR (Tesseract) ─────────────────────────────────────────────────────────────
def ocr_pages(doc) -> Tuple[List[dict], float]:
    import pytesseract
    from PIL import Image

    pages, confs = [], []
    for i, page in enumerate(doc):
        pix = page.get_pixmap(dpi=OCR_DPI)
        img = Image.open(io.BytesIO(pix.tobytes("png")))
        text = pytesseract.image_to_string(img)
        data = pytesseract.image_to_data(img, output_type=pytesseract.Output.DICT)
        page_confs = [int(c) for c in data.get("conf", []) if str(c).lstrip("-").isdigit() and int(c) >= 0]
        if page_confs:
            confs.append(sum(page_confs) / len(page_confs))
        pages.append({"page": i + 1, "text": text, "blocks": []})
    conf = round(sum(confs) / len(confs), 1) if confs else 0.0
    return pages, conf


# ── per-document dispatch ────────────────────────────────────────────────────────
def _abs_path(doc_row, workspace: Path) -> Path:
    return Path(workspace) / config.CORPORA[doc_row["corpus"]] / doc_row["rel_path"]


def parse_pdf_file(path: Path, strategy: str) -> dict:
    if fitz is None:
        raise ParserUnavailable("PyMuPDF (fitz) not installed")
    with fitz.open(str(path)) as doc:
        pages = extract_text_pages(doc)
        total_chars = sum(len(p["text"]) for p in pages)
        ocr_used = False
        conf: Optional[float] = None
        want_ocr = strategy == "ocr" or (
            doc.page_count and total_chars < TEXT_MIN_CHARS_PER_PAGE * doc.page_count
        )
        if want_ocr:
            pages, conf = ocr_pages(doc)
            ocr_used = True
            method = "tesseract"
        else:
            method = "pymupdf"
    tables = [] if ocr_used else extract_tables(path)
    return _assemble(pages, tables, method, ocr_used, conf)


def parse_archive(path: Path) -> dict:
    if fitz is None:
        raise ParserUnavailable("PyMuPDF (fitz) not installed")
    pages: List[dict] = []
    ocr_used = False
    confs = []
    with zipfile.ZipFile(str(path)) as z:
        for name in sorted(n for n in z.namelist() if n.lower().endswith(".pdf")):
            data = z.read(name)
            with fitz.open(stream=data, filetype="pdf") as doc:
                member_pages = extract_text_pages(doc)
                if doc.page_count and sum(len(p["text"]) for p in member_pages) < (
                    TEXT_MIN_CHARS_PER_PAGE * doc.page_count
                ):
                    member_pages, c = ocr_pages(doc)
                    ocr_used = True
                    confs.append(c)
            for p in member_pages:
                p["member"] = name
                pages.append(p)
    conf = round(sum(confs) / len(confs), 1) if confs else None
    method = "archive:tesseract" if ocr_used else "archive:pymupdf"
    return _assemble(pages, [], method, ocr_used, conf)


def _assemble(pages, tables, method, ocr_used, conf) -> dict:
    return {
        "pages": pages,
        "tables": tables,
        "method": method,
        "ocr_used": ocr_used,
        "confidence": conf,
        "char_count": sum(len(p["text"]) for p in pages),
        "table_count": len(tables),
        "page_count": len(pages),
    }


def parse_document(doc_row, workspace: Path) -> dict:
    strategy = doc_row["parser_strategy"] or "text_extract"
    path = _abs_path(doc_row, workspace)
    if not path.exists():
        raise FileNotFoundError(str(path))
    if doc_row["kind"] == "archive":
        return parse_archive(path)
    return parse_pdf_file(path, strategy)


# ── batch runner ─────────────────────────────────────────────────────────────────
def run(conn, workspace: Optional[Path] = None, limit: Optional[int] = None, force: bool = False) -> dict:
    workspace = Path(workspace) if workspace else config.WORKSPACE
    config.ensure_dirs()
    summary = {"parsed": 0, "skipped": 0, "failed": 0, "ocr": 0, "considered": 0}
    docs = phase1_verify.certified_docs(conn)
    for doc_row in docs:
        if doc_row["parser_strategy"] == "exclude":
            continue
        summary["considered"] += 1
        if limit and summary["parsed"] >= limit:
            break
        did = doc_row["doc_id"]
        if not ledger.needs_run(conn, did, "parse", doc_row["sha256"], force=force):
            summary["skipped"] += 1
            continue
        try:
            parsed = parse_document(doc_row, workspace)
        except Exception as exc:  # isolate per-doc; never abort the batch (§10)
            ledger.record(conn, did, "parse", "failed", input_sha256=doc_row["sha256"],
                          error=f"{type(exc).__name__}: {exc}")
            conn.commit()
            summary["failed"] += 1
            continue
        out_ref = f"parsed/{did}.json"
        (config.PARSED_DIR / f"{did}.json").write_text(_dumps(parsed))
        with store.txn(conn):
            conn.execute(
                """INSERT INTO parsed_documents
                     (doc_id, method, pages, char_count, table_count, ocr_used, output_ref, confidence, created_at)
                   VALUES (?,?,?,?,?,?,?,?,?)
                   ON CONFLICT(doc_id) DO UPDATE SET
                     method=excluded.method, pages=excluded.pages, char_count=excluded.char_count,
                     table_count=excluded.table_count, ocr_used=excluded.ocr_used,
                     output_ref=excluded.output_ref, confidence=excluded.confidence""",
                (did, parsed["method"], parsed["page_count"], parsed["char_count"],
                 parsed["table_count"], 1 if parsed["ocr_used"] else 0, out_ref,
                 parsed["confidence"], _now()),
            )
            ledger.record(conn, did, "parse", "done", input_sha256=doc_row["sha256"], output_ref=out_ref)
        summary["parsed"] += 1
        if parsed["ocr_used"]:
            summary["ocr"] += 1
    return summary


def _dumps(obj) -> str:
    import json
    return json.dumps(obj, ensure_ascii=False, sort_keys=True)
