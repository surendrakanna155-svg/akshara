"""Visual asset preservation — extract embedded raster images; record vector regions.

We PRESERVE analytical evidence, we do not redraw source visuals. For each document we:
  • extract every embedded raster image's bytes to assets/<doc_id>/<asset_id>.<ext>,
    de-duplicating identical bytes within the doc (a per-page watermark/logo is stored ONCE
    but every placement — page + bbox — is recorded, so association evidence is complete
    without N copies bloating disk);
  • record VECTOR regions (pages carrying substantial vector drawings — diagrams/graphs that
    are not embedded rasters) as bbox-only assets with extraction_method="vector_region_bbox"
    — no rasterisation, honest "a visual exists here" evidence.

Each asset record: asset_id, doc_id, page_number, bbox, asset_type, extraction_method,
width, height, file_path (rel to staging root), file_hash. linked_question_ids /
association_confidence are attached later by the question layer.
"""
from __future__ import annotations

import hashlib
from pathlib import Path
from typing import List, Optional

try:
    import fitz
except Exception:  # pragma: no cover
    fitz = None

from qcorpus import config

_MIN_DIM = 8              # skip 1×1 spacer/artefact images
VECTOR_DRAW_MIN = 40     # a page with >= this many vector items likely carries a diagram/graph


def _rel(p: Path) -> str:
    try:
        return str(p.relative_to(config.STAGING_ROOT))
    except ValueError:
        return str(p)


def extract_assets(path: Path, doc_id: str, pages: List[dict]) -> List[dict]:
    """Extract raster images + record vector regions. Returns the visual-asset records.

    `pages` is the parse result (used for vector-drawing counts already computed cheaply is
    not available, so we re-derive drawing counts from fitz here). Reopening the PDF is cheap
    relative to the parse and keeps this module independent of parse internals.
    """
    if fitz is None:
        return []
    out: List[dict] = []
    doc_dir = config.ASSETS_DIR / doc_id
    seen_hash: dict = {}          # content-hash -> stored file rel-path (per-doc dedup)
    idx = 0
    try:
        with fitz.open(str(path)) as doc:
            if doc.needs_pass:
                doc.authenticate("")
            for pno, page in enumerate(doc, start=1):
                # ── embedded raster images ──────────────────────────────────
                try:
                    infos = page.get_image_info(xrefs=True)
                except Exception:
                    infos = []
                for info in infos:
                    xref = info.get("xref")
                    if not xref:
                        continue
                    bbox = [round(float(x), 1) for x in info.get("bbox", (0, 0, 0, 0))]
                    w, h = info.get("width") or 0, info.get("height") or 0
                    if w < _MIN_DIM or h < _MIN_DIM:
                        continue
                    try:
                        img = doc.extract_image(xref)
                    except Exception:
                        continue
                    data = img.get("image")
                    if not data:
                        continue
                    fh = hashlib.sha256(data).hexdigest()
                    if fh in seen_hash:                      # identical bytes already stored
                        stored = seen_hash[fh]
                    else:
                        idx += 1
                        ext = (img.get("ext") or "png").lower()
                        doc_dir.mkdir(parents=True, exist_ok=True)
                        fp = doc_dir / f"{doc_id}_img{idx:04d}.{ext}"
                        fp.write_bytes(data)
                        stored = _rel(fp)
                        seen_hash[fh] = stored
                    out.append({
                        "asset_id": f"{doc_id}:a{len(out)+1:04d}",
                        "doc_id": doc_id, "page_number": pno, "bbox": bbox,
                        "asset_type": "raster_image", "extraction_method": "pymupdf_extract_image",
                        "width": w, "height": h, "file_path": stored, "file_hash": fh,
                        "linked_question_ids": [], "association_confidence": 0.0,
                    })
                # ── vector regions (diagrams/graphs drawn as vectors) ───────
                try:
                    drawings = page.get_drawings()
                except Exception:
                    drawings = []
                nitems = sum(len(d.get("items", [])) for d in drawings)
                if nitems >= VECTOR_DRAW_MIN:
                    xs, ys = [], []
                    for d in drawings:
                        r = d.get("rect")
                        if r:
                            xs += [r.x0, r.x1]
                            ys += [r.y0, r.y1]
                    bbox = ([round(min(xs), 1), round(min(ys), 1),
                             round(max(xs), 1), round(max(ys), 1)] if xs else None)
                    out.append({
                        "asset_id": f"{doc_id}:a{len(out)+1:04d}",
                        "doc_id": doc_id, "page_number": pno, "bbox": bbox,
                        "asset_type": "vector_region", "extraction_method": "vector_region_bbox",
                        "vector_item_count": nitems, "width": None, "height": None,
                        "file_path": None, "file_hash": None,
                        "linked_question_ids": [], "association_confidence": 0.0,
                    })
    except Exception:
        return out
    _mark_decorative(out)
    return out


def _mark_decorative(records: List[dict]) -> None:
    """Flag repeated watermarks/logos as decorative so they are excluded from question-figure
    association. An identical image (same content hash) that recurs across many pages is
    branding, not a question's diagram — StudentBro/MathonGo stamp a per-page watermark."""
    from collections import defaultdict
    pages_by_hash = defaultdict(set)
    for a in records:
        if a.get("file_hash"):
            pages_by_hash[a["file_hash"]].add(a["page_number"])
    npages = len({a["page_number"] for a in records}) or 1
    for a in records:
        fh = a.get("file_hash")
        spread = len(pages_by_hash.get(fh, ())) if fh else 0
        a["decorative"] = bool(fh and spread > 1 and (spread >= 3 or spread >= 0.4 * npages))
