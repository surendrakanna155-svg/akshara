#!/usr/bin/env python3
"""Continuous DETERMINISTIC curriculum acquisition service (spec Parts 02/03/05/06).

This is the replacement for the retired broad crawler
(`scripts/crawler/` — see scripts/crawler/RETIRED.md). It does NOT crawl and does
NOT download every discovered PDF. It walks the canonical curriculum matrix only:

    Board → Class → Subject → Document Type → Download → Verify → Store → Update coverage

Each cycle:
  1. (idempotently) merges every resolved source catalogue into DOWNLOAD_QUEUE.json
     (NCERT + CBSE + AP + CISCE).  Only canonical-matrix cells — no circulars,
     notifications, tenders, or administrative documents.
  2. runs one downloader pass (allow_network=True): every fetched file is routed
     through the certified VerificationEngine (V1-V11); failures follow the
     recovery ladder (RETRY w/ backoff → RECORD_MISSING).
  3. regenerates the coverage matrix (progress = coverage, not PDF count) and
     updates the Mission Control dashboard.

It runs until the matrix converges: no cell has actionable work left and no retry
is scheduled, OR N consecutive cycles make no progress while work is still due
(stuck — reported honestly, never faked). Designed to run detached in the
background with no manual intervention.

Usage:
  run_acquisition.py [--max-cycles N] [--no-progress-limit K] [--cycle-pause S]
"""

from __future__ import annotations

import argparse
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve()
WORKSPACE_ROOT = HERE.parents[2]          # curriculum/
SCRIPTS = HERE.parents[1]                 # curriculum/scripts/
for sub in ("common", "download", "discovery", "reports"):
    p = str(SCRIPTS / sub)
    if p not in sys.path:
        sys.path.insert(0, p)

from workspace import Workspace, load_json, write_json, utcnow  # noqa: E402
import downloader  # noqa: E402
import coverage_matrix  # noqa: E402
import ncert_catalogue, cbse_catalogue, cbse_sqp_catalogue, ap_catalogue, cisce_catalogue, telangana_catalogue  # noqa: E402

DASHBOARD = WORKSPACE_ROOT.parents[0] / "tools" / "progress-dashboard"
LOG = WORKSPACE_ROOT / "acquisition" / "acquire_continuous.log"


def _now():
    return datetime.now(timezone.utc)


def log(msg: str) -> None:
    line = f"[{_now().strftime('%H:%M:%S')}] {msg}"
    print(line, flush=True)
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with LOG.open("a", encoding="utf-8") as fh:
        fh.write(line + "\n")


def build_queue(ws: Workspace, *, ap_probe: bool = False) -> int:
    """Idempotently merge every resolved source catalogue into the queue."""
    total_added = 0
    for mod in (ncert_catalogue, cbse_catalogue, cbse_sqp_catalogue, ap_catalogue, cisce_catalogue, telangana_catalogue):
        try:
            if mod is ap_catalogue:
                cat = mod.build(ws, probe=ap_probe)
            else:
                cat = mod.build(ws)
            added, _ = mod.merge_queue(ws, cat)
            total_added += added
        except Exception as exc:  # noqa: BLE001
            log(f"catalogue {mod.__name__} error: {type(exc).__name__}: {exc}")
    return total_added


