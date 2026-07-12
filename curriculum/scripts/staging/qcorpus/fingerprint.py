"""File integrity + SHA-256 fingerprint + cheap document-level signals.

doc_id = sha256[:16] — the SAME content-addressed identity the KIE store uses
(kie.phase1_verify.doc_id_for), so a document has ONE stable processing identity across
crashes and resumes, keyed on content not path. A renamed copy of identical bytes collapses
to the same doc_id (that is exact-duplicate detection).
"""
from __future__ import annotations

import hashlib
import re
from pathlib import Path
from typing import Optional, Tuple

try:
    import fitz  # PyMuPDF — used only for a quick, cheap page-count + integrity probe.
except Exception:  # pragma: no cover
    fitz = None

_CHUNK = 1 << 20  # 1 MiB streaming read — never load a whole PDF into memory to hash.


def sha256_file(path: Path) -> Tuple[str, int]:
    """Streamed SHA-256 + byte size. Returns (hexdigest, size_bytes)."""
    h = hashlib.sha256()
    size = 0
    with open(path, "rb") as f:
        while True:
            b = f.read(_CHUNK)
            if not b:
                break
            size += len(b)
            h.update(b)
    return h.hexdigest(), size


def doc_id_for(sha256: str) -> str:
    return sha256[:16]


def probe_pdf(path: Path) -> dict:
    """Cheap integrity/structure probe WITHOUT full parse.

    Returns integrity_ok, page_count, encrypted, corruption_reason. A file that cannot be
    opened or has zero pages is flagged here so the pipeline can route it to FAILED without
    an expensive extraction attempt.
    """
    out = {"integrity_ok": False, "page_count": None, "encrypted": False,
           "corruption_reason": None}
    if fitz is None:
        out["corruption_reason"] = "pymupdf_unavailable"
        return out
    try:
        with fitz.open(str(path)) as doc:
            out["encrypted"] = bool(doc.needs_pass)
            if doc.needs_pass:
                # NCERT-style empty owner password; if it still won't open, it's truly locked.
                if not doc.authenticate(""):
                    out["corruption_reason"] = "encrypted_locked"
                    out["page_count"] = doc.page_count
                    return out
            out["page_count"] = doc.page_count
            if doc.page_count == 0:
                out["corruption_reason"] = "zero_pages"
                return out
            out["integrity_ok"] = True
    except Exception as exc:
        out["corruption_reason"] = f"{type(exc).__name__}: {exc}"
    return out


_WS = re.compile(r"\s+")
_NONWORD = re.compile(r"[^a-z0-9]+")


def normalized_filename(name: str) -> str:
    """Filename signature for PROBABLE-duplicate grouping (case/sep/ext-insensitive)."""
    stem = Path(name).stem.lower()
    stem = _NONWORD.sub("_", stem).strip("_")
    return stem


def text_fingerprint(sample_text: str) -> Optional[str]:
    """Stable hash of aggressively-normalized text for probable-duplicate detection.

    Whitespace-collapsed, lowercased, non-alphanumerics dropped. Two documents whose
    extracted text normalizes identically are near-certainly the same content even if the
    bytes differ (re-encoded/re-saved PDF). Returns None for empty text.
    """
    norm = _NONWORD.sub("", _WS.sub("", (sample_text or "").lower()))
    if len(norm) < 40:
        return None
    return hashlib.sha256(norm.encode("utf-8")).hexdigest()
