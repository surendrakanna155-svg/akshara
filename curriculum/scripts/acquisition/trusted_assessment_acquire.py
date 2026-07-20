#!/usr/bin/env python3
"""Trusted third-party assessment acquisition wave — controlled provenance expansion.

Runs after official/government/public assessment paths are exhausted. Discovers from
the trusted allowlist (AglaSem), downloads immediately, verifies, deduplicates, and
regenerates provenance + assessment coverage reports.

Never upgrades third-party files to official status. Storage is isolated under
Trusted_Third_Party_Assessment/ per board/class/subject.

Usage:
  trusted_assessment_acquire.py [--workspace DIR] [--board all|ap|cbse|telangana]
                                [--limit N] [--discover-only] [--fast] [--workers N]
"""
from __future__ import annotations

import argparse
import sys
import time
from collections import Counter
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

HERE = Path(__file__).resolve()
WORKSPACE_ROOT = HERE.parents[2]
SCRIPTS = HERE.parents[1]
for sub in ("common", "download", "discovery", "acquisition", "reports"):
    p = str(SCRIPTS / sub)
    if p not in sys.path:
        sys.path.insert(0, p)

from workspace import Workspace, get_engine, load_json, utcnow, write_json  # noqa: E402
from provenance_tier import TIER_TRUSTED_THIRD_PARTY, license_to_tier  # noqa: E402
import immediate_acquire  # noqa: E402
import trusted_assessment_catalogue as tac  # noqa: E402
import build_provenance  # noqa: E402
import assessment_evidence_matrix as aem  # noqa: E402

LOG = WORKSPACE_ROOT / "acquisition" / "trusted_assessment.log"

BOARD_CHOICES = {
    "all": {"ap", "cbse", "telangana"},
    "ap": {"ap"},
    "cbse": {"cbse"},
    "telangana": {"telangana"},
}


def log(msg: str) -> None:
    line = f"[{utcnow()}] {msg}"
    print(line, flush=True)
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with LOG.open("a", encoding="utf-8") as fh:
        fh.write(line + "\n")


def _existing_trusted_urls(ws: Workspace) -> set[str]:
    urls: set[str] = set()
    for row in load_json(ws.pm("completed_downloads"), []) or []:
        if license_to_tier(row.get("license_status")) == TIER_TRUSTED_THIRD_PARTY:
            if row.get("source_url"):
                urls.add(row["source_url"])
    for row in load_json(ws.pm("download_queue"), []) or []:
        if row.get("provenance_tier") == TIER_TRUSTED_THIRD_PARTY and row.get("source_url"):
            urls.add(row["source_url"])
    return urls


def _download_parallel(
    ws: Workspace,
    entries: list[dict],
    *,
    workers: int,
    existing: set[str],
    limit: int | None,
) -> Counter:
    stats: Counter = Counter()
    engine = get_engine(ws.root)
    pending = [e for e in entries if e["source_url"] not in existing]
    if limit is not None:
        pending = pending[:limit]

    def _one(entry: dict) -> tuple[str, dict]:
        outcome = immediate_acquire.acquire_one(ws, entry, engine, allow_network=True, fast=True)
        return outcome, entry

    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = [pool.submit(_one, e) for e in pending]
        for fut in as_completed(futures):
            outcome, entry = fut.result()
            stats[outcome] += 1
            if outcome == "VERIFIED":
                log(
                    f"OK T3P {entry['board']} {entry['class_label']} {entry['subject']} "
                    f"{entry['assessment_subtype']} -> {entry['expected_filename']}"
                )
    return stats


