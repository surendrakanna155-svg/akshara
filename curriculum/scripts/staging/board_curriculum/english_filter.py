"""English-only content filter for bilingual AP SCERT sources.

Policy: preserve English instructional content; strip Telugu mirrored blocks.
Detection-first: if a page is predominantly Telugu script, flag for review but still
emit English spans. Never duplicate concepts from Telugu-English mirrored layouts.
"""
from __future__ import annotations

import re
from typing import List

# Telugu Unicode block
_TELUGU = re.compile(r"[\u0C00-\u0C7F]")
# Devanagari (Hindi) — out of scope but strip if present in bilingual scans
_DEVANAGARI = re.compile(r"[\u0900-\u097F]")
_ENGLISH_WORD = re.compile(r"[A-Za-z]{2,}")


def _script_ratio(text: str) -> dict:
    if not text:
        return {"telugu": 0.0, "devanagari": 0.0, "latin": 0.0}
    n = len(text)
    return {
        "telugu": len(_TELUGU.findall(text)) / n,
        "devanagari": len(_DEVANAGARI.findall(text)) / n,
        "latin": sum(1 for c in text if c.isascii() and c.isalpha()) / n,
    }


def is_bilingual_source(rel_path: str, medium: str | None = None) -> bool:
    from board_curriculum import config
    if medium and "telugu" in medium.lower():
        return True
    upper = rel_path.replace("-", "_")
    return any(m.lower().replace("-", "_") in upper.lower() for m in config.BILINGUAL_MARKERS)


def filter_page_text(text: str, *, bilingual: bool) -> tuple[str, dict]:
    """Return (filtered_text, language_meta)."""
    meta = {"bilingual_source": bilingual, "english_only_policy": bilingual}
    if not bilingual or not text:
        return text, meta
    ratios = _script_ratio(text)
    meta["script_ratios"] = ratios
    if ratios["telugu"] > 0.35 and ratios["latin"] < 0.15:
        meta["layout"] = "PREDOMINANTLY_TELUGU_REVIEW"
        return "", meta
    # Drop lines that are mostly Telugu
    kept: List[str] = []
    for line in text.splitlines():
        lr = _script_ratio(line)
        if lr["telugu"] > 0.5 and lr["latin"] < 0.1:
            continue
        if _ENGLISH_WORD.search(line) or lr["latin"] > 0.2:
            kept.append(line)
    filtered = "\n".join(kept).strip()
    meta["chars_in"] = len(text)
    meta["chars_out"] = len(filtered)
    meta["layout"] = "BILINGUAL_SOURCE_ENGLISH_PRESENT"
    return filtered, meta


def filter_parsed_document(parsed: dict, *, bilingual: bool) -> dict:
    """Apply English-only filter to a phase2_parse output dict in-place copy."""
    out = dict(parsed)
    pages: List[dict] = []
    for p in parsed.get("pages", []):
        text, meta = filter_page_text(p.get("text", ""), bilingual=bilingual)
        np = dict(p)
        np["text"] = text
        np["language_meta"] = meta
        pages.append(np)
    out["pages"] = pages
    out["char_count"] = sum(len(p["text"]) for p in pages)
    out["english_only_filter"] = bilingual
    return out
