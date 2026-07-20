"""Targeted re-OCR recovery for chapters whose EMBEDDED PDF TEXT LAYER is corrupt.

Root cause (see OCR_RECOVERY_LIST_v1.0): two NCERT chapters carry a broken embedded text layer —
`kech202.pdf` (Organic unit) a non-uniform Caesar +3 cipher, `keph107.pdf` (Gravitation) a
Private-Use-Area font-glyph stream. Phase-2's detection-first OCR fallback OCRs only pages with NO
usable embedded text; these pages HAVE embedded text (just garbled), so OCR was skipped and the garbage
was kept.

This module forces image-raster OCR on the affected pages, REUSING the frozen `phase2_parse._ocr_page`
(300-DPI PyMuPDF pixmap → Tesseract), and rewrites the page text in the archive's parse JSON — but ONLY
where the OCR is a VERIFIED quality improvement over the corrupt original (a page whose embedded text was
already clean keeps its original text; OCR that fails to improve a page is refused and logged). The
original parse JSON is preserved (`.pre_reocr.json`) before any write. After a successful run, the caller
re-chunks the affected doc with the frozen `phase4_chunk.process_document`, so downstream extraction sees
clean text through the normal pipeline.

Deterministic (Tesseract on a fixed-DPI raster is reproducible). No AI. No fabrication — every recovered
character comes from the printed page's own glyphs.
"""
from __future__ import annotations

import io
import json
import re
import zipfile
from pathlib import Path
from typing import Optional

from kie import config, phase2_parse

_COMMON = {"the", "and", "of", "to", "in", "is", "are", "a", "for", "as", "we", "this", "that",
           "with", "on", "by", "an", "be", "or", "it", "from", "at", "which", "can", "will",
           "these", "has", "have", "was", "not", "its", "so", "if", "one", "two", "when"}


def _pua_ratio(t: str) -> float:
    return (sum(1 for ch in t if 0xE000 <= ord(ch) <= 0xF8FF) / len(t)) if t else 0.0


def _eng_ratio(t: str) -> float:
    w = re.findall(r"[a-zA-Z]{2,}", (t or "").lower())
    return (sum(1 for x in w if x in _COMMON) / len(w)) if w else 0.0


def _dec3(s: str) -> str:
    return "".join(
        chr((ord(c) - 97 - 3) % 26 + 97) if c.islower() else
        chr((ord(c) - 65 - 3) % 26 + 65) if c.isupper() else c for c in s)


def corruption_class(t: str) -> str:
    """Deterministic label for a page's text: clean | sparse | PUA | caesar | low-eng."""
    t = t or ""
    if len(t.strip()) < 20:
        return "sparse"
    if _pua_ratio(t) > 0.10:
        return "PUA"
    raw, cae = _eng_ratio(t), _eng_ratio(_dec3(t))
    if cae > raw + 0.04 and cae > 0.08:
        return "caesar"
    if raw < 0.03:
        return "low-eng"
    return "clean"


def is_corrupt(t: str) -> bool:
    return corruption_class(t) in ("PUA", "caesar", "low-eng")


def quality(t: str) -> float:
    """Higher is better. Rewards real-English density, penalises PUA glyphs and non-alpha noise."""
    if not t or not t.strip():
        return 0.0
    alpha = sum(1 for c in t if c.isalpha())
    return _eng_ratio(t) - _pua_ratio(t) + 0.15 * (alpha / len(t))


def _member_streams(archive_abs: Path):
    """Yield (member_name, page_index, fitz_page) for every page of every member PDF, in the SAME
    member order phase2.parse_archive uses (sorted PDF names)."""
    import fitz
    with zipfile.ZipFile(str(archive_abs)) as z:
        for name in sorted(n for n in z.namelist() if n.lower().endswith(".pdf")):
            data = z.read(name)
            doc = fitz.open(stream=data, filetype="pdf")
            if doc.needs_pass:
                doc.authenticate("")
            try:
                for i in range(len(doc)):
                    yield name, i, doc[i]
            finally:
                doc.close()


