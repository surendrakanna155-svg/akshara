"""Phase 2 — Parser. Local text / table / OCR extraction, routed by parser_strategy.

Deterministic tooling parses everything it can; nothing is ever sent to an LLM
(AIP v3.0 line 200). PyMuPDF is the PRIMARY parser (born-digital text + block structure
with fonts/sizes for Phase-4 chunking); pdfplumber is a table fallback used ONLY where
PyMuPDF finds no table on a ruled page; Tesseract OCRs scanned pages. Only CERTIFIED
documents are parsed (D-5). Output is a normalized parse per document at
parsed/<doc_id>.json + a parsed_documents row.

For the concept-extraction and question-intelligence phases, the parse PRESERVES, in the
shared PDF-point coordinate space (top-left origin):
  • page coordinates (width/height) + text block bboxes
  • image references (xref, bbox, dimensions, digest)
  • table boundaries (bbox + cells, source = pymupdf|pdfplumber)
  • equation locations (bbox, deterministic font+symbol heuristic — never an LLM)
  • chapter boundaries (PDF TOC, heuristic fallback)
  • OCR word coordinates (bbox per recognized word)
"""
from __future__ import annotations

import io
import re
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from typing import List, Optional

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

# Deterministic equation-location heuristic (font + math-symbol density; no LLM).
MATH_FONT_MARKERS = ("CMMI", "CMSY", "CMEX", "MSAM", "MSBM", "MATHJAX", "STIXM",
                     "XITSMATH", "CAMBRIAMATH", "LMMATH", "RSFS", "EUSM", "MTMI", "SYMBOL")
MATH_SYMBOLS = set("∫∑∏√∞±×÷≤≥≠≈→←↔⇒⇔∂∇∈∉⊂⊆⊃⊇∪∩∅αβγδεζηθικλμνξπρστυφχψω"
                   "ΓΔΘΛΞΠΣΦΨΩ°′″⋅∘∓≡≪≫∝⊥∠∴∵⟨⟩⌈⌉⌊⌋ℏℓ")
CHAPTER_RE = re.compile(r"^\s*(chapter|unit|exercise|section|part|lesson)\s+[\dIVXLC]+", re.I)


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


class ParserUnavailable(RuntimeError):
    pass


# ── deterministic element detectors ─────────────────────────────────────────────
def _norm_font(font: str) -> str:
    return font.split("+")[-1].upper()


def _is_math_span(font: str, text: str) -> bool:
    nf = _norm_font(font)
    if any(m in nf for m in MATH_FONT_MARKERS):
        return True
    return sum(1 for ch in text if ch in MATH_SYMBOLS) >= 2


def _page_has_grid(page) -> bool:
    """Ruled-grid detector via vector drawings — gates the pdfplumber table fallback."""
    h = v = rects = 0
    try:
        for d in page.get_drawings():
            for it in d.get("items", []):
                if it[0] == "l":
                    p1, p2 = it[1], it[2]
                    if abs(p1.y - p2.y) < 1.0:
                        h += 1
                    elif abs(p1.x - p2.x) < 1.0:
                        v += 1
                elif it[0] == "re":
                    rects += 1
    except Exception:
        return False
    return (h >= 2 and v >= 2) or rects >= 3


def _page_images(page) -> List[dict]:
    out = []
    try:
        for info in page.get_image_info(xrefs=True):
            dg = info.get("digest")
            out.append({
                "xref": info.get("xref"),
                "bbox": [round(float(x), 1) for x in info.get("bbox", (0, 0, 0, 0))],
                "width": info.get("width"), "height": info.get("height"),
                "colorspace": info.get("colorspace"),
                "digest": dg.hex() if isinstance(dg, bytes) else None,
            })
    except Exception:
        return []
    return out


def _pymupdf_tables(page) -> List[dict]:
    out = []
    try:
        for t in page.find_tables().tables:
            out.append({"bbox": [round(float(x), 1) for x in t.bbox],
                        "rows": t.extract(), "row_count": t.row_count,
                        "col_count": t.col_count, "source": "pymupdf"})
    except Exception:
        return []
    return out


def _toc_chapters(doc) -> List[dict]:
    out = []
    try:
        for lvl, title, pno in (doc.get_toc(simple=True) or []):
            t = (title or "").strip()
            if pno and len(t) >= 3:
                out.append({"page": pno, "level": lvl, "title": t[:160], "source": "toc"})
    except Exception:
        pass
    return out


def _heuristic_chapters(pages: List[dict]) -> List[dict]:
    out = []
    for p in pages:
        for b in p.get("blocks", []):
            first = (b.get("text") or "").splitlines()[0] if b.get("text") else ""
            if CHAPTER_RE.match(first):
                out.append({"page": p["page"], "level": 1,
                            "title": first.strip()[:160], "source": "heuristic"})
                break
    return out


