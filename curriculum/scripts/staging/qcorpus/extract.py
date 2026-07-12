"""Per-document extraction orchestration.

Reuses the PROVEN loss-minimising parser (kie.phase2_parse.parse_pdf_file) as the extraction
primitive — PyMuPDF primary, pdfplumber tables, detection-first Tesseract OCR (OCR runs ONLY
on pages with no usable embedded text). We then, WITHOUT degrading the raw evidence:

  RAW        = the parser output, verbatim, written once to raw/<doc_id>.json (never rewritten).
  NORMALIZED = per-page normalized_text + additive search_text + notation records, document
               signals, recovered questions, and extracted visual assets — written to
               normalized/<doc_id>.json. Normalisation NEVER overwrites the raw text.

The parser's DB batch-runner (run/parse_document) is deliberately NOT used, so kie.db is never
touched. Only the pure `parse_pdf_file`/`parse_archive` path-in/dict-out functions are called.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import List

from qcorpus import assets as assets_mod
from qcorpus import classify, config, notation, questions

# Make the proven KIE parser importable without importing its DB layer at call time.
_KIE_PKG = config.WORKSPACE / "scripts" / "intelligence"
if str(_KIE_PKG) not in sys.path:
    sys.path.insert(0, str(_KIE_PKG))
from kie import phase2_parse  # noqa: E402  (pure parse_pdf_file/parse_archive; no kie.db access)

_WS = re.compile(r"[ \t ]+")
_MULTINL = re.compile(r"\n{3,}")


def _normalize_text(text: str) -> str:
    """Whitespace-normalise while PRESERVING Unicode notation (super/subscripts, symbols)."""
    if not text:
        return ""
    out = _WS.sub(" ", text)
    out = "\n".join(line.strip() for line in out.splitlines())
    return _MULTINL.sub("\n\n", out).strip()


def run_extraction(path: Path, doc_id: str, kind: str) -> dict:
    """Full extraction for one document. Returns a bundle the pipeline persists.

    Raises on parser failure (caller isolates per-doc; the batch never aborts).
    """
    if kind == "archive":
        raw = phase2_parse.parse_archive(path)
    else:
        raw = phase2_parse.parse_pdf_file(path, "text_extract")

    pages = raw["pages"]
    doc_conf = raw.get("confidence")

    # ── normalized pages (+ notation) ────────────────────────────────────────
    norm_pages: List[dict] = []
    notation_records: List[dict] = []
    equation_records: List[dict] = []
    for p in pages:
        pno = p.get("page")
        raw_text = p.get("text") or ""
        norm_text = _normalize_text(raw_text)
        search_text, repairs = notation.build_search_text(norm_text)
        for r in repairs:
            notation_records.append({**r, "doc_id": doc_id, "page_number": pno})
        for u in notation.flag_uncertain(norm_text, bool(p.get("ocr"))):
            notation_records.append({**u, "doc_id": doc_id, "page_number": pno,
                                     "repair_rule": "flag_only", "repair_confidence": 0.0})
        # expose doc-level OCR confidence per OCR page for downstream OCR-damage labelling
        if p.get("ocr"):
            p["_ocr_conf"] = doc_conf
        for eq in (p.get("equations") or []):
            equation_records.append({"doc_id": doc_id, "page_number": pno, **eq})
        norm_pages.append({
            "page": pno, "width": p.get("width"), "height": p.get("height"),
            "ocr": bool(p.get("ocr")),
            "normalized_text": norm_text,
            "search_text": search_text if search_text != norm_text else None,
            "has_notation": notation.has_notation(norm_text),
            "image_count": len(p.get("images") or []),
            "equation_count": len(p.get("equations") or []),
            "table_count": len(p.get("tables") or []),
            "block_count": len(p.get("blocks") or []),
            "raw_char_count": len(raw_text),
        })

    signals = classify.document_signals(pages, raw)
    sample = "\n".join((p.get("text") or "")[:400] for p in pages[:3])
    language = classify.detect_language(sample)

    # ── visual assets ────────────────────────────────────────────────────────
    visual_assets = assets_mod.extract_assets(path, doc_id, pages)

    # ── question structure recovery ──────────────────────────────────────────
    qrec = questions.recover_questions(doc_id, pages, visual_assets)

    normalized = {
        "doc_id": doc_id,
        "language": language,
        "signals": signals,
        "chapter_boundaries": raw.get("chapter_boundaries", []),
        "pages": norm_pages,
        "questions": qrec["questions"],
    }
    return {
        "raw": raw,
        "normalized": normalized,
        "signals": signals,
        "language": language,
        "notation_records": notation_records,
        "equation_records": equation_records,
        "visual_assets": visual_assets,
        "question_summary": qrec["summary"],
        "page_records": [{"doc_id": doc_id, **np} for np in norm_pages],
        "parse_meta": {
            "method": raw.get("method"), "ocr_used": raw.get("ocr_used"),
            "ocr_pages": raw.get("ocr_pages"), "confidence": raw.get("confidence"),
            "page_count": raw.get("page_count"), "char_count": raw.get("char_count"),
            "table_count": raw.get("table_count"), "image_count": raw.get("image_count"),
            "equation_count": raw.get("equation_count"), "chapter_count": raw.get("chapter_count"),
        },
    }