def reocr_archive(did: str, target_members, archive_abs: Path, *, apply: bool = False,
                  min_gain: float = 0.05) -> dict:
    """Re-OCR corrupt pages of the named member PDFs inside an archive's parse JSON.

    A page is REPLACED only if its original text is corrupt AND the fresh OCR both (a) is not corrupt and
    (b) scores at least `min_gain` higher on `quality`. Returns a per-page decision log. Writes the parse
    JSON only when apply=True (after saving `<did>.pre_reocr.json`).
    """
    parsed_path = config.PARSED_DIR / f"{did}.json"
    parsed = json.loads(parsed_path.read_text())
    targets = set(target_members)

    # index pages of the parse JSON by (member, page-number) — page numbers reset per member
    page_index = {}
    for p in parsed["pages"]:
        page_index[(p.get("member"), p["page"])] = p

    decisions = []
    replaced = 0
    # walk the member PDFs; OCR only pages of target members
    for name, i, page in _member_streams(archive_abs):
        if name not in targets:
            continue
        pobj = page_index.get((name, i + 1))
        if pobj is None:
            decisions.append({"member": name, "page": i + 1, "action": "no-parse-page"})
            continue
        old = pobj.get("text") or ""
        old_class = corruption_class(old)
        if old_class in ("clean", "sparse"):
            decisions.append({"member": name, "page": i + 1, "old_class": old_class,
                              "action": "keep (not corrupt)", "q_old": round(quality(old), 3)})
            continue
        new_text, words, conf = phase2_parse._ocr_page(page)
        q_old, q_new = quality(old), quality(new_text)
        new_corrupt = is_corrupt(new_text)
        accept = (not new_corrupt) and (q_new >= q_old + min_gain)
        dec = {"member": name, "page": i + 1, "old_class": old_class,
               "q_old": round(q_old, 3), "q_new": round(q_new, 3), "ocr_conf": conf,
               "new_class": corruption_class(new_text), "new_chars": len(new_text.strip()),
               "action": "REPLACE" if accept else "refuse (no gain)"}
        decisions.append(dec)
        if accept and apply:
            pobj["text"] = new_text
            pobj["blocks"] = []          # OCR text has no font blocks → chunker paragraph-splits it
            pobj["words"] = words
            pobj["ocr"] = True
            pobj["ocr_dpi"] = phase2_parse.OCR_DPI
            pobj["reocr"] = True
            replaced += 1

    if apply and replaced:
        backup = config.PARSED_DIR / f"{did}.pre_reocr.json"
        if not backup.exists():
            backup.write_text(parsed_path.read_text())
        # keep method honest: some pages are now OCR-derived
        parsed["method"] = parsed.get("method", "") + "+reocr"
        parsed["char_count"] = sum(len(p["text"]) for p in parsed["pages"])
        parsed_path.write_text(json.dumps(parsed, ensure_ascii=False, sort_keys=True))

    return {"doc_id": did, "targets": sorted(targets), "replaced": replaced,
            "considered": len([d for d in decisions if "q_new" in d]), "decisions": decisions,
            "applied": apply}


def drop_corrupt_tables(did: str, *, apply: bool = False) -> dict:
    """Remove table objects whose CELL TEXT is corrupt (PUA/caesar) from an archive's parse JSON.

    Phase-2 extracts ruled tables as separate objects; a corrupt embedded text layer yields corrupt
    table cells that page-text re-OCR does not touch (Tesseract reads the table content inline as page
    text instead). Such a table object contributes only garbage to chunks while its real content already
    survives in the re-OCR'd page text — so dropping it is zero-loss cleanup. Clean tables are kept.
    """
    parsed_path = config.PARSED_DIR / f"{did}.json"
    parsed = json.loads(parsed_path.read_text())
    tables = parsed.get("tables", [])
    kept, dropped = [], []
    for t in tables:
        cell_text = " ".join((c or "") for row in (t.get("rows") or []) for c in row)
        (dropped if corruption_class(cell_text) in ("PUA", "caesar") else kept).append(t)
    if apply and dropped:
        backup = config.PARSED_DIR / f"{did}.pre_reocr.json"
        if not backup.exists():
            backup.write_text(parsed_path.read_text())
        parsed["tables"] = kept
        parsed["table_count"] = len(kept)
        parsed_path.write_text(json.dumps(parsed, ensure_ascii=False, sort_keys=True))
    return {"doc_id": did, "tables_total": len(tables), "tables_dropped": len(dropped),
            "tables_kept": len(kept), "applied": apply}


def summarize(result: dict) -> str:
    out = [f"doc {result['doc_id']}  targets={result['targets']}  "
           f"considered={result['considered']}  replaced={result['replaced']}  applied={result['applied']}"]
    for d in result["decisions"]:
        if d.get("action", "").startswith(("REPLACE", "refuse")):
            out.append(f"  {d['member']} p{d['page']:>2}: {d['old_class']:>7} "
                       f"q{d.get('q_old')}->{d.get('q_new')} [{d.get('new_class')}] -> {d['action']}")
    return "\n".join(out)
