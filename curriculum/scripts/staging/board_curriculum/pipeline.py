#!/usr/bin/env python3
"""Governed OCR/extraction for verified CBSE + AP board textbooks.

Recovery-first: skip docs whose source sha256 already has COMPLETE parse output.
English-only filter applied to bilingual AP sources.
Does not modify kie.db or qcorpus_noncert.

Usage:
  python pipeline.py [--limit N] [--board cbse|ap|all] [--dry-run]
"""
from __future__ import annotations

import hashlib
import json
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve()
INTEL = HERE.parents[1]
sys.path.insert(0, str(INTEL))
sys.path.insert(0, str(HERE.parent))

from board_curriculum import config, english_filter  # noqa: E402
from kie import phase2_parse  # noqa: E402

TERMINAL = {"COMPLETE", "FAILED", "SKIPPED"}


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _doc_id(sha: str) -> str:
    return sha[:16]


def _load_state() -> dict:
    config.STATE_DIR.mkdir(parents=True, exist_ok=True)
    p = config.PROCESSING_STATE
    if p.is_file():
        return json.loads(p.read_text())
    return {"docs": {}, "stats": {"complete": 0, "failed": 0, "skipped": 0}}


def _save_state(st: dict) -> None:
    tmp = config.PROCESSING_STATE.with_suffix(".tmp")
    tmp.write_text(json.dumps(st, indent=2))
    tmp.replace(config.PROCESSING_STATE)


def discover(board: str) -> list[dict]:
    roots = []
    if board in ("cbse", "all"):
        roots.append(config.SOURCE_ROOTS[0])
    if board in ("ap", "all"):
        roots.append(config.SOURCE_ROOTS[1])
    items = []
    for root in roots:
        if not root.is_dir():
            continue
        for ext in ("*.pdf", "*.zip"):
            for p in sorted(root.rglob(ext)):
                rel = p.relative_to(config.WORKSPACE)
                parts = rel.parts
                if "Textbooks" not in parts:
                    continue
                board_name = parts[2] if len(parts) > 2 else "unknown"
                items.append({
                    "abs_path": str(p),
                    "rel_path": str(rel),
                    "board": board_name.upper() if board_name == "cbse" else "APSCERT",
                    "filename": p.name,
                    "kind": "archive" if p.suffix.lower() == ".zip" else "pdf",
                })
    return items


def _parse_one(path: Path, kind: str) -> dict:
    if kind == "archive":
        return phase2_parse.parse_archive(path)
    return phase2_parse.parse_pdf_file(path, "text_extract")


def run(*, board: str = "all", limit: int | None = None, dry_run: bool = False) -> dict:
    config.PARSED_DIR.mkdir(parents=True, exist_ok=True)
    config.MANIFESTS_DIR.mkdir(parents=True, exist_ok=True)
    config.REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    config.DOC_STATE_DIR.mkdir(parents=True, exist_ok=True)

    st = _load_state()
    manifest_path = config.MANIFESTS_DIR / "board_extraction_manifest.jsonl"
    items = discover(board)
    stats = {"considered": 0, "complete": 0, "skipped": 0, "failed": 0, "ocr": 0, "bilingual": 0}

    with manifest_path.open("a", encoding="utf-8") as mf:
        for item in items:
            if limit is not None and stats["complete"] >= limit:
                break
            stats["considered"] += 1
            path = Path(item["abs_path"])
            sha = _sha256(path)
            did = _doc_id(sha)
            prev = st["docs"].get(did, {})
            if prev.get("status") in TERMINAL and prev.get("source_sha256") == sha:
                out_p = config.PARSED_DIR / f"{did}.json"
                if out_p.is_file():
                    stats["skipped"] += 1
                    continue

            bilingual = english_filter.is_bilingual_source(item["rel_path"])
            if bilingual:
                stats["bilingual"] += 1

            if dry_run:
                stats["complete"] += 1
                continue

            try:
                parsed = _parse_one(path, item["kind"])
                if bilingual:
                    parsed = english_filter.filter_parsed_document(parsed, bilingual=True)
                out_p = config.PARSED_DIR / f"{did}.json"
                out_p.write_text(json.dumps(parsed, ensure_ascii=False, indent=2))
                rec = {
                    "doc_id": did,
                    "status": "COMPLETE",
                    "source_sha256": sha,
                    "rel_path": item["rel_path"],
                    "board": item["board"],
                    "bilingual": bilingual,
                    "method": parsed.get("method"),
                    "ocr_used": parsed.get("ocr_used"),
                    "char_count": parsed.get("char_count"),
                    "page_count": parsed.get("page_count"),
                    "parsed_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                    "output": str(out_p.relative_to(config.WORKSPACE)),
                }
                st["docs"][did] = rec
                mf.write(json.dumps(rec) + "\n")
                stats["complete"] += 1
                if parsed.get("ocr_used"):
                    stats["ocr"] += 1
                st["stats"] = dict(stats)
            except Exception as exc:  # noqa: BLE001
                st["docs"][did] = {
                    "doc_id": did, "status": "FAILED", "source_sha256": sha,
                    "rel_path": item["rel_path"], "error": f"{type(exc).__name__}: {exc}",
                }
                stats["failed"] += 1
                st["stats"] = dict(stats)
            _save_state(st)

    st["stats"] = stats
    _save_state(st)
    report = config.REPORTS_DIR / "BOARD_OCR_EXTRACTION_REPORT.md"
    report.write_text(
        f"# Board Curriculum OCR/Extraction Report\n\n"
        f"Generated: {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}\n\n"
        f"- Board filter: {board}\n"
        f"- Considered: {stats['considered']}\n"
        f"- Complete: {stats['complete']}\n"
        f"- Skipped (reused): {stats['skipped']}\n"
        f"- Failed: {stats['failed']}\n"
        f"- Bilingual AP sources: {stats['bilingual']}\n"
        f"- OCR used: {stats['ocr']}\n",
        encoding="utf-8",
    )
    return stats


def main() -> int:
    import argparse
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--board", choices=["cbse", "ap", "all"], default="all")
    ap.add_argument("--limit", type=int, default=None)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    stats = run(board=args.board, limit=args.limit, dry_run=args.dry_run)
    print(json.dumps(stats, indent=2))
    return 0 if stats["failed"] == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