# ── text + structure (PyMuPDF) ──────────────────────────────────────────────────
def extract_text_pages(doc) -> List[dict]:
    """Per-page structure. Keeps page/text/blocks (feed Phase-4 chunking) and ADDS
    width/height, image references, equation locations, and PyMuPDF table boundaries.
    A transient `_grid` flag marks pages the pdfplumber fallback should re-check."""
    pages = []
    for i, page in enumerate(doc):
        rect = page.rect
        text = page.get_text("text")
        blocks, equations = [], []
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
            for s in spans:
                st = s.get("text", "")
                if st.strip() and _is_math_span(s.get("font", ""), st):
                    sb = s.get("bbox", [0, 0, 0, 0])
                    equations.append({
                        "bbox": [round(float(x), 1) for x in sb],
                        "text": st.strip()[:200],
                        "kind": "display" if (sb[2] - sb[0]) > 0.5 * rect.width else "inline",
                        "detector": "font_symbol_heuristic",
                    })
        pages.append({
            "page": i + 1,
            "width": round(float(rect.width), 1),
            "height": round(float(rect.height), 1),
            "text": text,
            "blocks": blocks,
            "images": _page_images(page),
            "equations": equations,
            "tables": _pymupdf_tables(page),
            "_grid": _page_has_grid(page),
        })
    return pages


def _pdfplumber_fallback(path: Path, pages: List[dict]) -> None:
    """Fill tables ONLY on pages where PyMuPDF found none but a ruled grid is present."""
    if pdfplumber is None:
        return
    need = [i for i, p in enumerate(pages) if not p["tables"] and p.get("_grid")]
    if not need:
        return
    try:
        with pdfplumber.open(str(path)) as pdf:
            for i in need:
                if i >= len(pdf.pages):
                    continue
                for t in pdf.pages[i].find_tables():
                    pages[i]["tables"].append({
                        "bbox": [round(float(x), 1) for x in t.bbox],
                        "rows": t.extract(), "source": "pdfplumber",
                    })
    except Exception:
        return


def _flatten_tables(pages: List[dict]) -> List[dict]:
    """Top-level table list (page + bbox + cells + source) for table_count + consumers."""
    out = []
    for p in pages:
        for t in p.get("tables", []):
            out.append({"page": p["page"], "bbox": t.get("bbox"),
                        "rows": t.get("rows"), "source": t.get("source")})
    return out


# ── OCR (Tesseract) ─────────────────────────────────────────────────────────────
def ocr_pages(doc):
    """Per-page OCR text + word boxes (px→PDF-points via 72/dpi, shared coordinate space)."""
    import pytesseract
    from PIL import Image

    scale = 72.0 / OCR_DPI
    pages, confs = [], []
    for i, page in enumerate(doc):
        rect = page.rect
        pix = page.get_pixmap(dpi=OCR_DPI)
        img = Image.open(io.BytesIO(pix.tobytes("png")))
        text = pytesseract.image_to_string(img)
        data = pytesseract.image_to_data(img, output_type=pytesseract.Output.DICT)
        words, page_confs = [], []
        for j, txt in enumerate(data.get("text", [])):
            t = (txt or "").strip()
            if not t:
                continue
            c = data["conf"][j]
            ci = int(c) if str(c).lstrip("-").isdigit() else -1
            if ci >= 0:
                page_confs.append(ci)
            words.append({
                "text": t, "conf": float(ci),
                "bbox": [round(data["left"][j] * scale, 1), round(data["top"][j] * scale, 1),
                         round((data["left"][j] + data["width"][j]) * scale, 1),
                         round((data["top"][j] + data["height"][j]) * scale, 1)],
            })
        if page_confs:
            confs.append(sum(page_confs) / len(page_confs))
        pages.append({"page": i + 1, "width": round(float(rect.width), 1),
                      "height": round(float(rect.height), 1), "text": text,
                      "blocks": [], "words": words, "images": [], "equations": [],
                      "tables": [], "ocr_dpi": OCR_DPI})
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
        chapters = _toc_chapters(doc) or _heuristic_chapters(pages)
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
            _pdfplumber_fallback(path, pages)
    for p in pages:
        p.pop("_grid", None)
    return _assemble(pages, _flatten_tables(pages), method, ocr_used, conf, chapters)


def parse_archive(path: Path) -> dict:
    if fitz is None:
        raise ParserUnavailable("PyMuPDF (fitz) not installed")
    pages: List[dict] = []
    chapters: List[dict] = []
    ocr_used = False
    confs = []
    with zipfile.ZipFile(str(path)) as z:
        for name in sorted(n for n in z.namelist() if n.lower().endswith(".pdf")):
            data = z.read(name)
            with fitz.open(stream=data, filetype="pdf") as doc:
                member_pages = extract_text_pages(doc)
                member_chapters = _toc_chapters(doc)
                if doc.page_count and sum(len(p["text"]) for p in member_pages) < (
                    TEXT_MIN_CHARS_PER_PAGE * doc.page_count
                ):
                    member_pages, c = ocr_pages(doc)
                    ocr_used = True
                    confs.append(c)
            for p in member_pages:
                p.pop("_grid", None)
                p["member"] = name
                pages.append(p)
            for ch in member_chapters:
                ch["member"] = name
                chapters.append(ch)
    conf = round(sum(confs) / len(confs), 1) if confs else None
    method = "archive:tesseract" if ocr_used else "archive:pymupdf"
    return _assemble(pages, _flatten_tables(pages), method, ocr_used, conf, chapters)


def _assemble(pages, tables, method, ocr_used, conf, chapters=None) -> dict:
    chapters = chapters or []
    return {
        "pages": pages,
        "tables": tables,
        "chapter_boundaries": chapters,
        "method": method,
        "ocr_used": ocr_used,
        "confidence": conf,
        "char_count": sum(len(p["text"]) for p in pages),
        "table_count": len(tables),
        "page_count": len(pages),
        "image_count": sum(len(p.get("images", [])) for p in pages),
        "equation_count": sum(len(p.get("equations", [])) for p in pages),
        "chapter_count": len(chapters),
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
