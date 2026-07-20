#!/usr/bin/env python3
"""Atomic discover → download → verify for curriculum + assessment PDFs.

Does NOT queue URLs for later. Each probed source is downloaded immediately;
verified bytes land under resources/curriculum/. Source URL is recorded only
as provenance metadata alongside sha256 — the file is the authority.

Usage:
  immediate_acquire.py [--board all|cbse|ap|telangana|icse] [--limit N] [--assessment-only]
"""
from __future__ import annotations

import argparse
import hashlib
import shutil
import sys
import threading
import time
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve()
WORKSPACE_ROOT = HERE.parents[2]
SCRIPTS = HERE.parents[1]
for sub in ("common", "download", "discovery", "reports"):
    p = str(SCRIPTS / sub)
    if p not in sys.path:
        sys.path.insert(0, p)

from workspace import Workspace, get_engine, load_json, write_json, utcnow  # noqa: E402
from source_probe import probe_url  # noqa: E402
import downloader  # noqa: E402
import ncert_catalogue  # noqa: E402
import ap_catalogue  # noqa: E402
import telangana_catalogue  # noqa: E402
import cisce_catalogue  # noqa: E402
import cisce_discover  # noqa: E402
import diksha_catalogue  # noqa: E402
import cbse_sqp_catalogue  # noqa: E402
import cbse_catalogue  # noqa: E402

LOG = WORKSPACE_ROOT / "acquisition" / "immediate_acquire.log"
_ACQUIRE_LOCK = threading.Lock()
BOARD_FILTER = {
    "cbse": {"CBSE"},
    "ap": {"APSCERT"},
    "telangana": {"TSSCERT"},
    "icse": {"CISCE"},
    "all": {"CBSE", "APSCERT", "TSSCERT", "CISCE"},
}


def log(msg: str) -> None:
    line = f"[{utcnow()}] {msg}"
    print(line, flush=True)
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with LOG.open("a", encoding="utf-8") as fh:
        fh.write(line + "\n")


def _final_path(ws: Workspace, entry: dict) -> Path:
    return ws.p("resources_dir") / entry["destination"] / entry["expected_filename"]


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _record_completed(ws: Workspace, entry: dict, final_rel: str, sha: str) -> None:
    completed = load_json(ws.pm("completed_downloads"), []) or []
    rid = entry.get("resource_id")
    row = {
        "resource_id": rid,
        "board": entry.get("board"),
        "class_label": entry.get("class_label"),
        "subject": entry.get("subject"),
        "resource_category": entry.get("resource_category"),
        "document_type": entry.get("document_type"),
        "license_status": entry.get("license_status"),
        "provenance_tier": entry.get("provenance_tier"),
        "assessment_subtype": entry.get("assessment_subtype"),
        "source_url": entry.get("source_url"),
        "source_page_url": entry.get("source_page_url"),
        "local_path": final_rel,
        "sha256": sha,
        "status": "VERIFIED",
        "acquired_at": utcnow(),
        "acquisition_mode": "IMMEDIATE",
    }
    completed = [c for c in completed if c.get("resource_id") != rid]
    completed.append(row)
    write_json(ws.pm("completed_downloads"), completed)


def acquire_one(ws: Workspace, entry: dict, engine, *, allow_network: bool, fast: bool = False) -> str:
    """Download + verify one entry. Returns outcome token."""
    fp = _final_path(ws, entry)
    if fp.is_file() and fp.stat().st_size > 1000:
        return "EXISTING"

    lic = entry.get("license_status", "")
    if lic.startswith("UNOFFICIAL"):
        return "SKIP_UNOFFICIAL"
    # TRUSTED_THIRD_PARTY_ASSESSMENT is allowed — separate storage tier, never official.

    rules = ws.config("download_rules")
    rules = dict(rules)
    rules["allow_network"] = allow_network
    if fast:
        rules["networking"] = {
            **rules.get("networking", {}),
            "read_timeout_seconds": 45,
            "connect_timeout_seconds": 15,
            "polite_delay_seconds": 0,
        }

    ok, incoming, note = downloader._fetch(entry, ws, rules, allow_network)
    if not ok:
        log(f"FETCH_FAIL {entry.get('resource_id')}: {note}")
        return "FETCH_FAIL"

    result = engine.verify_resource(dict(entry), incoming)
    if result.status in ("VERIFIED", "DUPLICATE"):
        if fp.is_file():
            sha = _sha256(fp)
            rel = str(fp.relative_to(ws.root))
            with _ACQUIRE_LOCK:
                _record_completed(ws, entry, rel, sha)
            return "VERIFIED" if result.status == "VERIFIED" else "DUPLICATE"
        return result.status
    log(f"VERIFY_FAIL {entry.get('resource_id')}: {result.reason_code}")
    return "VERIFY_FAIL"


