"""Owned-source page access + rendering — the reusable bottom layer of notation recovery.

Resolves ANY owned source document (plain PDF, or a chapter PDF inside a textbook .zip) from the canonical
evidence stores and renders a page to a PNG the math-capable extractor can read. Deterministic and cached;
strictly READ-ONLY on the evidence tree (never writes into resources/).

Why this exists: the notation we need was destroyed by text extraction, so recovery must return to the actual
rendered page — the owner's rule "when notation is damaged, return to the actual source PDF/page/image".
"""
from __future__ import annotations

import hashlib
import os
import re
import sqlite3
import zipfile
from dataclasses import dataclass
from typing import Iterator, List, Optional, Tuple

from kie import config

# rendered page cache (local, derived — gitignored like every other derived store)
CACHE_DIR = config.KIE_HOME / "notation_pages"
DEFAULT_DPI = 170

# text-extraction damage signals: a page whose math is flattened (bare exponent/subscript digits, stray
# greek, equation labels) — these are exactly the pages worth re-reading from the image.
_EQ_LABEL = re.compile(r"\(\d+\.\d+\)")
_GREEK = re.compile(r"[εμπρσΔΩλθφω]")
_MATH_HINT = re.compile(r"[=∫∑√±×÷]")


@dataclass(frozen=True)
class SourcePage:
    doc_id: str
    store_path: str        # path of the owned source (zip or pdf), relative to the workspace
    entry: Optional[str]   # pdf entry inside the zip (None for a plain pdf)
    page: int              # 0-based
    subject: Optional[str] = None
    chapter: Optional[str] = None

    @property
    def ref(self) -> str:
        return f"{os.path.basename(self.store_path)}:{self.entry or '-'}:p{self.page}"

    @property
    def cache_key(self) -> str:
        return hashlib.sha256(f"{self.store_path}|{self.entry}|{self.page}".encode()).hexdigest()[:20]


def _open_pdf(store_abs: str, entry: Optional[str]):
    import fitz
    if store_abs.lower().endswith(".zip"):
        with zipfile.ZipFile(store_abs) as z:
            return fitz.open(stream=z.read(entry), filetype="pdf")
    return fitz.open(store_abs)


def list_pdf_entries(store_rel: str) -> List[str]:
    """PDF entries inside an owned .zip textbook (empty for a plain PDF)."""
    p = config.WORKSPACE / store_rel
    if not str(p).lower().endswith(".zip") or not p.exists():
        return []
    with zipfile.ZipFile(p) as z:
        return sorted(n for n in z.namelist() if n.lower().endswith(".pdf"))


def entry_title(store_rel: str, entry: Optional[str]) -> str:
    """First-page heading of a chapter PDF — the reliable chapter identity (the zip/db class labels are
    known-unreliable: NCERT_Class12_keph1dd.zip actually contains the Class XI book)."""
    doc = _open_pdf(str(config.WORKSPACE / store_rel), entry)
    try:
        txt = doc[0].get_text()
    finally:
        doc.close()
    lines = [l.strip() for l in txt.splitlines() if l.strip()][:6]
    return " | ".join(lines)


def page_text(sp: SourcePage) -> str:
    doc = _open_pdf(str(config.WORKSPACE / sp.store_path), sp.entry)
    try:
        return doc[sp.page].get_text()
    finally:
        doc.close()


def math_damage_score(text: str) -> float:
    """0..1 — how much this page looks like flattened/destroyed math worth re-reading from the image.
    Driven by equation labels, stray greek, math operators, and short numeric-only lines (the tell-tale of
    a fraction/exponent exploded into separate tokens)."""
    if not text:
        return 0.0
    lines = [l.strip() for l in text.splitlines()]
    if not lines:
        return 0.0
    short_numeric = sum(1 for l in lines if l and len(l) <= 3 and re.fullmatch(r"[0-9πε\-–+/^]+", l or ""))
    labels = len(_EQ_LABEL.findall(text))
    greek = len(_GREEK.findall(text))
    math = len(_MATH_HINT.findall(text))
    score = (min(short_numeric / 12.0, 1.0) * 0.5 + min(labels / 3.0, 1.0) * 0.25
             + min(greek / 8.0, 1.0) * 0.15 + min(math / 10.0, 1.0) * 0.10)
    return round(min(score, 1.0), 3)


def render(sp: SourcePage, dpi: int = DEFAULT_DPI, force: bool = False) -> str:
    """Render the source page to a cached PNG; returns the absolute path. Deterministic + idempotent."""
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    out = CACHE_DIR / f"{sp.cache_key}_dpi{dpi}.png"
    if out.exists() and not force:
        return str(out)
    doc = _open_pdf(str(config.WORKSPACE / sp.store_path), sp.entry)
    try:
        doc[sp.page].get_pixmap(dpi=dpi).save(str(out))
    finally:
        doc.close()
    return str(out)


def iter_pages(store_rel: str, entry: Optional[str], doc_id: str = "", subject: Optional[str] = None,
               chapter: Optional[str] = None) -> Iterator[Tuple[SourcePage, str]]:
    """Yield (SourcePage, page_text) for every page of an owned source document."""
    doc = _open_pdf(str(config.WORKSPACE / store_rel), entry)
    try:
        for i in range(doc.page_count):
            yield SourcePage(doc_id, store_rel, entry, i, subject, chapter), doc[i].get_text()
    finally:
        doc.close()


def stem_sources(kconn: sqlite3.Connection, subjects=("Physics", "Chemistry", "Mathematics"),
                 category: str = "NCERT") -> List[dict]:
    """In-scope owned STEM textbook sources from the certified corpus (read-only kie.db)."""
    kconn.row_factory = sqlite3.Row
    q = ("SELECT doc_id, rel_path, subject, class_label FROM source_documents "
         "WHERE category=? AND certify_status='certified' AND rel_path LIKE '%.zip'")
    out = []
    for r in kconn.execute(q, (category,)):
        if r["subject"] in subjects:
            out.append({"doc_id": r["doc_id"], "store_path": "resources/foundation/" + r["rel_path"],
                        "subject": r["subject"], "class_label": r["class_label"]})
    return out
