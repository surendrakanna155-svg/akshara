#!/usr/bin/env python3
"""Direct acquisition — search every board, probe, download immediately (no queue wait).

For each discovered URL (official catalogues + DIKSHA + papers):
  1. skip if already VERIFIED in master index
  2. HEAD-probe
  3. download → verify (V1-V11) → move to resources/… correct folder
  4. log result and continue to next file

Usage:
  fetch_all_direct.py [--board cbse|ap|telangana|icse|all] [--limit N] [--dry-run]
"""

from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve()
WORKSPACE_ROOT = HERE.parents[2]
SCRIPTS = HERE.parents[1]
for sub in ("common", "download", "discovery", "acquisition"):
    p = str(SCRIPTS / sub)
    if p not in sys.path:
        sys.path.insert(0, p)

from workspace import Workspace, get_engine, load_json, utcnow  # noqa: E402
from source_probe import probe_url  # noqa: E402
import downloader  # noqa: E402
import ncert_catalogue, cbse_catalogue, cbse_sqp_catalogue  # noqa: E402
import ap_catalogue, cisce_catalogue, telangana_catalogue, diksha_catalogue  # noqa: E402

# Reuse paper discovery from fetch_papers_direct
from fetch_papers_direct import discover_cbse as discover_cbse_papers  # noqa: E402
from fetch_papers_direct import discover_cisce as discover_cisce_papers  # noqa: E402

LOG = WORKSPACE_ROOT / "acquisition" / "fetch_direct.log"

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


def _build_catalogues(ws: Workspace) -> list[dict]:
    """Collect catalogue entries from every resolver (live scrape / API)."""
    entries: list[dict] = []
    builders: list[tuple[str, object, dict]] = [
        ("ncert", ncert_catalogue, {}),
        ("cbse_syllabus", cbse_catalogue, {}),
        ("cbse_sqp", cbse_sqp_catalogue, {"probe": True}),
        ("ap", ap_catalogue, {"probe": True}),
        ("cisce", cisce_catalogue, {}),
        ("telangana", telangana_catalogue, {}),
        ("diksha", diksha_catalogue, {"probe": True}),
    ]
    for label, mod, kwargs in builders:
        try:
            cat = mod.build(ws, **kwargs)
            log(f"discover {label}: {len(cat)} URLs")
            entries.extend(cat)
        except TypeError:
            cat = mod.build(ws)
            log(f"discover {label}: {len(cat)} URLs")
            entries.extend(cat)
        except Exception as exc:  # noqa: BLE001
            log(f"discover {label} ERROR: {type(exc).__name__}: {exc}")

    try:
        papers = discover_cbse_papers(ws) + discover_cisce_papers(ws)
        log(f"discover papers: {len(papers)} URLs")
        entries.extend(papers)
    except Exception as exc:  # noqa: BLE001
        log(f"discover papers ERROR: {type(exc).__name__}: {exc}")

    # dedupe by source_url
    seen: set[str] = set()
    out: list[dict] = []
    for e in entries:
        url = e.get("source_url")
        if not url or url in seen:
            continue
        seen.add(url)
        out.append(e)
    return out


def _verified_urls(ws: Workspace) -> set[str]:
    master = load_json(ws.index("master"), {}) or {}
    return {
        e.get("source_url")
        for e in master.values()
        if e.get("verification_status") == "VERIFIED" and e.get("source_url")
    }


def fetch_one(ws: Workspace, entry: dict, engine, rules: dict, *, dry_run: bool) -> str:
    url = entry["source_url"]
    if url in _verified_urls(ws):
        return "SKIP_VERIFIED"
    pr = probe_url(url, referer=entry.get("source_portal"))
    if not pr["ok"]:
        return f"SKIP_PROBE_{pr['reason']}"
    if dry_run:
        return "WOULD_DOWNLOAD"
    ok, incoming, note = downloader._fetch(entry, ws, rules, allow_network=True)
    if not ok or not incoming:
        return f"FAIL_FETCH {note}"
    result = engine.verify_resource(entry, incoming)
    if result.status == "VERIFIED":
        return f"OK {result.final_path}"
    if result.status == "DUPLICATE":
        return f"OK_DUP {result.detail}"
    return f"FAIL_VERIFY {result.reason_code}"


def run(board: str, limit: int | None, dry_run: bool) -> dict:
    ws = Workspace(WORKSPACE_ROOT)
    rules = ws.config("download_rules")
    engine = get_engine(WORKSPACE_ROOT)
    allowed = BOARD_FILTER[board]

    log(f"=== fetch_all_direct START board={board} dry_run={dry_run} ===")
    entries = _build_catalogues(ws)
    entries = [e for e in entries if e.get("board") in allowed]
    log(f"total unique URLs to process: {len(entries)}")

    stats = {"total": len(entries), "ok": 0, "skip": 0, "fail": 0}
    for i, entry in enumerate(entries, 1):
        if limit is not None and stats["ok"] + stats["fail"] >= limit:
            break
        label = (f"[{i}/{len(entries)}] {entry.get('board')} {entry.get('class_label')} "
                 f"{entry.get('subject')} {entry.get('resource_category')}")
        try:
            outcome = fetch_one(ws, entry, engine, rules, dry_run=dry_run)
        except Exception as exc:  # noqa: BLE001
            outcome = f"ERROR {type(exc).__name__}: {exc}"
        log(f"{label} → {outcome}")
        if outcome.startswith("OK"):
            stats["ok"] += 1
        elif outcome.startswith("SKIP"):
            stats["skip"] += 1
        else:
            stats["fail"] += 1
        if not dry_run:
            time.sleep(rules["networking"].get("polite_delay_seconds", 2))

    engine.generate_report()
    log(f"=== DONE {stats} ===")
    return stats


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--board", choices=list(BOARD_FILTER), default="all")
    ap.add_argument("--limit", type=int, default=None)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    stats = run(args.board, args.limit, args.dry_run)
    print("stats:", stats)
    return 0 if stats["fail"] == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