def run(
    ws: Workspace,
    *,
    board: str,
    limit: int | None,
    discover_only: bool,
    fast: bool,
    workers: int,
) -> dict:
    boards = BOARD_CHOICES[board]
    log(
        f"TRUSTED ASSESSMENT WAVE start boards={boards} "
        f"fast={fast} workers={workers} policy=controlled_provenance_expansion"
    )

    existing = _existing_trusted_urls(ws)
    catalogue: list[dict] = []
    stats: Counter = Counter()

    if fast and boards <= {"ap", "cbse"}:
        log(f"FAST: direct URLs + parallel probe boards={boards}")
        catalogue = tac.discover_all_parallel(ws, boards=boards, workers=workers)
        log(f"discovered {len(catalogue)} trusted assessment PDFs")
    elif fast:
        log("FAST: parallel stream skipped for multi-board — use --board ap for speed")
        for entry in tac.discover_stream(ws, boards=boards):
            catalogue.append(entry)
    else:
        log("stream mode: crawl page → find PDF → download immediately")
        for entry in tac.discover_stream(ws, boards=boards):
            catalogue.append(entry)
            if discover_only:
                if limit is not None and len(catalogue) >= limit:
                    break
                continue
            if entry["source_url"] in existing:
                stats["SKIP_EXISTING"] += 1
                continue
            outcome = immediate_acquire.acquire_one(
                ws, entry, get_engine(ws.root), allow_network=True, fast=True,
            )
            stats[outcome] += 1
            if outcome == "VERIFIED":
                log(
                    f"OK T3P {entry['board']} {entry['class_label']} {entry['subject']} "
                    f"{entry['assessment_subtype']} -> {entry['expected_filename']}"
                )

    out = ws.p("discovery_dir") / "trusted_assessment_catalogue.json"
    write_json(out, {
        "generated_at": utcnow(),
        "policy": "controlled_provenance_expansion_assessment_only",
        "provenance_tier": TIER_TRUSTED_THIRD_PARTY,
        "documents": catalogue,
    })

    tac.merge_queue(ws, catalogue)

    if not discover_only and fast:
        stats.update(_download_parallel(ws, catalogue, workers=workers, existing=existing, limit=limit))

    manifest = build_provenance.build(ws)
    write_json(ws.root / "PROVENANCE_MANIFEST.json", manifest)

    matrix = aem.build(ws)
    matrix_out = ws.p("reports_dir") / "ASSESSMENT_EVIDENCE_MATRIX.json"
    write_json(matrix_out, matrix)

    t3p_resources = [r for r in manifest["resources"] if r.get("provenance_tier") == TIER_TRUSTED_THIRD_PARTY]

    report = {
        "generated_at": utcnow(),
        "mode": "TRUSTED_ASSESSMENT_ACQUIRE_FAST" if fast else "TRUSTED_ASSESSMENT_ACQUIRE",
        "policy": "controlled_provenance_expansion_assessment_only",
        "boards": sorted(boards),
        "discovered": len(catalogue),
        "download_stats": dict(stats),
        "provenance_totals": {
            "verified_resources": manifest["totals"]["verified_resources"],
            "by_provenance_tier": dict(manifest["totals"].get("by_provenance_tier", {})),
            "trusted_third_party_assessment_count": len(t3p_resources),
            "trusted_third_party_bytes": sum(r.get("bytes") or 0 for r in t3p_resources),
        },
        "assessment_matrix": {
            "cell_count": matrix["cell_count"],
            "cells_with_official_evidence": matrix.get("cells_with_official_evidence", 0),
            "cells_with_trusted_third_party_evidence": matrix.get("cells_with_trusted_third_party_evidence", 0),
            "cells_with_any_evidence": matrix.get("cells_with_any_evidence", 0),
            "cells_missing_all_evidence": matrix.get("cells_missing_all_evidence", 0),
        },
        "never_upgrade_to_official": True,
    }
    report_out = ws.p("reports_dir") / "TRUSTED_ASSESSMENT_PROVENANCE_REPORT.json"
    write_json(report_out, report)

    log(f"DONE stats={dict(stats)} t3p={len(t3p_resources)} matrix_any={matrix.get('cells_with_any_evidence')}")
    log(f"reports: {report_out} | {matrix_out}")
    return report


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--workspace", type=Path, default=WORKSPACE_ROOT)
    ap.add_argument("--board", default="ap", choices=list(BOARD_CHOICES))
    ap.add_argument("--limit", type=int, default=None)
    ap.add_argument("--discover-only", action="store_true")
    ap.add_argument("--fast", action="store_true", default=True)
    ap.add_argument("--no-fast", action="store_false", dest="fast")
    ap.add_argument("--workers", type=int, default=8)
    args = ap.parse_args()
    ws = Workspace(args.workspace)
    run(
        ws,
        board=args.board,
        limit=args.limit,
        discover_only=args.discover_only,
        fast=args.fast,
        workers=args.workers,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
