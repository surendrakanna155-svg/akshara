#!/usr/bin/env python3
"""Strict extraction-integrity audit — read-only, no re-OCR.

Measures source PDFs vs parsed outputs for board curriculum staging.
Usage: extraction_integrity_audit.py [--workspace DIR]
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import zipfile
from collections import Counter, defaultdict
from pathlib import Path

HERE = Path(__file__).resolve()
SCRIPTS = HERE.parents[1]
STAGING = SCRIPTS / "staging"
sys.path.insert(0, str(STAGING))
sys.path.insert(0, str(SCRIPTS / "intelligence"))

from board_curriculum import config as bc_config  # noqa: E402
from board_curriculum import english_filter  # noqa: E402
from board_curriculum import pipeline as bc_pipeline  # noqa: E402

WORKSPACE_ROOT = HERE.parents[2]
REPORT_JSON = WORKSPACE_ROOT / "reports" / "EXTRACTION_INTEGRITY_AUDIT.json"
REPORT_MD = WORKSPACE_ROOT / "reports" / "EXTRACTION_INTEGRITY_AUDIT.md"

USABLE_CHARS = 20  # matches phase2_parse TEXT_MIN_CHARS_PER_PAGE
NEAR_EMPTY_DOC_CHARS = 200
NEAR_EMPTY_CHARS_PER_PAGE = 30

_TELUGU = re.compile(r"[\u0C00-\u0C7F]")
_LATIN = re.compile(r"[A-Za-z]")


def _parse_path(rel_path: str) -> dict:
    parts = Path(rel_path).parts
    board_dir = parts[2] if len(parts) > 2 else ""
    class_label = parts[3] if len(parts) > 3 else ""
    subject = parts[4] if len(parts) > 4 else ""
    board = "CBSE" if board_dir == "cbse" else "APSCERT" if board_dir == "ap" else board_dir.upper()
    return {"board": board, "class": class_label, "subject": subject, "board_dir": board_dir}


def _source_page_count(path: Path, kind: str) -> int:
    try:
        import fitz
    except ImportError:
        return 0
    try:
        if kind == "archive":
            total = 0
            with zipfile.ZipFile(str(path)) as z:
                for name in sorted(n for n in z.namelist() if n.lower().endswith(".pdf")):
                    with fitz.open(stream=z.read(name), filetype="pdf") as doc:
                        total += doc.page_count
            return total
        with fitz.open(str(path)) as doc:
            if doc.needs_pass:
                doc.authenticate("")
            return doc.page_count
    except (zipfile.BadZipFile, Exception):
        return -1


def _detect_languages(text: str) -> list[str]:
    langs = []
    if not text:
        return ["none"]
    if _LATIN.search(text):
        langs.append("latin/english")
    if _TELUGU.search(text):
        langs.append("telugu")
    if not langs:
        langs.append("unknown")
    return langs


def _page_stats(pages: list[dict]) -> dict:
    empty = near_empty = usable = image_heavy = table_pages = equation_pages = 0
    ocr_pages = 0
    for p in pages:
        t = (p.get("text") or "").strip()
        clen = len(t)
        if clen < USABLE_CHARS:
            empty += 1
        elif clen < NEAR_EMPTY_CHARS_PER_PAGE:
            near_empty += 1
        else:
            usable += 1
        if p.get("ocr") or p.get("words"):
            ocr_pages += 1
        if p.get("images") and len(p["images"]) > 2 and clen < USABLE_CHARS:
            image_heavy += 1
        if p.get("tables"):
            table_pages += 1
        if p.get("equations"):
            equation_pages += 1
    return {
        "processed_pages": len(pages),
        "ocr_pages_detected": ocr_pages,
        "usable_text_pages": usable,
        "empty_text_pages": empty,
        "near_empty_pages": near_empty,
        "image_heavy_low_text_pages": image_heavy,
        "table_pages": table_pages,
        "equation_pages": equation_pages,
    }


def _bilingual_sample(pages: list[dict]) -> dict:
    """Sample first/middle/last pages for English+Telugu readability."""
    if not pages:
        return {"sampled": 0, "english_readable": 0, "telugu_present": 0, "predominantly_telugu_empty": 0}
    idxs = sorted({0, len(pages) // 2, len(pages) - 1})
    eng_ok = tel = pred_empty = 0
    samples = []
    for i in idxs:
        p = pages[i]
        raw = p.get("text") or ""
        meta = p.get("language_meta") or {}
        latin = len(_LATIN.findall(raw))
        tel_chars = len(_TELUGU.findall(raw))
        samples.append({
            "page": p.get("page"),
            "chars": len(raw),
            "latin_chars": latin,
            "telugu_chars": tel_chars,
            "layout": meta.get("layout"),
        })
        if latin >= 50:
            eng_ok += 1
        if tel_chars >= 20:
            tel += 1
        if meta.get("layout") == "PREDOMINANTLY_TELUGU_REVIEW" or (tel_chars > latin * 2 and latin < 30):
            pred_empty += 1
    return {
        "sampled": len(idxs),
        "english_readable_samples": eng_ok,
        "telugu_present_samples": tel,
        "predominantly_telugu_or_empty_samples": pred_empty,
        "page_samples": samples,
    }


def _classify_doc(row: dict) -> str:
    if row["pipeline_status"] == "SKIPPED_REUSED":
        base = row.get("integrity_status", "COMPLETE")
        return base
    if row["pipeline_status"] == "NO_OUTPUT":
        return "FAILED"
    if row["pipeline_status"] == "STATE_FAILED":
        return "FAILED"
    if row["source_pages"] < 0:
        return "FAILED"
    if row["source_pages"] > 0 and row["processed_pages"] == 0:
        return "FAILED"
    if row["page_count_mismatch"]:
        return "PARTIAL"
    if row["char_count"] < NEAR_EMPTY_DOC_CHARS:
        return "PARTIAL"
    if row["empty_text_pages"] > 0 and row["empty_text_pages"] / max(row["processed_pages"], 1) > 0.15:
        return "PARTIAL"
    if row["usable_text_pages"] == 0:
        return "PARTIAL"
    if row["mapping_mismatch"]:
        return "PARTIAL"
    return "COMPLETE"


def audit(ws: Path) -> dict:
    bc_config.WORKSPACE = ws
    st_path = bc_config.PROCESSING_STATE
    state = json.loads(st_path.read_text()) if st_path.is_file() else {"docs": {}, "stats": {}}
    state_docs = state.get("docs", {})

    items = bc_pipeline.discover("all")
    parsed_dir = bc_config.PARSED_DIR
    all_parsed = {p.stem: p for p in parsed_dir.glob("*.json")} if parsed_dir.is_dir() else {}

    rows = []
    skipped_list = []

    for item in items:
        path = Path(item["abs_path"])
        if not path.is_file():
            continue
        sha = bc_pipeline._sha256(path)
        did = bc_pipeline._doc_id(sha)
        mapping = _parse_path(item["rel_path"])
        bilingual = english_filter.is_bilingual_source(item["rel_path"])

        prev = state_docs.get(did, {})
        out_p = parsed_dir / f"{did}.json"
        would_skip = (
            prev.get("status") in {"COMPLETE", "FAILED", "SKIPPED"}
            and prev.get("source_sha256") == sha
            and out_p.is_file()
        )

        source_pages = _source_page_count(path, item["kind"])
        source_bytes = path.stat().st_size

        parsed = None
        output_bytes = 0
        if out_p.is_file():
            output_bytes = out_p.stat().st_size
            parsed = json.loads(out_p.read_text())

        pipeline_status = "PARSED"
        skip_reason = None
        if would_skip and prev.get("status") == "COMPLETE":
            pipeline_status = "SKIPPED_REUSED"
            skip_reason = "Prior COMPLETE parse reused (same sha256 + parsed output exists)"
            skipped_list.append({
                "doc_id": did,
                "filename": item["filename"],
                "rel_path": item["rel_path"],
                "reason": skip_reason,
            })
        elif prev.get("status") == "FAILED":
            pipeline_status = "STATE_FAILED"
        elif not out_p.is_file():
            pipeline_status = "NO_OUTPUT"

        pages = parsed.get("pages", []) if parsed else []
        ps = _page_stats(pages)
        method = parsed.get("method") if parsed else None
        ocr_used = parsed.get("ocr_used") if parsed else False
        ocr_pages_meta = parsed.get("ocr_pages", 0) if parsed else 0
        char_count = parsed.get("char_count", 0) if parsed else 0

        page_mismatch = (
            source_pages >= 0
            and source_pages != ps["processed_pages"]
        )

        mapping_mismatch = False
        if prev.get("board") and prev["board"] != mapping["board"]:
            mapping_mismatch = True

        row = {
            "doc_id": did,
            "board": mapping["board"],
            "class": mapping["class"],
            "subject": mapping["subject"],
            "source_filename": item["filename"],
            "rel_path": item["rel_path"],
            "source_bytes": source_bytes,
            "source_pages": source_pages,
            "kind": item["kind"],
            "bilingual_source": bilingual,
            "extraction_method": method,
            "ocr_used_flag": ocr_used,
            "ocr_pages_reported": ocr_pages_meta,
            **ps,
            "char_count": char_count,
            "output_bytes": output_bytes,
            "output_path": str(out_p.relative_to(ws)) if out_p.is_file() else None,
            "detected_languages": _detect_languages(
                "\n".join((p.get("text") or "")[:500] for p in pages[:3])
            ),
            "page_count_mismatch": page_mismatch,
            "mapping_mismatch": mapping_mismatch,
            "pipeline_status": pipeline_status,
            "skip_reason": skip_reason,
            "table_count": parsed.get("table_count", 0) if parsed else 0,
            "image_count": parsed.get("image_count", 0) if parsed else 0,
            "equation_count": parsed.get("equation_count", 0) if parsed else 0,
            "english_only_filter": parsed.get("english_only_filter") if parsed else None,
        }
        if bilingual and pages:
            row["bilingual_audit"] = _bilingual_sample(pages)
        row["extraction_status"] = _classify_doc(row)
        rows.append(row)

    # Orphans: parsed JSON without matching discovered source
    discovered_ids = {r["doc_id"] for r in rows}
    orphans = [k for k in all_parsed if k not in discovered_ids]

    # Duplicate outputs (same board/class/subject/filename stem)
    bucket_counts = Counter((r["board"], r["class"], r["subject"]) for r in rows)
    dup_outputs = [r for r in rows if bucket_counts[(r["board"], r["class"], r["subject"])] > 5]

    status_counts = Counter(r["extraction_status"] for r in rows)
    pipeline_skipped = [r for r in rows if r["pipeline_status"] == "SKIPPED_REUSED"]

    # Aggregates by board/class/subject
    breakdown = defaultdict(lambda: {
        "docs": 0, "source_bytes": 0, "output_bytes": 0, "source_pages": 0,
        "processed_pages": 0, "usable_pages": 0, "empty_pages": 0,
        "complete": 0, "partial": 0, "failed": 0,
    })
    for r in rows:
        key = (r["board"], r["class"], r["subject"])
        b = breakdown[key]
        b["docs"] += 1
        b["source_bytes"] += r["source_bytes"]
        b["output_bytes"] += r["output_bytes"]
        b["source_pages"] += r["source_pages"]
        b["processed_pages"] += r["processed_pages"]
        b["usable_pages"] += r["usable_text_pages"]
        b["empty_pages"] += r["empty_text_pages"]
        b[r["extraction_status"].lower()] = b.get(r["extraction_status"].lower(), 0) + 1

    reocr = [
        r for r in rows
        if r["extraction_status"] in ("PARTIAL", "FAILED")
        or r["page_count_mismatch"]
        or r["char_count"] < NEAR_EMPTY_DOC_CHARS
        or (r["bilingual_source"] and r.get("bilingual_audit", {}).get("english_readable_samples", 1) == 0)
    ]

    empty_complete = [
        r for r in rows
        if r["extraction_status"] == "COMPLETE" and r["char_count"] < 500
    ]

    ocr_docs = [r for r in rows if r.get("ocr_used_flag")]
    ocr_page_gaps = [
        r for r in ocr_docs
        if r["ocr_pages_reported"] < r["empty_text_pages"] and r["empty_text_pages"] > 0
    ]

    totals = {
        "pdf_count": len(rows),
        "source_bytes": sum(r["source_bytes"] for r in rows),
        "source_pages": sum(r["source_pages"] for r in rows),
        "processed_pages": sum(r["processed_pages"] for r in rows),
        "ocred_pages_reported": sum(r["ocr_pages_reported"] for r in rows),
        "ocred_pages_detected": sum(r["ocr_pages_detected"] for r in rows),
        "usable_text_pages": sum(r["usable_text_pages"] for r in rows),
        "empty_text_pages": sum(r["empty_text_pages"] for r in rows),
        "near_empty_pages": sum(r["near_empty_pages"] for r in rows),
        "image_heavy_low_text_pages": sum(r["image_heavy_low_text_pages"] for r in rows),
        "extracted_text_chars": sum(r["char_count"] for r in rows),
        "output_bytes": sum(r["output_bytes"] for r in rows),
    }

    trustworthy = (
        status_counts["FAILED"] == 0
        and status_counts["PARTIAL"] == 0
        and len(orphans) == 0
        and len(empty_complete) == 0
        and len(page_mismatch_docs := [r for r in rows if r["page_count_mismatch"]]) == 0
    )

    report = {
        "generated_at": __import__("datetime").datetime.now(__import__("datetime").timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "audit_type": "EXTRACTION_INTEGRITY",
        "read_only": True,
        "pipeline_stats_claimed": state.get("stats", {}),
        "totals": totals,
        "status_counts": dict(status_counts),
        "skipped_documents": skipped_list,
        "skipped_count": len(skipped_list),
        "orphan_parsed_outputs": orphans,
        "empty_marked_complete": empty_complete,
        "page_mismatch_documents": [r for r in rows if r["page_count_mismatch"]],
        "ocr_coverage_gaps": ocr_page_gaps,
        "bilingual_documents": [r for r in rows if r["bilingual_source"]],
        "reocr_or_recovery_required": reocr,
        "class_subject_breakdown": {
            f"{k[0]}|{k[1]}|{k[2]}": v for k, v in sorted(breakdown.items())
        },
        "documents": rows,
        "verdict": {
            "ocr_extraction_trustworthy": "YES" if trustworthy else "NO",
            "reasons": [] if trustworthy else [
                *(["PARTIAL documents present"] if status_counts["PARTIAL"] else []),
                *(["FAILED documents present"] if status_counts["FAILED"] else []),
                *(["Page count mismatches"] if any(r["page_count_mismatch"] for r in rows) else []),
                *(["Orphan parsed outputs"] if orphans else []),
                *(["Near-empty COMPLETE docs"] if empty_complete else []),
            ],
        },
    }
    return report


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--workspace", type=Path, default=WORKSPACE_ROOT)
    args = ap.parse_args()
    ws = args.workspace
    bc_config.WORKSPACE = ws
    report = audit(ws)
    REPORT_JSON.parent.mkdir(parents=True, exist_ok=True)
    REPORT_JSON.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")

    sc = report["status_counts"]
    t = report["totals"]
    lines = [
        "# Extraction Integrity Audit",
        f"\nGenerated: {report['generated_at']}\n",
        f"**Verdict: OCR/EXTRACTION TRUSTWORTHY = {report['verdict']['ocr_extraction_trustworthy']}**\n",
        "## Totals",
        f"- PDFs: {t['pdf_count']} | source {t['source_bytes']/1e6:.1f} MB",
        f"- Source pages: {t['source_pages']} | processed: {t['processed_pages']}",
        f"- OCR pages (reported): {t['ocred_pages_reported']} | usable text pages: {t['usable_text_pages']}",
        f"- Empty pages: {t['empty_text_pages']} | extracted chars: {t['extracted_text_chars']:,}",
        f"\n## Status",
        f"- COMPLETE: {sc.get('COMPLETE', 0)}",
        f"- PARTIAL: {sc.get('PARTIAL', 0)}",
        f"- FAILED: {sc.get('FAILED', 0)}",
        f"- SKIPPED (reused): {report['skipped_count']}",
    ]
    REPORT_MD.write_text("\n".join(lines), encoding="utf-8")
    print(f"TRUSTWORTHY={report['verdict']['ocr_extraction_trustworthy']} "
          f"COMPLETE={sc.get('COMPLETE',0)} PARTIAL={sc.get('PARTIAL',0)} "
          f"FAILED={sc.get('FAILED',0)} SKIPPED={report['skipped_count']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