def discover_all(ws: Workspace, boards: set[str], *, assessment_only: bool) -> list[dict]:
    entries: list[dict] = []
    seen: set[str] = set()
    ASSESSMENT_CATS = {"sample_paper", "blueprint", "question_bank", "previous_paper"}

    def add_batch(batch: list[dict], *, trusted_only: bool = False) -> None:
        for e in batch:
            if e.get("board") not in boards:
                continue
            if trusted_only and (e.get("license_status") or "").startswith("UNOFFICIAL"):
                continue
            cat = e.get("resource_category", "textbook")
            if assessment_only and cat not in ASSESSMENT_CATS:
                continue
            if not assessment_only and cat not in ASSESSMENT_CATS and cat != "textbook" and cat != "syllabus":
                continue
            url = e.get("source_url")
            if not url or url in seen:
                continue
            seen.add(url)
            entries.append(e)

    if not assessment_only:
        if "CBSE" in boards:
            add_batch(ncert_catalogue.build(ws))
            add_batch(cbse_catalogue.build(ws))
        if "APSCERT" in boards:
            add_batch(ap_catalogue.build(ws))
        if "TSSCERT" in boards:
            add_batch(telangana_catalogue.build(ws), trusted_only=True)
        if "CISCE" in boards:
            add_batch(cisce_catalogue.build(ws))
            add_batch(cisce_discover.discover(ws))

    add_batch(diksha_catalogue.build(ws, probe=True))
    if "CBSE" in boards:
        add_batch(cbse_sqp_catalogue.build(ws, probe=True))

    return entries


def run(ws: Workspace, *, board: str, limit: int | None, assessment_only: bool) -> dict:
    boards = BOARD_FILTER[board]
    log(f"IMMEDIATE ACQUIRE start boards={boards} assessment_only={assessment_only}")
    engine = get_engine(ws.root)
    entries = discover_all(ws, boards, assessment_only=assessment_only)
    log(f"discovered {len(entries)} probed sources")

    stats = Counter()
    for i, entry in enumerate(entries):
        if limit is not None and i >= limit:
            break
        outcome = acquire_one(ws, entry, engine, allow_network=True)
        stats[outcome] += 1
        if outcome == "VERIFIED":
            log(f"OK {entry['board']} {entry['class_label']} {entry['subject']} "
                f"{entry.get('resource_category')} -> {entry['expected_filename']}")
        time.sleep(0.5)

    report = {
        "generated_at": utcnow(),
        "mode": "IMMEDIATE_ACQUIRE",
        "boards": sorted(boards),
        "assessment_only": assessment_only,
        "discovered": len(entries),
        "stats": dict(stats),
    }
    write_json(ws.p("reports_dir") / "IMMEDIATE_ACQUIRE_REPORT.json", report)
    log(f"DONE {dict(stats)}")
    return report


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--workspace", type=Path, default=WORKSPACE_ROOT)
    ap.add_argument("--board", default="all", choices=list(BOARD_FILTER))
    ap.add_argument("--limit", type=int, default=None)
    ap.add_argument("--assessment-only", action="store_true")
    args = ap.parse_args()
    ws = Workspace(args.workspace)
    run(ws, board=args.board, limit=args.limit, assessment_only=args.assessment_only)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