def _due_analysis(ws: Workspace) -> tuple[int, int, datetime | None]:
    """Return (due_now, future_retry, soonest_future_retry)."""
    queue = load_json(ws.pm("download_queue"), []) or []
    now = _now()
    due_now = future = 0
    soonest = None
    for e in queue:
        st = e.get("status")
        if st in ("VERIFIED", "NOT_PUBLICLY_AVAILABLE", "FAILED"):
            continue
        if st == "RETRY_PENDING":
            nr = e.get("next_retry")
            when = None
            if nr:
                try:
                    when = datetime.strptime(nr, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
                except ValueError:
                    when = None
            if when and when > now:
                future += 1
                soonest = when if soonest is None or when < soonest else soonest
            else:
                due_now += 1
        else:  # PENDING / DOWNLOADED / SKIPPED
            due_now += 1
    return due_now, future, soonest


def verified_count(ws: Workspace) -> int:
    master = load_json(ws.index("master"), {}) or {}
    return sum(1 for e in master.values() if e.get("verification_status") == "VERIFIED")


COUNTERS = WORKSPACE_ROOT / "acquisition" / ".counters.json"


def update_counters(ws: Workspace, stats: dict) -> None:
    """Cumulative resource metrics: Downloaded / Rejected / Duplicates (Verified read live)."""
    c = load_json(COUNTERS, {}) or {}
    if not c.get("started_at"):
        c["started_at"] = utcnow()
    c["downloaded"] = c.get("downloaded", 0) + int(stats.get("processed", 0) or 0)
    c["rejected"] = c.get("rejected", 0) + int(stats.get("failed", 0) or 0)
    c["duplicates"] = c.get("duplicates", 0) + int(stats.get("duplicate", 0) or 0)
    c["updated_at"] = utcnow()
    write_json(COUNTERS, c)


def update_reports_and_dashboard(ws: Workspace) -> dict:
    data = coverage_matrix.compute(ws, ("A",))
    reports = ws.p("reports_dir")
    reports.mkdir(parents=True, exist_ok=True)
    (reports / "COVERAGE_MATRIX.md").write_text(coverage_matrix.render_md(data), encoding="utf-8")
    write_json(reports / "COVERAGE_MATRIX.json", data)

    # --- Mission Control acquisition.json (coverage-based, NOT pdf count) -----
    if DASHBOARD.is_dir():
        o = data["overall"]
        board_label = {"CBSE": "CBSE", "APSCERT": "AP SCERT", "TSSCERT": "TS SCERT", "CISCE": "CISCE"}
        boards = []
        for code, t in data["per_board"].items():
            s = t["by_state"]
            status = ("running" if s["DOWNLOADING"] or s["RETRY_SCHEDULED"]
                      else "complete" if t["coverage_pct"] >= 100
                      else "waiting" if s["UNRESOLVED"] and not s["VERIFIED"]
                      else "partial")
            boards.append({
                "id": code.lower(), "label": board_label.get(code, code),
                "expectedCells": t["total"], "verifiedCells": s["VERIFIED"],
                "downloading": s["DOWNLOADING"], "retry": s["RETRY_SCHEDULED"],
                "unresolved": s["UNRESOLVED"], "documentedGap": s["DOCUMENTED_GAP"],
                "coveragePct": t["coverage_pct"], "etaSeconds": t.get("eta_seconds", 0),
                "etaHuman": t.get("eta_human", "—"), "status": status,
            })
        write_json(DASHBOARD / "acquisition.json", {
            "schemaVersion": 3,
            "updatedAt": utcnow(),
            "strategy": "deterministic-matrix",
            "note": "Progress = curriculum coverage (verified cells / expected Priority-A matrix cells). NOT a PDF count. Verified is the success criterion.",
            "coverageBasis": "Board × Class × Subject × Document-Type; Priority-A curriculum content only",
            "denominator": data["denominator"],
            "provenance": data["provenance"]["by_tier"],
            "resourceMetrics": data["resource_metrics"],
            "etaHumanOverall": coverage_matrix._human(data["eta"]["eta_seconds_overall"]),
            "totals": {
                "expectedCells": o["total"], "verifiedCells": o["by_state"]["VERIFIED"],
                "downloading": o["by_state"]["DOWNLOADING"], "retry": o["by_state"]["RETRY_SCHEDULED"],
                "unresolved": o["by_state"]["UNRESOLVED"], "documentedGap": o["by_state"]["DOCUMENTED_GAP"],
            },
            "coveragePct": o["coverage_pct"],
            "boards": boards,
        })
    return data


def run(max_cycles: int, no_progress_limit: int, cycle_pause: float) -> dict:
    ws = Workspace(WORKSPACE_ROOT)
    log("=== deterministic acquisition service START ===")
    added = build_queue(ws, ap_probe=True)
    q = load_json(ws.pm("download_queue"), []) or []
    log(f"queue built: {len(q)} matrix cells ({added} newly merged)")

    prev_verified = verified_count(ws)
    no_progress = 0
    cycle = 0
    while cycle < max_cycles:
        cycle += 1
        try:
            stats = downloader.run(WORKSPACE_ROOT, allow_network=True)
        except Exception as exc:  # noqa: BLE001 — never let one pass kill the service
            log(f"cycle {cycle} downloader error: {type(exc).__name__}: {exc}")
            stats = {}
        update_counters(ws, stats)
        data = update_reports_and_dashboard(ws)
        vc = verified_count(ws)
        o = data["overall"]
        log(f"cycle {cycle} pass: {stats} | coverage {o['coverage_pct']}% "
            f"({o['by_state']['VERIFIED']} verified / {o['total']} cells) "
            f"| verified_resources={vc}")

        due_now, future, soonest = _due_analysis(ws)
        unresolved = o["by_state"]["UNRESOLVED"]
        accounted = o["accounted"]
        total = o["total"]
        # Converge only when every cell is VERIFIED or DOCUMENTED_GAP — not merely when
        # the download queue has no due items (653+ UNRESOLVED cells still need discovery).
        if due_now == 0 and future == 0 and accounted >= total:
            log(f"CONVERGED — all {total} cells accounted "
                f"(verified={o['by_state']['VERIFIED']} gap={o['by_state']['DOCUMENTED_GAP']}). "
                f"Service stopping.")
            break
        if due_now == 0 and future == 0 and unresolved > 0:
            log(f"no download work; {unresolved} UNRESOLVED cells remain — "
                f"re-running discovery next cycle (coverage {o['coverage_pct']}%)")
            time.sleep(max(cycle_pause * 5, 30.0))
            build_queue(ws, ap_probe=False)   # skip AP HEAD probes on rediscovery loops
            continue

        if vc > prev_verified:
            no_progress = 0
        elif due_now > 0:
            no_progress += 1
            if no_progress >= no_progress_limit:
                log(f"STOP — {no_progress} consecutive cycles with due work but no new "
                    f"verified resources (remaining are unreachable/failed). Reported honestly "
                    f"in the coverage matrix. due_now={due_now} future_retry={future}.")
                break
        prev_verified = vc

        if due_now == 0 and future > 0:
            wait = 30.0
            if soonest:
                wait = max(5.0, min((soonest - _now()).total_seconds(), 300.0))
            log(f"only future retries scheduled ({future}); waiting {wait:.0f}s for backoff")
            time.sleep(wait)
        else:
            time.sleep(cycle_pause)

    data = update_reports_and_dashboard(ws)
    o = data["overall"]
    log(f"=== SERVICE END === coverage {o['coverage_pct']}% "
        f"(verified={o['by_state']['VERIFIED']} downloading={o['by_state']['DOWNLOADING']} "
        f"retry={o['by_state']['RETRY_SCHEDULED']} unresolved={o['by_state']['UNRESOLVED']} "
        f"gap={o['by_state']['DOCUMENTED_GAP']} / {o['total']} cells)")
    return data


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--max-cycles", type=int, default=300)
    ap.add_argument("--no-progress-limit", type=int, default=3)
    ap.add_argument("--cycle-pause", type=float, default=3.0)
    args = ap.parse_args()
    run(args.max_cycles, args.no_progress_limit, args.cycle_pause)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
