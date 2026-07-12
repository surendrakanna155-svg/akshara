"""Deterministic document classification (confidence-scored; UNKNOWN where unsure).

Two stages:
  classify_static() — cheap, pre-parse: source_group + provenance + path/filename tokens.
  document_signals() — post-parse measured ratios: native_text_ratio, image_page_ratio,
                       scan_probability, layout_complexity, equation_density, visual_density,
                       and the native/scanned/mixed classification.

We NEVER fabricate metadata. Every candidate carries a confidence in [0,1]; low-evidence
fields are returned as "UNKNOWN" with confidence 0.0.
"""
from __future__ import annotations

import re
from typing import List, Optional

from qcorpus import config

# Subject inference from path/filename tokens (case-insensitive whole-word-ish).
_SUBJECT_TOKENS = [
    ("Biology",     re.compile(r"\b(biology|bio|botany|zoology)\b", re.I)),
    ("Chemistry",   re.compile(r"\b(chemistry|chem|organic|inorganic|physical_chem)\b", re.I)),
    ("Physics",     re.compile(r"\b(physics|phys)\b", re.I)),
    ("Mathematics", re.compile(r"\b(mathematics|maths?|calculus|algebra|trigonometry)\b", re.I)),
]

# Document-type refinement from filename/text signals (source-group default is the prior).
_DOCTYPE_TOKENS = [
    ("ANSWER_KEY",              re.compile(r"\b(answer[\s_-]?key|answers?)\b", re.I)),
    ("SOLUTION_SET",           re.compile(r"\b(solutions?|hints?[\s_&-]*solutions?)\b", re.I)),
    ("MOCK_PAPER",             re.compile(r"\b(mock|full[\s_-]?test|grand[\s_-]?test)\b", re.I)),
    ("PREVIOUS_PAPER",         re.compile(r"\b(previous|pyq|past[\s_-]?paper|20\d{2})\b", re.I)),
    ("DPP",                    re.compile(r"\b(dpp|daily[\s_-]?practice)\b", re.I)),
    ("CHAPTERWISE_QUESTION_SET", re.compile(r"\b(chapter[\s_-]?wise|chapterwise)\b", re.I)),
    ("WORKSHEET",              re.compile(r"\b(worksheet)\b", re.I)),
]

_LANG_DEVANAGARI = re.compile(r"[ऀ-ॿ]")


def _match_subject(text: str) -> Optional[str]:
    for subj, rx in _SUBJECT_TOKENS:
        if rx.search(text or ""):
            return subj
    return None


def classify_static(group: str, rel_parts: List[str], filename: str,
                    prov: Optional[dict]) -> dict:
    """Pre-parse classification from group registry + provenance + path/filename tokens."""
    reg = config.SOURCE_GROUPS.get(group, {})
    path_join = " ".join(rel_parts)

    # ── subject ──────────────────────────────────────────────────────────────
    subject, subj_conf = "UNKNOWN", 0.0
    if prov and prov.get("subject"):
        subject, subj_conf = prov["subject"], 0.98            # source manifest = authoritative
    elif reg.get("subject"):
        subject, subj_conf = reg["subject"], 0.9              # single-subject group (physicsaholics)
    else:
        s = _match_subject(path_join) or _match_subject(filename)
        if s:
            subject, subj_conf = s, 0.8                       # directory/filename token

    # ── document_type ────────────────────────────────────────────────────────
    doc_type, dt_conf = reg.get("doc_type", "UNKNOWN"), (0.7 if reg.get("doc_type") else 0.0)
    for dt, rx in _DOCTYPE_TOKENS:
        if rx.search(filename):
            doc_type, dt_conf = dt, 0.85
            break

    # ── chapter / topic ──────────────────────────────────────────────────────
    chapter, ch_conf = "UNKNOWN", 0.0
    topic, tp_conf = "UNKNOWN", 0.0
    if prov and prov.get("chapter"):
        chapter, ch_conf = prov["chapter"], 0.95              # source manifest = authoritative
    if prov and prov.get("topic"):
        topic, tp_conf = prov["topic"], 0.9
    # Directory-based chapter fallback ONLY when provenance supplied none — e.g.
    # physicsaholics_dpps/NEET_JEE/<Chapter>/file.pdf where the parent dir IS the chapter.
    if chapter == "UNKNOWN" and len(rel_parts) >= 2:
        cand = rel_parts[-2] if rel_parts[-1].lower().endswith(".pdf") else rel_parts[-1]
        if cand and cand not in config.SOURCE_GROUPS and (("_" in cand) or cand[:1].isupper()):
            chapter, ch_conf = cand.replace("_", " "), 0.6

    return {
        "source_group": group,
        "exam_profile": reg.get("exam", "UNKNOWN"),
        "document_type": doc_type, "document_type_confidence": round(dt_conf, 2),
        "subject_candidate": subject, "subject_confidence": round(subj_conf, 2),
        "chapter_candidate": chapter, "chapter_confidence": round(ch_conf, 2),
        "topic_candidate": topic, "topic_confidence": round(tp_conf, 2),
        "source_url": (prov or {}).get("source_url"),
        "topic_url": (prov or {}).get("topic_url"),
    }


def detect_language(sample_text: str) -> str:
    """Coarse language flag. English-dominant corpus; flag Devanagari presence honestly."""
    if _LANG_DEVANAGARI.search(sample_text or ""):
        return "hi_or_mixed"
    return "en" if (sample_text or "").strip() else "UNKNOWN"


def document_signals(pages: List[dict], parse_meta: dict) -> dict:
    """Measured document signals from the parse result (per-page evidence)."""
    n = len(pages) or 1
    ocr_pages = sum(1 for p in pages if p.get("ocr"))
    image_only = sum(1 for p in pages
                     if len((p.get("text") or "").strip()) < 20 and p.get("images"))
    native_pages = n - ocr_pages
    total_chars = sum(len(p.get("text") or "") for p in pages)
    total_images = sum(len(p.get("images") or []) for p in pages)
    total_eq = sum(len(p.get("equations") or []) for p in pages)
    total_tables = sum(len(p.get("tables") or []) for p in pages)

    native_text_ratio = round(native_pages / n, 3)
    image_page_ratio = round(image_only / n, 3)
    scan_probability = round(ocr_pages / n, 3)

    if scan_probability >= 0.6:
        media = "scanned"
    elif scan_probability <= 0.05 and image_page_ratio <= 0.1:
        media = "native"
    else:
        media = "mixed"

    # Layout complexity: blend of multi-column hint (blocks/page) + tables + images.
    blocks_per_page = sum(len(p.get("blocks") or []) for p in pages) / n
    layout_score = min(1.0, (blocks_per_page / 60.0) + (total_tables / n) * 0.3
                       + (total_images / n) * 0.1)
    layout = "high" if layout_score > 0.66 else "medium" if layout_score > 0.33 else "low"

    return {
        "media_class": media,                       # native | scanned | mixed
        "native_text_ratio": native_text_ratio,
        "image_page_ratio": image_page_ratio,
        "scan_probability": scan_probability,
        "ocr_page_count": ocr_pages,
        "layout_complexity": layout,
        "equation_density": round(total_eq / n, 2),
        "visual_density": round(total_images / n, 2),
        "table_density": round(total_tables / n, 2),
        "chars_per_page": round(total_chars / n, 1),
        "parser_method": parse_meta.get("method"),
        "parser_confidence": parse_meta.get("confidence"),
    }
